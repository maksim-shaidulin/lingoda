#!/bin/bash
set -e

CUR_DIR=$(dirname "$0")
cd "$CUR_DIR/.."

NAMESPACE="symfony-demo"
K8S_DIR="k8s"

# 1. Create or update the nginx config ConfigMap
echo "Applying nginx.conf as ConfigMap..."
kubectl -n $NAMESPACE create configmap nginx-config --from-file=nginx.conf=nginx.conf --dry-run=client -o yaml | kubectl apply -f -

# 2. Apply all Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f $K8S_DIR/namespace.yaml

# 3. Run and wait the completion of the database migration job
echo "Running database migration job..."
kubectl -n $NAMESPACE delete job db-migrate --ignore-not-found
kubectl -n $NAMESPACE apply -f $K8S_DIR/db-migration-job.yaml
# commented out the wait command because migrations are not exists yet
# kubectl -n $NAMESPACE wait --for=condition=complete job/db-migrate

# 4. Apply the deployments and services
echo "Applying deployments and services..."
kubectl -n $NAMESPACE apply -f $K8S_DIR/php-deployment.yaml
kubectl -n $NAMESPACE apply -f $K8S_DIR/nginx-deployment.yaml
kubectl -n $NAMESPACE apply -f $K8S_DIR/services.yaml

echo "Deployment complete."