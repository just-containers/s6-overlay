FROM ubuntu:14.04
MAINTAINER Gorka Lerchundi Osa <glertxundi@gmail.com>

##
## VERSION
##

ENV RELEASE_VERSION 1.3.0

##
## OVERLAY
##

ENV ROOTFS_PATH /rootfs

# root filesystem
COPY rootfs $ROOTFS_PATH

# fix-attrs
ADD https://github.com/glerchundi/fix-attrs/releases/download/v0.4.0/fix-attrs-0.4.0-linux-amd64 $ROOTFS_PATH/usr/bin/fix-attrs

# execline
ADD https://github.com/glerchundi/container-s6-builder/releases/download/v$RELEASE_VERSION/execline-2.1.0.0-linux-amd64-bin.tar.gz /tmp/execline.tar.gz
RUN tar xvfz /tmp/execline.tar.gz -C $ROOTFS_PATH

# s6
ADD https://github.com/glerchundi/container-s6-builder/releases/download/v$RELEASE_VERSION/s6-2.1.1.2-linux-amd64-bin.tar.gz /tmp/s6.tar.gz
RUN tar xvfz /tmp/s6.tar.gz -C $ROOTFS_PATH

# s6-portable-utils
ADD https://github.com/glerchundi/container-s6-builder/releases/download/v$RELEASE_VERSION/s6-portable-utils-2.0.0.1-linux-amd64-bin.tar.gz /tmp/s6-portable-utils.tar.gz
RUN tar xvfz /tmp/s6-portable-utils.tar.gz -C $ROOTFS_PATH

# s6-linux-utils
ADD https://github.com/glerchundi/container-s6-builder/releases/download/v$RELEASE_VERSION/s6-linux-utils-2.0.1.0-linux-amd64-bin.tar.gz /tmp/s6-linux-utils.tar.gz
RUN tar xvfz /tmp/s6-linux-utils.tar.gz -C $ROOTFS_PATH

# s6-dns
ADD https://github.com/glerchundi/container-s6-builder/releases/download/v$RELEASE_VERSION/s6-dns-2.0.0.2-linux-amd64-bin.tar.gz /tmp/s6-dns.tar.gz
RUN tar xvfz /tmp/s6-dns.tar.gz -C $ROOTFS_PATH

# s6-networking
ADD https://github.com/glerchundi/container-s6-builder/releases/download/v$RELEASE_VERSION/s6-networking-2.1.0.0-linux-amd64-bin.tar.gz /tmp/s6-networking.tar.gz
RUN tar xvfz /tmp/s6-networking.tar.gz -C $ROOTFS_PATH

##
## FIX PERMS
##

RUN chmod +x $ROOTFS_PATH/init                        \
             $ROOTFS_PATH/etc/s6/.s6-svscan/finish    \
             $ROOTFS_PATH/etc/s6/.s6-init/init-stage* \
             $ROOTFS_PATH/usr/bin/fix-attrs

##
## RUN & DIST!
##

RUN mkdir -p /dist
CMD [ "tar", "-zcvf", "/dist/s6-overlay-$RELEASE_VERSION-linux-amd64.tar.gz", "-C", "/rootfs", "./" ]
