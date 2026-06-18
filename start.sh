# Create a kubernetes cluster in Docker
kind create cluster --config=kubernetes/kind-cluster.yaml

# Install nginx as ingress controller
#kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
#helm install my-release oci://ghcr.io/nginxinc/charts/nginx-ingress --version 2.0.0

# Initialize helm repos
helm repo add traefik https://traefik.github.io/charts
helm repo add rustfs https://rustfs.github.io/helm/
helm repo add confluentinc https://packages.confluent.io/helm
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update

# Alternative: Install traefik as ingress controller with Loadbalancer
helm upgrade -n traefik --create-namespace --install traefik traefik/traefik -f kubernetes/k8s-traefik.yaml

# Install RustFS as minio is not maintained anymore
helm upgrade -n rustfs --create-namespace --install rustfs rustfs/rustfs -f kubernetes/k8s-rustfs.yaml
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

helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes
# Install a CP cluster
kubectl apply -f confluent/platform/confluent-platform.yaml

# Install cert-manager
helm upgrade --install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.20.2 \
  --set crds.enabled=true

# Install the Confluent Platform for Apache Flink Kubernetes operator
kubectl create namespace flink
helm upgrade -n flink-operator --create-namespace --install cp-flink-kubernetes-operator \
confluentinc/flink-kubernetes-operator -f kubernetes/k8s-flink-kubernetes-operator.yaml

# Install Confluent Manger for Apache Flink (using version 2.3.0 due to an issue with 2.3.1)
helm upgrade --create-namespace --install cmf \
confluentinc/confluent-manager-for-apache-flink --version 2.3.0 \
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

# Calculate expiration time
END_TIME=$((SECONDS + TIMEOUT_SECS))

echo "Polling $URL for up to ${TIMEOUT_SECS}s..."

while [ $SECONDS -lt $END_TIME ]; do
    # Fetch HTTP status code only
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
    
    # Exit loop if status is anything other than 503
    if [ "$STATUS" != "503" -a "$STATUS" != "404" ]; then
        echo "Finished waiting. Final status code: $STATUS"
        curl -H "Content-Type: application/json" \
          -X POST http://flink/cmf/api/v1/environments \
          -d@kubernetes/rest-flink-my-environment.json

        curl -v -H "Content-Type: application/json" \
        -X POST http://flink/cmf/api/v1/environments/my-environment/compute-pools \
        -d@kubernetes/rest-flink-my-compute-pool.json
        
        curl -H "Content-Type: application/json" \
          -X POST http://flink/cmf/api/v1/catalogs/kafka \
          -d@kubernetes/rest-flink-my-catalog.json

        curl -H "Content-Type: application/json" \
          -X POST http://flink/cmf/api/v1/catalogs/kafka/my-kafka-catalog/databases \
          -d@kubernetes/rest-flink-my-database.json

        exit 0
    fi
    
    echo "Waiting for Confluent Manager for Apache Flink (received $STATUS). Retrying in ${INTERVAL_SECS}s..."
    sleep "$INTERVAL_SECS"
done

echo "Error: Timeout reached before endpoint recovered."
exit 1
