# Lingoda Task 1 - Symfony Demo App in Kubernetes

This project demonstrates how to deploy the official [Symfony Demo](https://github.com/symfony/demo) application to a Kubernetes cluster using Docker and YAML manifests.

---

## Prerequisites

- Docker
- Minikube (or compatible Kubernetes cluster)
- kubectl

---

## Build Images (inside Minikube)

Make sure you're building images **inside the Minikube Docker environment**:

```bash
eval $(minikube docker-env)

docker build -t symfony-php:latest -f Dockerfile .
docker build -t symfony-nginx:latest -f Dockerfile.nginx .
```

## Create Kubernetes Secret

Note: You must create this secret manually. It is not stored in Git for security reasons.

Create the `APP_SECRET` as a Kubernetes Secret outside the repository:

## Deploy to Kubernetes

```bash
kubectl apply -f k8s/namespace.yaml
kubectl -n symfony-demo apply -f k8s/php-deployment.yaml
kubectl -n symfony-demo apply -f k8s/nginx-deployment.yaml
kubectl -n symfony-demo apply -f k8s/services.yaml
```

## Access the App

Start the Minikube tunnel:
```
minikube tunnel
```

Then open the Symfony app in your browser:
```
minikube service -n symfony-demo nginx
```

## ToDo

* Ask an user to create a Secret in advance and don't store the secret in git
* Move images to Docker Hub/JFrog Artifactory instead of building locally
* Use standard nginx image instead of custom one and just pass the config
* Add healthcheck probes
* Use multi-stage Docker builds to make the image smaller and secure
* Do not use a root user to run the app

