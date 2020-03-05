#! /bin/bash

echo "Building..."
sudo docker build . -t cicd-actions:latest

echo "Testing..."
sudo docker run -e INPUT_DEBUG_MODE=true -e INPUT_NAME=cicd-test -e INPUT_TESTS=run_test.sh -e GITHUB_REF=refs/heads/alan/cicd -v `pwd`/test_repo:/test_repo -w /test_repo cicd-actions:latest
