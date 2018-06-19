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
# The keep package installed from the previous repository should not
# match the BUILD_DATE of the current repository, and the version should not
# change during the following upgrades, making it a good candidate to ensure
# that refresh works.
#
# We also need to verify that it is currently in the cache directory, to test
# that we can detect the download needs to be performed even if the sizes
# happen to match.
#
@test "${REPO_NAME} ensure BUILD_DATE is not current" {
	skip_if_version -lt 001000 "Does not support BUILD_DATE"
	run pkg_info -Q BUILD_DATE keep-1.0
	[ ${status} -eq 0 ]
	[ -n "${output}" ]
	[ "${output}" != "${REPO_BUILD_DATE}" ]
}
@test "${REPO_NAME} ensure BUILD_DATE package exists in the cache" {
	skip_if_version -lt 001000 "Does not support BUILD_DATE"
	run [ -f ${TEST_PKGIN_CACHE}/keep-1.0.tgz ]
	[ ${status} -eq 0 ]
}

#
# Test all parts of a full-upgrade, including no-op output, download only, and
# an actual install.  Sprinkle some -f to ensure forced updates are correct.
#
# pkgin 0.9.x. requires an explicit update for repository refresh.
#
@test "${REPO_NAME} perform pkgin update" {
	skip_if_version -ge 001000 "Not required for 0.10+"
	run pkgin -fy update
	[ ${status} -eq 0 ]
}
@test "${REPO_NAME} test pkgin full-upgrade (output only)" {
	run pkgin -n fug
	[ ${status} -eq 0 ]
	file_match -I "full-upgrade-output-only.regex"
}
@test "${REPO_NAME} test pkgin full-upgrade (download only)" {
	# pkgin 0.9.4 doesn't download only!
	skip_if_version -lt 001000 "known fail"

	# The output order here is non-deterministic.
	run pkgin -dfy fug
	file_match -I "full-upgrade-download-only.regex"
}

@test "${REPO_NAME} test pkgin full-upgrade (output only after download)" {
	run pkgin -fn fug
	[ ${status} -eq 0 ]
	file_match -I "full-upgrade-output-only-2.regex"
}
@test "${REPO_NAME} test pkgin full-upgrade" {
	run pkgin -y fug
	[ ${status} -eq 0 ]
	file_match "full-upgrade.regex"
}

#
# Now verify that the keep package has been refreshed with the current
# repository BUILD_DATE
#
@test "${REPO_NAME} verify BUILD_DATE refresh" {
	skip_if_version -lt 001000 "Does not support BUILD_DATE"
	run pkg_info -Q BUILD_DATE keep-1.0
	[ ${status} -eq 0 ]
	[ -n "${output}" ]
	[ "${output}" = "${REPO_BUILD_DATE}" ]
}

#
# Verify behaviour of PKGPATH with regards to upgrades:
#
#  1. An upgrade should not consider a newer version if PKGPATH does not match.
#  2. A "pkgin import" using the original PKGPATH should not either.
#  3. An explicit "pkgin install" of a different PKGPATH should upgrade.
#
# Versions of pkgin prior to 0.11.2 do not handle #2 correctly, they only
# match on PKGNAME not FULLPKGNAME and end up performing an upgrade, so that
# test is skipped.
#
@test "${REPO_NAME} verify PKGPATH change prevented upgrade" {
	run pkg_info -qe pkgpath-1.0
	[ ${status} -eq 0 ]
}
@test "${REPO_NAME} test pkgin import does not upgrade PKGPATH" {
	skip_if_version -lt 001102

	echo "testsuite/pkgpath1" >${REPO_OUTDIR}/import-pkgpath1
	run pkgin -y import ${REPO_OUTDIR}/import-pkgpath1
	[ ${status} -eq 0 ]

	run pkg_info -qe pkgpath-1.0
	[ ${status} -eq 0 ]
}
@test "${REPO_NAME} test install of package where PKGPATH changed" {
	run pkgin -y install pkgpath-2.0
	[ ${status} -eq 0 ]
	file_match "install-pkgpath-upgrade.regex"
}
#
# Just for completeness sake do a full downgrade and upgrade using
# "pkgin import", ending up back where we started for verification.
#
@test "${REPO_NAME} test installing PKGPATH changes via import" {
	skip_if_version -lt 001102

	echo "testsuite/pkgpath1" >${REPO_OUTDIR}/import-pkgpath1
	run pkgin -y import ${REPO_OUTDIR}/import-pkgpath1
	[ ${status} -eq 0 ]

	run pkg_info -qe pkgpath-1.0
	[ ${status} -eq 0 ]

	echo "testsuite/pkgpath2" >${REPO_OUTDIR}/import-pkgpath2
	run pkgin -y import ${REPO_OUTDIR}/import-pkgpath2
	[ ${status} -eq 0 ]

	run pkg_info -qe pkgpath-2.0
	[ ${status} -eq 0 ]
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
	compare_output "cat-share-doc-all.out"
}
