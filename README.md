# s6 overlay [![Build Status](https://travis-ci.org/just-containers/s6-overlay-builder.svg?branch=v1.7.2)](https://travis-ci.org/just-containers/s6-overlay-builder)

```
mkdir dist
chmod o+rw dist
docker build .                                    | \
tail -n 1 | awk '{ print $3; }'                   | \
xargs docker run --rm -v `pwd`/dist:/builder/dist
```
