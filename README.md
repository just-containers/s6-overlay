```
mkdir dist
chmod o+rw dist
docker build .                                    | \
tail -n 1 | awk '{ print $3; }'                   | \
xargs docker run --rm -v `pwd`/dist:/builder/dist
```