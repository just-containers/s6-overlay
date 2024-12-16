**Table of Contents**

- [Quickstart](#quickstart)
- [Compatibility with v2](#compatibility-with-v2)
- [Goals](#goals)
- [Features](#features)
- [The Docker Way?](#the-docker-way)
- [Init stages](#init-stages)
- [Installation](#installation)
- [Usage](#usage)
  - [Using `CMD`](#using-cmd)
  - [Writing a service script](#writing-a-service-script)
  - [Setting the exit code of the container to the exit code of your main service](#setting-the-exit-code-of-the-container-to-the-exit-code-of-your-main-service)
  - [Fixing ownership and permissions](#fixing-ownership-and-permissions)
  - [Executing initialization and finalization tasks](#executing-initialization-and-finalization-tasks)
  - [Writing an optional finish script](#writing-an-optional-finish-script)
  - [Logging](#logging)
  - [Dropping privileges](#dropping-privileges)
  - [Read-only Root Filesystem](#read-only-root-filesystem)
  - [Container environment](#container-environment)
  - [Customizing s6-overlay's behaviour](#customizing-s6-overlay-behaviour)
  - [syslog](#syslog)
- [Performance](#performance)
- [Verifying Downloads](#verifying-downloads)
- [Notes](#notes)
- [Releases](#releases)
  - [Which architecture to use depending on your TARGETARCH](#which-architecture-to-use-depending-on-your-targetarch)
- [Contributing](#contributing)
- [Building the overlay yourself](#building-the-overlay-yourself)
- [Upgrade notes](#upgrade-notes)

# s6-overlay [![Build Status](https://api.travis-ci.org/just-containers/s6-overlay.svg?branch=master)](https://travis-ci.org/just-containers/s6-overlay)

s6-overlay is an easy-to-install (just extract a tarball or two!) set of scripts and utilities
allowing you to use existing Docker images while using [s6](https://skarnet.org/software/s6/overview.html)
as a pid 1 for your container and process supervisor for your services.

## Quickstart

Build the following Dockerfile and try it out:

```
# Use your favorite image
FROM ubuntu
ARG S6_OVERLAY_VERSION=3.2.0.3

RUN apt-get update && apt-get install -y nginx xz-utils
RUN echo "daemon off;" >> /etc/nginx/nginx.conf
CMD ["/usr/sbin/nginx"]

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz
ENTRYPOINT ["/init"]
```

```
docker-host $ docker build -t demo .
docker-host $ docker run --name s6demo -d -p 80:80 demo
docker-host $ docker top s6demo acxf
PID                 TTY                 STAT                TIME                COMMAND
11735               ?                   Ss                  0:00                \_ s6-svscan
11772               ?                   S                   0:00                \_ s6-supervise
11773               ?                   Ss                  0:00                | \_ s6-linux-init-s
11771               ?                   Ss                  0:00                \_ rc.init
11812               ?                   S                   0:00                | \_ nginx
11814               ?                   S                   0:00                | \_ nginx
11816               ?                   S                   0:00                | \_ nginx
11813               ?                   S                   0:00                | \_ nginx
11815               ?                   S                   0:00                | \_ nginx
11779               ?                   S                   0:00                \_ s6-supervise
11785               ?                   Ss                  0:00                | \_ s6-ipcserverd
11778               ?                   S                   0:00                \_ s6-supervise
docker-host $ curl --head http://127.0.0.1/
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Mon, 17 Jan 2022 13:33:58 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Mon, 17 Jan 2022 13:32:11 GMT
Connection: keep-alive
ETag: "61e56fdb-264"
Accept-Ranges: bytes

```

## Compatibility with v2

If you're migrating from a previous version of s6-overlay (*v2*) to the
new version (*v3*), you may need to make some changes to your services
or the way you use s6-overlay in order for everything to work smoothly.
This document tries to be accurate on how v3 works, but we have a
[separate page](https://github.com/just-containers/s6-overlay/blob/master/MOVING-TO-V3.md)
listing the main differences, and things you're likely to notice. Please
read it if you're in this situation!

## Goals

The project has the following goals:

* Be usable on top of *any* Docker image
* Make it easy to create new images, that will operate like any other images
* Provide users with a turnkey s6 installation that will give them a stable
pid 1, a fast and orderly init sequence and shutdown sequence, and the power
of process supervision and automatically rotated logs.

## Features

* A simple init process which allows the end-user to execute tasks like initialization (`cont-init.d`),
finalization (`cont-finish.d`) and their own services with dependencies between them
* The s6-overlay provides proper `PID 1` functionality
  * You'll never have zombie processes hanging around in your container, they will be properly cleaned up.
* Multiple processes in a single container
* Able to operate in "The Docker Way"
* Usable with all base images - Ubuntu, CentOS, Fedora, Alpine, Busybox...
* Distributed as a small number of .tar.xz files depending on what exact functionality you need - to keep your image's number of layers small.
* A whole set of utilities included in `s6` and `s6-portable-utils`. They include handy and composable utilities which make our lives much, much easier.
* Log rotating out-of-the-box through `logutil-service` which uses [`s6-log`](https://skarnet.org/software/s6/s6-log.html) under the hood.
* Some support for Docker's `USER` directive, to run your whole process tree as a specific user. Not compatible with all features, details in the [notes](#notes) section.

## The Docker Way?

One of the oft-repeated Docker mantras is "one process per container", but we disagree.
There's nothing inherently *bad* about running multiple processes in a container.
The more abstract "one *thing* per container" is our policy - a container should do one thing,
such as "run a chat service" or "run gitlab." This may involve multiple processes, which is fine.

The other reason image authors shy away from process supervisors is they believe a process supervisor
*must* restart failed services, meaning the Docker container will never die.

This does effectively break the Docker ecosystem - most images run one process that will
exit when there's an error. By exiting on error, you allow the system administrator to
handle failures however they prefer. If your image will never exit, you now need some
alternative method of error recovery and failure notification.

Our policy is that if "the thing" fails, then the container should fail, too.
We do this by determining which processes can restart, and which should bring down
the container. For example, if `cron` or `syslog` fails, your container can most
likely restart it without any ill effects, but if `ejabberd` fails, the container
should exit so the system administrator can take action.

Our interpretation of "The Docker Way" is thus:

* Containers should do one thing
* Containers should stop when that thing stops

and our init system is designed to do exactly that. Your images will behave like
other Docker images and fit in with the existing ecosystem of images.

See "Writing an optional finish script" under the [Usage](#usage) section for details on stopping "the thing."

## Init stages

Our overlay init is a properly customized one to run appropriately in containerized environments.
This section briefly explains how stages work but if you want to know how a complete init system
should work, you can read this article: [How to run s6-svscan as process 1](https://skarnet.org/software/s6/s6-svscan-1.html)

1. **stage 1**: Its purpose is to set up the image to execute the supervision tree which
will handle all the auxiliary services, and to launch stage 2. Stage 1 is where all the
black magic happens, all the container setup details that we handle for you so that you don't
have to care about them.
2. **stage 2**: This is where most of the end-user provided files are meant to be executed:
    1. Execute legacy oneshot user scripts contained in `/etc/cont-init.d`.
    2. Run user s6-rc services declared in `/etc/s6-overlay/s6-rc.d`, following dependencies
    3. Copy legacy longrun user services (`/etc/services.d`) to a temporary directory and have s6 start (and supervise) them.
3. **stage 3**: This is the shutdown stage. When the container is supposed to exit, it will:
    1. Send a TERM signal to all legacy longrun services and, if required, wait for them to exit.
    2. Bring down user s6-rc services in an orderly fashion.
    3. Run any finalization scripts contained in `/etc/cont-finish.d`.
    4. Send all remaining processes a `TERM` signal. There should not be any remaining processes anyway.
    5. Sleep for a small grace time, to allow stray processes to exit cleanly.
    6. Send all processes a `KILL` signal. Then the container exits.

## Installation

s6-overlay comes as a set of tarballs that you can extract onto your image.
The tarballs you need are a function of the image you use; most people will
need the first two, and the other ones are extras you can use at your
convenience.

1. `s6-overlay-noarch.tar.xz`: this tarball contains the scripts
implementing the overlay. We call it "noarch" because it is architecture-
independent: it only contains scripts and other text files. Everyone who
wants to run s6-overlay needs to extract this tarball.
2. `s6-overlay-x86_64.tar.xz`: replace `x86_64` with your
system's architecture. This tarball contains all the necessary binaries
from the s6 ecosystem, all linked statically and out of the way of
your image's binaries. Unless you know for sure that your image already
comes with all the packages providing the binaries used in the overlay,
you need to extract this tarball.
3. `s6-overlay-symlinks-noarch.tar.xz`: this tarball contains
symlinks to the s6-overlay scripts so they are accessible via `/usr/bin`.
It is normally not needed, all the scripts are accessible via the PATH
environment variable, but if you have old user scripts containing
shebangs such as `#!/usr/bin/with-contenv`, installing these symlinks
will make them work.
4. `s6-overlay-symlinks-arch.tar.xz`: this tarball contains
symlinks to the binaries from the s6 ecosystem provided by the second
tarball, to make them accessible via `/usr/bin`. It is normally not
needed, but if you have old user scripts containing shebangs such as
`#!/usr/bin/execlineb`, installing these symlinks will make them work.
5. `syslogd-overlay-noarch.tar.xz`: this tarball contains
definitions for a `syslogd` service. If you are running daemons that
cannot log to stderr to take advantage of the s6 logging infrastructure,
but hardcode the use of the old `syslog()` mechanism, you can extract
this tarball, and your container will run a lightweight emulation of a
`syslogd` daemon, so your syslog logs will be caught and stored to disk.

To install those tarballs, add lines to your Dockerfile that correspond
to the functionality you want to install. For instance, most people would
use the following:
```
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz
```

Make sure to preserve file permissions when extracting (i.e. to use the
`-p` option to `tar`.)

## Usage

The project is distributed as a set of standard .tar.xz files, which you extract at the root of your image.
(You need the xz-utils package for `tar` to understand `.tar.xz` files; it is available
in every distribution, but not always in the default container images, so you may need
to `apt install xz-utils` or `apk add xz`, or equivalent, before you can
expand the archives.)

Afterwards, set your `ENTRYPOINT` to `/init`.

Right now, we recommend using Docker's `ADD` directive instead of running `wget` or `curl`
in a `RUN` directive - Docker is able to handle the https URL when you use `ADD`, whereas
your base image might not be able to use https, or might not even have `wget` or `curl`
installed at all.

From there, you have a couple of options:

* If you want the container to exit when your program exits: run the program as your image's `CMD`.
* If you want the container to run until told to exit, and your program to be supervised by s6:
write a service script for your program.

### Using `CMD`

Using `CMD` is a convenient way to take advantage of the overlay. Your `CMD` can be given at
build time in the Dockerfile, or at run time on the command line, either way is fine. It will
be run as a normal process in the environment set up by s6; when it fails or exits, the
container will shut down cleanly and exit. You can run interactive programs in this manner:
only the CMD will receive your interactive command, the support processes will be unimpacted.

For example:

```
FROM busybox
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz
ENTRYPOINT ["/init"]
```

```
docker-host $ docker build -t s6demo .
docker-host $ docker run -ti s6demo /bin/sh
/package/admin/s6-overlay/libexec/preinit: notice: /var/run is not a symlink to /run, fixing it
s6-rc: info: service s6rc-oneshot-runner: starting
s6-rc: info: service s6rc-oneshot-runner successfully started
s6-rc: info: service fix-attrs: starting
s6-rc: info: service fix-attrs successfully started
s6-rc: info: service legacy-cont-init: starting
s6-rc: info: service legacy-cont-init successfully started
s6-rc: info: service legacy-services: starting
s6-rc: info: service legacy-services successfully started
/ # ps
PID   USER     TIME  COMMAND
    1 root      0:00 /package/admin/s6/command/s6-svscan -d4 -- /run/service
   17 root      0:00 {rc.init} /bin/sh -e /run/s6/basedir/scripts/rc.init top /bin/sh
   18 root      0:00 s6-supervise s6-linux-init-shutdownd
   20 root      0:00 /package/admin/s6-linux-init/command/s6-linux-init-shutdownd -c /run/s6/basedir -g 3000 -C -B
   24 root      0:00 s6-supervise s6rc-fdholder
   25 root      0:00 s6-supervise s6rc-oneshot-runner
   31 root      0:00 /package/admin/s6/command/s6-ipcserverd -1 -- /package/admin/s6/command/s6-ipcserver-access -v0 -E -l0 -i data/rules -- /packa
   58 root      0:00 /bin/sh
   66 root      0:00 ps
/ # exit
s6-rc: info: service legacy-services: stopping
s6-rc: info: service legacy-services successfully stopped
s6-rc: info: service legacy-cont-init: stopping
s6-rc: info: service legacy-cont-init successfully stopped
s6-rc: info: service fix-attrs: stopping
s6-rc: info: service fix-attrs successfully stopped
s6-rc: info: service s6rc-oneshot-runner: stopping
s6-rc: info: service s6rc-oneshot-runner successfully stopped
docker-host $
```

### Writing a service script

The other way to use a container with s6-overlay is to make your
services supervised. You can supervise any number of services;
usually they're just support services for the main daemon you run as
a CMD, but if that's what you want, nothing prevents you from having
an empty CMD and running your main daemon as a supervised service as
well. In that case, the daemon will be restarted by s6 whenever it
exits; the container will only stop when you tell it to do so, either
via a `docker stop` command, or from inside the container with the
`/run/s6/basedir/bin/halt` command.

There are two ways of making a supervised service. The old way, which
is still supported, is to make a "pure s6" service directory. Create a
directory with the name of your service in `/etc/services.d` and put an executable `run`
file into it; this is the file in which you'll put your long-lived process execution.
For details of supervision of service directories, and how you can
configure how s6 handles your daemon, you can take a look at the
[servicedir](https://skarnet.org/software/s6/servicedir.html) documentation.
A simple example would look like this:

`/etc/services.d/myapp/run`:
```
#!/command/execlineb -P
nginx -g "daemon off;"
```

The new way is to make an [s6-rc](https://skarnet.org/software/s6-rc/)
*source definition directory* in the `/etc/s6-overlay/s6-rc.d` directory,
and add the name of that directory to the `user` bundle, i.e. create an
empty file with the same name in the `/etc/s6-overlay/s6-rc.d/user/contents.d`
directory. The format of a *source definition directory* is described in
[this page](https://skarnet.org/software/s6-rc/s6-rc-compile.html). Note that
you can define *longruns*, i.e. daemons that will get supervised by s6 just
like with the `/etc/services.d` method, but also *oneshots*, i.e. programs that
will run once and exit. Your main service is probably a *longrun*, not a
*oneshot*: you probably need a daemon to stick around.

The advantage of this new format is that it allows you to define dependencies
between services: if *B* depends on *A*, then *A* will start first, then *B* will
start when *A* is ready, and when the container is told to exit, *B* will stop
first, then *A*. If you have a complex architecture where various processes
depends on one another, or simply where you have to mix *oneshots* and *longruns*
in a precise order, this may be for you.

The example above could be rewritten this way:

`/etc/s6-overlay/s6-rc.d/myapp/type`:
```
longrun
```

`/etc/s6-overlay/s6-rc.d/myapp/run`:
```
#!/command/execlineb -P
nginx -g "daemon off;"
```

`/etc/s6-overlay/s6-rc.d/user/contents.d/myapp`: empty file.
(This adds `myapp` to the set of services that s6-rc will start at
container boot.)

`/etc/s6-overlay/s6-rc.d/myapp/dependencies.d/base`: empty file.
(This tells s6-rc to only start `myapp` when all the base services
are ready: it prevents race conditions.)

We encourage you to switch to the new format, but if you don't need its
benefits, you can stick with regular service directories in `/etc/services.d`,
it will work just as well.

### Setting the exit code of the container to the exit code of your main service

If you run your main service as a CMD, you have nothing to do: when your CMD
exits, or when you run `docker stop`, the container will naturally exit with the
same exit code as your service. (Be aware, however, that in the `docker stop`
case, your service will get a SIGTERM, in which case the exit code will entirely
depend on how your service handles it - it could trap it and exit 0, trap it and
exit something else, or not trap it and let the shell exit its own code for it -
normally 130.)

If you run your main service as a supervised service, however, things are
different, and you need to tell the container what code to exit with when you
send it a `docker stop` command. To do that, you need to write a `finish` script:

- If your service is a legacy service in `/etc/services.d`, you need an
executable `/etc/services.d/myapp/finish` script.
- If your service is an s6-rc one, you need a
`/etc/s6-overlay/s6-rc.d/myapp/finish` file containing your script (the
file may or may not be executable).

This `finish` script will be run when your service exits, and will take
two arguments:

- The first argument will be the exit code of your service, or 256 if
your service was killed by an uncaught signal.
- The second argument is only meaningful if your service was killed by
an uncaught signal, and contains the number of said signal.

In the `finish` script, you need to write the container exit code you
want to the `/run/s6-linux-init-container-results/exitcode` file - and
that's it.

For instance, the `finish` script for the `myapp` service above could
be something like this:
```sh
#!/bin/sh

if test "$1" -eq 256 ; then
  e=$((128 + $2))
else
  e="$1"
fi

echo "$e" > /run/s6-linux-init-container-results/exitcode
```
When you send a `docker stop` command to your container, the `myapp`
service will be killed and this script will be run; it will write
either `myapp`'s exit code (if `myapp` catches the TERM signal) or
130 (if `myapp` does not catch the TERM signal) to the special
`/run/s6-linux-init-container-results/exitcode` file, which will
be read by s6-overlay at the end of the container shutdown procedure,
and your container will exit with that value.

### Fixing ownership and permissions

This section describes a functionality from the versions of s6-overlay
that are **anterior to** v3. fix-attrs is still supported in v3,
but is **deprecated**, for several reasons: one of them is that it's
generally not good policy to change ownership dynamically when it can be
done statically. Another reason is that it doesn't work with USER containers.
Instead of fix-attrs, we now recommend you to take care of ownership and
permissions on host mounts *offline, before running the container*. This
should be done in your Dockerfile, when you have all the needed information.

That said, here is what we wrote for previous versions and that is still
applicable today (but please stop depending on it):

Sometimes it's interesting to fix ownership & permissions before proceeding because,
for example, you have mounted/mapped a host folder inside your container. Our overlay
provides a way to tackle this issue using files in `/etc/fix-attrs.d`.
This is the pattern format followed by fix-attrs files:

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
  * `daemon:11111,3:4:      UID=2     GID=11111`
  * `11111:daemon,3:4:      UID=11111 GID=2`
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

### Executing initialization and finalization tasks

Here is the old way of doing it:

After fixing attributes (through `/etc/fix-attrs.d/`) and before starting
user provided services (through s6-rc or `/etc/services.d`) our overlay will
execute all the scripts found in `/etc/cont-init.d`, for example:

[`/etc/cont-init.d/02-confd-onetime`](https://github.com/just-containers/nginx-loadbalancer/blob/master/rootfs/etc/cont-init.d/02-confd-onetime):
```
#!/command/execlineb -P

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

This way is still supported. However, there is now a more generic and
efficient way to do it: writing your oneshot initialization and finalization
tasks as s6-rc services, by adding service definition directories in
`/etc/s6-overlay/s6-rc.d`, making them part of the `user` bundle (so they
are actually started when the container boots), and making them depend on
the `base` bundle (so they are only started after `base`).

All the information on s6-rc can be found [here](https://skarnet.org/software/s6-rc/).

When the container is started, the operations are performed in this order:

- (deprecated) Attribute fixing is performed according to files in `/etc/fix-attrs.d`.
- (legacy) One-shot initialization scripts in `/etc/cont-init.d` are run sequentially.
- Services in the `user` bundle are started by s6-rc, in an order defined by
dependencies. Services can be oneshots (initialization
tasks) or longruns (daemons that will run throughout the container's lifetime). If
the services depend on `base`, they are guaranteed to start at this point and not
earlier; if they do not, they might have been started earlier, which may cause
race conditions - so it's recommended to always make them depend on `base`.
- (legacy) Longrun services in `/etc/services.d` are started.
- Services in the `user2` bundle with the correct dependency are started.
(Most people don't need to use this; if you are not sure, stick to the `user` bundle.)

When the container is stopped, either because the admin sent a stop command or
because the CMD exited, the operations are performed in the reverse order:

- Services in the `user2` bundle with the correct dependency are stopped.
- (legacy) Longrun services in `/etc/services.d` are stopped.
- All s6-rc services are stopped, in an order defined by dependencies. For
oneshots, that means that the `down` script in the source definition directory
is executed; that's how s6-rc can perform finalization tasks.
- (legacy) One shot finalization scripts in `/etc/cont-finish.d` are run sequentially.

The point of the `user2` bundle is to allow user services declared in it to
start *after* the `/etc/services.d` ones; but in order to do so, every service
in `user2` needs to declare a dependency to `legacy-services`. In other words,
for a service `foobar` to start late, you need to:
- Define it in `/etc/s6-overlay/s6-rc.d/foobar` like any other s6-rc service.
- Add an `/etc/s6-overlay/s6-rc.d/foobar/dependencies.d/legacy-services` file
- Add an `/etc/s6-overlay/s6-rc.d/user2/contents.d/foobar` file.

That will ensure that `foobar` will start _after_ everything in `/etc/services.d`.

### Writing an optional finish script

By default, services created in `/etc/services.d` will automatically restart.
If a service should bring the container down, you should probably run it as
a CMD instead; but if you'd rather run it as a supervised service, then you'll
need to write a `finish` script, which will be run when the service is down; to
make the container stop, the `/run/s6/basedir/bin/halt` command must be invoked.
Here's an example finish script:

`/etc/services.d/myapp/finish`:
```
#!/command/execlineb -S0

foreground { redirfd -w 1 /run/s6-linux-init-container-results/exitcode echo 0 }
/run/s6/basedir/bin/halt
```

The first line of the script writes `0` to the `/run/s6-linux-init-container-results/exitcode` file.
The second line stops the container. When you stop the container via the `/run/s6/basedir/bin/halt`
command run from inside the container, `/run/s6-linux-init-container-results/exitcode` is read and
its contents are used as the exit code for the `docker run` command that launched the container.
If the file doesn't exist, or if the container is stopped with `docker stop` or another reason,
that exit code defaults to 0.

It is possible to do more advanced operations in a finish script. For example, here's a script
from that only brings down the service when it exits nonzero:

`/etc/services.d/myapp/finish`:
```
#!/command/execlineb -S1
if { eltest ${1} -ne 0 -a ${1} -ne 256 }
/run/s6/basedir/bin/halt
```

Note that in general, finish scripts should only be used for local cleanups
after a daemon dies. If a service is so important that the container needs
to stop when it dies, we really recommend running it as the CMD.

### Logging

Every service can have its dedicated logger. A logger is a s6 service that
automatically reads from the *stdout* of your service, and logs the data
to an automatically rotated file in the place you want. Note that daemons
usually log to stderr, not stdout, so you should probably start your service's
run script with `exec 2>&1` in shell, or with `fdmove -c 2 1` in execline, in
order to catch *stderr*.

s6-overlay provides a utility called `logutil-service` which is a wrapper over
the [`s6-log`](https://skarnet.org/software/s6/s6-log.html) program.
This helper does the following:
- read how s6-log should proceed reading the logging script contained in `S6_LOGGING_SCRIPT`
- drop privileges to the `nobody` user (defaulting to `65534:65534` if it doesn't exist)
- clean all the environments variables
- execute into s6-log.

s6-log will then run forever, reading data from your service and writing it to
the directory you specified to `logutil-service`.

Please note:
- Since the privileges are dropped automatically, there is no need to switch users with `s6-setuidgid`
- You should ensure the log folder either:
  - exists, and is writable by the `nobody` user
  - does not exist, but the parent folder is writable by the `nobody` user.

You can create log folders in `cont-init.d` scripts, or as s6-rc oneshots.
Here is an example of a logged service `myapp` implemented the old way:

`/etc/cont-init.d/myapp-log-prepare`:
```sh
#!/bin/sh -e
mkdir -p /var/log/myapp
chown nobody:nogroup /var/log/myapp
chmod 02755 /var/log/myapp
```

`/etc/services.d/myapp/run`:
```sh
#!/bin/sh
exec 2>&1
exec mydaemon-in-the-foreground-and-logging-to-stderr
```

`/etc/services.d/myapp/log/run`:
```sh
#!/bin/sh
exec logutil-service /var/log/myapp
```

And here is the same service, myapp, implemented in s6-rc.

`/etc/s6-overlay/s6-rc.d/myapp-log-prepare/dependencies.d/base`: empty file

`/etc/s6-overlay/s6-rc.d/myapp-log-prepare/type`:
```
oneshot
```

`/etc/s6-overlay/s6-rc.d/myapp-log-prepare/up`:
```
if { mkdir -p /var/log/myapp }
if { chown nobody:nogroup /var/log/myapp }
chmod 02755 /var/log/myapp
```

<details><summary>(Click here for an explanation of the weird syntax
or if you don't understand why your `up` file isn't working.)</summary>
<p>

(Beginning of the detailed section.)

So, the `up` and `down` files are special: they're not shell scripts, but
single command lines interpreted by [execlineb](https://skarnet.org/software/execline/execlineb.html).
You should not have to worry about execline; you should only remember that
an `up` file contains a single command line. So if you need a script with
several instructions, here's how to do it:

- Write your script in the language of your choice, in a location of your choice
- Make it executable
- Call that script in the `up` file.

Here is how you would normally proceed to write the `up` file for
`myapp-log-prepare`:

`/etc/s6-overlay/s6-rc.d/myapp-log-prepare/up`:
```
/etc/s6-overlay/scripts/myapp-log-prepare
```

`/etc/s6-overlay/scripts/myapp-log-prepare`: (needs to be executable)
```sh
#!/bin/sh -e
mkdir -p /var/log/myapp
chown nobody:nogroup /var/log/myapp
chmod 02755 /var/log/myapp
```

The location of the actual script is arbitrary, it just needs to match
what you're writing in the `up` file.

But here, it just so happens that the script is simple enough that it can
fit entirely in the `up` file without making it too complex or too
difficult to understand. So, we chose to include it as an example to
show that there's more that you can do with `up` files, if you are
so inclined. You can read the full documentation for the execline
language [here](https://skarnet.org/software/execline/).

(End of the detailed section, click the triangle above again to collapse.)
</p>
</details>

`/etc/s6-overlay/s6-rc.d/myapp/dependencies.d/base`: empty file

`/etc/s6-overlay/s6-rc.d/myapp-log/dependencies.d/myapp-log-prepare`: empty file


`/etc/s6-overlay/s6-rc.d/myapp/type`:
```
longrun
```

`/etc/s6-overlay/s6-rc.d/myapp/run`:
```sh
#!/bin/sh
exec 2>&1
exec mydaemon-in-the-foreground-and-logging-to-stderr
```

`/etc/s6-overlay/s6-rc.d/myapp/producer-for`:
```
myapp-log
```

`/etc/s6-overlay/s6-rc.d/myapp-log/type`:
```
longrun
```

`/etc/s6-overlay/s6-rc.d/myapp-log/run`:
```sh
#!/bin/sh
exec logutil-service /var/log/myapp
```

`/etc/s6-overlay/s6-rc.d/myapp-log/consumer-for`:
```
myapp
```

`/etc/s6-overlay/s6-rc.d/myapp-log/pipeline-name`:
```
myapp-pipeline
```

`/etc/s6-overlay/s6-rc.d/user/contents.d/myapp-pipeline`: empty file

That's a lot of files! A summary of what it all means is:
- myapp-log-prepare is a oneshot, preparing the logging directory.
It is a dependency of myapp-log, so it will be started *before* myapp-log.
- myapp is a producer for myapp-log and myapp-log is a consumer for myapp,
so what myapp writes to its stdout will go to myapp-log's stdin. Both
are longruns, i.e. daemons that will be supervised by s6.
- The `myapp | myapp-log` pipeline is given a name, `myapp-pipeline`, and
this name is declared as a part of the `user` bundle, so it will be started
when the container starts.
- `myapp-log-prepare`, `myapp-log` and `myapp` all depend on the `base`
bundle, which means they will only be started when the system is actually
ready to start them.

It really accomplishes the same things as the `/etc/cont-init.d` plus
`/etc/services.d` method, but it's a lot cleaner underneath, and can handle
much more complex dependency graphs, so whenever you get the opportunity,
we recommend you familiarize yourself with the [s6-rc](https://skarnet.org/software/s6-rc/)
way of declaring your services and your loggers. The full syntax of a
service definition directory, including declaring whether your service
is a longrun or a oneshot, declaring pipelines, adding service-specific
timeouts if you need them, etc., can be found
[here](https://skarnet.org/software/s6-rc/s6-rc-compile.html#source).


### Dropping privileges

When it comes to executing a service, no matter whether it's a service or a logger,
a good practice is to drop privileges before executing it.
`s6` already includes utilities to do exactly these kind of things:

In `execline`:

```
#!/command/execlineb -P
s6-setuidgid daemon
myservice
```

In `sh`:

```sh
#!/bin/sh
exec s6-setuidgid daemon myservice
```

If you want to know more about these utilities, please take a look at:
[`s6-setuidgid`](http://skarnet.org/software/s6/s6-setuidgid.html),
[`s6-envuidgid`](http://skarnet.org/software/s6/s6-envuidgid.html), and
[`s6-applyuidgid`](http://skarnet.org/software/s6/s6-applyuidgid.html).

### Container environment

If you want your custom script to have container environments available:
you can use the `with-contenv` helper, which will push all of those into your
execution environment, for example:

`/etc/cont-init.d/01-contenv-example`:
```sh
#!/command/with-contenv sh
env
```

This script will output the contents of your container environment.

### Read-Only Root Filesystem

Recent versions of Docker allow running containers with a read-only root filesystem.
If your container is in such a case, you should set `S6_READ_ONLY_ROOT=1` to inform
s6-overlay that it should not attempt to write to certain areas - instead, it will
perform copies into a tmpfs mounted on `/run`.

Note that s6-overlay assumes that:
- `/run` exists and is writable. If it is not, it will attempt to mount a tmpfs there.
- `/var/run` is a symbolic link to `/run`, for compatibility with previous versions. If it is not, it will make it so.

In general your default docker settings should already provide a suitable tmpfs in `/run`.

### Customizing s6-overlay behaviour

It is possible somehow to tweak s6-overlay's behaviour by providing an already predefined set of environment variables to the execution context:

* `PATH` (default = `/command:/usr/bin:/bin`):
this is the default PATH that all the services in the container,
including the CMD, will have. Set this variable if you have a lot
of services that depend on binaries stored in another directory, e.g.
`/usr/sbin`. Note that `/command`, `/usr/bin` and `/bin` will always
be added to that path if they're not already in the one you provide.
* `S6_KEEP_ENV` (default = 0): if set, then environment is not reset and whole supervision tree sees original set of env vars. It switches `with-contenv` into a nop.
* `S6_LOGGING` (default = 0): 
  * **`0`**: Outputs everything to stdout/stderr.
  * **`1`**: Uses an internal `catch-all` logger and persists everything on it, it is located in `/var/log/s6-uncaught-logs`. Anything run as a `CMD` is still output to stdout/stderr.
  * **`2`**: Uses an internal `catch-all` logger and persists everything on it, including the output of `CMD`. Absolutely nothing is written to stdout/stderr.
* `S6_CATCHALL_USER` (default = root): if set, and if `S6_LOGGING` is 1 or 2,
then the catch-all logger is run as this user, which must be defined in your
image's `/etc/passwd`. Every bit of privilege separation helps a little with security.
* `S6_BEHAVIOUR_IF_STAGE2_FAILS` (default = 0): determines what the container should do
if one of the service scripts fails. This includes:
  * if the early stage2 hook exits nonzero (by default there's no hook)
  * if anything fails in `fix-attrs`
  * if any old-style `/etc/cont-init.d` or new-style [s6-rc](https://skarnet.org/software/s6-rc/) oneshot fails
  * if any old-style `/etc/services.d` or new-style [s6-rc](https://skarnet.org/software/s6-rc/) longrun is marked
as expecting readiness notification, and fails to become *ready* in the allotted time (see
`S6_CMD_WAIT_FOR_SERVICES_MAXTIME` below). The valid values for `S6_BEHAVIOUR_IF_STAGE2_FAILS`
are the following:
  * **`0`**: Continue silently even if a script has failed.
  * **`1`**: Continue but warn with an annoying error message.
  * **`2`**: Stop the container.
* `S6_KILL_FINISH_MAXTIME` (default = 5000): How long (in milliseconds) the system should
wait, at shutdown time, for a script in `/etc/cont-finish.d` to finish naturally. After this
duration, the script will be sent a SIGKILL. Bear in mind that scripts in `/etc/cont.finish.d`
are run sequentially, and the shutdown sequence will potentially wait for `S6_KILL_FINISH_MAXTIME`
milliseconds for *each* script.
* `S6_SERVICES_READYTIME` (default = 50): With services declared in `/etc/services.d`, there is
an unavoidable race condition between the moment when services are started and the moment when
they can be tested for readiness. To avoid that race, we sleep a little time, by default 50
milliseconds, before testing for readiness. If your machine is slow or very busy, you may
get errors looking like `s6-svwait: fatal: unable to s6_svstatus_read: No such file or directory`.
In that case, you should increase the sleeping time, by declaring it (in milliseconds) in the
`S6_SERVICES_READYTIME` variable. Note that it only concerns `/etc/services.d`; s6-rc is immune
to the race condition.
* `S6_SERVICES_GRACETIME` (default = 3000): How long (in milliseconds) `s6` should wait,
at shutdown time, for services declared in `/etc/services.d` to die before proceeding
with the rest of the shutdown.
* `S6_KILL_GRACETIME` (default = 3000): How long (in milliseconds) `s6` should wait, at the end of
the shutdown procedure when all the processes have received a TERM signal, for them to die
before sending a `KILL` signal to make *sure* they're dead.
* `S6_LOGGING_SCRIPT` (default = "n20 s1000000 T"): This env decides what to log and how, by default every line will prepend with ISO8601, rotated when the current logging file reaches 1mb and archived, at most, with 20 files.
* `S6_CMD_ARG0` (default = not set): Value of this env var will be prepended to any `CMD` args passed by docker. Use it if you are migrating an existing image to s6-overlay and want to make it a drop-in replacement: setting this variable to the value of a previously used ENTRYPOINT will help you transition.
* `S6_CMD_USE_TERMINAL` (default = 0): Set this value to **1** if you have a CMD that needs a terminal for its output
(typically when you're running your container with `docker run -it`), and you have set `S6_LOGGING` to a nonzero value.
This setting will make your CMD actually output to your terminal; the drawback is that its output will not be logged.
By default (when this variable is **0** or not set), the stdout and stderr of your CMD are logged when `S6_LOGGING` is nonzero,
which means they go to a pipe even if you're running it in an interactive terminal.
* `S6_FIX_ATTRS_HIDDEN` (default = 0): Controls how `fix-attrs.d` scripts process files and directories.
  * **`0`**: Hidden files and directories are excluded.
  * **`1`**: All files and directories are processed.
* `S6_CMD_WAIT_FOR_SERVICES` (default = 0): By default when the container starts,
services in `/etc/services.d` will be started and execution will proceed to
starting the `user2` bundle and the CMD, if any of these is defined. If
`S6_CMD_WAIT_FOR_SERVICES` is nonzero, however, the container starting sequence
will wait until the services in `/etc/services.d` are *ready* before proceeding
with the rest of the sequence. Note that this is only significant if the services in `/etc/services.d`
[notify their readiness](https://skarnet.org/software/s6/notifywhenup.html) to s6.
* `S6_CMD_WAIT_FOR_SERVICES_MAXTIME` (default = 0, i.e. infinite): The maximum time (in milliseconds) the services could take to bring up before proceding to CMD executing.
Set this variable to a positive value if you have services that can potentially block indefinitely and you prefer the container to fail
if not everything is up after a given time.
Note that this value also includes the time setting up legacy container initialization (`/etc/cont-init.d`) and services (`/etc/services.d`), so
take that into account when computing a suitable value. In versions of s6-overlay up to 3.1.6.2, the default was 5000 (five seconds),
but it caused more unwanted container failures than it solved issues, so now there's no timeout by default: s6-overlay will wait as long as
is necessary for all the services to be brought up.
* `S6_READ_ONLY_ROOT` (default = 0): When running in a container whose root filesystem is read-only, set this env to **1** to inform init stage 2 that it should copy user-provided initialization scripts from `/etc` to `/run/s6/etc` before it attempts to change permissions, etc. See [Read-Only Root Filesystem](#read-only-root-filesystem) for more information.
* `S6_SYNC_DISKS` (default = 0): Set this env to **1** to inform init stage 3 that it should attempt to sync filesystems before stopping the container. Note: this will likely sync all filesystems on the host.
* `S6_STAGE2_HOOK` (default = none): If this variable exists, its contents
will be interpreted as a shell excerpt that will be run in the early stage 2,
before services are started. This can be used, for instance, to dynamically
patch the service database at run-time right before it is compiled and run.
If the hook program exits nonzero and `S6_BEHAVIOUR_IF_STAGE2_FAILS` is 2 or more,
the container will stop instantly. Please note that running the wrong hook program
may prevent your container from starting properly, or may endanger your security;
so only use this if you know exactly what you are doing. When in doubt, leave
this variable undefined.
* `S6_VERBOSITY` (default = 2): controls the verbosity of s6-rc, and potentially
other tools, at container start and stop time. The default, 2, is normally verbose:
it will list the service start and stop operations. You can make the container quieter
by decreasing this number: 1 will only print warnings and errors, and 0 will only
print errors. You can also make the container _more_ verbose, i.e. print tracing and
debug information, by increasing this number up to 5, but the output will quickly
become _very_ noisy, and most people shouldn't need this.
* `S6_CMD_RECEIVE_SIGNALS` (default = 0): decides whether signals sent to the
container should be sent to the container's pid 1 or to the CMD. By default, when
you perform for instance a `docker stop`, a TERM signal will be sent to the
container's pid 1, which will trigger the full container shutdown sequence - but
if a CMD is present, it will be among the last processes to be killed, only when
everything else is down and the container is about to exit. If this variable is
1 or more, signals are diverted from pid 1 to the CMD, which means that `docker stop`
will send a SIGTERM to the CMD instead, and the container will only trigger its shutdown
procedure when the CMD is dead. Note that only SIGTERM, SIGQUIT, SIGINT, SIGUSR1,
SIGUSR2, SIGPWR and SIGWINCH are diverted; other signals either are ignored or
cannot be diverted and are necessarily handled by pid 1. Please be aware that using
this option may prevent interactive CMDs from working at all - in other words, if
you're running an interactive CMD in a terminal, don't set this variable; but that
should be fine since in this case you already have interactive ways of stopping your CMD.

### syslog

If software running in your container requires syslog, extract the
`syslogd-overlay-noarch.tar.xz` tarball:
that will give you a small syslogd emulation. Logs will be found
under various subdirectories of `/var/log/syslogd`, for instance
messages will be found in the `/var/log/syslogd/messages/` directory,
the latest logs being available in the `/var/log/syslogd/messages/current` file.
Logging directories are used rather than files so that logs can be
automatically rotated without race conditions (that is a feature of
[s6-log](https://skarnet.org/software/s6/s6-log.html)).

It is recommended to add `syslog` and `sysllog` users to your image, for
privilege separation; the syslogd emulation processes will run as these users
if they exist. Otherwise they will default to `32760:32760` and `32761:32761`,
numeric uids/gids that may already exist on your system.

## Performance

- The noarch and symlinks tarballs are all tiny. The biggest tarball is the
one that contains the binaries; it's around 650 kB.
- Uncompressed on a tmpfs, the overlay scripts use about 120 kB, and the
binaries for x86_64 use about 5.7 MB.
- We haven't yet measured the time it takes for the container to be up and running
once you run `docker run`, but you will notice it's fast. Faster than previous
versions of s6-overlay, with fewer delays. And if you convert your `/etc/cont-init.d`
scripts to the s6-rc format, they will be able to run in parallel, so you will
gain even more performance. If you have benchmarks, please send them to us!


## Verifying Downloads

The s6-overlay releases have a checksum files you can use to verify
the download using SHA256:

```sh
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz.sha256 /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz.sha256 /tmp
RUN cd /tmp && sha256sum -c *.sha256
```

## Notes

### `USER` directive

As of version 3.2.0.2, s6-overlay has limited support for running as a user other than `root`:

* Tools like `fix-attrs` and `logutil-service` are unlikely to work (they rely
  on being able to change UIDs).
* The syslogd emulation will not work.

Generally speaking, if you're running a simple container with a main application and
one or two support services, you may benefit from the `USER` directive if that is
your preferred way of running containers. However, if you're running more than a few
services, or daemons that expect a real system with complete Unix infrastructure,
then USER is probably not a good idea and you would benefit more from using
privilege separation between services in your container.

### Terminal support

Generally speaking, you *should not* run your containers with `docker run -it`.
It is bad practice to have console access to your containers. That said, if your
CMD is interactive and needs a terminal, s6-overlay will try to support it whenever
possible, but the nature of terminals makes it difficult to ensure that everything
works perfectly in all cases.

In particular, if you are stacking virtualization environments and other layers
already have their own kludges for terminals - for instance, if you are running
s6-overlay under qemu - then it is almost guaranteed that `docker run -it` will
not work. However, once the container is running, you should always be able to
access an interactive shell inside it via `docker exec -it containername /bin/sh`.

The same caveats apply to stopping containers with ^C. Normally containers are
stopped via `docker stop`, or when the CMD exits; ^C is not an officially supported
method of stopping them. s6-overlay *tries* to exit cleanly on ^C, whether the
container is running with `-it` or not, but there will be cases where it is
unfortunately impossible.


## Releases

Over on the releases tab, we have a number of tarballs:

* `s6-overlay-noarch.tar.xz`: the s6-overlay scripts.
* `s6-overlay-${arch}.tar.xz`: the binaries for platform *${arch}*.
They are statically compiled and will work with any Linux distribution.
* `s6-overlay-symlinks-noarch.tar.xz`: `/usr/bin` symlinks to the s6-overlay scripts. Totally optional.
* `s6-overlay-symlinks-arch.tar.xz`: `/usr/bin` symlinks to the skaware binaries. Totally optional.
* `syslogd-overlay-noarch.tar.xz`: the syslogd emulation. Totally optional.
* `s6-overlay-${version}.tar.xz`: the s6-overlay source. Download it if you want to build s6-overlay yourself.

We have binaries for at least x86_64, aarch64, arm32, i486, i686, riscv64, and s390x.
The full list of supported arches can be found in [conf/toolchains](https://github.com/just-containers/s6-overlay/blob/master/conf/toolchains).

### Which architecture to use depending on your TARGETARCH

The `${arch}` part in the `s6-overlay-${arch}.tar.xz` tarball uses
the naming conventions of gcc, which are not the ones that Docker
uses. (Everyone does something different in this field depending on
their needs, and no solution is better than any other, but the Docker
one is *worse* than others because its naming is inconsistent. The gcc
convention is better for us because it simplifies our builds greatly and
makes them more maintainable.)

The following table should help you find the right tarball for you
if you're using the TARGETARCH value provided by Docker:

| ${TARGETARCH} | ${arch} | Notes                 |
|:--------------|:--------|:----------------------|
| amd64         | x86_64  |                       |
| arm64         | aarch64 |                       |
| arm/v7        | arm     | armv7 with soft-float |
| arm/v6        | armhf   | Raspberry Pi 1        |
| 386           | i686    | i486 for very old hw  |
| riscv64       | riscv64 |                       |
| s390x         | s390x   |                       |

If you need another architecture, ask us and we'll try to make a toolchain
for it. In particular, we know that armv7 is a mess and needs a flurry of
options depending on your precise target (and this is one of the reasons why
the Docker naming system isn't good, although arguably the gcc naming system
isn't much better on that aspect).

## Contributing

Any way you want! Open issues, open PRs, we welcome all contributors!

## Building the overlay yourself

- Download the [s6-overlay source].
- Check the [conf/defaults.mk](https://github.com/just-containers/s6-overlay/blob/master/conf/defaults.mk)
file for variables you may want to change. Do not modify the file itself.
- Call `make` followed by your variable assignments. Example: `make ARCH=riscv64-linux-musl`
to build the overlay for RISCV64.
- The tarballs will be in the `output` subdirectory, unless you changed the `OUTPUT` variable.

## Upgrade Notes

Please see [CHANGELOG](./CHANGELOG.md).
