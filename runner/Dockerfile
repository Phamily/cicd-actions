FROM ubuntu:18.04

# basic setup
RUN apt-get update -y && apt-get install -y software-properties-common
RUN add-apt-repository ppa:git-core/ppa -y
RUN apt-get update -y 
RUN apt-get install -y git curl jq build-essential libssl-dev libffi-dev python3 python3-venv python3-dev

# install docker
RUN curl -fsSL https://get.docker.com -o get-docker.sh
RUN sh get-docker.sh

# install yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt update -y
RUN apt-get -y install yarn

#ENV RUNNER_DIR /actions-runner
#WORKDIR /actions-runner

#RUN curl -o actions-runner-linux-x64-2.277.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.277.1/actions-runner-linux-x64-2.277.1.tar.gz

#RUN tar xzf ./actions-runner-linux-x64-2.277.1.tar.gz

COPY start.sh /root/start.sh

RUN chmod +x /root/start.sh

ENV RUNNER_ALLOW_RUNASROOT="1"

#USER docker

ENTRYPOINT ["/root/start.sh"]