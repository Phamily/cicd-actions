FROM debian:11-slim
LABEL "maintainer"="Alan Graham"

RUN apt-get update -y

RUN apt-get install curl -qy

# install docker
RUN curl -L https://download.docker.com/linux/debian/dists/bullseye/pool/stable/amd64/docker-ce-cli_20.10.10~3-0~debian-bullseye_amd64.deb > /root/docker-cli.deb
RUN dpkg -i /root/docker-cli.deb
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
RUN curl -L https://omnibus-aptible-toolbelt.s3.amazonaws.com/aptible/omnibus-aptible-toolbelt/master/378/pkg/aptible-toolbelt_0.19.4%2B20220909185211~debian.9.13-1_amd64.deb > /root/aptible.deb
RUN dpkg -i /root/aptible.deb
RUN aptible version

# add ruby files
ADD cicd /cicd
ADD kube /kube
RUN mkdir -p /kube/build

ENTRYPOINT ["/cicd/main.rb"]