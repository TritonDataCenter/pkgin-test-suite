#!/usr/bin/env bats
#
# This repository tests invalid or exaggerated pkg_summary values.
#

SUITE="invalid"

load common

setup_file()
{
	BUILD_DATE="1970-01-01 01:01:01 +0000"

	# Initial package to satisfy pkgin-0.9.4
	create_pkg_buildinfo "preserve-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=invalid" \
	    "PKGPATH=invalid/preserve"
	create_pkg_comment "preserve-1.0" "Package should remain at all times"
	create_pkg_file "preserve-1.0" "share/doc/preserve"
	create_pkg_preserve "preserve-1.0"
	create_pkg "preserve-1.0"

	create_pkg_buildinfo "badfilesize-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=invalid" \
	    "PKGPATH=invalid/badfilesize"
	create_pkg_comment "badfilesize-1.0" "Package FILE_SIZE is too big"
	create_pkg_file "badfilesize-1.0" "share/doc/badfilesize"
	create_pkg_filter "badfilesize-1.0" \
	    "/^FILE_SIZE/s/=.*/=987654321987654321/"
	create_pkg "badfilesize-1.0"

	create_pkg_buildinfo "nofilesize-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=invalid" \
	    "PKGPATH=invalid/nofilesize"
	create_pkg_comment "nofilesize-1.0" "Package has no FILE_SIZE"
	create_pkg_file "nofilesize-1.0" "share/doc/nofilesize"
	create_pkg_filter "nofilesize-1.0" \
	    "/^FILE_SIZE/d"
	create_pkg "nofilesize-1.0"

	create_pkg_buildinfo "badsizepkg-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=invalid" \
	    "PKGPATH=invalid/badsizepkg"
	create_pkg_comment "badsizepkg-1.0" "Package SIZE_PKG is too big"
	create_pkg_file "badsizepkg-1.0" "share/doc/badsizepkg"
	create_pkg_size "badsizepkg-1.0" 123456789123456789
	create_pkg "badsizepkg-1.0"

	# BUILD_DATE is a required pkg_summary field, deliberately omit it.
	create_pkg_buildinfo "badsum-1.0" \
	    "CATEGORIES=invalid" \
	    "PKGPATH=invalid/badsum"
	create_pkg_comment "badsum-1.0" "Package pkg_summary is invalid"
	create_pkg_file "badsum-1.0" "share/doc/badsum"
	create_pkg "badsum-1.0"

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
	# Explicit install for pkgin-0.9.x support
	export PKG_PATH=${PACKAGES}/All
	run pkg_add preserve
	[ ${status} -eq 0 ]

	run pkgin -fy update
	[ ${status} -eq 0 ]
}

@test "${SUITE} test massive FILE_SIZE" {
	run pkgin -y install badfilesize
	[ ${status} -eq 1 ]
	output_match "does not have enough space for download"
}

@test "${SUITE} test no FILE_SIZE" {
	skip_if_version -lt 211200 "known crash"
	run pkgin -y install nofilesize
	[ ${status} -eq 1 ]
	output_match "nofilesize is not available in the repository"
}

@test "${SUITE} test massive SIZE_PKG" {
	run pkgin -y install badsizepkg
	[ ${status} -eq 1 ]
	output_match "does not have enough space for installation"
}

#
# This package should install correctly, the missing/invalid entries are
# designed to trigger e.g. bad strcpy/strdup of NULL values.
#
@test "${SUITE} test package with missing or invalid pkg_summary entries" {
        if [ ${PKGIN_VERSION} -eq 001000 -o ${PKGIN_VERSION} -eq 001001 ]; then
		skip "known crash"
	fi
	run pkgin -y install badsum
	[ ${status} -eq 0 ]
}

@test "${SUITE} test pkgin stats with large values" {
	skip_if_version -lt 000700 "does not support stats"
	run pkgin stats
	[ ${status} -eq 0 ]
	output_match "Total size of packages: 877P"
}
