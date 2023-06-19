#!/usr/bin/env bats
#
# Reproduce a test case seen in the wild where a "pkgin install" operation
# against an updated repository does not correctly calculate the required
# upgrades.
#

SUITE="partial-upgrade"

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

	create_pkg_buildinfo "python38-3.8.6" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/python38"
	create_pkg_comment "python38-3.8.6" \
	    "Interpreted, interactive, object-oriented programming language"
	create_pkg "python38-3.8.6"

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
	create_pkg "npm-6.14.11" -P "nodejs-[0-9]* python38>=3.8.0"

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

	create_pkg_buildinfo "python310-3.10.9" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/python310"
	create_pkg_comment "python310-3.10.9" \
	    "Interpreted, interactive, object-oriented programming language"
	create_pkg "python310-3.10.9" -P "gcc12-libs>=12.2.0"

	create_pkg_buildinfo "nodejs-14.21.1" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/nodejs14"
	create_pkg_comment "nodejs-14.21.1" \
	    "V8 JavaScript for clients and servers"
	create_pkg "nodejs-14.21.1" -P "gcc12-libs>=12.2.0"

	create_pkg_buildinfo "nghttp2-1.51.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=www" \
	    "PKGPATH=www/nghttp2"
	create_pkg_comment "nghttp2-1.51.0" "Implementation of HTTP/2 in C"
	create_pkg "nghttp2-1.51.0"

	create_pkg_buildinfo "nodejs-19.2.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/nodejs"
	create_pkg_comment "nodejs-19.2.0" \
	    "V8 JavaScript for clients and servers"
	create_pkg "nodejs-19.2.0" -P "gcc12-libs>=12.2.0 nghttp2>=1.45.1"

	create_pkg_buildinfo "npm-8.15.1" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/npm"
	create_pkg_comment "npm-8.15.1" "Package manager for JavaScript"
	create_pkg "npm-8.15.1" -P "nodejs-[0-9]* python310>=3.10"

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
	run pkg_add npm
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
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
# This is where things go wrong.  As the "nodejs-[0-9]*" dependency doesn't
# change but the lang/nodejs package does (with our current version moving to
# lang/nodejs14) its new dependencies aren't calculated correctly.  During the
# install, nodejs is refreshed at best, even though it's an upgrade, and the
# new dependency on nghttp2 is not pulled in, causing pkg_add to fail.
#
# Different versions fail in different ways depending on what support they had
# at the time for e.g. refresh.
#
@test "${SUITE} install new npm" {
	run pkgin -y install npm

	#
	# pkgin 0.9.4 and earlier complete somewhat successfully, but do not
	# upgrade nodejs, leaving the older 14.16.1 package installed.
	#
	if [ ${PKGIN_VERSION} -le 000904 ]; then
		output_match "1 packages to be upgraded"
		output_match "3 packages to be installed"
		[ ${status} -eq 0 ]
	#
	# pkgin 0.10.* through 0.11.3 actually work correctly, though through
	# luck thanks to pkg_add pulling in the right packages automatically,
	# and with incorrect output (considering the nodejs upgrade to be a
	# refresh).
	#
	elif [ ${PKGIN_VERSION} -le 001103 ]; then
		[ ${status} -eq 0 ]
		output_match_clean_pkg_install
	#
	# pkgin 0.11.4 onwards fixed some DEPENDS matching during recursion
	# which had the side effect of no longer happening to accidentally work
	# for this test case.
	#
	# pkgin 20.7.0 onwards continue to fail but in a slightly different way
	# due to changes in install ordering, so the tests below are written
	# cover both cases.
	#
	elif [ ${PKGIN_VERSION} -le 221000 ]; then
		[ ${status} -eq 1 ]
		output_match "2 to refresh, 1 to upgrade, 1 to install"
		output_match "pkg_install warnings: 0, errors: 2"
	#
	# Bug finally found and fixed correctly after 22.10.0.
	#
	else
		output_match "1 to refresh, 2 to upgrade, 2 to install"
		output_match_clean_pkg_install
	fi
}

#
# The final "pkgin list" will verify the correct packages are installed, but we
# also need to check that refreshes happened correctly.
#
@test "${SUITE} verify status of dependencies" {
	skip_if_version -lt 001000 "does not support BUILD_DATE"

	# Packages in the recursive dependencies path should be refreshed.
	run pkg_info -Q BUILD_DATE gcc12-libs
	[ "${output}" = "${BUILD_DATE_2}" ]

	# Superseded by python310, should be left alone.
	run pkg_info -Q BUILD_DATE python38
	[ "${output}" = "${BUILD_DATE_1}" ]
}

#
# Versions between 0.10 and 0.11.3 happen to succeed here due to older logic
# that relied on (incorrectly) automatically installing dependencies, all
# others fail due to various reasons explained above.
#
@test "${SUITE} verify pkgin list against existing installation" {
	if [ ${PKGIN_VERSION} -lt 001000 ] ||
	   [ ${PKGIN_VERSION} -gt 001103 -a ${PKGIN_VERSION} -le 221000 ]; then
		skip "does not handle partial upgrades correctly"
	fi

	compare_pkgin_list "pkgin.list"
}
