#
# Test file:// downloads.  @VARS@ are substituted from the top-level Makefile.
#
PKG_OK="@PKG_OK@"
PKG_NOTFOUND="@PKG_NOTFOUND@"
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

	run pkgin -fy up
	[ ${status} -eq 0 ]
}

#
# Test a file download, which is just a symlink.  Do not install.
#
@test "${REPO_NAME} test download-only" {
	run pkgin -dy install ${PKG_OK}
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		file_match "0.9" "download-only.regex"
	elif [ ${PKGIN_VERSION} -lt 001100 ]; then
		file_match "0.10" "download-only.regex"
	else
		file_match "download-only.regex"
	fi

	run [ -L ${TEST_PKGIN_CACHE}/${PKG_OK}.tgz ]
	[ ${status} -eq 0 ]

	run pkg_info -qe ${PKG_OK}
	[ ${status} -eq 1 ]
}

#
# Now install separately.
#
@test "${REPO_NAME} test successful install" {
	run pkgin -y install ${PKG_OK}
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		file_match "0.9" "install-downloaded.regex"
	elif [ ${PKGIN_VERSION} -lt 001100 ]; then
		file_match "0.10" "install-downloaded.regex"
	else
		file_match "install-downloaded.regex"
	fi

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

	run [ ! -d ${TEST_PKGIN_CACHE} ]
	[ ${status} -eq 0 ]
}

#
# Now install to test both the install and also the download counters.
#
@test "${REPO_NAME} test download and install" {
	run pkg_delete ${PKG_OK}
	[ ${status} -eq 0 ]

	run pkgin -y install ${PKG_OK}
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		file_match "0.9" "download-install.regex"
	elif [ ${PKGIN_VERSION} -lt 001100 ]; then
		file_match "0.10" "download-install.regex"
	else
		file_match "download-install.regex"
	fi

	run pkg_info -qe ${PKG_OK}
	[ ${status} -eq 0 ]
}

#
# Test a failed download by removing the package first.  Not supported by
# pkgin-0.9.x.
#
@test "${REPO_NAME} test failed pkgin download (not found)" {
	skip_if_version -lt 001000 "Does not handle file not found"

	run rm ${REPO_PACKAGES}/${PKG_NOTFOUND}.tgz
	[ ${status} -eq 0 ]

	run pkgin -y install ${PKG_NOTFOUND}
	[ ${status} -eq 1 ]
	if [ ${PKGIN_VERSION} -lt 001100 ]; then
		file_match "0.10" "download-notfound.regex"
	else
		file_match "download-notfound.regex"
	fi

	run [ -L ${TEST_PKGIN_CACHE}/${PKG_NOTFOUND}.tgz ]
	[ ${status} -eq 1 ]

}

#
# Test a mismatched download by truncating the file to half its size, not
# supported by pkgin-0.9.x.
#
@test "${REPO_NAME} test failed pkgin download (mismatch)" {
	skip_if_version -lt 001000 "Does not handle mismatches"

	truncfile="${REPO_PACKAGES}/${PKG_MISMATCH}.tgz"
	len=$(wc -c < ${truncfile} | awk '{print $1}')
	run dd if=${truncfile} of=${truncfile}.tmp bs=1 count=$((len / 2))
	[ ${status} -eq 0 ]

	run mv ${truncfile}.tmp ${truncfile}
	[ ${status} -eq 0 ]

	# The install attempt should abort prior to calling pkg_add
	run pkgin -y install ${PKG_MISMATCH}
	[ ${status} -eq 1 ]
	if [ ${PKGIN_VERSION} -lt 001100 ]; then
		file_match "0.10" "download-mismatch.regex"
	else
		file_match "download-mismatch.regex"
	fi

	run [ -L ${TEST_PKGIN_CACHE}/${PKG_MISMATCH}.tgz ]
	[ ${status} -eq 1 ]
}

#
# Ensure that this package is removed so that subsequent test runs correctly
# regenerate it and pkg_summary.  This must be its own test to ensure it is
# executed.
#
@test "${REPO_NAME} explicitly remove mismatched package" {
	run rm ${REPO_PACKAGES}/${PKG_MISMATCH}.tgz
	[ ${status} -eq 0 ]
}

@test "${REPO_NAME} compare pkg_info" {
	compare_pkg_info "pkg_info.final"
}
