#!/bin/bash

INSTNAME=${1:-$HOSTNAME}
REPO=$PHAMILY_REPO
ACCESS_TOKEN=$GITHUB_ACCESS_TOKEN

export RUNNER_ALLOW_RUNASROOT="1"

cp -a /root/actions-runner/base /root/actions-runner/$INSTNAME
cd /root/actions-runner/$INSTNAME

REG_TOKEN=$(curl -sX POST -H "Authorization: token ${ACCESS_TOKEN}" https://api.github.com/repos/${REPO}/actions/runners/registration-token | jq .token --raw-output)


./config.sh --url https://github.com/${REPO} --token ${REG_TOKEN}

cleanup() {
    echo "Removing runner..."
    REG_TOKEN=$(curl -sX POST -H "Authorization: token ${ACCESS_TOKEN}" https://api.github.com/repos/${REPO}/actions/runners/registration-token | jq .token --raw-output)
    ./config.sh remove --unattended --token ${REG_TOKEN} || true
    echo "Cleaning up runner directory..."
    rm -rf /root/actions-runner/$INSTNAME
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!