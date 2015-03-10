FROM ubuntu:14.04
MAINTAINER Gorka Lerchundi Osa <glertxundi@gmail.com>

ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y curl
COPY rootfs /
RUN chmod +x /build-*

ENV OVERLAY_ROOTFS_PATH /overlay-rootfs
COPY overlay-rootfs $OVERLAY_ROOTFS_PATH

CMD [ "/build-wrapper" ]
