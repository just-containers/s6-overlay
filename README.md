**Table of Contents**

- [Quickstart](#quickstart)
- [Goals](#goals)
- [Features](#features)
- [The Docker Way?](#the-docker-way)
- [Our `s6-overlay` based images](#our-s6-overlay-based-images)
- [Init stages](#init-stages)
- [Usage](#usage)
  - [Using `CMD`](#using-cmd)
  - [Fixing ownership & permissions](#fixing-ownership--permissions)
  - [Executing initialization And/Or finalization tasks](#executing-initialization-andor-finalization-tasks)
  - [Writing a service script](#writing-a-service-script)
  - [Writing an optional finish script](#writing-an-optional-finish-script)
  - [Dropping privileges](#dropping-privileges)
  - [Container environment](#container-environment)
  - [Customizing `s6` behaviour](#customizing-s6-behaviour)
- [Known issues and workarounds](#known-issues-and-workarounds)
  - [`/bin` and `/sbin` are symlinks](#bin-and-sbin-are-symlinks)
- [Performance](#performance)
- [Verifying Downloads](#verifying-downloads)
- [Notes](#notes)
- [Contributing](#contributing)

# s6 overlay [![Build Status](https://api.travis-ci.org/just-containers/s6-overlay.svg?branch=master)](https://travis-ci.org/just-containers/s6-overlay)

The s6-overlay-builder project is a series of init scripts and utilities to ease creating Docker images using [s6](http://skarnet.org/software/s6/overview.html) as a process supervisor.

## Quickstart

Build the following Dockerfile and try this guy out:

```
FROM ubuntu
ADD https://github.com/just-containers/s6-overlay/releases/download/v1.11.0.1/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /
RUN apt-get update && \
    apt-get install -y nginx && \
    echo "daemon off;" >> /etc/nginx/nginx.conf
ENTRYPOINT ["/init"]
CMD ["nginx"]
```

```
docker-host $ docker build -t demo .
docker-host $ docker run --name s6demo -d -p 80:80 demo
docker-host $ docker top s6demo acxf
PID                 TTY                 STAT                TIME                COMMAND
3788                ?                   Ss                  0:00                \_ s6-svscan
3827                ?                   S                   0:00                | \_ foreground
3834                ?                   S                   0:00                | | \_ foreground
3879                ?                   S                   0:00                | | \_ nginx
3880                ?                   S                   0:00                | | \_ nginx
3881                ?                   S                   0:00                | | \_ nginx
3882                ?                   S                   0:00                | | \_ nginx
3883                ?                   S                   0:00                | | \_ nginx
3828                ?                   S                   0:00                | \_ s6-supervise
3829                ?                   S                   0:00                | \_ s6-supervise
3830                ?                   Ss                  0:00                | \_ s6-log
docker-host $ curl --head http://127.0.0.1/
HTTP/1.1 200 OK
Server: nginx/1.4.6 (Ubuntu)
Date: Thu, 26 Mar 2015 14:57:34 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 04 Mar 2014 11:46:45 GMT
Connection: keep-alive
ETag: "5315bd25-264"
Accept-Ranges: bytes
```

## Goals
The project has the following goals:

* Make it easy for image authors to take advantage of s6
* Still operate like other Docker images

## Features

* A simple init process which allows to the end-user execute tasks like initialization (`cont-init.d`), finalization (`cont-finish.d`) as well as fixing ownership permissions (`fix-attrs.d`).
* The s6-overlay provides proper `PID 1` functionality
  * You'll never have zombie processes hanging around in your container, they will be properly cleaned up.
* Multiple processes in a single container
* Able to operate in "The Docker Way"
* Usable with all base images - Ubuntu, CentOS, Fedora, and even Busybox.
* Distributed as a single .tar.gz file, to keep your image's number of layers small.
* A whole set of utilities included in `s6` and `s6-portable-utils`. They include handy and composable utilities which make our lives much, much easier.
* Log rotating out-of-the-box through `logutil-service` which uses [`s6-log`](http://skarnet.org/software/s6/s6-log.html) under the hood.

## The Docker Way?

One of the oft-repeated Docker mantras is "one process per container", but we disagree. There's nothing inherently *bad* about running multiple processes in a container. The more abstract "one *thing* per container" is our policy - a container should do one thing, such as "run a chat service" or "run gitlab." This may involve multiple processes, which is fine.

The other reason image authors shy away from process supervisors is they believe a process supervisor *must* restart failed services, meaning the Docker container will never die.

This does effectively break the Docker ecosystem - most images run one process that will exit when there's an error. By exiting on error, you allow the system administrator to handle failures however they prefer. If your image will never exit, you now need some alternative method of error recovery and failure notification.

Our policy is that if "the thing" fails, then the container should fail, too. We do this by determining which processes can restart, and which should bring down the container. For example, if `cron` or `syslog` fails, your container can most likely restart it without any ill effects, but if `ejabberd` fails, the container should exit so the system administrator can take action.

Our interpretation of "The Docker Way" is thus:

* Containers should do one thing
* Containers should stop when that thing stops

and our init system is designed to do exactly that! Your images will still behave like other Docker images and fit in with the existing ecosystem of images.

See "Writing an optional finish script" under the [Usage](#usage) section for details on stopping "the thing."

## Our `s6-overlay` based images

We've developed two docker images which can be used as base images:
* [base](https://github.com/just-containers/base): Based on Ubuntu 14.04 LTS, it was intended to use as a general purpose image.
* [base-alpine](https://github.com/just-containers/base-alpine): Based on Alpine Linux 3.1, as advertised on their website: "a security-oriented, lightweight Linux distribution based on musl libc and busybox" - the base image is under 10MB but still includes a package manager!

## Init stages

Our overlay init is a properly customized one to run appropriately in containerized environments. This section briefly explains how our stages work but if you want to know how a complete init system should work, please read this article: [How to run s6-svscan as process 1](http://skarnet.org/software/s6/s6-svscan-1.html) by Laurent Bercot.

1. **stage 1**: Its purpose is to prepare the image to enter into the second stage. Among other things, it is responsible for preparing the container environment variables, block the startup of the second stage until `s6` is effectively started, ...
2. **stage 2**: This is where most of the end-user provided files are mean to be executed:
  1. Fix ownership and permissions using `/etc/fix-attrs.d`.
  2. Execute initialization scripts contained in `/etc/cont-init.d`.
  3. Copy user services (`/etc/services.d`) to the folder where s6 is running its supervision and signal it so that it can properly start supervising them. 
3. **stage 3**: This is the shutdown stage. Its purpose is to clean everything up, stop services and execute finalization scripts contained in `/etc/cont-finish.d`. This is when our init system stops all container processes, first gracefully using `SIGTERM` and then (after `S6_KILL_GRACETIME`) forcibly using `SIGKILL`. And, of course, it reaps all zombies :-).

## Usage

The project is distributed as a standard .tar.gz file, which you extract at the root of your image. Afterwards, set your `ENTRYPOINT` to `/init`

Right now, we recommend using Docker's `ADD` directive instead of running `wget` or `curl` in a `RUN` directive - Docker is able to handle the https URL when you use `ADD`, whereas your base image might not be able to use https, or might not even have `wget` or `curl` installed at all.

From there, you have a couple of options:

* Run your service/program as your image's `CMD`
* Write a service script

### Using `CMD`

Using `CMD` is a really convenient way to take advantage of the s6-overlay. Your `CMD` can be given at build-time in the Dockerfile, or at runtime on the command line, either way is fine - it will be run under the s6 supervisor, and when it fails or exits, the container will exit. You can even run interactive programs under the s6 supervisor!

For example:

```
FROM busybox
ADD https://github.com/just-containers/s6-overlay/releases/download/v1.11.0.1/s6-overlay-amd64.tar.gz /tmp/
RUN gunzip -c /tmp/s6-overlay-amd64.tar.gz | tar -xf - -C /
ENTRYPOINT ["/init"]
```

```
docker-host $ docker build -t s6demo .
docker-host $ docker run -ti s6demo /bin/sh
[fix-attrs.d] applying owners & permissions fixes...
[fix-attrs.d] 00-runscripts: applying... 
[fix-attrs.d] 00-runscripts: exited 0.
[fix-attrs.d] done.
[cont-init.d] executing container initialization scripts...
[cont-init.d] done.
[services.d] starting services
[services.d] done.
/ # ps
PID   USER     COMMAND
    1 root     s6-svscan -t0 /var/run/s6/services
   21 root     foreground  if   /etc/s6/init/init-stage2-redirfd   foreground    if     s6-echo     [fix-attrs.d] applying owners & permissions fixes.
   22 root     s6-supervise s6-fdholderd
   23 root     s6-supervise s6-svscan-log
   24 nobody   s6-log -bp -- t /var/log/s6-uncaught-logs
   28 root     foreground  s6-setsid  -gq  --  with-contenv  /bin/sh  import -u ? if  s6-echo  --  /bin/sh exited ${?}  foreground  s6-svscanctl  -t
   73 root     /bin/sh
   76 root     ps
/ # exit
/bin/sh exited 0
docker-host $
```

### Fixing ownership & permissions

Sometimes it's interesting to fix ownership & permissions before proceeding because, for example, you have mounted/mapped a host folder inside your container. Our overlay provides a way to tackle this issue using files in `/etc/fix-attrs.d`. This is the pattern format followed by fix-attrs files:

```
path recurse account fmode dmode
```
* `path`: File or dir path.
* `recurse`: (Set to `true` or `false`) If a folder is found, recurse through all containing files & folders in it.
* `account`: Target account. It's possible to default to fallback `uid:gid` if the account isn't found. For example, `nobody,32768:32768` would try to use the `nobody` account first, then fallback to `uid 32768` instead.
If, for instance, `daemon` account is `UID=2` and `GID=2`, these are the possible values for `account` field:
  * `daemon:                UID=2     GID=2`
  * `daemon,3:4:            UID=2     GID=2`
  * `2:2,3:4:               UID=2     GID=2`
  * `daemon:11111,3:4:      UID=11111 GID=2`
  * `11111:daemon,3:4:      UID=2     GID=11111`
  * `daemon:daemon,3:4:     UID=2     GID=2`
  * `daemon:unexisting,3:4: UID=2     GID=4`
  * `unexisting:daemon,3:4: UID=3     GID=2`
  * `11111:11111,3:4:       UID=11111 GID=11111`
* `fmode`: Target file mode. For example, `0644`.
* `dmode`: Target dir/folder mode. For example, `0755`.

Here you have some working examples:

`/etc/fix-attrs.d/01-mysql-data-dir`:
```
/var/lib/mysql true mysql 0600 0700
```
`/etc/fix-attrs.d/02-mysql-log-dirs`:
```
/var/log/mysql-error-logs true nobody,32768:32768 0644 2700
/var/log/mysql-general-logs true nobody,32768:32768 0644 2700
/var/log/mysql-slow-query-logs true nobody,32768:32768 0644 2700
```

### Executing initialization And/Or finalization tasks

After fixing attributes (through `/etc/fix-attrs.d/`) and just before starting user provided services up (through `/etc/services.d`) our overlay will execute all the scripts found in `/etc/cont-init.d`, for example:

[`/etc/cont-init.d/02-confd-onetime`](https://github.com/just-containers/nginx-loadbalancer/blob/master/rootfs/etc/cont-init.d/02-confd-onetime):
```
#!/usr/bin/execlineb -P

with-contenv
s6-envuidgid nginx
multisubstitute
{
  import -u -D0 UID
  import -u -D0 GID
  import -u CONFD_PREFIX
  define CONFD_CHECK_CMD "/usr/sbin/nginx -t -c {{ .src }}"
}
confd --onetime --prefix="${CONFD_PREFIX}" --tmpl-uid="${UID}" --tmpl-gid="${GID}" --tmpl-src="/etc/nginx/nginx.conf.tmpl" --tmpl-dest="/etc/nginx/nginx.conf" --tmpl-check-cmd="${CONFD_CHECK_CMD}" etcd
```

### Writing a service script

Creating a supervised service cannot be easier, just create a service directory with the name of your service into `/etc/services.d` and put a `run` file into it, this is the file in which you'll put your long-lived process execution. You're done! If you want to know more about s6 supervision of servicedirs take a look to [`servicedir`](http://skarnet.org/software/s6/servicedir.html) documentation. A simple example would look like this:

`/etc/services.d/myapp/run`:
```
#!/usr/bin/execlineb -P
nginx -g "daemon off;"
```

### Writing an optional finish script

By default, services created in `/etc/services.d` will automatically restart. If a service should bring the container down, you'll need to write a `finish` script that does that. Here's an example finish script:

`/etc/services.d/myapp/finish`:
```
#!/usr/bin/execlineb -S0

s6-svscanctl -t /var/run/s6/services
```

It's possible to do more advanced operations - for example, here's a script from @smebberson that only brings down the service when it crashes:

`/etc/services.d/myapp/finish`:
```
#!/usr/bin/execlineb -S1
if { s6-test ${1} -ne 0 }
if { s6-test ${1} -ne 256 }

s6-svscanctl -t /var/run/s6/services
```

### Logging

Our overlay provides a way to handle logging easily since `s6` already provides logging mechanisms out-of-the-box via [`s6-log`](http://skarnet.org/software/s6/s6-log.html)!. We also provide a helper utility called `logutil-service` to make logging a matter of calling one binary. This helper does the following things:
- read how s6-log should proceed reading the logging script contained in `S6_LOGGING_SCRIPT`
- drop privileges to the `nobody` user (defaulting to `32768:32768` if it doesn't exist)
- clean all the environments variables
- initiate logging by executing s6-log :-)

This example will send all the log lines present in stdin (following the rules described in `S6_LOGGING_SCRIPT`) to `/var/log/myapp`: 

`/etc/services.d/myapp/log/run`:
```
#!/bin/sh
exec logutil-service /var/log/myapp
```

If, for instance, you want to use a fifo instead of stdin as an input, write your log services as follows:

`/etc/services.d/myapp/log/run`:
```
#!/bin/sh
exec logutil-service -f /var/run/myfifo /var/log/myapp
```

### Dropping privileges

When it comes to executing a service, no matter it's a service or a logging service, a very good practice is to drop privileges before executing it. `s6` already includes utilities to do exactly these kind of things:

In `execline`:

```
#!/usr/bin/execlineb -P
s6-setuidgid daemon
myservice
```

In `sh`:

```
#!/bin/sh
exec s6-setuidgid daemon myservice
```

If you want to know more about these utilities, please take a look to: [`s6-setuidgid`](http://skarnet.org/software/s6/s6-setuidgid.html), [`s6-envuidgid`](http://skarnet.org/software/s6/s6-envuidgid.html) and [`s6-applyuidgid`](http://skarnet.org/software/s6/s6-applyuidgid.html).

### Container environment

If you want your custom script to have container environments available just make use of `with-contenv` helper, which will push all of those into your execution environment, for example:

`/etc/cont-init.d/01-contenv-example`:
```
#!/usr/bin/with-contenv sh
echo $MYENV
```

This script will output whatever the `MYENV` enviroment variable contains.

### Customizing `s6` behaviour

It is possible somehow to tweak `s6` behaviour by providing an already predefined set of environment variables to the execution context:

* `S6_KEEP_ENV` (default = 0): if set, then environment is not reset and whole supervision tree sees original set of env vars. It switches `with-contenv` into noop.
* `S6_LOGGING` (default = 0): 
  * **`0`**: Outputs everything to stdout/stderr.
  * **`1`**: Uses an internal `catch-all` logger and persists everything on it, it is located in `/var/log/s6-uncaught-logs`. Nothing would be written to stdout/stderr.
* `S6_BEHAVIOUR_IF_STAGE2_FAILS` (default = 0):
  * **`0`**: Continue silently even if any script (`fix-attrs` or `cont-init`) has failed.
  * **`1`**: Continue but warn with an annoying error message.
  * **`2`**: Stop by sending a termination signal to the supervision tree.
* `S6_KILL_FINISH_MAXTIME` (default = 5000): The maximum time (in milliseconds) a script in `/etc/cont-finish.d` could take before sending a `KILL` signal to it. Take into account that this parameter will be used per each script execution, it's not a max time for the whole set of scripts.
* `S6_KILL_GRACETIME` (default = 3000): How long (in milliseconds) `s6` should wait to reap zombies before sending a `KILL` signal.
* `S6_LOGGING_SCRIPT` (default = "n20 s1000000 T"): This env decides what to log and how, by default every line will prepend with ISO8601, rotated when the current logging file reaches 1mb and archived, at most, with 20 files.
* `S6_CMD_ARG0` (default = not set): Value of this env var will be prepended to any `CMD` args passed by docker. Use it if you are migrting an existing image to a s6-overlay and want to make it a drop-in replacement, then setting this variable to a value of previously used ENTRYPOINT will improve compatibility with the way image is used.
* `S6_FIX_ATTRS_HIDDEN` (default = 0): Controls how `fix-attrs.d` scripts process files and directories.
  * **`0`**: Hidden files and directories are excluded.
  * **`1`**: All files and directories are processed.
* `S6_CMD_WAIT_FOR_SERVICES` (default = 0): In order to proceed executing CMD overlay will wait until services are up. Be aware that up doesn't mean ready. Depending if `notification-fd` was found inside the servicedir overlay will use `s6-svwait -U` or `s6-svwait -u` as the waiting statement.
* `S6_CMD_WAIT_FOR_SERVICES_MAXTIME` (default = 5000): The maximum time (in milliseconds) the services could take to bring up before proceding to CMD executing.

## Known issues and workarounds

### `/bin` and `/sbin` are symlinks

Some Linux distros (like CentOS 7) have started replacing `/bin` with a symlink
to `/usr/bin` (and the same for `/sbin -> /usr/sbin`). When you extract the
tarball, these symlinks are overwritten, so important programs like `/bin/sh`
disappear.

The current workaround is to extract the tarball in two steps:

```
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C / --exclude="./bin" --exclude="./sbin" && \
    tar xzf /tmp/s6-overlay-amd64.tar.gz -C /usr ./bin ./sbin
```

This will prevent tar from deleting those `/bin` and `/sbin` symlinks, and
everything will work as normal.

## Performance

And what about numbers? `s6-overlay` takes more or less **`904K`** compressed and **`3.4M`** uncompressed, that's very cheap! Although we already provide packaged base images, it is up to you which base image to use. And when it comes to how much time does it take to get supervision tree up and running, it's less than **`100ms`** #3!

## Verifying Downloads

The `s6-overlay` releases are signed using `gpg`, you can import our public key:

```bash
$ curl https://keybase.io/justcontainers/key.asc | gpg --import
```

Then verify the downloaded files:

```bash
$ gpg --verify s6-overlay-amd64.tar.gz.sig s6-overlay-amd64.tar.gz
gpg: Signature made Sun 22 Nov 2015 09:11:29 AM CST using RSA key ID BD7BF0DC
gpg: Good signature from "Just Containers <just-containers@jrjrtech.com>"
```

## Notes

* For now, `s6-overlay` doesn't support running it with a user different than `root`, so consequently Dockerfile `USER` directive is not supported (except `USER root` of course ;P).

## Contributing

Anyway you want! Open issues, open PRs, we welcome all contributors!

## Want to build the overlay on your system?

First create the output folder with its corresponding required permissions:
```
mkdir dist
chmod o+rw dist
```

Then build from official skaware releases:
```
docker build .                                    | \
tail -n 1 | awk '{ print $3; }'                   | \
xargs docker run --rm -v `pwd`/dist:/builder/dist
```

Or use your own release folder:
```
docker build .                                                          | \
tail -n 1 | awk '{ print $3; }'                                         | \
xargs docker run --rm                                                     \
  -e SKAWARE_SOURCE=file:///skaware  -v `pwd`/../skaware/dist:/skaware:ro \
  -v `pwd`/dist:/builder/dist
```

