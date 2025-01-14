# Create a kubernetes cluster in Docker
kind create cluster --config=kubernetes/kind-cluster.yaml

# Install nginx as ingress controller
#kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
#helm install my-release oci://ghcr.io/nginxinc/charts/nginx-ingress --version 2.0.0

# Initialize helm repos
helm repo add traefik https://traefik.github.io/charts
helm repo add minio-operator https://operator.min.io
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update

# Alternative: Install traefik as ingress controller with Loadbalancer
helm upgrade -n traefik --create-namespace --install traefik traefik/traefik -f kubernetes/k8s-traefik.yaml

# Install minio


# Create a namespace called "confluent" and switch to it
kubectl create namespace confluent
kubectl config set-context --current --namespace confluent

# Add the Confluent repo to the helm package manager and update it

# Install the operator of Confluent for Kubernetes

helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes
kubectl apply -f confluent/platform/confluent-platform.yaml
