FROM docker:19.03.2
LABEL "maintainer"="Alan Graham"

RUN apk update && apk upgrade

RUN apk add ruby 
RUN apk add ruby-json
RUN apk add py-pip 
RUN apk add unzip
RUN apk add curl

# install aws-cli
RUN pip install awscli
RUN aws --version

# install kubectl
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl > /root/kubectl
RUN chmod a+x /root/kubectl
RUN mv /root/kubectl /usr/local/bin/kubectl
RUN kubectl version --client

ADD cicd /cicd
ADD kube /kube
RUN mkdir -p /kube/build

ENTRYPOINT ["/cicd/main.rb"]
