#! /bin/bash

set -e

echo "Building..."
sudo docker build . -t cicd-actions:latest

echo "Cleaning..."
sudo docker rm -f cicd-app || true
#sudo docker network rm cicd || true

#echo "Testing build..."
#sudo docker run -e INPUT_TASKS="docker:build" -e INPUT_IMAGE_NAME=cicd-test -e INPUT_TESTS=run_test.sh -e INPUT_BUILD_ARTIFACT="true" -e GITHUB_REF=refs/heads/alan/cicd -v `pwd`/test_repo:/test_repo -w /test_repo cicd-actions:latest

build() {
  echo "Testing build..."
  #sudo docker build /home/alan/Projects/web/phamily-rails -t phamily-rails:latest
  sudo docker run \
    -e INPUT_TASKS="docker:build" \
    -e INPUT_BUILD_FROM_CACHE=false \
    -e INPUT_IMAGE_NAME=phamily-rails \
    -e INPUT_IMAGE_NAMESPACE=phamily \
    -e INPUT_TEST_ENV_FILE=.github/test.env \
    -e INPUT_AWS_ACCESS_KEY=$PHAMILY_CICD_AWS_ACCESS_KEY \
    -e INPUT_AWS_SECRET_ACCESS_KEY=$PHAMILY_CICD_AWS_SECRET_ACCESS_KEY \
    -e INPUT_AWS_REGION=us-east-2 \
    -e GITHUB_REF=refs/heads/alan/cicd-test \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/alan/Projects/web/phamily-rails:/app \
    -w /app \
    --rm \
    cicd-actions:latest
}

push() {
  #sudo docker build /home/alan/Projects/web/phamily-rails -t phamily-rails:latest
  sudo docker run \
    -e INPUT_TASKS="docker:push" \
    -e INPUT_BUILD_FROM_CACHE=true \
    -e INPUT_IMAGE_NAME=phamily-rails \
    -e INPUT_IMAGE_NAMESPACE=phamily \
    -e INPUT_USE_TEMPORARY_REMOTE_IMAGE=true \
    -e INPUT_TEST_ENV_FILE=.github/test.env \
    -e INPUT_AWS_ACCESS_KEY=$PHAMILY_CICD_AWS_ACCESS_KEY \
    -e INPUT_AWS_SECRET_ACCESS_KEY=$PHAMILY_CICD_AWS_SECRET_ACCESS_KEY \
    -e INPUT_AWS_REGION=us-east-2 \
    -e GITHUB_REF=refs/heads/alan/cicd-test \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/alan/Projects/web/phamily-rails:/app \
    -w /app \
    --rm \
    cicd-actions:latest
}

pull() {
  #sudo docker build /home/alan/Projects/web/phamily-rails -t phamily-rails:latest
  sudo docker run \
    -e INPUT_TASKS="docker:pull" \
    -e INPUT_BUILD_FROM_CACHE=true \
    -e INPUT_IMAGE_NAME=phamily-rails \
    -e INPUT_IMAGE_NAMESPACE=phamily \
    -e INPUT_TEST_ENV_FILE=.github/test.env \
    -e INPUT_AWS_ACCESS_KEY=$PHAMILY_CICD_AWS_ACCESS_KEY \
    -e INPUT_AWS_SECRET_ACCESS_KEY=$PHAMILY_CICD_AWS_SECRET_ACCESS_KEY \
    -e INPUT_AWS_REGION=us-east-2 \
    -e GITHUB_REF=refs/heads/alan/cicd-test \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/alan/Projects/web/phamily-rails:/app \
    -w /app \
    --rm \
    cicd-actions:latest
}

retag() {
  sudo docker run \
    -e INPUT_TASKS="docker:retag" \
    -e INPUT_BUILD_FROM_CACHE=true \
    -e INPUT_IMAGE_NAME=phamily-rails \
    -e INPUT_IMAGE_NAMESPACE=phamily \
    -e INPUT_TEST_ENV_FILE=.github/test.env \
    -e INPUT_AWS_ACCESS_KEY=$PHAMILY_CICD_AWS_ACCESS_KEY \
    -e INPUT_AWS_SECRET_ACCESS_KEY=$PHAMILY_CICD_AWS_SECRET_ACCESS_KEY \
    -e INPUT_AWS_REGION=us-east-2 \
    -e GITHUB_REF=refs/heads/alan/cicd-test \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/alan/Projects/web/phamily-rails:/app \
    -w /app \
    --rm \
    cicd-actions:latest
}

