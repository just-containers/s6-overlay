
# Moving from s6-overlay v2 to s6-overlay v3

 There are a lot of changes between version 2 of s6-overlay, which was
the one used until 2021, and version 3, which was released in January 2022.

 This document sums up the most important changes.
 As always, please refer to the latest version of the
[README.md file](https://github.com/just-containers/s6-overlay/blob/master/README.md)
for detailed s6-overlay usage instructions.

 Thanks for @alexyao2015 for the initial ideas for this document.

## Immediately visible changes

- s6-overlay is now provided as a series of several tarballs, that you can pick
and choose depending on the details of how you use s6-overlay. Most people will
need *two* tarballs (the architecture-dependent binaries, and the architecture-independent
overlay scripts).
  * These tarballs are `.tar.xz` files: to extract them, most distributions
require installing the `xz-utils` package, which is not always provided by
default.
- Except when specifically built otherwise, commands and scripts provided by s6-overlay
now reside under `/command`. This means several things:
  * The default PATH always contains `/command` as well as `/usr/bin` and `/bin`. You can
add directories to that PATH by declaring your own `PATH` variable in the Dockerfile.
  * s6-overlay commands should *always* be called by their short name, never by an
absolute path. You should always trust PATH to do the right thing.
    + In practice: every time you used something like `/bin/s6-chmod`, change it to
`s6-chmod` instead. That will work in every situation.
  * Shebangs, which require absolute paths, are an exception, and need manual editing.
For instance, `#!/usr/bin/with-contenv` should be changed to `#!/command/with-contenv`.
    + To give you time to perform that change incrementally, s6-overlay provides
optional tarballs that install `/usr/bin/foobar` symlinks to `/command/foobar`.
- All the user scripts need to be executable: they are now *executed* instead of
*interpreted by a shell*.
- The supervision tree now resides in `/run/service`, and you should not attempt to stop it
when you want to exit the container; more generally you should not attempt to send
control commands to the supervision tree. In particular, you should not try to run
the `s6-svscanctl -t /var/run/s6/services` command - it will not work anyway because
the supervision tree has changed locations. If you need to exit a container from the
inside, without your CMD dying (or without having declared a CMD), run the
`/run/s6/basedir/bin/halt` command instead.
  * Services that were previously addressed via `/var/run/s6/services/foobar` are now
addressed via `/run/service/foobar`.
- The CMD, if any, always used to run under the container environment. This is not
the case anymore: just like supervised services, the CMD is now run with a minimal
environment by default, and you need to prepend it with `with-contenv` if you want
to provide it with the full container environment.

## Service management-related changes

The container startup process now uses [s6-rc](https://skarnet.org/software/s6-rc/),
which has several benefits over the old method. This impacts the overlay in the
following ways:

- There is a global timeout for all the services, adjustable via the
`S6_CMD_WAIT_FOR_SERVICES_MAXTIME` variable. You can disable it via setting this
variable to 0.
- The scripts in `/etc/cont-init.d` are now run as the `up` command of the first service
(a oneshot); the scripts in `/etc/cont-finish.d` are run as the `down` command of the
same service. This means `/etc/cont-init.d` is run as the first thing when the container
starts, and `/etc/cont-finish.d` is run as the last thing when the container stops. (This
does not change from the v2 behaviour.)
  * This means that `/etc/cont-init.d` is subjected to the `S6_CMD_WAIT_FOR_SERVICES_MAXTIME`
timeout. Adjust this timeout if your container initialization scripts take a long time
to run.
- The service directories in `/etc/services.d` are copied to a subdirectory of `/run` and
supervised by s6, as the `up` command of the second service. This means they're started
after `/etc/cont-init.d` is run, and they are *not stopped* until the container stops.
Services declared in `/etc/services.d` are still running when `/etc/cont-finish.d` is
run; they are stopped afterwards.
- Rather than running their services in `/etc/cont-init.d`, `/etc/services.d` and
`/etc/cont-finish.d`, users can now add s6-rc source definitions for them, so they will
be run independently by the service manager. The old way is still supported, and will
continue to be, but we encourage users to switch to the new way.
  * This has the advantage of supporting both oneshots (scripts that do one thing and
exit) and longruns (daemons that are supervised with s6), and dependencies can be
declared between services for super flexible ordering; you can also add more
complex service pipelines for multi-step log processing.
  * The drawback is that it requires following the
[s6-rc source format](https://skarnet.org/software/s6-rc/s6-rc-compile.html#source),
which is not immediately intuitive. Please read the documentation attentively
if you want to convert your services to that format. As a quickstart, what you
need to know immediately is:
    + You need a `type` file in the directory, saying whether the service is a
`oneshot` or a `longrun`.
    + The source definition directory for a *longrun* looks a lot like a service
directory: it has a `run` script, possibly a `finish` script, etc.
    + The source definition directory for a *oneshot* is different. It
needs an `up` file, but don't write your script in it. Instead, put your
script in another executable file, in a place of your choice (for instance
`/etc/s6-overlay/scripts/foobar`, and just put `/etc/s6-overlay/scripts/foobar`
in your `up` file.
    + To get your service _foo_ properly started at container boot time, you need
to add it to the `user` bundle: `touch /etc/s6-overlay/s6-rc.d/user/contents.d/foo`.
Also, to ensure it's started at the proper time, you should make it depend on
`base`: `mkdir /etc/s6-overlay/s6-rc.d/foo/contents.d && touch
/etc/s6-overlay/s6-rc.d/foo/contents.d/base`.
- Services are run from their own, temporary, current working directory, instead
of `WORKDIR`; scripts should now use absolute paths instead of paths relative
to `WORKDIR`. The CMD, if any, is still run in `WORKDIR`.

## Other changes

 - Socklog has been replaced by a `syslogd-overlay` tarball, provided by
s6-overlay. The tarball expands into a series of s6-rc services implementing
a small syslogd emulation, using a combination of the new `s6-socklog`
binary and a `s6-log` service with a complex logging script that dispatches
logs the same way syslogd would.

