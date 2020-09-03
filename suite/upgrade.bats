#!/usr/bin/env bats
#
# Test various upgrade scenarios.
#

SUITE="upgrade"

load common

#
# Configure a couple of different repositories, installing from the first, and
# then upgrading to the second.
#
export BUILD_DATE_1="1970-01-01 01:01:01 +0000"
export BUILD_DATE_2="1970-02-02 02:02:02 +0000"
#
setup_file()
{
	#
	# Set up the first repository.
	#
	PACKAGES="${SUITE_WORKDIR}/repo1"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg1"
	HTTPD_PID="${SUITE_WORKDIR}/httpd1.pid"

	create_pkg_buildinfo "refresh-1.0" \
	    "BUILD_DATE=${BUILD_DATE_1}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/refresh"
	create_pkg_comment "refresh-1.0" "Package should be refreshed"
	create_pkg_file "refresh-1.0" "share/doc/refresh"
	create_pkg "refresh-1.0"

	create_pkg_buildinfo "upgrade-1.0" \
	    "BUILD_DATE=${BUILD_DATE_1}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/upgrade"
	create_pkg_comment "upgrade-1.0" "Package should be upgraded"
	create_pkg_file "upgrade-1.0" "share/doc/upgrade"
	create_pkg "upgrade-1.0"

	create_pkg_buildinfo "pkgpath-1.0" \
	    "BUILD_DATE=${BUILD_DATE_1}" \
	    "CATEGORIES=cat2" \
	    "PKGPATH=cat2/pkgpath1"
	create_pkg_comment "pkgpath-1.0" "PKGPATH differs to pkgpath-2.0"
	create_pkg_file "pkgpath-1.0" "share/doc/pkgpath"
	create_pkg "pkgpath-1.0"

	create_pkg_buildinfo "pkgpath-2.0" \
	    "BUILD_DATE=${BUILD_DATE_1}" \
	    "CATEGORIES=cat2" \
	    "PKGPATH=cat2/pkgpath2"
	create_pkg_comment "pkgpath-2.0" "PKGPATH differs to pkgpath-1.0"
	create_pkg_file "pkgpath-2.0" "share/doc/pkgpath"
	create_pkg "pkgpath-2.0"

	create_pkg_buildinfo "deptree-bottom-1.0" \
	    "BUILD_DATE=${BUILD_DATE_1}" \
	    "CATEGORIES=cat3" \
	    "PKGPATH=cat3/deptree-bottom"
	create_pkg_comment "deptree-bottom-1.0" \
	    "Package is at the bottom of a dependency tree"
	create_pkg_file "deptree-bottom-1.0" "share/doc/deptree-bottom"
	create_pkg "deptree-bottom-1.0" -P "refresh>=1.0"

	create_pkg_buildinfo "deptree-top-1.0" \
	    "BUILD_DATE=${BUILD_DATE_1}" \
	    "CATEGORIES=cat3" \
	    "PKGPATH=cat3/deptree-top"
	create_pkg_comment "deptree-top-1.0" \
	    "Package is at the top of a dependency tree"
	create_pkg_file "deptree-top-1.0" "share/doc/deptree-top"
	create_pkg "deptree-top-1.0" -P "deptree-bottom>=1.0"

	create_pkg_summary

	#
	# Set up the second repository.
	#
	PACKAGES="${SUITE_WORKDIR}/repo2"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg2"

	create_pkg_buildinfo "refresh-1.0" \
	    "BUILD_DATE=${BUILD_DATE_2}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/refresh"
	create_pkg_comment "refresh-1.0" "Package should be refreshed"
	create_pkg_file "refresh-1.0" "share/doc/refresh"
	create_pkg "refresh-1.0"

	create_pkg_buildinfo "upgrade-2.0" \
	    "BUILD_DATE=${BUILD_DATE_2}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/upgrade"
	create_pkg_comment "upgrade-2.0" "Package should be upgraded"
	create_pkg_file "upgrade-2.0" "share/doc/upgrade"
	create_pkg "upgrade-2.0"

	#
	# Retain original BUILD_DATE for pkgpath, just so we have a package
	# that should be marked as do nothing when upgrading.
	#
	create_pkg_buildinfo "pkgpath-1.0" \
	    "BUILD_DATE=${BUILD_DATE_1}" \
	    "CATEGORIES=cat2" \
	    "PKGPATH=cat2/pkgpath1"
	create_pkg_comment "pkgpath-1.0" "PKGPATH differs to pkgpath-2.0"
	create_pkg_file "pkgpath-1.0" "share/doc/pkgpath"
	create_pkg "pkgpath-1.0"

	create_pkg_buildinfo "pkgpath-2.0" \
	    "BUILD_DATE=${BUILD_DATE_2}" \
	    "CATEGORIES=cat2" \
	    "PKGPATH=cat2/pkgpath2"
	create_pkg_comment "pkgpath-2.0" "PKGPATH differs to pkgpath-1.0"
	create_pkg_file "pkgpath-2.0" "share/doc/pkgpath"
	create_pkg "pkgpath-2.0"

	create_pkg_buildinfo "deptree-bottom-2.0" \
	    "BUILD_DATE=${BUILD_DATE_2}" \
	    "CATEGORIES=cat3" \
	    "PKGPATH=cat3/deptree-bottom"
	create_pkg_comment "deptree-bottom-2.0" \
	    "Package is at the bottom of a dependency tree"
	create_pkg_file "deptree-bottom-2.0" "share/doc/deptree-bottom"
	create_pkg "deptree-bottom-2.0"

	create_pkg_buildinfo "deptree-middle-2.0" \
	    "BUILD_DATE=${BUILD_DATE_2}" \
	    "CATEGORIES=cat3" \
	    "PKGPATH=cat3/deptree-middle"
	create_pkg_comment "deptree-middle-2.0" \
	    "Package is in the middle of a dependency tree"
	create_pkg_file "deptree-middle-2.0" "share/doc/deptree-middle"
	create_pkg "deptree-middle-2.0" -P "deptree-bottom-[0-9]*"

	create_pkg_buildinfo "deptree-top-2.0" \
	    "BUILD_DATE=${BUILD_DATE_2}" \
	    "CATEGORIES=cat3" \
	    "PKGPATH=cat3/deptree-top"
	create_pkg_comment "deptree-top-2.0" \
	    "Package is at the top of a dependency tree"
	create_pkg_file "deptree-top-2.0" "share/doc/deptree-top"
	create_pkg "deptree-top-2.0" -P "deptree-middle>=2.0"

	#
	# Ensure the second repository has a different timestamp, Last-Modified
	# only has granularity of 1 second.
	#
	sleep 1
	create_pkg_summary

	#
	# Start with the first repository, we'll switch to the second later
	# by updating the symlink.
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
	# Use pkg_add for the first package to help 0.9.x which does not
	# support installing from scratch.
	#
	export PKG_PATH=${SUITE_WORKDIR}/repo1/All
	run pkg_add refresh
	[ $status -eq 0 ]
	[ -z "${output}" ]

	run pkgin -y install deptree-top pkgpath-1.0 upgrade
	[ $status -eq 0 ]
}

