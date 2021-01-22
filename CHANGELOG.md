# CHANGELOG for s6-overlay

## Note about minor changes

Please view the git log to see all the minor changes made to the code. This document only tracks major/breaking changes.

## Major changes

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

