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

## Access the Application

Start the Minikube tunnel:
```bash
minikube tunnel
```

Then open the Symfony app in your browser:
```bash
minikube service -n symfony-demo nginx
```

## Database migrations

All the DB changes that may break the existing code should follow the [expand and contract pattern](https://blog.thepete.net/blog/2023/12/05/expand/contract-making-a-breaking-change-without-a-big-bang/).

Such changes should be applied in the following sequence:
#. Run a DB migration that updates schema, but don't break the existing code. For instance if you need to add a non-nullable column, alter the table and add this column as nullable.
#. Run a script to set a value to this column in all the existing rows.
#. Deploy the new version of the application that works with this new column.
#. Once all instances of new application is deployed, it is safe to alter the table and make the column not-nullable using new migration.

To run database schema migrations before starting the application:
```bash
kubectl -n symfony-demo apply -f k8s/db-migration-job.yaml
kubectl -n symfony-demo wait --for=condition=complete job/db-migrate
```

If you need to rerun the job:
```bash
kubectl -n symfony-demo delete job db-migrate
kubectl -n symfony-demo apply -f k8s/db-migration-job.yaml
```

## ToDo/Considerations

* Ask an user to create a Secret in advance and don't store the secret in git
* Move images to Docker Hub/JFrog Artifactory instead of building locally
* Use standard nginx image instead of custom one and just pass the config
* Add healthcheck probes
* Use multi-stage Docker builds to make the image smaller and secure
* Do not use a root user to run the app
* Migrate to Helm and use hooks to run DB migrations automatically
