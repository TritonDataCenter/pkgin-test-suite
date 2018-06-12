#
# Test http:// downloads.  @VARS@ are substituted from the top-level Makefile.
#
PKG_OK="@PKG_OK@"
PKG_NOTFOUND="@PKG_NOTFOUND@"
PKG_TRUNCATE="@PKG_TRUNCATE@"
PKG_MISMATCH="@PKG_MISMATCH@"

#
# Ensure we start with a clean work area, and install the initial package to
# work around issues with older pkgin which cannot install packages to an
# empty pkgdb.
#
@test "${REPO_NAME} setup test suite environment" {
	run rm -rf ${TEST_LOCALBASE} ${TEST_VARBASE}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run mkdir -p ${TEST_PKGIN_DBDIR}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run pkg_add keep
	[ ${status} -eq 0 ]

	run pkgin up
	[ ${status} -eq 0 ]
}

#
# Test a successful file download.  Do not install.
#
@test "${REPO_NAME} test download-only" {
	run pkgin -dy install ${PKG_OK}
	[ ${status} -eq 0 ]
	file_match "download-only.regex"

	run [ -f ${TEST_PKGIN_CACHE}/${PKG_OK}.tgz ]
	[ ${status} -eq 0 ]

	run pkg_info -qe ${PKG_OK}
	[ ${status} -eq 1 ]
}

#
# Now install separately.
#
@test "${REPO_NAME} test install of already-downloaded package" {
	run pkgin -y install ${PKG_OK}
	[ ${status} -eq 0 ]
	file_match "install-downloaded.regex"

	run pkg_info -qe ${PKG_OK}
	[ ${status} -eq 0 ]
}

#
# Test pkgin clean, should result in an empty directory that can successfully
# be rmdir'd.
#
@test "${REPO_NAME} test pkgin clean" {
	run pkgin clean
	[ ${status} -eq 0 ]

	run rmdir ${TEST_PKGIN_CACHE}
	[ ${status} -eq 0 ]

	[ ! -d ${TEST_PKGIN_CACHE} ]
	[ ${status} -eq 0 ]
}

#
# Now install to test both the install and also the download counters.
#
@test "${REPO_NAME} test download and install" {
	run pkg_delete ${PKG_OK}
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		run pkgin -fy update
		[ ${status} -eq 0 ]
	fi

	run pkgin -y install ${PKG_OK}
	[ ${status} -eq 0 ]
	file_match "download-install.regex"

	run pkg_info -qe ${PKG_OK}
	[ ${status} -eq 0 ]
}

#
# These tests all rely on our fake httpd to amend the packages in transit
# even though they exist fine in the repository.
#
# pkgin-0.9.4 differs in some of the output, hence not supporting file_match
#
@test "${REPO_NAME} test failed download (not found)" {
	run pkgin -y install ${PKG_NOTFOUND}
	[ ${status} -eq 1 ]
	file_match "download-notfound.regex"

	run [ -L ${TEST_PKGIN_CACHE}/${PKG_NOTFOUND}.tgz ]
	[ ${status} -eq 1 ]
}
@test "${REPO_NAME} test failed download (truncated)" {
	run pkgin -y install ${PKG_TRUNCATE}
	[ ${status} -eq 1 ]
	file_match "download-truncate.regex"

	run [ -L ${TEST_PKGIN_CACHE}/${PKG_TRUNCATE}.tgz ]
	[ ${status} -eq 1 ]
}
@test "${REPO_NAME} test failed download (mismatch)" {
	run pkgin -y install ${PKG_MISMATCH}
	[ ${status} -eq 1 ]
	file_match "download-mismatch.regex"

	run [ -L ${TEST_PKGIN_CACHE}/${PKG_MISMATCH}.tgz ]
	[ ${status} -eq 1 ]
}

#
# Test again but all at the same time to verify counters and output format.
#
@test "${REPO_NAME} test all failed downloads" {
	run pkgin -y install ${PKG_NOTFOUND} ${PKG_TRUNCATE} ${PKG_MISMATCH}
	[ ${status} -eq 1 ]
	file_match "download-all-failed.regex"
}

# Verify everything is as it should be at the end of the tests.
@test "${REPO_NAME} compare pkg_info" {
	compare_pkg_info "pkg_info.final"
}
