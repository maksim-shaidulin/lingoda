#!/bin/bash
set -e

CUR_DIR=$(dirname "$0")
cd "$CUR_DIR/.."

NAMESPACE="symfony-demo"
K8S_DIR="k8s"

echo "Creating namespace $NAMESPACE if it doesn't exist..."
kubectl -n $NAMESPACE apply -f $K8S_DIR/namespace.yaml

# Create the APP_SECRET secret if it does not exist
if ! kubectl -n $NAMESPACE get secret symfony-secret >/dev/null 2>&1; then
  echo "You did't provide the symfony-secret, creating one with random value..."
  kubectl -n $NAMESPACE create secret generic symfony-secret --from-literal=APP_SECRET=$(openssl rand -hex 16)
fi


echo "Saving nginx configuration as ConfigMap..."
kubectl -n $NAMESPACE create configmap nginx-config --from-file=default.conf=docker/nginx/default.conf --dry-run=client -o yaml | kubectl apply -f -

echo "Running database migration job..."
kubectl -n $NAMESPACE delete job db-migrate --ignore-not-found
kubectl -n $NAMESPACE apply -f $K8S_DIR/db-migration-job.yaml
# commented out the wait command because migrations are not exists yet
# kubectl -n $NAMESPACE wait --for=condition=complete job/db-migrate

echo "Applying deployments and services..."
kubectl -n $NAMESPACE apply -f $K8S_DIR/php-deployment.yaml
kubectl -n $NAMESPACE apply -f $K8S_DIR/nginx-deployment.yaml
kubectl -n $NAMESPACE apply -f $K8S_DIR/services.yaml
kubectl -n $NAMESPACE apply -f $K8S_DIR/hpa.yaml

echo "Deployment complete."