#
# The second repository tests upgrade scenarios from a file:// repository.
#

@test "${REPO_NAME} test install of already-installed package" {
	run pkg_add keep-1.0
	[ ${status} -eq 0 ]
	output_match "already recorded as installed"
}

@test "${REPO_NAME} save builddate BUILD_DATE" {
	run pkg_info -Q BUILD_DATE builddate
	[ ${status} -eq 0 ]
	echo "${output}" >${REPO_OUTDIR}/out.buildinfo.old
}

@test "${REPO_NAME} test pkgin full-upgrade (download only)" {
	# pkgin 0.9.4 doesn't download only!
	skip094 known fail

	run pkgin -dy fug
	[ ${status} -eq 0 ]
	output_match "symlinking "
	! output_match "removing "
	! output_match "installing "
}
@test "${REPO_NAME} test pkgin full-upgrade (output only)" {
	run pkgin -n fug
	[ ${status} -eq 0 ]
}
@test "${REPO_NAME} test pkgin full-upgrade" {
	run pkgin -y fug
	[ ${status} -eq 0 ]
	#XXX output_match "1 to refresh, 3 to upgrade, 1 to remove, 0 to install"
	output_match "removing "
	output_match "installing "
	output_match "pkg_install warnings: 0, errors: 0"
	! output_match "error log can be found"
}

#
# This repository uses a file:// URL which should result in packages being
# symlinked and not copied.
#
@test "${REPO_NAME} test packages were symlinked" {
	run [ -L ${TEST_PKGIN_CACHE}/upgrade-2.0.tgz ] 
	[ ${status} -eq 0 ]
}

#
# As well as upgrading upgrade-1.0 -> upgrade-2.0, this should fail to
# upgrade pkgpath-1.0 -> pkgpath-2.0 as the PKGPATH is different.
#
@test "${REPO_NAME} verify PKGPATH change prevented upgrade" {
	run pkg_info -qE pkgpath-1.0
	[ ${status} -eq 0 ]
}

@test "${REPO_NAME} verify builddate BUILD_DATE" {
	skip requires refresh support
	run pkg_info -Q BUILD_DATE builddate
	echo "${output}" >${REPO_OUTDIR}/out.buildinfo.new
	[ "${output}" = "${REPO_BUILD_DATE}" ]
	[ ${status} -eq 0 ]
}

@test "${REPO_NAME} verify builddate BUILD_DATE actually changed" {
	skip requires refresh support
	run diff -u ${REPO_OUTDIR}/out.buildinfo.{old,new}
	[ ${status} -eq 1 ]
}

#
# Now test that explicitly installing upgrade-2.0 works.
#
@test "${REPO_NAME} test install of package where PKGPATH changed" {
	run pkgin -py install pkgpath-2.0
	[ ${status} -eq 0 ]
	#XXX output_match "1 to upgrade"
}

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