@test "${SUITE} verify initial BUILD_DATE" {
	run pkg_info -Q BUILD_DATE refresh
	[ ${status} -eq 0 ]
	[ "${output}" = "${BUILD_DATE_1}" ]
}

@test "${SUITE} switch to updated repository" {
	run rm ${SUITE_WORKDIR}/packages
	[ ${status} -eq 0 ]

	run ln -s repo2 ${SUITE_WORKDIR}/packages
	[ ${status} -eq 0 ]
}

# pkgin 0.9.x. requires an explicit update for repository refresh.
@test "${SUITE} perform pkgin update" {
	skip_if_version -ge 001000 "Not required for 0.10+"
	run pkgin -fy update
	[ ${status} -eq 0 ]
}

#
# XXX: fix
# The keep package installed from the previous repository should not
# match the BUILD_DATE of the current repository, and the version should not
# change during the following upgrades, making it a good candidate to ensure
# that refresh works.
#
# We also need to verify that it is currently in the cache directory, to test
# that we can detect the download needs to be performed even if the sizes
# happen to match.
#
#@test "${SUITE} ensure BUILD_DATE is not current" {
#	skip_if_version -lt 001000 "Does not support BUILD_DATE"
#	run pkg_info -Q BUILD_DATE refresh-1.0
#	[ ${status} -eq 0 ]
#	[ -n "${output}" ]
#	[ "${output}" != "${REPO_BUILD_DATE}" ]
#}
#@test "${SUITE} ensure BUILD_DATE package exists in the cache" {
#	skip_if_version -lt 001000 "Does not support BUILD_DATE"
#	run [ -f ${TEST_PKGIN_CACHE}/refresh-1.0.tgz ]
#	[ ${status} -eq 0 ]
#}

