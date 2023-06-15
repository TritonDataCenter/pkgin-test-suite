#!/usr/bin/env bats
#
# Test file:// downloads.
#
# Note that as we're using the actual packages in the repository rather than
# copies kept in the pkgin cache directory, any tests that modify the files
# are destructive.
#

SUITE="file-dl"

load common

export PKG_REPOS="file://${PACKAGES}/All"

setup_file()
{
	BUILD_DATE="1970-01-01 01:01:01 +0000"

	#
	# XXX: pkgin does not (yet) print "marking <pkg> as non auto-removable"
	# messages when installing the first package to an empty pkgdb for some
	# reason, so just create a dummy package to act as the first one in
	# order to avoid changing the output matches.
	#
	create_pkg_buildinfo "preserve-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=download" \
	    "PKGPATH=download/preserve"
	create_pkg_comment "preserve-1.0" "Package should remain at all times"
	create_pkg_file "preserve-1.0" "share/doc/preserve"
	create_pkg_preserve "preserve-1.0"
	create_pkg "preserve-1.0"

	#
	# The packages on differ by COMMENT.  Later on we modify them based on
	# the filename.
	#
	for pkg in ok notfound mismatch; do
		create_pkg_buildinfo "download-${pkg}-1.0" \
		    "BUILD_DATE=${BUILD_DATE}" \
		    "CATEGORIES=download" \
		    "PKGPATH=download/download-${pkg}"
		case "${pkg}" in
		ok)       c="Package tests download success" ;;
		notfound) c="Package tests download failure (404)" ;;
		mismatch) c="Package tests download failure (corrupt)" ;;
		esac
		create_pkg_comment "download-${pkg}-1.0" "${c}"
		create_pkg_file "download-${pkg}-1.0" \
		    "share/doc/download-${pkg}"
		create_pkg "download-${pkg}-1.0"
	done

	create_pkg_summary

	rm -rf ${LOCALBASE} ${VARBASE}
	mkdir -p ${PKGIN_DBDIR}
}

#
# Ensure we start with a clean work area, and install the initial package to
# work around issues with older pkgin which cannot install packages to an
# empty pkgdb.
#
@test "${SUITE} perform initial pkgin setup" {
	#
	# Use pkg_add to aid pkgin-0.9 and also to keep the cache directory
	# empty.
	#
	export PKG_PATH=${PACKAGES}/All
	run pkg_add preserve
	[ ${status} -eq 0 ]

	run pkgin -fy update
	[ ${status} -eq 0 ]

	run rmdir ${PKGIN_CACHE}
	[ ${status} -eq 0 ]
}

#
# Test a file download, which is just a symlink.  Do not install.
#
@test "${SUITE} test download-only" {
	run pkgin -dy install download-ok
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -lt 001101 -o ${PKGIN_VERSION} -eq 001600 ]; then
		output_match "1 package.* to .* download"
		output_match "download-ok-1.0"
	else
		file_match "download-only.regex"
	fi

	run [ -L ${PKGIN_CACHE}/download-ok-1.0.tgz ]
	[ ${status} -eq 0 ]

	run pkg_info -qe download-ok
	[ ${status} -eq 1 ]
}

#
# Now install separately.
#
@test "${SUITE} test successful install" {
	run pkgin -y install download-ok
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -lt 001101 -o ${PKGIN_VERSION} -eq 001600 ]; then
		output_match "1 package.* to .* install"
		output_match "installing download-ok-1.0"
		output_match "marking download-ok-1.0 as non auto-removable"
	else
		file_match "install-downloaded.regex"
	fi

	run pkg_info -qe download-ok
	[ ${status} -eq 0 ]
}

#
# Test pkgin clean, should result in an empty directory that can successfully
# be rmdir'd.
#
@test "${SUITE} test pkgin clean" {
	run pkgin clean
	[ ${status} -eq 0 ]

	run rmdir ${PKGIN_CACHE}
	[ ${status} -eq 0 ]

	run [ ! -d ${PKGIN_CACHE} ]
	[ ${status} -eq 0 ]
}

#
# Now install to test both the install and also the download counters.
#
@test "${SUITE} test download and install" {
	run pkg_delete download-ok
	[ ${status} -eq 0 ]

	run pkgin -y install download-ok
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -lt 001101 -o ${PKGIN_VERSION} -eq 001600 ]; then
		output_match "1 package.* to .* install"
		output_match "installing download-ok-1.0"
		output_match "marking download-ok-1.0 as non auto-removable"
		output_match_clean_pkg_install
	else
		file_match "download-install.regex"
	fi

	run pkg_info -qe download-ok
	[ ${status} -eq 0 ]
}

#
# Test a failed download by removing the package first.  Not supported by
# pkgin-0.9.x.
#
@test "${SUITE} test failed pkgin download (not found)" {
	skip_if_version -lt 001000 "Does not handle file not found"

	run rm ${PACKAGES}/All/download-notfound-1.0.tgz
	[ ${status} -eq 0 ]

	run pkgin -y install download-notfound
	[ ${status} -eq 1 ]

	if [ ${PKGIN_VERSION} -lt 001101 -o ${PKGIN_VERSION} -eq 001600 ]; then
		output_match "download-notfound-1.0 is not available"
		output_match "1 package.* to .* install"
		output_match "download-notfound-1.0"
	else
		file_match "download-notfound.regex"
	fi

	run [ -L ${PKGIN_CACHE}/download-notfound-1.0.tgz ]
	[ ${status} -eq 1 ]

}

#
# Test a mismatched download by truncating the file to half its size, not
# supported by pkgin-0.9.x.
#
@test "${SUITE} test failed pkgin download (mismatch)" {
	skip_if_version -lt 001000 "Does not handle mismatches"

	truncfile="${PACKAGES}/All/download-mismatch-1.0.tgz"
	len=$(wc -c < ${truncfile} | awk '{print $1}')
	run dd if=${truncfile} of=${truncfile}.tmp bs=1 count=$((len / 2))
	[ ${status} -eq 0 ]

	run mv ${truncfile}.tmp ${truncfile}
	[ ${status} -eq 0 ]

	# The install attempt should abort prior to calling pkg_add
	run pkgin -y install download-mismatch
	[ ${status} -eq 1 ]

	if [ ${PKGIN_VERSION} -lt 001101 -o ${PKGIN_VERSION} -eq 001600 ]; then
		output_match "download error: .* does not match pkg_summary"
		output_match "1 package.* to .* install"
		output_match "download-mismatch-1.0"
	else
		file_match "download-mismatch.regex"
	fi

	run [ -L ${PKGIN_CACHE}/download-mismatch-1.0.tgz ]
	[ ${status} -eq 1 ]
}

@test "${SUITE} compare pkg_info" {
	compare_pkg_info "pkg_info.final"
}
