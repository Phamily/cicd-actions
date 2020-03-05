FROM docker:19.03.2
LABEL "maintainer"="Alan Graham"

RUN apk update && apk upgrade

RUN apk add ruby

ADD main.rb /main.rb

ENTRYPOINT ["/main.rb"]
