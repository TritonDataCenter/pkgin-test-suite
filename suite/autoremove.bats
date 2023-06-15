#!/usr/bin/env bats
#
# Test autoremove after upgrade.
#

SUITE="autoremove"

load common

setup_file()
{
	#
	# Set up the first repository.
	#
	BUILD_DATE="${BUILD_DATE_1}"
	PACKAGES="${SUITE_WORKDIR}/repo1"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg1"
	REPO_DATE="${REPO_DATE_1}"

	create_pkg_buildinfo "base-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/base"
	create_pkg_comment "base-1.0" "Base package for initial installation"
	create_pkg_file "base-1.0" "share/doc/base"
	create_pkg "base-1.0"

	create_pkg_buildinfo "depend-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/depend"
	create_pkg_comment "depend-1.0" "Package is depended upon"
	create_pkg_file "depend-1.0" "share/doc/depend"
	create_pkg "depend-1.0"

	create_pkg_buildinfo "upgrade-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/upgrade"
	create_pkg_comment "upgrade-1.0" "Package should be upgraded"
	create_pkg_file "upgrade-1.0" "share/doc/upgrade"
	create_pkg "upgrade-1.0" -P "depend-[0-9]*"

	create_pkg_summary "${REPO_DATE}"

	#
	# Set up the second repository.
	#
	BUILD_DATE="${BUILD_DATE_2}"
	PACKAGES="${SUITE_WORKDIR}/repo2"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg2"
	REPO_DATE="${REPO_DATE_2}"

	create_pkg_buildinfo "base-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/base"
	create_pkg_comment "base-1.0" "Base package for initial installation"
	create_pkg_file "base-1.0" "share/doc/base"
	create_pkg "base-1.0"

	create_pkg_buildinfo "upgrade-2.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/upgrade"
	create_pkg_comment "upgrade-2.0" "Package should be upgraded"
	create_pkg_file "upgrade-2.0" "share/doc/upgrade"
	create_pkg "upgrade-2.0"

	create_pkg_summary "${REPO_DATE}"

	#
	# Start with the first repository, we'll switch to subsequent
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
	#
	# Use pkg_add for the first package to help 0.9.4 and earlier which do
	# not support installing from scratch.
	#
	export PKG_PATH=${SUITE_WORKDIR}/repo1/All
	run pkg_add base
	[ $status -eq 0 ]
	[ -z "${output}" ]

	run pkgin -y install upgrade
	[ $status -eq 0 ]
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
	run pkgin -y fug
	[ ${status} -eq 0 ]

	output_match "pkg_install warnings: 0, errors: 0"
	output_not_match "pkg_install warnings: [1-9]"
	output_not_match "pkg_install .*errors: [1-9]"

	# pkgin 22.9.0 has a bug where packages are not correctly marked as
	# keep, and keep/unkeep do not work, so we need to do it manually to
	# avoid them being autoremoved later.
	if [ ${PKGIN_VERSION} -eq 220900 ]; then
		export PKG_PATH=${SUITE_WORKDIR}/repo2/All
		run pkg_delete upgrade
		[ $status -eq 0 ]
		run pkg_add -U upgrade
		[ $status -eq 0 ]
		run pkgin -f update
		[ $status -eq 0 ]
	fi
}

@test "${SUITE} run pkgin autoremove" {
	# Older releases didn't support -y with autoremove, and we can't
	# echo "Y" | run pkgin as that doesn't work with bats, so just
	# remove the package by hand so later tests work.
	if [ ${PKGIN_VERSION} -lt 001103 ]; then
		run pkg_delete depend-1.0
		[ ${status} -eq 0 ]
		[ -z "${output}" ]

		run pkgin -fy update
		[ ${status} -eq 0 ]
	else
		run pkgin -y autoremove
		[ ${status} -eq 0 ]

		output_match "1 package.* to be autoremoved"
		output_match "removing depend-1.0"
		output_match "pkg_install warnings: 0, errors: 0"
		output_not_match "pkg_install warnings: [1-9]"
		output_not_match "pkg_install .*errors: [1-9]"
	fi
}

@test "${SUITE} verify pkg_info" {
	compare_pkg_info "pkg_info.final"
}