#
# Test all parts of a full-upgrade, including no-op output, download only, and
# an actual install.  Sprinkle some -f to ensure forced updates are correct.
@test "${SUITE} test pkgin full-upgrade (output only)" {
	run pkgin -n fug
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		file_match -I "0.9" "full-upgrade-output-only.regex"
	elif [ ${PKGIN_VERSION} -lt 001100 ]; then
		file_match -I "0.10" "full-upgrade-output-only.regex"
	else
		file_match -I "full-upgrade-output-only.regex"
	fi
}
@test "${SUITE} test pkgin full-upgrade (download only)" {
	# pkgin 0.9.4 doesn't download only!
	skip_if_version -lt 001000 "known fail"

	# The output order here is non-deterministic.
	run pkgin -dfy fug
	if [ ${PKGIN_VERSION} -lt 001100 ]; then
		file_match -I "0.10" "full-upgrade-download-only.regex"
	elif [ ${PKGIN_VERSION} -lt 001300 ]; then
		file_match -I "0.12" "full-upgrade-download-only.regex"
	elif [ ${PKGIN_VERSION} -lt 001601 ]; then
		# Caused by a bug introduced in 0.13, fixed in 0.16.1, trying
		# to record refresh packages after only downloading.  Should
		# have run the test suite!
		file_match -I "0.15" "full-upgrade-download-only.regex"
	else
		file_match -I "full-upgrade-download-only.regex"
	fi
}

@test "${SUITE} test pkgin full-upgrade (output only after download)" {
	run pkgin -fn fug
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		file_match -I "0.9" "full-upgrade-output-only-2.regex"
	elif [ ${PKGIN_VERSION} -lt 001100 ]; then
		file_match -I "0.10" "full-upgrade-output-only-2.regex"
	elif [ ${PKGIN_VERSION} -lt 001300 ]; then
		file_match -I "0.12" "full-upgrade-output-only-2.regex"
	else
		file_match -I "full-upgrade-output-only-2.regex"
	fi
}
@test "${SUITE} test pkgin full-upgrade" {
	run pkgin -y fug
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		file_match "0.9" "full-upgrade.regex"
	elif [ ${PKGIN_VERSION} -lt 001100 ]; then
		file_match "0.10" "full-upgrade.regex"
	elif [ ${PKGIN_VERSION} -eq 001600 ]; then
		# Avoid 0.16.0 due to double printing bug of error log.
		:
	elif [ ${PKGIN_VERSION} -le 200501 ]; then
		file_match "20.5.1" "full-upgrade.regex"
	else
		file_match "full-upgrade.regex"
	fi
}

@test "${SUITE} perform upgrade" {
	run pkgin -y full-upgrade
	[ ${status} -eq 0 ]
}

