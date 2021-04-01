# Github Self-hosted Runner

## Dependencies

You must create a personal access token for registering the runner (https://docs.github.com/en/rest/reference/actions#create-a-registration-token-for-a-repository). The token must have the `repo` scope.

Download the *Linux* runner to /root/actions-runner/base

## Build

```
$ sudo docker build -t runner-image
```

## Start

```
docker-compose build
docker-compose up --scale runner=2 -d
```