#!/usr/bin/env bats
#
# Test the category-based commands.
#
# XXX: These tests are broken, and must be improved once NetBSDfr/pkgin#103 is
# fixed.  Until then we simply verify that the commands are producing the
# currently expected broken behaviour.
#

SUITE="categories"

load common

setup_file()
{
	export BUILD_DATE="1970-01-01 12:34:56 +0000"

	create_pkg_buildinfo "one-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/one"
	create_pkg_comment "one-1.0" "Package belongs to one category"
	create_pkg_file "one-1.0" "share/doc/one"
	create_pkg_preserve "one-1.0"
	create_pkg "one-1.0"

	create_pkg_buildinfo "two-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat1 cat2" \
	    "PKGPATH=cat2/two"
	create_pkg_comment "two-1.0" "Package belongs to two categories"
	create_pkg_file "two-1.0" "share/doc/two"
	create_pkg "two-1.0"

	create_pkg_buildinfo "three-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat1 cat2 cat3" \
	    "PKGPATH=cat3/three"
	create_pkg_comment "three-1.0" "Package belongs to three categories"
	create_pkg_file "three-1.0" "share/doc/three"
	create_pkg "three-1.0"

	create_pkg_summary
	start_httpd
}
teardown_file()
{
	stop_httpd
}

#
# Ensure a clean work area to start with.
#
@test "${SUITE} setup test packages" {
	# Use pkg_add to assist pkgin-0.9.x
	export PKG_PATH=${PACKAGES}/All
	run pkg_add one
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	# Perform an explicit update now to avoid extra output later.
	run pkgin -y update
	[ ${status} -eq 0 ]
}

#
# Run two versions of each test in order to verify the aliases.
#
@test "${SUITE} verify pkgin show-category" {
	run pkgin show-category cat1
	[ ${status} -eq 0 ]
	[ "${output}" = "one-1.0              Package belongs to one category" ]

	# XXX: This is wrong, should list two and three
	run pkgin sc cat2
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}

@test "${SUITE} verify pkgin show-pkg-category" {
	run pkgin show-pkg-category two
	[ ${status} -eq 0 ]
	[ "${output}" = "cat1 cat2    - two-1.0" ]

	run pkgin spc three
	[ ${status} -eq 0 ]
	[ "${output}" = "cat1 cat2 cat3 - three-1.0" ]
}

@test "${SUITE} verify pkgin show-all-categories" {
	# XXX: This is wrong, should list all three categories.
	run pkgin show-all-categories
	[ ${status} -eq 0 ]
	[ "${output}" = "cat1" ]

	# XXX: This is wrong, should list all three categories.
	run pkgin sac
	[ ${status} -eq 0 ]
	[ "${output}" = "cat1" ]
}
