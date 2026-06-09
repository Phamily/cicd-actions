FROM debian:11-slim
LABEL "maintainer"="Alan Graham"

RUN apt-get update -y

RUN apt-get install curl -qy
# Add docker 
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg

RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install the Docker CLI (docker-ce-cli)
RUN apt-get update && apt-get install -y docker-ce-cli
#RUN docker ps
#RUN apt-get install docker-ce docker-ce-cli containerd.io -y

# install ruby
RUN apt-get install ruby -qy
RUN apt-get install git -qy

# install aws-cli
RUN apt-get install python3-pip -qy
RUN pip install awscli
RUN aws --version

# install kubectl
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl > /root/kubectl
RUN chmod a+x /root/kubectl
RUN mv /root/kubectl /usr/local/bin/kubectl
RUN kubectl version --client

# install aptible
# Pinned to aptible-toolbelt 0.26.8+20260608224849 (debian-9 build). The old
# 0.19.4 (2022) CLI deployed images by writing the now-deprecated
# APTIBLE_DOCKER_IMAGE / APTIBLE_PRIVATE_REGISTRY_USERNAME / _PASSWORD config
# vars, which Aptible rejects ("User Error: Deprecated environment variable
# used"). The modern CLI passes --docker-image via the deploy API instead.
# We fetch the `latest` artifact but verify its sha256 so the version is
# effectively pinned and only changes via a reviewed bump of this hash.
RUN curl -L https://omnibus-aptible-toolbelt.s3.amazonaws.com/aptible/omnibus-aptible-toolbelt/latest/aptible-toolbelt_latest_debian-9_amd64.deb > /root/aptible.deb && \
    echo "d8079d48dde27b140a55dcfcd4dd88f6219d05dc098c19d203471c0584c0c303  /root/aptible.deb" | sha256sum -c -
RUN dpkg -i /root/aptible.deb
RUN aptible version

# add ruby files
ADD cicd /cicd
ADD kube /kube
RUN mkdir -p /kube/build

ENTRYPOINT ["/cicd/main.rb"]