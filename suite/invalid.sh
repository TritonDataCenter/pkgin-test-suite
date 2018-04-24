#
# This repository tests download failures.
#

pkg_filesize="badfilesize-1.0"
pkg_sizepkg="badsizepkg-1.0"

@test "${REPO_NAME} 1" {
	skip
	run pkgin -y install ${pkg_filesize}
	[ ${status} -eq 123 ]
}
@test "${REPO_NAME} 2" {
	skip
	run pkgin -y install ${pkg_sizepkg}
	[ ${status} -eq 123 ]
}
@test "${REPO_NAME} 3" {
	skip
	run pkgin stats
	[ ${status} -eq 123 ]
}
