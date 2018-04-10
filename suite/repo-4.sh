#
# The fourth repository tests removal scenarios and downloads from directory.
#
pkg_download="download-ok-1.0"
pkg_dlrm="download-notfound-1.0"

@test "${REPO_NAME} test pkgin clean" {
	run pkgin clean
	[ ${status} -eq 0 ]
}
@test "${REPO_NAME} test pkgin autoremove (list-only)" {
	run pkgin -n autoremove
	[ ${status} -eq 0 ]
	line_match 0 "1 packages to be autoremoved:"
	line_match 1 "deptree-bottom-1.0"
}
@test "${REPO_NAME} test pkgin autoremove (for real)" {
	run pkgin_autoremove
	[ ${status} -eq 0 ]
	output_match "removing "
	output_match "pkg_install warnings: 0, errors: 0"
}
@test "${REPO_NAME} test pkgin autoremove (should be empty)" {
	run pkgin_autoremove
	[ ${status} -eq 0 ]
	[ "${output}" = "no orphan dependencies found." ]
}
@test "${REPO_NAME} test pkgin download from directory" {
	skip094 known fail

	run rm ${REPO_PACKAGES}/${pkg_dlrm}.tgz
	[ ${status} -eq 0 ]

	run pkgin -dy install ${pkg_download} ${pkg_dlrm}
	[ ${status} -eq 1 ]
	output_match "${pkg_dlrm} is not available"
	output_match "symlinking .*${pkg_download}"

	run [ -L ${TEST_PKGIN_CACHE}/${pkg_dlrm}.tgz ]
	[ ${status} -eq 1 ]

	run [ -L ${TEST_PKGIN_CACHE}/${pkg_download}.tgz ]
	[ ${status} -eq 0 ]
}

@test "${REPO_NAME} remove and verify upgrade package" {
	run pkgin -y remove upgrade
	[ ${status} -eq 0 ]
	output_match "removing.upgrade"
	output_match "pkg_install warnings: 0, errors: 0"
}

@test "${REPO_NAME} verify pkg_info" {
	compare_pkg_info "pkg_info.final"
}

@test "${REPO_NAME} verify pkgin list" {
	compare_pkgin_list "pkgin-list.final"
}
