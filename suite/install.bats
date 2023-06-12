#!/usr/bin/env bats
#
# This repository performs a variety of installs, verifying that packages
# are correcly chosen and installed as expected.
#
# Once a few packages are installed we're also able to verify a number of
# query commands.
#

SUITE="install"

load common

#
# Set a common BUILD_DATE for the repository used by this test suite.
#
export BUILD_DATE="1970-01-01 12:34:56 +0000"

#
# Generate packages to be used by the install suite.
#
setup_file()
{
	#
	# Simple initial package that must be kept (PKG_PRESERVE)
	#
	create_pkg_buildinfo "preserve-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/preserve"
	create_pkg_comment "preserve-1.0" "Package should remain at all times"
	create_pkg_file "preserve-1.0" "share/doc/preserve"
	create_pkg_preserve "preserve-1.0"
	create_pkg "preserve-1.0"

	#
	# Two different packages with the same name but different versions
	# and PKGPATHs.
	#
	create_pkg_buildinfo "pkgpath-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat2" \
	    "PKGPATH=cat2/pkgpath1"
	create_pkg_comment "pkgpath-1.0" "PKGPATH differs to pkgpath-2.0"
	create_pkg_file "pkgpath-1.0" "share/doc/pkgpath"
	create_pkg "pkgpath-1.0"

	create_pkg_buildinfo "pkgpath-2.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat2" \
	    "PKGPATH=cat2/pkgpath2"
	create_pkg_comment "pkgpath-2.0" "PKGPATH differs to pkgpath-1.0"
	create_pkg_file "pkgpath-2.0" "share/doc/pkgpath"
	create_pkg "pkgpath-2.0"

	#
	# Dependency tree of packages.
	#
	create_pkg_buildinfo "deptree-bottom-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat3" \
	    "PKGPATH=cat3/deptree-bottom"
	create_pkg_comment "deptree-bottom-1.0" \
	    "Package is at the bottom of a dependency tree"
	create_pkg_file "deptree-bottom-1.0" "share/doc/deptree-bottom"
	create_pkg "deptree-bottom-1.0" \
	    -P "preserve>=1.0" -T "preserve-1.0"

	create_pkg_buildinfo "deptree-middle-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat3" \
	    "PKGPATH=cat3/deptree-middle"
	create_pkg_comment "deptree-middle-1.0" \
	    "Package is in the middle of a dependency tree"
	create_pkg_file "deptree-middle-1.0" "share/doc/deptree-middle"
	create_pkg "deptree-middle-1.0" \
	    -P "deptree-bottom-[0-9]*" -T "deptree-bottom-1.0"

	create_pkg_buildinfo "deptree-top-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat3" \
	    "PKGPATH=cat3/deptree-top"
	create_pkg_comment "deptree-top-1.0" \
	    "Package is at the top of a dependency tree"
	create_pkg_file "deptree-top-1.0" "share/doc/deptree-top"
	create_pkg "deptree-top-1.0" \
	    -P "deptree-middle>=1.0" -T "deptree-middle-1.0 deptree-bottom-1.0"

	create_pkg_summary
	start_httpd

	#sleep 2
	#
	# Generate import file for later use
	#
	cat >${SUITE_WORKDIR}/import-list <<-EOF
		cat1/preserve
		cat2/pkgpath1
		cat3/deptree-top
	EOF
}
teardown_file()
{
	stop_httpd
}

#
# Ensure a clean work area to start with.
#
@test "${SUITE} ensure clean work directory" {
	run rm -rf ${LOCALBASE} ${VARBASE}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run mkdir -p ${PKGIN_DBDIR}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}

#
# Start with an existing pkg_add installation, to ensure we correctly pick up
# existing local packages and do not try to perform the install.
#
@test "${SUITE} install first package using pkg_add" {
	export PKG_PATH=${PACKAGES}/All
	run pkg_add preserve
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}
@test "${SUITE} verify first package with pkg_info" {
	compare_pkg_info "pkg_info.start"
}
@test "${SUITE} test pkgin install against existing installation" {
	run pkgin -y install preserve
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		output_match "nothing to do"
	else
		file_match "install-against-existing.regex"
	fi
}
@test "${SUITE} verify PKG_INSTALL_LOG is missing" {
	run [ ! -f ${PKG_INSTALL_LOG} ]
	[ ${status} -eq 0 ]
}
@test "${SUITE} verify pkgin list against existing installation" {
	if [ ${PKGIN_VERSION} -eq 000700 -o ${PKGIN_VERSION} -eq 000800 ]; then
		# NetBSDfr/pkgin#46 (incorrectly uses parseable output)
		compare_pkg_info "pkg_info.start"
	else
		compare_pkgin_list "pkgin-list.start"
	fi
}

