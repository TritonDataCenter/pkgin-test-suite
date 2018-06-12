#
# This repository tests invalid or exaggerated pkg_summary values.
#

pkg_filesize="badfilesize-1.0"
pkg_sizepkg="badsizepkg-1.0"
pkg_badsum="badsum-1.0"

#
# Explicit update for 0.9.x. repository refresh
#
@test "${REPO_NAME} perform pkgin update" {
	skip_if_version -ge 001000 "Not required for 0.10+"
	run pkgin -fy update
	[ ${status} -eq 0 ]
}

@test "${REPO_NAME} test massive FILE_SIZE" {
	run pkgin -y install ${pkg_filesize}
	[ ${status} -eq 1 ]
	output_match "does not have enough space for download"
}
@test "${REPO_NAME} test massive SIZE_PKG" {
	run pkgin -y install ${pkg_sizepkg}
	[ ${status} -eq 1 ]
	output_match "does not have enough space for installation"
}

#
# This package should install correctly, the missing/invalid entries are
# designed to trigger e.g. bad strcpy/strdup of NULL values.
#
@test "${REPO_NAME} test package with missing or invalid pkg_summary entries" {
	run pkgin -y install ${pkg_badsum}
	[ ${status} -eq 0 ]
}

@test "${REPO_NAME} test pkgin stats with large values" {
	run pkgin stats
	[ ${status} -eq 0 ]
	output_match "Total size of packages: 877P"
}
