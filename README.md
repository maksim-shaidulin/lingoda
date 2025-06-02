# Lingoda Task 1 - Symfony Demo App in Kubernetes

This project demonstrates how to deploy the official [Symfony Demo](https://github.com/symfony/demo) application to a Kubernetes cluster using Docker and YAML manifests.

---

## Prerequisites

- Docker
- Minikube (or compatible Kubernetes cluster)
- kubectl

---

## Build Images

To deploy and run the demo application you need create a Docker image. 

In case of using local Minikube the images keep locally, all you need is to build them and Kubernetes will pull them automatically. If you use a remote Docker registry, you have to push the image to your registry and update the lines `image: symfony-php:v2.7.0` in `php-deployment.yaml` and `db-migration-job.yaml` to point to a correct registry and repository.

For Minikube environment first run this command:
```bash
eval $(minikube docker-env)
```

Use the provided `build.sh` script to build Docker images for the Symfony application and Nginx. You can specify the Symfony version tag (e.g., `v2.7.0`) as an argument. If no version is provided, it defaults to `v2.7.0`.

**Usage:**
```bash
./build.sh v2.7.0
```
or simply:
```bash
./build.sh
```
This will build the images `symfony-php:v2.7.0` and `symfony-nginx:latest`.


## Create Kubernetes Secret

Symfony requires an application password to be provided. As we can't store secrets in git, you have to define it as Kubernetes Secret in advance.

Create the `APP_SECRET` as a Kubernetes Secret:
```bash
kubectl -n symfony-demo create secret generic symfony-secret --from-literal=APP_SECRET=<your-secret>
```

You can generate the password on the fly as random chars:
```bash
kubectl -n symfony-demo create secret generic symfony-secret --from-literal=APP_SECRET=$(openssl rand -hex 16)
```

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
1. Run a DB migration that updates schema, but don't break the existing code. For instance if you need to add a non-nullable column, alter the table and add this column as nullable.
2. Run a script to set a value to this column in all the existing rows.
3. Deploy the new version of the application that works with this new column.
4. Once all instances of new application is deployed, it is safe to alter the table and make the column not-nullable using new migration.

To run database schema migrations before starting the application:
```bash
kubectl -n symfony-demo apply -f k8s/db-migration-job.yaml
kubectl -n symfony-demo wait --for=condition=complete job/db-migrate
```

If the migration task will fail, Kubernetes will try to run it one more time.

If you need to rerun the job:
```bash
kubectl -n symfony-demo delete job db-migrate
kubectl -n symfony-demo apply -f k8s/db-migration-job.yaml
```

## Upgrading to a New Version of the Application

To upgrade the Symfony Demo application to a new version, follow these steps:
1. Build the Docker images for the new version, e.g. `v2.8.0` see [Build Images](#build-images).
2. Update the Kubernetes Manifests. Edit your deployment files (e.g., `k8s/php-deployment.yaml` and `k8s/db-migration-job.yaml`) and update the `image` field to use the new tag.
3. Apply Database Migrations (if needed). See [Database migrations](#database-migrations).
4. Deploy the New Application Version. See [Deploy to Kubernetes](#deploy-to-kubernetes).
5. Verify the Upgrade. Use `kubectl get pods` and `kubectl get services` to check the status of your deployment.


## ToDo/Considerations

* [X] Ask an user to create a Secret in advance and don't store the secret in git
* [ ] Move images to Docker Hub/JFrog Artifactory instead of building locally
* [ ] Use standard nginx image instead of custom one and just pass the config
* [ ] Add health check probes
* [ ] Use multi-stage Docker builds to make the image smaller and secure
* [ ] Do not use a root user to run the app
* [ ] Migrate to Helm and use hooks to run DB migrations automatically
* [ ] Keep the Symfony version in one place my using Helm or Kustomize

