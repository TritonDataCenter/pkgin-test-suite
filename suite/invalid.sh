#
# This repository tests invalid or exaggerated pkg_summary values.
#

pkg_filesize="badfilesize-1.0"
pkg_sizepkg="badsizepkg-1.0"

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
@test "${REPO_NAME} test pkgin stats with large values" {
	run pkgin stats
	[ ${status} -eq 0 ]
	output_match "Total size of packages: 877P"
}
