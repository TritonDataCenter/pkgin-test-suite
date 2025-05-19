#!/usr/bin/env bats
#
# Test SUPERSEDES.
#

SUITE="supersedes"

load common

#
# Generate repository packages.
#
setup_file()
{
	#
	# Set up the first repository.
	#
	BUILD_DATE="${BUILD_DATE_1}"
	PACKAGES="${SUITE_WORKDIR}/repo1"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg1"
	REPO_DATE="${REPO_DATE_1}"

	create_pkg_buildinfo "gcc12-libs-12.2.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/gcc12-libs"
	create_pkg_comment "gcc12-libs-12.2.0" \
	    "The GNU Compiler Collection (GCC) support shared libraries"
	create_pkg_file "gcc12-libs-12.2.0" "share/doc/gcc12-libs"
	create_pkg "gcc12-libs-12.2.0"

	create_pkg_buildinfo "nodejs-14.16.1" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/nodejs"
	create_pkg_comment "nodejs-14.16.1" \
	    "V8 JavaScript for clients and servers"
	create_pkg "nodejs-14.16.1" -P "gcc12-libs>=12.2.0"

	create_pkg_buildinfo "npm-6.14.11" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/npm"
	create_pkg_comment "npm-6.14.11" "Package manager for JavaScript"
	create_pkg "npm-6.14.11" -P "nodejs-[0-9]*"

	create_pkg_buildinfo "app-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=sysutils" \
	    "PKGPATH=sysutils/app"
	create_pkg_comment "app-1.0" "App depends on npm"
	create_pkg "app-1.0" -P "npm-[0-9]*"

	create_pkg_buildinfo "old-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=sysutils" \
	    "PKGPATH=sysutils/old"
	create_pkg_comment "old-1.0" "Previous version of misc utility"
	create_pkg "old-1.0"

	create_pkg_summary "${REPO_DATE}"

	#
	# Set up the second repository.
	#
	BUILD_DATE="${BUILD_DATE_2}"
	PACKAGES="${SUITE_WORKDIR}/repo2"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg2"
	REPO_DATE="${REPO_DATE_2}"

	create_pkg_buildinfo "gcc12-libs-12.2.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/gcc12-libs"
	create_pkg_comment "gcc12-libs-12.2.0" \
	    "The GNU Compiler Collection (GCC) support shared libraries"
	create_pkg "gcc12-libs-12.2.0"

	create_pkg_buildinfo "nodejs-14.21.1" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/nodejs" \
	    "SUPERSEDES=npm-[0-9]*"
	create_pkg_comment "nodejs-14.21.1" \
	    "V8 JavaScript for clients and servers"
	create_pkg "nodejs-14.21.1" -P "gcc12-libs>=12.2.0" -C "npm-[0-9]*"

	create_pkg_buildinfo "app-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=sysutils" \
	    "PKGPATH=sysutils/app"
	create_pkg_comment "app-1.0" "App now depends on nodejs"
	create_pkg "app-1.0" -P "nodejs-[0-9]*"

	create_pkg_buildinfo "old-1.0nb1" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=sysutils" \
	    "PKGPATH=sysutils/old"
	create_pkg_comment "old-1.0nb1" "Previous version of misc utility"
	create_pkg "old-1.0nb1" -C "new-[0-9]*"

	create_pkg_buildinfo "new-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=sysutils" \
	    "PKGPATH=sysutils/new" \
	    "SUPERSEDES=old-[0-9]*"
	create_pkg_comment "new-1.0" "Replacement version of misc utility"
	create_pkg "new-1.0" -C "old-[0-9]*"

	create_pkg_summary "${REPO_DATE}"

	PACKAGES="${SUITE_WORKDIR}/packages"
	ln -s repo1 ${SUITE_WORKDIR}/packages
	start_httpd
}

teardown_file()
{
	stop_httpd
}

@test "${SUITE} install initial packages" {
	export PKG_PATH=${SUITE_WORKDIR}/repo1/All
	run pkg_add app old
	[ ${status} -eq 0 ]
	run pkgin -f update
	[ ${status} -eq 0 ]
}

@test "${SUITE} verify keep/no-keep before" {
	skip_if_version -lt 230801 "output differences"
	run pkgin show-keep
	[ ${status} -eq 0 ]
	compare_output "pkgin-keep.before"

	run pkgin show-no-keep
	[ ${status} -eq 0 ]
	compare_output "pkgin-nokeep.before"
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

#
# Upgrade should remove npm, now superseded by the newer nodejs, and replace
# old-* with new-*.  The former is handled in 23.8.0 but the latter is only
# handled in 25.5.0.  Older versions either try to install the newer nodejs
# package which conflicts at install time, or say there's nothing to do.
#
@test "${SUITE} run pkgin upgrade" {
	run pkgin -y upgrade
	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		[ ${status} -eq 0 ]
		output_match "nothing to do"
	elif [ ${PKGIN_VERSION} -le 221000 ]; then
		[ ${status} -eq 1 ]
	elif [ ${PKGIN_VERSION} -lt 250500 ]; then
		[ ${status} -eq 0 ]
	else
		[ ${status} -eq 0 ]
		file_match "pkgin-upgrade.regex"
	fi
}

#
@test "${SUITE} verify pkgin list" {
	skip_if_version -lt 250500 "unsupported"
	compare_pkgin_list "pkgin.list"
}

@test "${SUITE} verify keep/no-keep after" {
	skip_if_version -lt 250500 "unsupported"
	run pkgin sk
	[ ${status} -eq 0 ]
	compare_output "pkgin-keep.after"

	run pkgin snk
	[ ${status} -eq 0 ]
	compare_output "pkgin-nokeep.after"
}
