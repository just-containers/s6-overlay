FROM buildpack-deps:focal

WORKDIR /workspace

RUN apt-get update \
  && apt-get install -y --no-install-recommends software-properties-common \
  && add-apt-repository -y ppa:neurobin/ppa \
  && apt-get update \
  && apt-get install -y shc

COPY init.sh .

RUN shc -S -r -f init.sh -o init
