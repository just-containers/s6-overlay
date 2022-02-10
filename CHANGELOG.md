# CHANGELOG for s6-overlay

## Note about minor changes

Please view the git log to see all the minor changes made to the code. This document only tracks major/breaking changes.

## Major changes

### Version 3.1.0.0

* `/etc/s6-overlay/config/global_path` isn't provided or taken into
account anymore. Instead, the initial value of PATH for all the services
is read from the `S6_GLOBAL_PATH` environment variable, that you can set
in the Dockerfile.

### Version 3.0.0.0

* Completely revamp the build system and the installation system.
  * Building is now a single `make` invocation.
  * No more self-extracting installer.
  * One to five tarballs to be installed, depending on user needs.
  * Only one of these tarballs is architecture-dependent.
* Use shell where beneficial. Execline is still used where it makes sense.
* Take advantage of new skaware.
  * Stage 1 is now handled by [s6-linux-init](https://skarnet.org/software/s6-linux-init/).
    * The new `S6_CATCHALL_USER` variable can be used to run the catch-all logger as non-root.
  * Stage 2 is now handled by [s6-rc](https://skarnet.org/software/s6-rc/).
    * `fix-attrs`,`cont-init`/`cont-finish`, and `/etc/services.d` are
still supported; under the hood, they're run as s6-rc services.
    * A `user` bundle is provided for users to put all their services in.
    * All script needs to have execution permission in beforehand. Previously this was not required.
    * The `PATH` environment variable available for all S6-executed scripts, including `CMD`, is now taken from the contents of `/etc/s6-overlay/config/global_path` (which defaults to `/command:/usr/bin:/bin`). Previously it used to inherit the container's `PATH`.
    * `S6_CMD_WAIT_FOR_SERVICES_MAXTIME` is now taken into account even when `CMD` is unset. Previously it was only applicable when `CMD` was set.
* Move binaries out of the way.
  * All skaware is installed under `/package` and accessible via `/command`.
  * All binaries are accessed via PATH resolution, making it transparent.
  * `/usr/bin` symlinks are provided in optional tarballs.
  * Some distributions will provide skaware binaries in their own packages;
those will likely be accessible via `/bin` or `/usr/bin`, but the overlay
scripts do not care.
* All in all this is a complete rewrite of s6-overlay, but the transition
from 2.1.0.2 to 3.0.0.0 should be painless for users.

### Version 2.1.0.2

* Add a new self-extracting installer as an installation
  option. It works correctly on all distros, whether or not `/bin` is a
  symlink to `/usr/bin` or a directory.

### Version 2.1.0.0

* Add initial support for Docker's `USER` directive.
* Add a new binary to the tarball (`s6-overlay-preinit`), and move creating
  a specific folder from the build-time to runtime.

### Version 2.0.0.1

* Fix issues with shells overwriting the `cd`
  binary [#278](https://github.com/just-containers/s6-overlay/issues/278)
  and tarballs having too-loose permissions [#274](https://github.com/just-containers/s6-overlay/issues/274).

### Version 2.0.0.0

* Starting with version `2.0.0.0`, `with-contenv` no longer uses `s6-envdir`, instead it
  uses [justc-envdir](https://github.com/just-containers/justc-envdir), a small fork that
  uses the entire contents of the files in the envdir. A new script is introduced, `with-contenv-legacy`,
  in case you rely on the old behavior.

### Version 1.21.8.0

* Up to and including version `1.21.8.0`, the init system would call `s6-sync` to sync disks when
  the container exited. This actually syncs all block devices on the hosts, which is
  likely not what you want to do. As of version `1.22.0.0`, this is disabled by default, see the
  README on how to re-enable it.
