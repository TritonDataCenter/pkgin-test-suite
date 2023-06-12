#!/usr/bin/env bats
#
# This test is ... complicated.

# In historical pkgin releases (0.9.4 and earlier) break_depends() tries to
# calculate changes in DEPENDS to remove packages that are no longer a match.
# I think this was to help upgrades where new versions conflicted with older.
#
# Trying to trigger a break is quite convoluted due to the limited number of
# circumstances where it applies, and in the wild it is rarely seen.
#
# However, it doesn't really work, and only really works by accident.  Packages
# that are still required end up being marked for removal, and those packages
# are only reinstalled due to pkg_add pulling in the dependency automatically,
# and that only works if the user didn't "pkgin clean" before the upgrade and
# happened to have an old copy of the package available in the cache.
#
# It is also disconcerting to the operator to see in the proposed output that
# required packages are going to be removed with no suggestion that they are
# going to be reinstalled, potentially leaving the machine in a broken state.
#
# In newer releases (0.10 onwards) with BUILD_DATE refresh support, the logic
# changed and break_depends() ends up effectively being a nop as no packages
# are removed.  This was somewhat unintended, but we didn't know any better at
# the time.
#
# The correct approach, I believe, is to handle CONFLICTS and SUPERSEDES as
# intended, only removing automatic packages where a preferred match or
# supersede package is available, and leave other orphaned packages to
# autoremove.
#
# Note that this suite does not use BUILD_DATE to ensure that any tests on
# newer releases do not simply pull in a refreshed package.  Triggering the
# break_depends() behaviour relies on the fact the "break" dependency does not
# change.
#

SUITE="break-depends"

load common

#
setup_file()
{
	#
	# Set up the first repository.
	#
	PACKAGES="${SUITE_WORKDIR}/repo1"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg1"
	HTTPD_PID="${SUITE_WORKDIR}/httpd1.pid"

	create_pkg_buildinfo "base-1.0" \
	    "CATEGORIES=cat" \
	    "PKGPATH=cat/base"
	create_pkg_comment "base-1.0" "Base package for initial installation"
	create_pkg_file "base-1.0" "share/doc/base"
	create_pkg "base-1.0"

	for side in left right; do
		create_pkg_buildinfo "${side}1-1.0" \
		    "CATEGORIES=cat" \
		    "PKGPATH=cat/${side}1"
		create_pkg_comment "${side}1-1.0" "First dep pkg on ${side}"
		create_pkg_file "${side}1-1.0" "share/doc/${side}1"
		create_pkg "${side}1-1.0" -P "base-[0-9]*"

		create_pkg_buildinfo "${side}2-1.0" \
		    "CATEGORIES=cat" \
		    "PKGPATH=cat/${side}2"
		create_pkg_comment "${side}2-1.0" "Second dep pkg on ${side}"
		create_pkg_file "${side}2-1.0" "share/doc/${side}2"
		create_pkg "${side}2-1.0" -P "${side}1>=1.0"

		create_pkg_buildinfo "required-${side}-1.0" \
		    "CATEGORIES=cat" \
		    "PKGPATH=cat/required-${side}"
		create_pkg_comment "required-${side}-1.0" "Package is required by top"
		create_pkg_file "required-${side}-1.0" "share/doc/required-${side}"
		create_pkg "required-${side}-1.0" -P "left2>=1.0 right2>=1.0"

	done

	create_pkg_buildinfo "top-1.0" \
	    "CATEGORIES=cat" \
	    "PKGPATH=cat/top"
	create_pkg_comment "top-1.0" "Package is at the top"
	create_pkg_file "top-1.0" "share/doc/top"
	create_pkg "top-1.0" -P "required-left>=1.0 required-right>=1.0"

	create_pkg_summary

	#
	# Set up the second repository.
	#
	PACKAGES="${SUITE_WORKDIR}/repo2"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg2"

	create_pkg_buildinfo "base-2.0" \
	    "CATEGORIES=cat" \
	    "PKGPATH=cat/base"
	create_pkg_comment "base-2.0" "Base package for initial installation"
	create_pkg_file "base-2.0" "share/doc/base"
	create_pkg "base-2.0"

	# The DEPENDS for required-${side} change to trigger break_depends(),
	# but the version stays the same, otherwise they are marked for
	# upgrade and handled normally.
	for side in left right; do
		create_pkg_buildinfo "${side}1-2.0" \
		    "CATEGORIES=cat" \
		    "PKGPATH=cat/${side}1"
		create_pkg_comment "${side}1-2.0" "First dep pkg on ${side}"
		create_pkg_file "${side}1-2.0" "share/doc/${side}1"
		create_pkg "${side}1-2.0" -P "base-[0-9]*"

		create_pkg_buildinfo "${side}2-2.0" \
		    "CATEGORIES=cat" \
		    "PKGPATH=cat/${side}2"
		create_pkg_comment "${side}2-2.0" "Second dep pkg on ${side}"
		create_pkg_file "${side}2-2.0" "share/doc/${side}2"
		create_pkg "${side}2-2.0" -P "${side}1>=2.0"

		create_pkg_buildinfo "required-${side}-1.0" \
		    "CATEGORIES=cat" \
		    "PKGPATH=cat/required-${side}"
		create_pkg_comment "required-${side}-1.0" "Package is/was required by top"
		create_pkg_file "required-${side}-1.0" "share/doc/required-${side}"
		create_pkg "required-${side}-1.0" -P "${side}2>=1.0"
	done

	create_pkg_buildinfo "top-2.0" \
	    "CATEGORIES=cat" \
	    "PKGPATH=cat/top"
	create_pkg_comment "top-2.0" "Package is at the top"
	create_pkg_file "top-2.0" "share/doc/top"
	create_pkg "top-2.0" -P "required-left>=1.0"

	#
	# Ensure the second repository has a different timestamp, Last-Modified
	# only has granularity of 1 second.
	#
	sleep 1
	create_pkg_summary

	#
	# Start with the first repository, we'll switch to the other
	# repositories by updating the symlink.
	#
	PACKAGES="${SUITE_WORKDIR}/packages"
	ln -s repo1 ${SUITE_WORKDIR}/packages
	start_httpd

	rm -rf ${LOCALBASE} ${VARBASE}
	mkdir -p ${PKGIN_DBDIR}
}