#
# Now do the same but against an empty installation.  It is important that this
# test comes after the previous one, as we rely on the cache directory having
# some packages in it to test upgrades work correctly (e.g. mismatches).
#
@test "${SUITE} create empty installation" {
	run rm -rf ${LOCALBASE} ${VARBASE}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run mkdir -p ${PKGIN_DBDIR}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}
@test "${SUITE} test pkgin install against empty installation" {
	#
	# pkgin earlier than 0.10.0 does not work against an empty install,
	# but we need the package installed for later tests, even though this
	# defeats the point of this test.
	#
	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		export PKG_PATH=${PACKAGES}/All
		run pkg_add preserve
		[ ${status} -eq 0 ]
		[ -z "${output}" ]

		run pkgin -fy up
		[ ${status} -eq 0 ]
	fi

	run pkgin -y install preserve
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		output_match "nothing to do"
	elif [ ${PKGIN_VERSION} -lt 001100 -o \
	       ${PKGIN_VERSION} -eq 001600 ]; then
		output_match "1 package.* install"
		output_match "installing preserve-1.0"
		output_match "pkg_install warnings: 0, errors: 0"
	else
		file_match "install-against-empty.regex"
	fi
}
@test "${SUITE} verify pkgin list against empty installation" {
	if [ ${PKGIN_VERSION} -eq 000700 -o ${PKGIN_VERSION} -eq 000800 ]; then
		# NetBSDfr/pkgin#46 (incorrectly uses parseable output)
		compare_pkg_info "pkg_info.start"
	else
		compare_pkgin_list "pkgin-list.start"
	fi
}

#
# Install subsequent packages.  This uses -f to test that a force refresh
# of the remote database is performed correctly.
#
@test "${SUITE} install remaining packages" {
	if [ ${PKGIN_VERSION} -eq 001000 -o ${PKGIN_VERSION} -eq 001001 ]; then
		# Buggy versions did not install properly, use pkg_add to
		# ensure later tests can succeed.
		export PKG_PATH=${PACKAGES}/All
		run pkg_add pkgpath-1.0 deptree-top-1.0
		[ ${status} -eq 0 ]
		[ -z "${output}" ]

		run pkgin -fy up
		[ ${status} -eq 0 ]

		skip "fail to install correctly"
	else
		run pkgin -fy install pkgpath-1.0 deptree-top-1.0
		[ ${status} -eq 0 ]
	fi

	if [ ${PKGIN_VERSION} -lt 001300 -o ${PKGIN_VERSION} -eq 001600 ]; then
		output_match "4 packages .* install"
		output_match "pkg_install warnings: 0, errors: 0"
		output_match "marking pkgpath-1.0 as non auto-removable"
		output_match "marking deptree-top-1.0 as non auto-removable"
	else
		# Non-deterministic output ordering.
		file_match -I "install-remaining.regex"
	fi
}
# Should only contain "installing .." lines.
@test "${SUITE} verify PKG_INSTALL_LOG contents" {
	run [ -s ${PKG_INSTALL_LOG} ]
	[ ${status} -eq 0 ]

	run grep -v installing ${PKG_INSTALL_LOG}
	[ ${status} -eq 1 ]
	[ -z "${output}" ]
}
@test "${SUITE} attempt to install already-installed package" {
	run pkgin -y install preserve
	[ ${status} -eq 0 ]
	output_match "nothing to do"

	# Verify a force install refreshes the remote summary, except it
	# doesn't prior to 0.10.0.
	run pkgin -fy install preserve
	if [ ${PKGIN_VERSION} -eq 001000 -o ${PKGIN_VERSION} -eq 001001 ]; then
		[ ${status} -eq 1 ]
	else
		[ ${status} -eq 0 ]
	fi
	if [ ${PKGIN_VERSION} -gt 001001 ]; then
		output_match "processing remote summary"
	fi
	output_match "nothing to do"

	export PKG_PATH=${PACKAGES}/All
	run pkg_add preserve
	[ ${status} -eq 0 ]
	output_match "already recorded as installed"
}

