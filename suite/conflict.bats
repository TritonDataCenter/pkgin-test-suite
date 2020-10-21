#!/usr/bin/env bats
#
# Test various conflicts.
#
# There are two types of CONFLICTs, those explicitly marked with @pkgcfl
# entries in a PLIST which are translated from CONFLICT entries in pkgsrc
# packages, and those where there are conflicting PLIST entries.
#
# The former we can correctly detect before install, but unfortunately the
# latter cannot, so we simply test that the errors are correctly reported.
#
# XXX: Note that pkgin does not yet test whether a remote package CONFLICTS
# matches any local packages, only whether a local package CONFLICTS matches
# any incoming remote package.  This should be fixed!
#

SUITE="conflict"

load common

setup_file()
{
	BUILD_DATE="1970-01-01 01:01:01 +0000"

	create_pkg_buildinfo "preserve-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=conflict" \
	    "PKGPATH=conflict/preserve"
	create_pkg_comment "preserve-1.0" "Package should remain at all times"
	create_pkg_file "preserve-1.0" "share/doc/preserve"
	create_pkg_preserve "preserve-1.0"
	create_pkg "preserve-1.0" -C "conflict-pkg-[0-9]*"

	create_pkg_buildinfo "conflict-pkg-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=conflict" \
	    "PKGPATH=conflict/conflict-pkg"
	create_pkg_comment "conflict-pkg-1.0" "Package conflicts (@pkgcfl)"
	create_pkg_file "conflict-pkg-1.0" "share/doc/conflict-pkg"
	create_pkg "conflict-pkg-1.0"

	create_pkg_buildinfo "conflict-plist-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=conflict" \
	    "PKGPATH=conflict/conflict-plist"
	create_pkg_comment "conflict-plist-1.0" "Package conflicts (PLIST)"
	create_pkg_file "conflict-plist-1.0" "share/doc/preserve"
	create_pkg "conflict-plist-1.0"

	create_pkg_summary
	start_httpd

	rm -rf ${LOCALBASE} ${VARBASE}
	mkdir -p ${PKGIN_DBDIR}
}

teardown_file()
{
	stop_httpd
}
@test "${SUITE} perform initial pkgin setup" {
        export PKG_PATH=${PACKAGES}/All
        run pkg_add preserve
        [ ${status} -eq 0 ]

        run pkgin -fy update
        [ ${status} -eq 0 ]
}

#
# Test @pkgcfl conflicts.
#
@test "${SUITE} attempt to not install @pkgcfl conflict package" {
	if [ ${PKGIN_VERSION} -eq 200700 -o ${PKGIN_VERSION} -eq 200800 ]; then
		skip "crashes due to NetBSDfr/pkgin#105"
	fi
	run pkgin -n install conflict-pkg
	[ ${status} -eq 0 ]
	output_match "conflict-pkg.* conflicts with installed package preserve"
}
@test "${SUITE} attempt to install @pkgcfl conflict package" {
	run pkgin -y install conflict-pkg
	[ ${status} -eq 1 ]
	output_match "conflict-pkg.* conflicts with installed package preserve"
	output_match "pkg_install warnings: 0, errors: 1"
}
@test "${SUITE} verify pkg_install-err.log (@pkgcfl)" {
	run cat ${PKG_INSTALL_LOG}
	[ ${status} -eq 0 ]
	output_match "Installed package.*preserve.*conflicts.*with.*conflict-pkg"
}
#
# Test PLIST conflicts.
#
@test "${SUITE} attempt to install PLIST confict package" {
	run pkgin -y install conflict-plist
	[ ${status} -eq 1 ]
	output_match "pkg_install warnings: 0, errors: 1"
}
@test "${SUITE} verify pkg_install-err.log (PLIST)" {
	run cat ${PKG_INSTALL_LOG}
	[ ${status} -eq 0 ]
	output_match "Conflicting PLIST with preserve-1.0"
}

#
# Verify the database entries have been loaded, this is useful when developing
# the pkgin parser to ensure they are correctly registered.
#
@test "${SUITE} verify LOCAL_CONFLICTS table" {
	skip "not currently working"

	run pkgdbsql "SELECT DISTINCT LOCAL_CONFLICTS_PKGNAME FROM LOCAL_CONFLICTS;"
	[ ${status} -eq 0 ]
	compare_output "pkgin-conflicts.local"
}
@test "${SUITE} verify REMOTE_CONFLICTS table" {
	run pkgdbsql "SELECT DISTINCT REMOTE_CONFLICTS_PKGNAME FROM REMOTE_CONFLICTS;"
	[ ${status} -eq 0 ]
	compare_output "pkgin-conflicts.remote"
}

@test "${SUITE} verify pkg_info" {
	compare_pkg_info "pkg_info.final"
}
