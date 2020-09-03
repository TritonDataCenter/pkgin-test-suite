#!/usr/bin/env bats
#
# Test PROVIDES/REQUIRES.
#

SUITE="provreq"

load common

setup_file()
{
	BUILD_DATE="1970-01-01 01:01:01 +0000"

	create_pkg_buildinfo "preserve-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=provreq" \
	    "PKGPATH=provreq/preserve"
	create_pkg_comment "preserve-1.0" "Package should remain at all times"
	create_pkg_file "preserve-1.0" "share/doc/preserve"
	create_pkg_preserve "preserve-1.0"
	create_pkg "preserve-1.0"

	create_pkg_buildinfo "provides-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=provreq" \
	    "PKGPATH=provreq/provides" \
	    "PROVIDES=${LOCALBASE}/lib/libprovides.so"
	create_pkg_comment "provides-1.0" "Package provides libprovides.so"
	create_pkg_file "provides-1.0" "lib/libprovides.so"
	create_pkg "provides-1.0"

	create_pkg_buildinfo "requires-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=provreq" \
	    "PKGPATH=provreq/requires" \
	    "REQUIRES=${LOCALBASE}/lib/libprovides.so"
	create_pkg_comment "requires-1.0" "Package requires libprovides.so"
	create_pkg_file "requires-1.0" "share/doc/requires"
	create_pkg "requires-1.0"

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

@test "${SUITE} attempt to install missing REQUIRES package" {
	run pkgin -y install requires
	[ ${status} -eq 0 ]
	output_match "libprovides.so, needed by requires-1.0 is not present"

	run pkg_info -qe requires
	[ ${status} -eq 1 ]
}

@test "${SUITE} install PROVIDES package" {
	run pkgin -y install provides
	[ ${status} -eq 0 ]
}

@test "${SUITE} install REQUIRES package" {
	run pkgin -y install requires
	[ ${status} -eq 0 ]
}

@test "${SUITE} verify show-* commands" {
	for cmd in provides prov; do
		run pkgin ${cmd} provides
		[ ${status} -eq 0 ]
		line_match 1 "libprovides.so"
	done
	for cmd in requires req; do
		run pkgin ${cmd} requires
		[ ${status} -eq 0 ]
		line_match 1 "libprovides.so"
	done
}

#
# Verify the database entries have been loaded, this is useful when developing
# the pkgin parser to ensure they are correctly registered.
#
@test "${SUITE} verify LOCAL_PROVIDES table" {
	run pkgdbsql "SELECT DISTINCT LOCAL_PROVIDES_PKGNAME FROM LOCAL_PROVIDES;"
	[ ${status} -eq 0 ]
	line_match 0 "libprovides.so"
}
@test "${SUITE} verify REMOTE_PROVIDES table" {
	run pkgdbsql "SELECT DISTINCT REMOTE_PROVIDES_PKGNAME FROM REMOTE_PROVIDES;"
	[ ${status} -eq 0 ]
	line_match 0 "libprovides.so"
}

@test "${SUITE} verify LOCAL_REQUIRES table" {
	run pkgdbsql "SELECT DISTINCT LOCAL_REQUIRES_PKGNAME FROM LOCAL_REQUIRES;"
	[ ${status} -eq 0 ]
	line_match 0 "libprovides.so"
}
@test "${SUITE} verify REMOTE_REQUIRES table" {
	run pkgdbsql "SELECT DISTINCT REMOTE_REQUIRES_PKGNAME FROM REMOTE_REQUIRES;"
	[ ${status} -eq 0 ]
	line_match 0 "libprovides.so"
}

@test "${SUITE} verify pkg_info" {
	compare_pkg_info "pkg_info.final"
}
