# This file normally shouldn't be changed; the values can be
# overridden by invoking make with arguments.
# e.g.: make SHEBANGDIR=/usr/bin VERSION=3.2.0.3

# The version of the software being built.
VERSION := 3.2.1.0

# Where stuff is going to be built. Change for out-of-tree builds.
OUTPUT := output

# Where to find the execlineb program.
# Change if building for a distro that provides its own skaware packages.
SHEBANGDIR := /command

# This is the target triplet for the toolchain.
ARCH := x86_64-linux-musl

# The path to the base toolchain.
# Leave empty to fetch one from the web.
TOOLCHAIN_PATH :=

# When fetching one from the web, what version we want.
# Only a few versions are available, don't change blindly.
TOOLCHAIN_VERSION := 14.2.0

# For fetching toolchains: the download command.
# Change to curl -O if you don't have wget.
DL_CMD := wget
