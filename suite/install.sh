#
# This repository performs the first proper installs, verifying that packages
# are available and install as expected, then leaves them for subsequent test
# repositories to perform against.
#
# The first package is installed using pkg_add to verify that pkgin correctly
# updates the database with existing packages.
#

# deptree-top automatically pulls in deptree-* dependencies.
pkg_first="keep-1.0"
pkg_rest="pkgpath-1.0 upgrade-1.0 deptree-top-1.0"
if [ ${PKGIN_VERSION} -ge 001000 ]; then
	: pkg_rest="${pkg_rest} supersedes-1.0"
fi
pkg_showdeps="deptree-top-1.0"
pkg_showrdeps="deptree-bottom" # XXX: doesn't support FULLPKGNAME
#
category="testsuite"
pkg_category="pkgpath"

#
# Ensure a clean work area to start with.
#
@test "${REPO_NAME} ensure clean work directory" {
	run rm -rf ${TEST_LOCALBASE} ${TEST_VARBASE}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run mkdir -p ${TEST_PKGIN_DBDIR}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}

#
# Start with an existing pkg_add installation, to ensure we correctly pick up
# existing local packages and do not try to perform the install.
#
# This doesn't work correctly pre-0.10 so just skip for 0.9.
#
@test "${REPO_NAME} install first package using pkg_add" {
	run pkg_add ${pkg_first}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}
@test "${REPO_NAME} verify first package with pkg_info" {
	compare_pkg_info "pkg_info.start"
}
@test "${REPO_NAME} test pkgin install against existing installation" {
	skip_if_version -lt 001000
	run pkgin -y install ${pkg_first}
	[ ${status} -eq 0 ]
	file_match "install-against-existing.regex"
}
@test "${REPO_NAME} verify TEST_PKG_INSTALL_LOG is missing" {
	run [ ! -f ${TEST_PKG_INSTALL_LOG} ]
	[ ${status} -eq 0 ]
}
@test "${REPO_NAME} verify pkgin list against existing installation" {
	skip_if_version -lt 001000
	compare_pkgin_list "pkgin-list.start"
}

#
# Now do the same but against an empty installation.  It is important that this
# test comes after the previous one, as we rely on the cache directory having
# some packages in it to test upgrades work correctly (e.g. mismatches).
#
@test "${REPO_NAME} create empty installation" {
	run rm -rf ${TEST_LOCALBASE} ${TEST_VARBASE}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run mkdir -p ${TEST_PKGIN_DBDIR}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}
@test "${REPO_NAME} test pkgin install against empty installation" {
	# Pre-0.10 doesn't work against an empty installation, so we need to
	# give it a helping hand.
	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		run pkg_add ${pkg_first}
		[ ${status} -eq 0 ]
		[ -z "${output}" ]

		run pkgin -fy up
		[ ${status} -eq 0 ]
	fi
	run pkgin -y install ${pkg_first}
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		file_match "0.9" "install-against-empty.regex"
	elif [ ${PKGIN_VERSION} -lt 001100 ]; then
		file_match "0.10" "install-against-empty.regex"
	else
		file_match "install-against-empty.regex"
	fi
}
@test "${REPO_NAME} verify pkgin list against empty installation" {
	compare_pkgin_list "pkgin-list.start"
}

#
# Install subsequent packages.  This uses -f to test that a force refresh
# of the remote database is performed correctly.
#
@test "${REPO_NAME} install remaining packages" {
	run pkgin -fy install ${pkg_rest}
	[ ${status} -eq 0 ]
	# The output order here is nondeterministic.
	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		file_match -I "0.9" "install-remaining.regex"
	elif [ ${PKGIN_VERSION} -lt 001100 ]; then
		file_match -I "0.10" "install-remaining.regex"
	elif [ ${PKGIN_VERSION} -lt 001300 ]; then
		file_match -I "0.12" "install-remaining.regex"
	else
		file_match -I "install-remaining.regex"
	fi
}
# Should only contain "installing .." lines.
@test "${REPO_NAME} verify TEST_PKG_INSTALL_LOG contents" {
	run [ -s ${TEST_PKG_INSTALL_LOG} ]
	[ ${status} -eq 0 ]

	run grep -v installing ${TEST_PKG_INSTALL_LOG}
	[ ${status} -eq 1 ]
	[ -z "${output}" ]
}
@test "${REPO_NAME} attempt to install already-installed package" {
	run pkgin -y install ${pkg_first}
	[ ${status} -eq 0 ]
	output_match "nothing to do"

	# Verify a force install refreshes the remote summary, except it
	# doesn't pre-0.10
	run pkgin -fy install ${pkg_first}
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} -ge 001000 ]; then
		output_match "processing remote summary"
	fi
	output_match "nothing to do"

	run pkg_add ${pkg_first}
	[ ${status} -eq 0 ]
	output_match "already recorded as installed"
}

