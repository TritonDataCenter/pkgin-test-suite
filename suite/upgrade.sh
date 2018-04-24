#
# Test upgrade scenarios
#

#
# Not a pkgin test, but good to check anyway.
#
@test "${REPO_NAME} test install of already-installed package" {
	run pkg_add keep-1.0
	[ ${status} -eq 0 ]
	output_match "already recorded as installed"
}

#
# The builddate package installed from the previous repository should not
# match the BUILD_DATE of the current repository.  We later then test that
# it does, proving that it was correctly refreshed.
#
@test "${REPO_NAME} ensure builddate BUILD_DATE is not current" {
	run pkg_info -Q BUILD_DATE builddate
	[ ${status} -eq 0 ]
	[ -n "${output}" ]
	[ "${output}" != "${REPO_BUILD_DATE}" ]
}

#
# Test all parts of a full-upgrade, including no-op output, download only, and
# an actual install.
#
@test "${REPO_NAME} test pkgin full-upgrade (output only)" {
	run pkgin -n fug
	[ ${status} -eq 0 ]
	file_match "full-upgrade-output-only.regex"
}
@test "${REPO_NAME} test pkgin full-upgrade (download only)" {
	# pkgin 0.9.4 doesn't download only!
	skip094 known fail

	run pkgin -dy fug
	file_match "full-upgrade-download-only.regex"
}
@test "${REPO_NAME} test pkgin full-upgrade (output only after download)" {
	run pkgin -n fug
	[ ${status} -eq 0 ]
	file_match "full-upgrade-output-only-2.regex"
}
@test "${REPO_NAME} test pkgin full-upgrade" {
	run pkgin -y fug
	[ ${status} -eq 0 ]
	file_match "full-upgrade.regex"
}

#
# The pkgpath package should not be upgraded as the PKGPATH between version 1.0
# and 2.0 is different.
#
@test "${REPO_NAME} verify PKGPATH change prevented upgrade" {
	run pkg_info -qe pkgpath-1.0
	[ ${status} -eq 0 ]
}

#
# Now verify that the builddate package has been refreshed with the current
# repository BUILD_DATE
#
@test "${REPO_NAME} verify builddate BUILD_DATE" {
	run pkg_info -Q BUILD_DATE builddate
	[ ${status} -eq 0 ]
	[ -n "${output}" ]
	[ "${output}" = "${REPO_BUILD_DATE}" ]
}

#
# Now test that explicitly installing upgrade-2.0 works.
#
@test "${REPO_NAME} test install of package where PKGPATH changed" {
	run pkgin -py install pkgpath-2.0
	[ ${status} -eq 0 ]
	file_match "install-pkgpath-upgrade.regex"
}

#
# Verify final contents.
#
@test "${REPO_NAME} verify pkg_info" {
	compare_pkg_info "pkg_info.final"
}
@test "${REPO_NAME} verify pkgin list" {
	compare_pkgin_list "pkgin-list.final"
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
