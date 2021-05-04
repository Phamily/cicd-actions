# Github Self-hosted Runner

## Dependencies

You must create a personal access token for registering the runner (https://docs.github.com/en/rest/reference/actions#create-a-registration-token-for-a-repository). The token must have the `repo` scope.

Download the *Linux* runner to /root/actions-runner/base

Set the `GITHUB_ACCESS_TOKEN` and `PHAMILY_REPO` environment variables in /root/.bashrc

```
$ apt-get update -y && apt-get install -y software-properties-common
$ add-apt-repository ppa:git-core/ppa -y
$ apt-get update -y 
$ apt-get install -y git curl jq build-essential libssl-dev libffi-dev python3 python3-venv python3-dev
$ apt-get update -y
$ apt-get install -y curl jq
$ apt-get install ruby-full
$ gem install foreman
```

## Build

```
$ sudo docker build -t runner-image
```

## Start

For Foreman

```
$ cd /root/actions-runner
$ foreman start
```

For Docker
```
$ cd /root/cicd-actions/runner
$ docker-compose build
$ docker-compose up --scale runner=5 -d
```