#
# Now that we have some packages installed we can re-run basic commands
# that will now have output.
#
@test "${REPO_NAME} verify pkgin search" {
	for cmd in search se; do
		run pkgin ${cmd} keep
		[ ${status} -eq 0 ]
		compare_output "pkgin.search"
	done
}
@test "${REPO_NAME} verify pkgin stats" {
	for cmd in stats st; do
		run pkgin stats
		[ ${status} -eq 0 ]
		file_match "pkgin-stats.regex"
	done
}
@test "${REPO_NAME} verify pkgin show-keep" {
	for cmd in show-keep sk; do
		run pkgin_sorted ${cmd}
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-keep"
	done
}
@test "${REPO_NAME} verify pkgin show-no-keep" {
	for cmd in show-no-keep snk; do
		run pkgin_sorted ${cmd}
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-no-keep"
	done
}
@test "${REPO_NAME} verify pkgin show-deps" {
	for cmd in show-deps sd; do
		run pkgin ${cmd} ${pkg_showdeps}
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-deps"
	done
}
@test "${REPO_NAME} verify pkgin show-full-deps" {
	for cmd in show-full-deps sfd; do
		run pkgin ${cmd} ${pkg_showdeps}
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-full-deps"
	done
}
# XXX: find something that actually works
@test "${REPO_NAME} verify pkgin show-rev-deps" {
	for cmd in show-rev-deps srd; do
		run pkgin ${cmd} ${pkg_showrdeps}
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-rev-deps"
	done
}

@test "${REPO_NAME} verify pkgin export" {
	# For some reason 0.9.4 says "pkgin: empty local package list."
	skip_if_version -lt 001000 "known fail"

	for cmd in export ex; do
		run pkgin_sorted ${cmd}
		[ ${status} -eq 0 ]
		compare_output "pkgin.export"
	done
}
@test "${REPO_NAME} verify pkgin pkg-content" {
	for cmd in pkg-content pc; do
		run pkgin ${cmd} ${pkg_first}
		[ ${status} -eq 0 ]
		# Output changes depending on test directory
		line_match 0 "Information for .*${pkg_first}"
		line_match 1 "PACKAGE MAY NOT BE DELETED"
		line_match 2 "Files"
		line_match 3 "share.doc.keep"
	done
}
@test "${REPO_NAME} verify pkgin show-category" {
	# For some reason 0.9.4 segfaults
	skip_if_version -lt 001000 "known fail"

	for cmd in show-category sc; do
		run pkgin ${cmd} ${category}
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-category"
	done
}
@test "${REPO_NAME} verify pkgin show-pkg-category" {
	for cmd in show-pkg-category spc; do
		run pkgin ${cmd} ${pkg_category}
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-pkg-category"
	done
}

@test "${REPO_NAME} verify pkgin show-all-categories" {
	for cmd in show-all-categories sac; do
		run pkgin ${cmd}
		[ ${status} -eq 0 ]
		compare_output "pkgin.show-all-categories"
	done
}

#
# Verify both pkg_info and pkgin output are identical after all operations, as
# well as the contents of the packages themselves (to ensure they were actually
# installed correctly).
#
@test "${REPO_NAME} verify pkg_info" {
	compare_pkg_info "pkg_info.final"
}
@test "${REPO_NAME} verify pkgin list" {
	compare_pkgin_list "pkgin-list.final"
}
@test "${REPO_NAME} verify package file contents" {
	run cat ${TEST_LOCALBASE}/share/doc/*
	[ ${status} -eq 0 ]
	compare_output "cat-share-doc-all.out"
}
@test "${REPO_NAME} verify BUILD_DATE" {
	run pkg_info -Q BUILD_DATE keep-1.0
	[ ${status} -eq 0 ]
	[ -n "${output}" ]
	[ "${output}" = "${REPO_BUILD_DATE}" ]
}