#
# Get back to the current state by removing everything and then testing
# pkgin import.  Only supported from 20.7.0 onwards, prior versions either
# pick the wrong package (0.10 and earlier choose pkgpath-2.0 instead of
# pkgpath-1.0, or register automatic packages incorrectly (20.5.1 and earlier
# mark deptree-{middle,bottom} as keep packages.
#
@test "${SUITE} rerun installs using pkgin import" {
	skip_if_version -lt 001200 "incorrectly choose wrong pkgpath package"
	skip_if_version -lt 200700 "incorrectly register keep packages"

	run rm -rf ${LOCALBASE} ${VARBASE}
	[ ${status} -eq 0 ]

	run mkdir -p ${PKGIN_DBDIR}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run pkgin -y import ${SUITE_WORKDIR}/import-list
	[ ${status} -eq 0 ]
	file_match -I "import.regex"

	run [ -s ${PKG_INSTALL_LOG} ]
	[ ${status} -eq 0 ]

	run grep -v installing ${PKG_INSTALL_LOG}
	[ ${status} -eq 1 ]
	[ -z "${output}" ]
}

#
# Now that we have some packages installed we can re-run basic commands
# that will now have output.
#
@test "${SUITE} verify pkgin search" {
	for cmd in search se; do
		run pkgin ${cmd} preserve
		[ ${status} -eq 0 ]

		if [ ${PKGIN_VERSION} -eq 000700 -o \
		     ${PKGIN_VERSION} -eq 000800 ]; then
			output_match "preserve-1.0;=;Package should remain"
		else
			compare_output "pkgin.search"
		fi
	done
}
@test "${SUITE} verify pkgin stats" {
	skip_if_version -le 000604 "does not support stats"
	for cmd in stats st; do
		run pkgin stats
		[ ${status} -eq 0 ]
		file_match "pkgin-stats.regex"
	done
}
@test "${SUITE} verify pkgin show-keep" {
	for cmd in show-keep sk; do
		run pkgin_sorted ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} -le 211201 ]; then
			output_match "deptree-top-1.0 is marked as non-auto"
			output_match "pkgpath-1.0 is marked as non-auto"
			output_match "preserve-1.0 is marked as non-auto"
		else
			compare_output "pkgin.show-keep"
		fi
	done
}
@test "${SUITE} verify pkgin show-no-keep" {
	for cmd in show-no-keep snk; do
		run pkgin_sorted ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} -le 211201 ]; then
			output_match "deptree-bottom-1.0 is marked as auto"
			output_match "deptree-middle-1.0 is marked as auto"
		else
			compare_output "pkgin.show-no-keep"
		fi
	done
}
@test "${SUITE} verify pkgin show-deps" {
	for cmd in show-deps sd; do
		run pkgin ${cmd} deptree-top-1.0
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-deps"
	done
}
@test "${SUITE} verify pkgin show-full-deps" {
	for cmd in show-full-deps sfd; do
		run pkgin ${cmd} deptree-top-1.0
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-full-deps"
	done
}
# XXX: find something that actually works, some issue with FULLPKGNAME?
@test "${SUITE} verify pkgin show-rev-deps" {
	for cmd in show-rev-deps srd; do
		run pkgin ${cmd} deptree-bottom
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-rev-deps"
	done
}

@test "${SUITE} verify pkgin export" {
	# For some reason 0.9.4 says "pkgin: empty local package list."
	skip_if_version -lt 001000 "known fail"

	for cmd in export ex; do
		run pkgin_sorted ${cmd}
		[ ${status} -eq 0 ]
		compare_output "pkgin.export"
	done
}
@test "${SUITE} verify pkgin pkg-content" {
	for cmd in pkg-content pc; do
		run pkgin ${cmd} preserve
		[ ${status} -eq 0 ]
		# Output changes depending on test directory
		line_match 0 "Information for .*preserve-1.0"
		line_match 1 "PACKAGE MAY NOT BE DELETED"
		line_match 2 "Files"
		line_match 3 "share.doc.preserve"
	done
}

#
# Verify both pkg_info and pkgin output are identical after all operations, as
# well as the contents of the packages themselves (to ensure they were actually
# installed correctly).
#
@test "${SUITE} verify pkg_info" {
	compare_pkg_info "pkg_info.final"
}
@test "${SUITE} verify pkgin list" {
	skip_if_version -eq 000700 "NetBSDfr/pkgin#46 (uses parseable output)"
	skip_if_version -eq 000800 "NetBSDfr/pkgin#46 (uses parseable output)"
	compare_pkgin_list "pkgin-list.final"
}
@test "${SUITE} verify package file contents" {
	run cat ${LOCALBASE}/share/doc/*
	[ ${status} -eq 0 ]
	compare_output "cat-share-doc-all.out"
}
@test "${SUITE} verify BUILD_DATE" {
	run pkg_info -Q BUILD_DATE preserve-1.0
	[ ${status} -eq 0 ]
	[ -n "${output}" ]
	[ "${output}" = "${BUILD_DATE}" ]
}
