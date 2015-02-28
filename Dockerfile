FROM ubuntu:14.04
MAINTAINER Gorka Lerchundi Osa <glertxundi@gmail.com>

##
## ROOTFS
##

ENV ROOTFS_PATH /rootfs

# root filesystem
COPY rootfs $ROOTFS_PATH

# fix-attrs
ADD https://github.com/glerchundi/fix-attrs/releases/download/v0.4.0/fix-attrs-0.4.0-linux-amd64 $ROOTFS_PATH/usr/bin/fix-attrs

# execline
ADD https://github.com/glerchundi/container-s6-builder/releases/download/v1.2.0/execline-2.1.0.0-linux-amd64.tar.gz /tmp/execline.tar.gz
RUN tar xvfz /tmp/execline.tar.gz -C $ROOTFS_PATH

# s6 init system
ADD https://github.com/glerchundi/container-s6-builder/releases/download/v1.2.0/s6-2.1.1.2-linux-amd64.tar.gz /tmp/s6.tar.gz
RUN tar xvfz /tmp/s6.tar.gz -C $ROOTFS_PATH

# s6 portable utils
ADD https://github.com/glerchundi/container-s6-builder/releases/download/v1.2.0/s6-portable-utils-2.0.0.1-linux-amd64.tar.gz /tmp/s6-portable-utils.tar.gz
RUN tar xvfz /tmp/s6-portable-utils.tar.gz -C $ROOTFS_PATH

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
CMD [ "tar", "-zcvf", "/dist/s6-overlay-0.1.0-linux-amd64.tar.gz", "-C", "/rootfs", "./" ]
