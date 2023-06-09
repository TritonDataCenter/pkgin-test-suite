## pkgin test suite

This is the pkgin test suite.  The aim is to provide comprehensive coverage of
all scenarios pkgin may face.

The test suite uses the [Bash Automated Testing
System](https://github.com/sstephenson/bats) for writing tests.  See the
existing tests for examples of how to write them.  The most important thing to
note is that each test must have a unique name, otherwise they will clash and
only one of them will be executed.

## Requirements

This test suite requires:

* make (GNU or BSD are supported)
* socat (for the test httpd server)
* GNU parallel (optional, for running multiple jobs in parallel)

In order to test pkgin 0.9 or older, you will first need to apply the
following three commits:

https://github.com/NetBSDfr/pkgin/commit/1a1f4fbd1372f83e7b5abe5fd8a4d71e6c6fdbcd
https://github.com/NetBSDfr/pkgin/commit/f3b9d98e5bf248a4f90d378f6b07eb99f46e7321
https://github.com/NetBSDfr/pkgin/commit/84dddcf0dba02784d430fd42834f12c9bda82b7d

These add support for the `PKGIN_DBDIR` and `PKG_INSTALL_DIR` environment
variables.  Without these pkgin will use the system databases and bad things
will happen.

For versions 0.6.4 through 0.8.0 there are patch files in the
[patches](/patches/) directory for each of them to aid applying, as there are
numerous differences in these older releases that cause merge conflicts.

## Supported Versions

The test suite is designed to support all versions from 0.6.4 through to the
latest, and provides various syntactic sugar to make this easy.

Currently the test suite should run clean on all tagged versions since 0.6.4.

## Running

```console
$ make                  # Pretty print output
$ make bats-tap         # Standard tap output
```

You can provide environment variables to alter which pkgin is used, which bats
is used, and how many jobs runners to execute (requires GNU parallel):

```
PKGIN=pkgin             # The pkgin binary to use, default "pkgin"
BATS=/path/to/bats      # The bats script to use, default "bin/bats"
BATS_JOBS="-j 8"        # The number of test runners, default "-j 1"
```

## Hacking

The test suite is designed so that each test within each suite is run in
sequence, with each suite having its own package repository and set of tests.

This allows suites to be tested in parallel, but retain correct ordering within
each individual suite.

The current test suites are:

* [suite/categories.bats](suite/categories.bats): Test `show-category`, etc.
* [suite/conflict.bats](suite/conflict.bats): Test `CONFLICTS`, etc.
* [suite/empty.bats](suite/empty.bats): Verify usage against an empty repo.
* [suite/file-dl.bats](suite/file-dl.bats): Download tests against `file:///`.
* [suite/http-dl.bats](suite/http-dl.bats): Download tests against `http:///`.
* [suite/install.bats](suite/install.bats): Various install tests.
* [suite/invalid.bats](suite/invalid.bats): Invalid and exaggerated repo.
* [suite/provreq.bats](suite/provreq.bats): Test `PROVIDES` and `REQUIRES`.
* [suite/upgrade.bats](suite/upgrade.bats): Package upgrades.

Shared between each test suite script is [suite/common.bash](suite/common.bash)
which sets up the environment and shared functions.

## TODO

* Add support for SUPERSEDES
* Add remove/autoremove tests
* More complicated upgrade scenarios