@test "${SUITE} verify refreshed BUILD_DATE" {
	skip_if_version -lt 001000 "Does not support BUILD_DATE"
	run pkg_info -Q BUILD_DATE refresh
	[ ${status} -eq 0 ]
	[ "${output}" = "${BUILD_DATE_2}" ]
}

#
# Ensure that upgrades did not change status of keep/no-keep packages.
#
@test "${SUITE} verify keep/no-keep post-upgrade" {
	for cmd in show-keep sk; do
		run pkgin_sorted ${cmd}
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-keep"
	done
	for cmd in show-no-keep snk; do
		run pkgin_sorted ${cmd}
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-no-keep"
	done
}

#
# Now verify that the refresh package has been refreshed with the current
# repository BUILD_DATE
#
@test "${SUITE} verify BUILD_DATE refresh" {
	skip_if_version -lt 001000 "Does not support BUILD_DATE"
	run pkg_info -Q BUILD_DATE refresh-1.0
	[ ${status} -eq 0 ]
	[ -n "${output}" ]
	[ "${output}" = "${BUILD_DATE_2}" ]
}

#
# Verify behaviour of PKGPATH with regards to upgrades:
#
#  1. An upgrade should not consider a newer version if PKGPATH does not match.
#  2. A "pkgin import" using the original PKGPATH should not either.
#  3. An explicit "pkgin install" of a different PKGPATH should upgrade.
#
# Versions of pkgin prior to 0.11.2 do not handle #2 correctly, they only
# match on PKGNAME not FULLPKGNAME and end up performing an upgrade, so that
# test is skipped.
#
@test "${SUITE} verify PKGPATH change prevented upgrade" {
	run pkg_info -qe pkgpath-1.0
	[ ${status} -eq 0 ]
}
@test "${SUITE} test pkgin import does not upgrade PKGPATH" {
	skip_if_version -lt 001102

	echo "cat2/pkgpath1" >${SUITE_WORKDIR}/import-pkgpath1
	run pkgin -y import ${SUITE_WORKDIR}/import-pkgpath1
	[ ${status} -eq 0 ]

	run pkg_info -qe pkgpath-1.0
	[ ${status} -eq 0 ]
}
@test "${SUITE} test install of package where PKGPATH changed" {
	run pkgin -y install pkgpath-2.0
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		file_match "0.9" "install-pkgpath-upgrade.regex"
	elif [ ${PKGIN_VERSION} -lt 001100 ]; then
		file_match "0.10" "install-pkgpath-upgrade.regex"
	elif [ ${PKGIN_VERSION} -eq 001600 ]; then
		# Avoid 0.16.0 due to double printing bug of error log.
		:
	else
		file_match "install-pkgpath-upgrade.regex"
	fi
}
#
# Just for completeness sake do a full downgrade and upgrade using
# "pkgin import", ending up back where we started for verification.
#
@test "${SUITE} test installing PKGPATH changes via import" {
	skip_if_version -lt 001102

	echo "cat2/pkgpath1" >${SUITE_WORKDIR}/import-pkgpath1
	run pkgin -y import ${SUITE_WORKDIR}/import-pkgpath1
	[ ${status} -eq 0 ]

	run pkg_info -qe pkgpath-1.0
	[ ${status} -eq 0 ]

	echo "cat2/pkgpath2" >${SUITE_WORKDIR}/import-pkgpath2
	run pkgin -y import ${SUITE_WORKDIR}/import-pkgpath2
	[ ${status} -eq 0 ]

	run pkg_info -qe pkgpath-2.0
	[ ${status} -eq 0 ]
}

#
# Verify final contents.
#
@test "${SUITE} verify pkg_info" {
	compare_pkg_info "pkg_info.final"
}
@test "${SUITE} verify pkgin list" {
	compare_pkgin_list "pkgin-list.final"
}
@test "${SUITE} verify package file contents" {
	run cat ${LOCALBASE}/share/doc/*
	[ ${status} -eq 0 ]
	compare_output "cat-share-doc-all.out"
}
