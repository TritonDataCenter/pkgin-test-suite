#
# This repository tests download failures.
#

pkg_download="download-ok-1.0"
pkg_truncated="download-truncate-1.0"
pkg_mismatch="download-mismatch-1.0"
pkg_notfound="download-notfound-1.0"

#
# Test download scenarios.
#
@test "${REPO_NAME} verify bad pkg_summary" {
	# XXX: at some point we should do this, if first is truncated then
	# just try the next suffix.
	skip
	run pkgin update
	[ ${status} -eq 123 ]
}
@test "${REPO_NAME} ensure clean cache" {
	run pkgin clean
	[ ${status} -eq 0 ]
}
@test "${REPO_NAME} test download only" {
	run pkgin -dy install ${pkg_download}
	[ ${status} -eq 0 ]
	# XXX plural
	line_match 1 "1 packages to be downloaded"
	line_match 4 "downloading ${pkg_download}.* done"
}
@test "${REPO_NAME} test download only again" {
	run pkgin -dy install ${pkg_download}
	[ ${status} -eq 0 ]
	# XXX plural
	line_match 1 "1 packages to be downloaded .0B to download"
	! output_match "downloading ${pkg_download}"
}
@test "${REPO_NAME} test downloads of broken packages" {
	skip094 known fail

	run pkgin -y install ${pkg_notfound} ${pkg_truncated} ${pkg_mismatch}
	[ ${status} -eq 1 ]
	output_match "${pkg_truncated}.*: Not Found"
	output_match "download truncated for .*${pkg_truncated}"
	output_match "download size of .*${pkg_mismatch}.* does not match"
	! output_match "installing packages"
}
#
# Needs to be last, as after trashing it we can't get it back.
#
@test "${REPO_NAME} test pkg_summary download failure" {
	skip094 known fail

	run rm ${REPO_PACKAGES}/pkg_summary.*
	[ ${status} -eq 0 ]

	run pkgin -f update
	[ ${status} -eq 1 ]
	output_match "Could not fetch pkg_summary"
}
