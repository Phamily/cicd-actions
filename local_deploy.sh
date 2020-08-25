#! /bin/bash

set -e

echo "Building..."
sudo docker build . -t cicd-actions:latest

kube_apply () {
  sudo docker run \
    -e INPUT_TASKS="kube:config,kube:apply" \
    -e INPUT_IMAGE_NAME=phamily-rails \
    -e INPUT_IMAGE_NAMESPACE=phamily \
    -e INPUT_TEST_ENV_FILE=.github/test.env \
    -e INPUT_AWS_ACCESS_KEY=$PHAMILY_CICD_AWS_ACCESS_KEY \
    -e INPUT_AWS_SECRET_ACCESS_KEY=$PHAMILY_CICD_AWS_SECRET_ACCESS_KEY \
    -e INPUT_AWS_REGION=us-east-2 \
    -e INPUT_KUBE_CLUSTER_NAME=phamily \
    -e INPUT_REGISTRY_URL=$PHAMILY_CICD_REGISTRY_URL \
    -e GITHUB_REF=refs/heads/phamily-2020 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/alan/Projects/web/phamily-rails:/app \
    -w /app \
    --rm \
    cicd-actions:latest
}

kube_apply
