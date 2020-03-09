#! /bin/bash

echo "Building..."
sudo docker build . -t cicd-actions:latest

#echo "Testing build..."
#sudo docker run -e INPUT_TASKS="docker:build" -e INPUT_IMAGE_NAME=cicd-test -e INPUT_TESTS=run_test.sh -e INPUT_BUILD_ARTIFACT="true" -e GITHUB_REF=refs/heads/alan/cicd -v `pwd`/test_repo:/test_repo -w /test_repo cicd-actions:latest

echo "Testing cypress..."
#sudo docker run --env-file=.github/test.env phamily-rails rake db:reset
#sudo docker run -d -p 127.0.0.1:3000:3000 #{env_file_opt} #{fetch(:image_name)} rails s -p 3000"
sudo docker run \
  -e INPUT_TASKS="cypress:run" \
  -e INPUT_IMAGE_NAME=phamily-rails \
  -e INPUT_TEST_ENV_FILE=.github/test.env \
  -e GITHUB_REF=refs/heads/alan/cicd \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/alan/Projects/web/phamily-rails:/app \
  -w /app \
  --rm \
  cicd-actions:latest
