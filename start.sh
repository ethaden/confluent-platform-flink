# Create a kubernetes cluster in Docker (using standard registries directly from the internet)
kind create cluster --config=kubernetes/kind-cluster.yaml
# Comment the previously line and uncomment the following if using a local container image mirror
# We need to update two things: First, the `kind` command must pull its base image from the mirror.
# This is done by explicitly stating the image with full path on the command line (see below `kind create cluster ...`).
# Second, `kind` uses the internal service `containerd` for fetching images, by default directly from the internet.
# We need to configure containerd to use the mirror instead. 
# Make sure to customize `hosts.toml` files in `custom-registry/certs.d according to your setup
# Each subfolder contains the settings for a specific container image domain (i.e. docker.io, quay.io and k8s.io).
# In our example, we set up a mirror in the `custom-registry/docker-nexus-proxy` folder 
# and make three separate repository mirrors available inside of docker,
# One for each of the registries mentioned above.
# These `hosts.toml` file configure the internal containerd instance which is included in `kind` such that all requests to the specified registries
# are sent to the configured local mirrors instead. You need one mirror for each registry, i.e. docker.io, quay.io and k8s.io.
# You can configure each of them to listen on a unique port.
# NOTE: The base images used by kind (e.g. coredns) are included in kind directly. They are NOT pulled from the internet.

# TODO: Please update the URL to point to your real container image mirror.
# NOTE: In the next line we assume our image mirror (e.g. nexus) is listening for requests for images from docker.io on locahost, Port 15001
#export KIND_MIRROR_IMAGE=localhost:15001/kindest/node:v1.35.0
#kind create cluster --config=kubernetes/kind-cluster-with-local-image-registry.yaml --image $KIND_MIRROR_IMAGE

# Install nginx as ingress controller
#kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
#helm install my-release oci://ghcr.io/nginxinc/charts/nginx-ingress --version 2.0.0

# Initialize helm repos
helm repo add traefik https://traefik.github.io/charts
helm repo add rustfs https://rustfs.github.io/helm/
helm repo add confluentinc https://packages.confluent.io/helm
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update

# Optional: Pin Helm versions
HELM_VERSION_FLAG_TRAEFIK="--version 41.0.0"
HELM_VERSION_FLAG_RUSTFS="--version 0.8.0"
HELM_VERSION_FLAG_CERTMANAGER="--version v1.20.2"
HELM_VERSION_FLAG_CONFLUENT_FOR_KUBERNETES="--version 0.1514.40"
HELM_VERSION_FLAG_CONFLUENT_MANAGER_FOR_FLINK="--version 2.3.0"
HELM_VERSION_FLAG_FLINK_OPERATOR="--version 1.140.1"

# Alternative: Install traefik as ingress controller with Loadbalancer
helm upgrade -n traefik --create-namespace --install traefik traefik/traefik $HELM_VERSION_FLAG_TRAEFIK -f kubernetes/helm-traefik.yaml

# Install RustFS as minio is not maintained anymore
helm upgrade -n rustfs --create-namespace --install rustfs rustfs/rustfs $HELM_VERSION_FLAG_RUSTFS -f kubernetes/helm-rustfs.yaml
kubectl create namespace rustfs-flink
kubectl -n rustfs-flink apply -f kubernetes/k8s-rustfs-flink-tenant.yaml
#helm upgrade -n minio-operator --create-namespace --install minio-operator minio-operator/operator -f kubernetes/k8s-minio-operator.yaml
# Install a minio tenant for flink
#helm upgrade -n minio-flink --create-namespace --install  minio-flink minio-operator/tenant -f kubernetes/k8s-minio-flink.yaml

# Create a namespace called "confluent" and switch to it
kubectl create namespace confluent
kubectl config set-context --current --namespace confluent

# Configure bearer access to the Confluent Platform Metadata Service with username "kafka", password "kafka":
kubectl create secret generic c3-mds-client \
  --from-file=bearer.txt=confluent/platform/mds-credentials.txt \
  --namespace confluent

# Install the operator of Confluent for Kubernetes

helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes \
  $HELM_VERSION_FLAG_CONFLUENT_FOR_KUBERNETES
# Install a CP cluster: Please check versions of images used by the custom resources in the yaml file
kubectl apply -f confluent/platform/confluent-platform.yaml

# Install cert-manager
helm upgrade --install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  $HELM_VERSION_FLAG_CERTMANAGER \
  --set crds.enabled=true

# Install the Confluent Platform for Apache Flink Kubernetes operator
kubectl create namespace flink
helm upgrade -n flink-operator --create-namespace --install cp-flink-kubernetes-operator \
confluentinc/flink-kubernetes-operator $HELM_VERSION_FLAG_FLINK_OPERATOR -f kubernetes/k8s-flink-kubernetes-operator.yaml

# Install Confluent Manger for Apache Flink (using version 2.3.0 due to an issue with 2.3.1)
helm upgrade --create-namespace --install cmf \
confluentinc/confluent-manager-for-apache-flink $HELM_VERSION_FLAG_CONFLUENT_MANAGER_FOR_FLINK \
--namespace flink -f kubernetes/k8s-confluent-manager-for-apache-flink.yaml

# Create a service account for managing flink resources
#kubectl -n flink create serviceaccount flink-service-account
#kubectl create clusterrolebinding flink-role-binding-flink --clusterrole=edit --serviceaccount=default:flink-service-account

kubectl -n flink apply -f kubernetes/k8s-flink-ingress.yaml

kubectl create namespace flink-my-environment
# We need to wait until Flink is available...
URL="http://flink/cmf/api/v1/environments"
TIMEOUT_SECS=300
INTERVAL_SECS=5
CONTINUE=0

# Calculate expiration time
END_TIME=$((SECONDS + TIMEOUT_SECS))

echo "Polling $URL for up to ${TIMEOUT_SECS}s..."

while [ $SECONDS -lt $END_TIME -a $CONTINUE -ne 1 ]; do
    # Fetch HTTP status code only
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
    
    # Exit loop if status is anything other than 503
    if [ "$STATUS" != "503" -a "$STATUS" != "404" ]; then
        echo "Finished waiting. Final status code: $STATUS"

        curl -H "Content-Type: application/json" \
          -X POST http://flink/cmf/api/v1/catalogs/kafka \
          -d@kubernetes/rest-flink-my-catalog.json

        curl -H "Content-Type: application/json" \
          -X POST http://flink/cmf/api/v1/environments \
          -d@kubernetes/rest-flink-my-environment.json

        curl -v -H "Content-Type: application/json" \
        -X POST http://flink/cmf/api/v1/environments/myenv/compute-pools \
        -d@kubernetes/rest-flink-my-compute-pool.json
        
        curl -H "Content-Type: application/json" \
          -X POST http://flink/cmf/api/v1/catalogs/kafka/mycatalog/databases \
          -d@kubernetes/rest-flink-my-database.json

        CONTINUE=1
    fi
    
    echo "Waiting for Confluent Manager for Apache Flink (received $STATUS). Retrying in ${INTERVAL_SECS}s..."
    sleep "$INTERVAL_SECS"
done

# For deleting resources (we are NOT actually running these here. They are just provided for convenience)
if [ 1 -eq 0 ]; then
  curl -H "Content-Type: application/json" -X DELETE http://flink/cmf/api/v1/catalogs/kafka/mycatalog/databases/mykafka
  curl -H "Content-Type: application/json" -X DELETE http://flink/cmf/api/v1/environments/myenv/compute-pools/mypool
  curl -H "Content-Type: application/json" -X DELETE http://flink/cmf/api/v1/environments/myenv
  curl -H "Content-Type: application/json" -X DELETE http://flink/cmf/api/v1/catalogs/kafka/mycatalog
fi

if [ $CONTINUE -ne 1 ]; then
  echo "Error: Timeout reached before endpoint recovered."
  exit 1
fi

# Create topic "orders" and datagen connector
kubectl apply -f kubernetes/k8s-connector-datagen-orders.yaml