teardown_file()
{
	stop_httpd
}

@test "${SUITE} install initial packages" {
	skip_if_version -eq 001000 "known crash"
	skip_if_version -eq 001001 "known crash"

	# Use pkg_add for the first package to help 0.9.4 and earlier which do
	# not support installing from scratch.
	export PKG_PATH=${SUITE_WORKDIR}/repo1/All
	run pkg_add base
	[ $status -eq 0 ]
	[ -z "${output}" ]

	run pkgin -y install top
	[ $status -eq 0 ]

	output_match "7 package.* to.* install"
	output_match "marking top-1.0 as non auto"
	output_match "pkg_install warnings: 0, errors: 0"
	output_not_match "pkg_install warnings: [1-9]"
	output_not_match "pkg_install .*errors: [1-9]"
}

@test "${SUITE} switch repository" {
	run rm ${SUITE_WORKDIR}/packages
	[ ${status} -eq 0 ]

	run ln -s repo2 ${SUITE_WORKDIR}/packages
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		# Needs an explicit update after repo switch.
		run pkgin -fy update
		[ ${status} -eq 0 ]
	fi
}

@test "${SUITE} perform pkgin upgrade" {
	if [ ${PKGIN_VERSION} -ge 001000 -a \
	     ${PKGIN_VERSION} -le 001100 ]; then
		# 0.10.* fail due to empty BUILD_DATE
		# 0.11.0 fails due to erroneous FILE_SIZE
		skip "known crashes"
	fi

	# Removing the download cache is required to trigger the bug in pkgin
	# 0.9.4 and earlier where the "break" dependency can no longer be
	# installed automatically by pkg_add.
	run pkgin clean
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run pkgin -y full-upgrade

	# Run test for pkgin 0.9.4 and earlier anyway as it's useful to show
	# what happens.
	if [ ${PKGIN_VERSION} -le 000904 ]; then
		[ ${status} -eq 1 ]
		output_match "2 packages to be removed"
		output_match "pkg_install warnings: 0, errors: 2"
	else
		[ ${status} -eq 0 ]
		output_not_match "package.* to.* remove"
		output_match "pkg_install warnings: 0, errors: 0"
		output_not_match "pkg_install warnings: [1-9]"
		output_not_match "pkg_install .*errors: [1-9]"
	fi

}

@test "${SUITE} verify pkg_info" {
	skip_if_version -le 001100 "known fail"
	compare_pkg_info "pkg_info.final"
}
