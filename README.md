## pkgin test suite

This is the pkgin test suite.  The aim is to provide comprehensive coverage of
all scenarios pkgin may face.

## Requirements

This test suite requires:

* BSD make
* socat (for the test httpd server)
* pkgin 0.10.0 or newer

In order to test pkgin 0.9 or older, you will first need to apply the
following three commits:

https://github.com/joyent/pkgin/commit/1a1f4fbd1372f83e7b5abe5fd8a4d71e6c6fdbcd
https://github.com/joyent/pkgin/commit/f3b9d98e5bf248a4f90d378f6b07eb99f46e7321
https://github.com/joyent/pkgin/commit/84dddcf0dba02784d430fd42834f12c9bda82b7d

These add support for the `PKGIN_DBDIR` and `PKG_INSTALL_DIR` environment
variables.  Without these pkgin will use the system databases and bad things
will happen.

## Running

```console
$ bmake                 # Pretty print output
$ bmake bats-tap        # Standard tap output
```

You can provide environment variables to alter which pkgin is used, where
results are stored, etc.  The main variables you might want to change and their
defaults are:

```
SYSTEM_PKGIN=pkgin	# The pkgin binary to use
TEST_WORKDIR=.work      # Where to store the work area
```

See the top section of the Makefile for others.

## Hacking

The test suite is designed to run in sequence, with each area of tests having
its own package repository and suite script.  The order is currently:

1. suite/empty.sh - Test initialisation and command output
2. suite/install.sh - Test installs
3. suite/upgrade.sh - Test upgrades
4. suite/conflict.sh - Test conflicts
5. suite/invalid.sh - Test bad packages and invalid assumptions
6. suite/file-dl.sh - Test file:// downloads
7. suite/http-dl.sh - Test http:// downloads

Common to each test suite script are the header and footer files:

* suite/header.sh - Provide test script setup and common functions
* suite/footer.sh - Perform test suite cleanup

The exp/ directory contains expected output.  Per-version output is supported,
and header.sh provides a few functions to compare the output in a variety of
ways.

The Makefile controls which packages are available for each repository, as well
as providing ways of building packages specific for that repository.  The
suite/ files then perform the actual tests.

The pkgdb and pkgin database are left unmodified between runs, so that for
example the upgrades suite can follow on from the previous installs.

The test suite uses the [Bash Automated Testing
System](https://github.com/sstephenson/bats) for writing tests.  See the
existing tests for examples of how to write them.  The most important thing to
note is that each test must have a unique name, otherwise they will clash and
only one of them will be executed.

## TODO

* Add support for SUPERSEDES
* Add remove/autoremove tests
* More complicated upgrade scenarios
