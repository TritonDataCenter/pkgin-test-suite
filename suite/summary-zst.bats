#!/usr/bin/env bats
#
# Test that pkgin supports zstd-compressed pkg_summary files (.zst).
#

SUITE="summary-zst"
SUITE_MIN_VERSION="260200"

load common

export PKG_REPOS="file://${PACKAGES}/All"

setup_file()
{
	BUILD_DATE="${BUILD_DATE_1}"

	create_pkg_buildinfo "preserve-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/preserve"
	create_pkg_comment "preserve-1.0" "Package should remain at all times"
	create_pkg_file "preserve-1.0" "share/doc/preserve"
	create_pkg_preserve "preserve-1.0"
	create_pkg "preserve-1.0"

	create_pkg_buildinfo "basic-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat1" \
	    "PKGPATH=cat1/basic"
	create_pkg_comment "basic-1.0" "Basic test package"
	create_pkg_file "basic-1.0" "share/doc/basic"
	create_pkg "basic-1.0"

	create_pkg_summary_zst

	#
	# Verify only the .zst summary is available, ensuring pkgin is not
	# falling back to a different format.
	#
	[ ! -f ${PACKAGES}/All/pkg_summary.gz ]
	[ ! -f ${PACKAGES}/All/pkg_summary.bz2 ]
	[ -f ${PACKAGES}/All/pkg_summary.zst ]
}

@test "${SUITE} perform initial pkgin setup" {
	export PKG_PATH=${PACKAGES}/All
	run pkg_add preserve
	[ ${status} -eq 0 ]

	run pkgin -fy update
	[ ${status} -eq 0 ]
}

@test "${SUITE} verify pkgin update fetched pkg_summary.zst" {
	run pkgin -fy update
	[ ${status} -eq 0 ]
	output_match "processing remote summary"
}

@test "${SUITE} verify pkgin avail" {
	run pkgin avail
	[ ${status} -eq 0 ]
	output_match "basic-1.0"
	output_match "preserve-1.0"
}

@test "${SUITE} install package from zstd summary" {
	run pkgin -y install basic
	[ ${status} -eq 0 ]
	output_match "installing basic-1.0"
	output_match_clean_pkg_install
}

@test "${SUITE} compare pkg_info" {
	compare_pkg_info "pkg_info.final"
}
