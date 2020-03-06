#! /bin/bash

echo "Building..."
sudo docker build . -t cicd-actions:latest

echo "Testing..."
sudo docker run -e INPUT_TASKS="docker:build" -e INPUT_IMAGE_NAME=cicd-test -e INPUT_TESTS=run_test.sh -e INPUT_BUILD_ARTIFACT="true" -e GITHUB_REF=refs/heads/alan/cicd -v `pwd`/test_repo:/test_repo -w /test_repo cicd-actions:latest
