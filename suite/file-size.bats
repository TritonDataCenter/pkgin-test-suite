#!/usr/bin/env bats
#
# Test FILE_SIZE, SIZE_PKG, etc.  Other test suites ignore these values as it
# can be too much work to update them every time a minor change is made to the
# test.  This one ensures they are accurate.
#
# In particular, "-F none" is specified to ensure compression is not used which
# will almost certainly change across different systems.
#

SUITE="file-size"

load common

setup_file()
{
	BUILD_DATE="${BUILD_DATE_1}"
	PACKAGES="${SUITE_WORKDIR}/repo1"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg1"

	create_pkg_buildinfo "file-size-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat" \
	    "PKGPATH=cat/file-size"
	create_pkg_comment "file-size-1.0" "Package has a static FILE_SIZE"
	create_pkg_file "file-size-1.0" "share/doc/file-size" \
	    "Some text to start with."
	create_pkg "file-size-1.0" -F none

	create_pkg_summary "${REPO_DATE_1}"

	BUILD_DATE="${BUILD_DATE_2}"
	PACKAGES="${SUITE_WORKDIR}/repo2"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg2"

	create_pkg_buildinfo "file-size-2.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat" \
	    "PKGPATH=cat/file-size"
	create_pkg_comment "file-size-2.0" "Package has a static FILE_SIZE"
	create_pkg_file "file-size-2.0" "share/doc/file-size" \
	    "Some more text, more than previously."
	create_pkg "file-size-2.0" -F none

	create_pkg_summary "${REPO_DATE_2}"

	BUILD_DATE="${BUILD_DATE_3}"
	PACKAGES="${SUITE_WORKDIR}/repo3"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg3"

	create_pkg_buildinfo "file-size-3.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=cat" \
	    "PKGPATH=cat/file-size"
	create_pkg_comment "file-size-3.0" "Package has a static FILE_SIZE"
	create_pkg_file "file-size-3.0" "share/doc/file-size" "Less text."
	create_pkg "file-size-3.0" -F none

	create_pkg_summary "${REPO_DATE_3}"

	PACKAGES="${SUITE_WORKDIR}/packages"
	ln -s repo1 ${SUITE_WORKDIR}/packages
	start_httpd
}
teardown_file()
{
	stop_httpd
}

@test "${SUITE} install first package using pkg_add" {
	export PKG_PATH=${PACKAGES}/All
	run pkg_add file-size
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}

@test "${SUITE} test first upgrade (increase)" {
	run rm ${SUITE_WORKDIR}/packages
	[ ${status} -eq 0 ]

        run ln -s repo2 ${SUITE_WORKDIR}/packages
        [ ${status} -eq 0 ]

        if [ ${PKGIN_VERSION} -lt 001000 ]; then
                run pkgin -fy update
                [ ${status} -eq 0 ]
        fi

	run pkgin -y upgrade
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -le 221000 ]; then
		output_match "13K to download, 13B to install"
	else
		output_match "13K to download, 13B of additional"
	fi
}

@test "${SUITE} test second upgrade (decrease)" {
	run rm ${SUITE_WORKDIR}/packages
	[ ${status} -eq 0 ]

	run ln -s repo3 ${SUITE_WORKDIR}/packages
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		run pkgin -fy update
		[ ${status} -eq 0 ]
	fi

	run pkgin -y upgrade
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -le 221000 ]; then
		output_match "13K to download, -27B to install"
	else
		output_match "13K to download, 27B of disk space will be freed"
	fi
}
