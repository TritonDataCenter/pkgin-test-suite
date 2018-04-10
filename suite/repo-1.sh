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
pkg_rest="builddate-1.0 pkgpath-1.0 upgrade-1.0 deptree-top-1.0"
if [ ${PKGIN_VERSION} != "0.9.4" ]; then
	pkg_rest="${pkg_rest} supersedes-1.0"
fi
pkg_showdeps="deptree-top-1.0"
pkg_showrdeps="deptree-bottom" # XXX: doesn't support FULLPKGNAME
#
category="testsuite"
pkg_category="pkgpath"

#
# Test a fresh install against no existing databases.
#
# TEST_PKGIN_DBDIR needs to exist as pkgin does not create parent directories.
#
@test "${REPO_NAME} test first install against empty installation" {
	# pkgin 0.9.4 does not work correctly against an empty install
	skip094 known fail

	run rm -rf ${TEST_LOCALBASE} ${TEST_VARBASE}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run mkdir -p ${TEST_PKGIN_DBDIR}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run pkgin -y install ${pkg_first}
	[ ${status} -eq 0 ]
	output_match "processing local summary"
	output_match "processing remote summary"
	#XXX plural
	output_match "1 packages to be installed"
	output_match "installing.*${pkg_first}"
	output_match "pkg_install warnings: 0, errors: 0"

	compare_pkg_info "pkg_info.start"
}

#
# Now do the same but against an installation which has already had some
# packages installed using pkg_add.  This should correctly initialise the
# existing packages.
#
@test "${REPO_NAME} test first install against existing pkg_add installation" {
	run rm -rf ${TEST_LOCALBASE} ${TEST_VARBASE}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run pkg_add ${pkg_first}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	compare_pkg_info "pkg_info.start"

	run mkdir -p ${TEST_PKGIN_DBDIR}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run pkgin -y install ${pkg_first}
	[ ${status} -eq 0 ]
	output_match "processing local summary"
	if [ ${PKGIN_VERSION} != "0.9.4" ]; then
		output_match "processing remote summary"
	fi
	output_match "nothing to do"

	compare_pkgin_list "pkgin-list.start"
}
@test "${REPO_NAME} test TEST_PKG_INSTALL_LOG is missing" {
	run [ ! -f ${TEST_PKG_INSTALL_LOG} ]
	[ ${status} -eq 0 ]
}

#
# Install subsequent packages.
#
@test "${REPO_NAME} install remaining packages" {
	run pkgin -y install ${pkg_rest}
	[ ${status} -eq 0 ]
	output_match "packages to be installed"
	output_match "pkg_install warnings: 0, errors: 0"
	for pkg in ${pkg_rest}; do
		output_match "installing ${pkg}"
		output_match "marking ${pkg} as non auto-removable"
	done
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
	line_match 1 "nothing to do"

	run pkg_add ${pkg_first}
	[ ${status} -eq 0 ]
	output_match "already recorded as installed"
}

#
# Now that we have some packages installed we can re-run basic commands
# that will now have output.
#
@test "${REPO_NAME} verify pkgin clean" {
	run ls ${TEST_PKGIN_CACHE}
	[ ${status} -eq 0 ]
	[ -n "${output}" ]

	run pkgin clean
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	run ls ${TEST_PKGIN_CACHE}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}
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
		if [ ${PKGIN_VERSION} = "0.9.4" ]; then
			compare_output "pkgin-0.9.4.stats"
		else
			compare_output "pkgin.stats"
		fi
	done
}
@test "${REPO_NAME} verify pkgin show-keep" {
	for cmd in show-keep sk; do
		run pkgin ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} = "0.9.4" ]; then
			compare_output "pkgin-0.9.4.show-keep"
		else
			compare_output "pkgin.show-keep"
		fi
	done
}
@test "${REPO_NAME} verify pkgin show-no-keep" {
	for cmd in show-no-keep snk; do
		run pkgin ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} = "0.9.4" ]; then
			compare_output "pkgin-0.9.4.show-no-keep"
		else
			compare_output "pkgin.show-no-keep"
		fi
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
# XXX; why is pkgpath not being exported?
@test "${REPO_NAME} verify pkgin export" {
	# For some reason 0.9.4 says "pkgin: empty local package list."
	skip094 known fail

	for cmd in export ex; do
		run pkgin ${cmd}
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
		line_match 1 "Files"
		line_match 2 "share.doc.keep"
	done
}
@test "${REPO_NAME} verify pkgin show-category" {
	# For some reason 0.9.4 segfaults
	skip094 known fail

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
	if [ ${PKGIN_VERSION} = "0.9.4" ]; then
		compare_pkg_info "pkg_info-0.9.4.final"
	else
		compare_pkg_info "pkg_info.final"
	fi
}
@test "${REPO_NAME} verify pkgin list" {
	if [ ${PKGIN_VERSION} = "0.9.4" ]; then
		compare_pkgin_list "pkgin-list-0.9.4.final"
	else
		compare_pkgin_list "pkgin-list.final"
	fi
}
@test "${REPO_NAME} verify package file contents" {
	run cat ${TEST_LOCALBASE}/share/doc/*
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} = "0.9.4" ]; then
		compare_output "cat-share-doc-all-0.9.4.out"
	else
		compare_output "cat-share-doc-all.out"
	fi
}
@test "${REPO_NAME} verify builddate BUILD_DATE" {
	run pkg_info -Q BUILD_DATE builddate
	[ ${status} -eq 0 ]
	[ "${output}" = "${REPO_BUILD_DATE}" ]
}
