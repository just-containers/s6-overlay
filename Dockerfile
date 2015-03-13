FROM ubuntu:14.04
MAINTAINER Gorka Lerchundi Osa <glertxundi@gmail.com>

ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get -y install curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY builder /builder
RUN chown -R nobody:nogroup /builder

USER nobody
ENV HOME /builder
WORKDIR /builder

CMD [ "./build-wrapper" ]