test_cypress () {
  echo "Testing cypress..."
  #sudo docker run --env-file=.github/test.env phamily-rails rake db:reset
  #sudo docker run -d -p 127.0.0.1:3000:3000 #{env_file_opt} #{fetch(:image_name)} rails s -p 3000"
  sudo docker run \
    -e INPUT_TASKS="cypress:run" \
    -e INPUT_IMAGE_NAME=phamily-rails \
    -e INPUT_IMAGE_ENV_FILE=.github/cicd.env \
    -e GITHUB_REF=refs/heads/alan/cicd-test \
    -e GITHUB_EVENT_NAME=push \
    -e INPUT_CYPRESS_RECORD_ENABLED=true \
    -e INPUT_CYPRESS_BASE_URL=preview1.phamily.com \
    -e INPUT_CYPRESS_RECORD_KEY=$PHAMILY_CYPRESS_RECORD_KEY \
    -e INPUT_KEEP_DEPENDENCIES=false \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/alan/Projects/web/phamily-rails:/app \
    -w /app \
    --rm \
    cicd-actions:latest
}

test_playwright () {
  echo "Testing playwright..."
  #sudo docker run --env-file=.github/test.env phamily-rails rake db:reset
  #sudo docker run -d -p 127.0.0.1:3000:3000 #{env_file_opt} #{fetch(:image_name)} rails s -p 3000"
  sudo docker run \
    -e INPUT_TASKS="playwright:run" \
    -e GITHUB_REF=refs/heads/alan/cicd-test \
    -e GITHUB_EVENT_NAME=push \
    -e INPUT_PLAYWRIGHT_COMMAND="yarn playwright:core" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/alan/Projects/web/phamily-rails:/app \
    -w /app \
    --rm \
    cicd-actions:latest
}

test_rspec () {
  echo "Testing rspec..."
  #sudo docker run --env-file=.github/test.env phamily-rails rake db:reset
  #sudo docker run -d -p 127.0.0.1:3000:3000 #{env_file_opt} #{fetch(:image_name)} rails s -p 3000"
  sudo docker run \
    -e INPUT_TASKS="rspec:run" \
    -e INPUT_IMAGE_NAME=phamily-rails \
    -e INPUT_IMAGE_ENV_FILE=.github/test.env \
    -e GITHUB_REF=refs/heads/alan/cicd-test \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/alan/Projects/web/phamily-rails:/app \
    -w /app \
    --rm \
    cicd-actions:latest

}

test_rails() {
  echo "Testing rails..."
  sudo docker run \
    -e INPUT_TASKS="rails:run" \
    -e INPUT_IMAGE_NAME=phamily-rails \
    -e INPUT_IMAGE_ENV_FILE=.github/test.env \
    -e GITHUB_REF=refs/heads/alan/cicd-test \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/alan/Projects/web/phamily-rails:/app \
    -w /app \
    --rm \
    cicd-actions:latest
}

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
    -e GITHUB_REF=refs/heads/alan/cicd-test \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/alan/Projects/web/phamily-rails:/app \
    -w /app \
    --rm \
    cicd-actions:latest
}

git_skip_if_tagged () {
  echo "Testing git skip_if_tagged..."
  #sudo docker run --env-file=.github/test.env phamily-rails rake db:reset
  #sudo docker run -d -p 127.0.0.1:3000:3000 #{env_file_opt} #{fetch(:image_name)} rails s -p 3000"
  sudo docker run \
    -e INPUT_TASKS="git:skip_if_tagged" \
    -e INPUT_GIT_TAGS=test \
    -e INPUT_IMAGE_ENV_FILE=.github/test.env \
    -e GITHUB_REF=refs/heads/alan/cicd-test \
    -e GITHUB_SHA=597d47febfc0e85dddcdd01d11276b0862c1621a \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/alan/Projects/web/phamily-rails:/app \
    -w /app \
    --rm \
    cicd-actions:latest

}

#build
#push
#pull
#retag
#test_cypress
#test_playwright
test_rails
#test_rspec
#kube_apply
#git_skip_if_tagged
