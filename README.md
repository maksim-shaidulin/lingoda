# Lingoda - Symfony Demo App in Kubernetes

This project demonstrates how to deploy the official [Symfony Demo](https://github.com/symfony/demo) application to a Kubernetes cluster using Docker and YAML manifests.

## Notes for Lingoda

There was a set of changes done to complete all 3 tasks. The code in main branch contains the result of all 3 tasks. All feature branches were merged to the main branch via PRs.

**Task 1: Deploy Symfony Demo App in Kubernetes**

The source code of this initial implementation is in the branch https://github.com/maksim-shaidulin/lingoda/tree/task1. 

**Task 2: Implement Database Migrations**

I did some improvements, added DB migration documentation and code, see here: https://github.com/maksim-shaidulin/lingoda/tree/task2

**Task 3: Scaling Concerns and Implementations**

I rebuild the file structure, added build and deploy scripts and implemented horizontal scaling and update strategy, see https://github.com/maksim-shaidulin/lingoda/tree/task3 or the main branch.

---

## Prerequisites

- Docker
- Minikube (or compatible Kubernetes cluster)
- kubectl
- metrics-server addon enables for autoscaling

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

## Create Kubernetes Secret

Symfony requires an application password to be provided. As we can't store secrets in git, you have to define it as Kubernetes Secret in advance. If you don't create this secret in `symfony-demo` namespace, it will be automatically created by `scripts/deploy.sh` script with random value.

Create the `APP_SECRET` as a Kubernetes Secret:
```bash
# create a symfony-demo namespace if it does not exists
kubectl apply -f k8s/namespace.yaml
kubectl -n symfony-demo create secret generic symfony-secret --from-literal=APP_SECRET=<your-secret>
```

## Deploy to Kubernetes

The script `scripts/deploy.sh` runs the database migration and deploys the application.
```bash
scripts/deploy.sh
```

## Access the Application

If you use Minikube, start the Minikube tunnel:
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

The script `scripts/deploy.sh` runs the database migration before upgrading the application.

If you need to run a database migration manually, use these commands to recreate the migration Job and wait until migration completion:
```bash
kubectl -n symfony-demo delete job db-migrate --ignore-not-found
kubectl -n symfony-demo apply -f k8s/db-migration-job.yaml
kubectl -n symfony-demo wait --for=condition=complete job/db-migrate
```

If the migration task fails, Kubernetes will try to run it one more time.

If you need to rerun the job:
```bash
kubectl -n symfony-demo apply -f k8s/db-migration-job.yaml
```

## Upgrading to a new version of the Application

To upgrade the Symfony Demo application to a new version, follow these steps:
1. Build the Docker images for the new version, e.g. `v2.8.0` see [Build Images](#build-images).
2. Update the Kubernetes Manifests. Edit your deployment files (e.g., `k8s/php-deployment.yaml` and `k8s/db-migration-job.yaml`) to update the `image` field to use the new tag `v2.8.0`.
3. Deploy the New Application Version. See [Deploy to Kubernetes](#deploy-to-kubernetes).
4. Verify the Upgrade. Use `kubectl get pods` and `kubectl get services` to check the status of your deployment.


## Horizontal scaling

The application uses a Horizontal Pod Autoscaler (HPA) to scale PHP pods based on CPU usage.

`k8s/hpa.yaml` contains default settings:
| Setting                | Value                | Description                                      |
|------------------------|----------------------|--------------------------------------------------|
| minReplicas            | 2                    | Minimum number of application pods               |
| maxReplicas            | 10                   | Maximum number of application pods               |
| averageUtilization     | 50                   | Target average CPU utilization (%) for autoscale |

You can check the autoscaler status with:
```bash
kubectl get hpa -n symfony-demo
```
> **Warning:**  
> The metrics server must be enabled for autoscaling to work.  
> If you use Minikube, run:
> ```bash
> minikube addons enable metrics-server
> ```

## Scaling Concerns

### Application Layer

The current application is deployed as a stateless PHP service behind Nginx. Initially, it ran with a fixed number of replicas, which limited scalability and fault tolerance.

To address this, a Horizontal Pod Autoscaler (HPA) is used that dynamically adjusts the number of PHP pods based on CPU utilization. This ensures:

- Efficient resource usage under variable load.
- Improved availability and responsiveness under high traffic.
- Elimination of manual replica management.

Health probes are configured for the Nginx layer to ensure that only healthy pods serve traffic. The PHP deployment no longer defines a fixed replica count — HPA fully controls scaling within defined limits (`minReplicas: 2`, `maxReplicas: 10`, `averageUtilization: 50%`).

In addition, the application deployment uses a `RollingUpdate` strategy with `maxSurge: 1` and `maxUnavailable: 0`. This ensures that during upgrades, one additional pod is created temporarily while none of the existing pods are taken offline. This guarantees zero downtime and maintains full availability throughout the deployment process.

### Database Layer

The current database implementation uses SQLite, which introduces serious scalability and reliability limitations:

- Cannot handle concurrent writes.
- Cannot be scaled horizontally.
- All data is lost on pod deletion or rescheduling.
- No persistent volume or backup support.

To address these issues, the following strategy is proposed:

- Migrate to PostgreSQL, which supports concurrent access, remote connections, and production-grade reliability.
- Use a StatefulSet with a PersistentVolumeClaim (PVC) to provide stable, persistent storage across restarts.
- Enable automated backups and support for future scaling (e.g., read replicas or external DB service).

This migration path enables the application to scale safely and meet the reliability requirements of real-world deployments.

## ToDo

* [X] Ask an user to create a Secret in advance and don't store the secret in git
* [ ] Move images to Docker Hub/JFrog Artifactory instead of building locally
* [X] Use standard nginx image instead of custom one and just pass the config
* [X] Add health check probes to nginx
* [ ] Use multi-stage Docker builds to make the image smaller and secure
* [ ] Do not use a root user to run the app (if applicable)
* [ ] Migrate to Helm and use hooks to run DB migrations automatically
* [ ] Keep the Symfony version in one place by using Helm or Kustomize (VERSION file)
* [X] Enable horizontal autoscaling
* [ ] Migrate to an external database
