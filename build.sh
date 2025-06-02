#!/bin/bash
set -e

# set the Symfony version to build, defaulting to 2.7.0 if not provided
SYMFONY_VERSION=${1:-v2.7.0}

# Check if the provided Symfony version is valid
if ! [[ $SYMFONY_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid Symfony version format. Please use the format X.Y.Z (e.g., 2.7.0)."
  exit 1
fi
# Build the Docker images for Symfony
docker build --build-arg SYMFONY_VERSION=$SYMFONY_VERSION -t symfony-php:$SYMFONY_VERSION -f Dockerfile .

docker build -t symfony-nginx:latest -f Dockerfile.nginx .