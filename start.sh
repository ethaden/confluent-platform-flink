# Create a kubernetes cluster in Docker
kind create cluster --config=kubernetes/kind-cluster.yaml

# Install nginx as ingress controller
#kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
#helm install my-release oci://ghcr.io/nginxinc/charts/nginx-ingress --version 2.0.0

# Initialize helm repos
helm repo add traefik https://traefik.github.io/charts
helm repo add minio-operator https://operator.min.io
helm repo add confluentinc https://packages.confluent.io/helm
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update

# Alternative: Install traefik as ingress controller with Loadbalancer
helm upgrade -n traefik --create-namespace --install traefik traefik/traefik -f kubernetes/k8s-traefik.yaml

# Install minio operator
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
  --version v1.16.2 \
  --set crds.enabled=true

# Install the Confluent Platform for Apache Flink Kubernetes operator
helm upgrade -n flink-operator --create-namespace --install cp-flink-kubernetes-operator confluentinc/flink-kubernetes-operator

# Install Confluent Manger for Apache Flink
helm upgrade --create-namespace --install cmf \
confluentinc/confluent-manager-for-apache-flink \
--namespace flink
