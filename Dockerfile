FROM debian:13-slim
LABEL "maintainer"="Alan Graham"

RUN apt-get update -y

RUN apt-get install curl -qy

# install docker
RUN curl -L https://download.docker.com/linux/debian/dists/trixie/pool/stable/amd64/docker-ce-cli_29.2.1-1~debian.13~trixie_amd64.deb  > /root/docker-cli.deb
RUN dpkg -i /root/docker-cli.deb
#RUN docker ps
#RUN apt-get install docker-ce docker-ce-cli containerd.io -y

# install ruby
RUN apt-get install ruby \
    git \
    python3-pip \
    awscli -qy
RUN aws --version

# install kubectl
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl > /root/kubectl
RUN chmod a+x /root/kubectl
RUN mv /root/kubectl /usr/local/bin/kubectl
RUN kubectl version --client

# install aptible
RUN curl -L https://omnibus-aptible-toolbelt.s3.amazonaws.com/aptible/omnibus-aptible-toolbelt/latest/aptible-toolbelt_latest_debian-9_amd64.deb > /root/aptible.deb
RUN dpkg -i /root/aptible.deb
RUN aptible version

# add ruby files
ADD cicd /cicd
ADD kube /kube
RUN mkdir -p /kube/build

ENTRYPOINT ["/cicd/main.rb"]