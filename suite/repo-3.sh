#
# The third repository tests conflict scenarios.
#
# There are two types of CONFLICTs, those explicitly marked with @pkgcfl
# entries in a PLIST which are translated from CONFLICT entries in pkgsrc
# packages, and those where there are conflicting PLIST entries.
#

pkg_conflict_pkgcfl="conflict-pkgcfl"
pkg_conflict_plist="conflict-plist"
pkg_requires="requires"
pkg_provides="provides"

#
# Test @pkgcfl conflicts.
#
@test "${REPO_NAME} attempt to install @pkgcfl conflict package" {
	run pkgin -py install ${pkg_conflict_pkgcfl}
	[ ${status} -eq 1 ]
	output_match "pkg_install warnings: 0, errors: 1"
}
@test "${REPO_NAME} verify pkg_install-err.log (@pkgcfl)" {
	run cat ${TEST_PKG_INSTALL_LOG}
	[ ${status} -eq 0 ]
	output_match "Package.*conflict-.*conflicts.*with.*keep"
}
#
# Test PLIST conflicts.
#
@test "${REPO_NAME} attempt to install PLIST confict package" {
	run pkgin -py install ${pkg_conflict_plist}
	[ ${status} -eq 1 ]
	output_match "pkg_install warnings: 0, errors: 1"
}
@test "${REPO_NAME} verify pkg_install-err.log (PLIST)" {
	run cat ${TEST_PKG_INSTALL_LOG}
	[ ${status} -eq 0 ]
	output_match "Conflicting PLIST with keep-1.0"
}

@test "${REPO_NAME} attempt to install missing REQUIRES package" {
	run pkgin -py install ${pkg_requires}
	[ ${status} -eq 0 ]
	line_match 1 "libprovides.so, needed by requires-1.0 is not present"
}

#
# Verify the database entries have been loaded, this is useful when developing
# the pkgin parser to ensure they are correctly registered.
#
@test "${REPO_NAME} verify LOCAL_CONFLICTS table" {
	skip094 known fail

	run pkgdbsql "SELECT DISTINCT LOCAL_CONFLICTS_PKGNAME FROM LOCAL_CONFLICTS;"
	[ ${status} -eq 0 ]
	compare_output "pkgin-conflicts.local"
}
@test "${REPO_NAME} verify REMOTE_CONFLICTS table" {
	run pkgdbsql "SELECT DISTINCT REMOTE_CONFLICTS_PKGNAME FROM REMOTE_CONFLICTS;"
	[ ${status} -eq 0 ]
	compare_output "pkgin-conflicts.remote"
}

@test "${REPO_NAME} verify LOCAL_PROVIDES table" {
	run pkgdbsql "SELECT DISTINCT LOCAL_PROVIDES_PKGNAME FROM LOCAL_PROVIDES;"
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}
@test "${REPO_NAME} verify REMOTE_PROVIDES table" {
	run pkgdbsql "SELECT DISTINCT REMOTE_PROVIDES_PKGNAME FROM REMOTE_PROVIDES;"
	[ ${status} -eq 0 ]
	line_match 0 "libprovides.so"
}

@test "${REPO_NAME} verify LOCAL_REQUIRES table" {
	run pkgdbsql "SELECT DISTINCT LOCAL_REQUIRES_PKGNAME FROM LOCAL_REQUIRES;"
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}
@test "${REPO_NAME} verify REMOTE_REQUIRES table" {
	run pkgdbsql "SELECT DISTINCT REMOTE_REQUIRES_PKGNAME FROM REMOTE_REQUIRES;"
	[ ${status} -eq 0 ]
	line_match 0 "libprovides.so"
}

@test "${REPO_NAME} verify pkg_info" {
	compare_pkg_info "pkg_info.final"
}
