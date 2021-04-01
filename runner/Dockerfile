FROM ubuntu:18.04

# basic setup
RUN apt-get update -y && apt-get install -y software-properties-common
RUN add-apt-repository ppa:git-core/ppa -y
RUN apt-get update -y 
RUN apt-get install -y git curl jq build-essential libssl-dev libffi-dev python3 python3-venv python3-dev

# install docker
RUN curl -fsSL https://get.docker.com -o get-docker.sh
RUN sh get-docker.sh
#RUN apt-get install -y install appt-transport-https ca-certificates curl gnupg lsb-release
#RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
#RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
#RUN apt-get update -y
#RUN apt-get install docker-ce docker-ce-cli containerd.io

ENV RUNNER_DIR /actions-runner
WORKDIR /actions-runner

RUN curl -o actions-runner-linux-x64-2.277.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.277.1/actions-runner-linux-x64-2.277.1.tar.gz

RUN tar xzf ./actions-runner-linux-x64-2.277.1.tar.gz

COPY start.sh /root/start.sh

RUN chmod +x /root/start.sh

ENV RUNNER_ALLOW_RUNASROOT="1"

#USER docker

ENTRYPOINT ["/root/start.sh"]