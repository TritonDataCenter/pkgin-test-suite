#!/usr/bin/env bats
#
# Test pkgin self-upgrade with dependency chain changes.
#
# This tests that when pkgin upgrades itself, it correctly computes all
# dependencies, including new packages brought in by changed dependency trees.
#

SUITE="pkgin-upgrade"

load common

setup_file()
{
	#
	# Set up the first repository.
	#
	BUILD_DATE="${BUILD_DATE_1}"
	PACKAGES="${SUITE_WORKDIR}/repo1"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg1"
	REPO_DATE="${REPO_DATE_1}"

	create_pkg_buildinfo "readline-8.3nb1" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=devel" \
	    "PKGPATH=devel/readline"
	create_pkg_comment "readline-8.3nb1" "GNU library that can recall and edit previous input"
	create_pkg_file "readline-8.3nb1" "lib/libreadline.so"
	create_pkg "readline-8.3nb1"

	create_pkg_buildinfo "sqlite3-3.50.4" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=databases" \
	    "PKGPATH=databases/sqlite3"
	create_pkg_comment "sqlite3-3.50.4" "SQL Database Engine in a C Library"
	create_pkg_file "sqlite3-3.50.4" "lib/libsqlite3.so"
	create_pkg "sqlite3-3.50.4"

	create_pkg_buildinfo "pkg_install-20250417" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=pkgtools" \
	    "PKGPATH=pkgtools/pkg_install"
	create_pkg_comment "pkg_install-20250417" "Package management and administration tools for pkgsrc"
	create_pkg_file "pkg_install-20250417" "doc/pkg_add"
	create_pkg "pkg_install-20250417"

	create_pkg_buildinfo "pkgin-25.7.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=pkgtools" \
	    "PKGPATH=pkgtools/pkgin"
	create_pkg_comment "pkgin-25.7.0" "Apt / yum like tool for managing pkgsrc binary packages"
	create_pkg_file "pkgin-25.7.0" "doc/pkgin"
	create_pkg "pkgin-25.7.0" -P "pkg_install>=20250417 sqlite3>=3.50"

	create_pkg_buildinfo "python312-3.12.11" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/python312"
	create_pkg_comment "python312-3.12.11" "Interpreted, interactive, object-oriented programming language"
	create_pkg_file "python312-3.12.11" "bin/python3.12"
	create_pkg "python312-3.12.11" -P "readline-[0-9]* sqlite3>=3.50"

	create_pkg_buildinfo "llvm-19.1.7" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/llvm"
	create_pkg_comment "llvm-19.1.7" "Low Level Virtual Machine compiler infrastructure"
	create_pkg_file "llvm-19.1.7" "bin/llvm-config"
	create_pkg "llvm-19.1.7" -P "python312>=3.12"

	create_pkg_summary "${REPO_DATE}"

	#
	# Set up the second repository.  This tests pkgin self-upgrade with
	# dependency chain changes.
	#
	BUILD_DATE="${BUILD_DATE_2}"
	PACKAGES="${SUITE_WORKDIR}/repo2"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg2"
	REPO_DATE="${REPO_DATE_2}"

	create_pkg_buildinfo "readline-8.3nb1" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=devel" \
	    "PKGPATH=devel/readline"
	create_pkg_comment "readline-8.3nb1" "GNU library that can recall and edit previous input"
	create_pkg_file "readline-8.3nb1" "lib/libreadline.so"
	create_pkg "readline-8.3nb1"

	create_pkg_buildinfo "sqlite3-3.51.1" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=databases" \
	    "PKGPATH=databases/sqlite3"
	create_pkg_comment "sqlite3-3.51.1" "SQL Database Engine in a C Library"
	create_pkg_file "sqlite3-3.51.1" "lib/libsqlite3.so"
	create_pkg "sqlite3-3.51.1"

	# pkg_install refreshed with new BUILD_DATE
	create_pkg_buildinfo "pkg_install-20250417" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=pkgtools" \
	    "PKGPATH=pkgtools/pkg_install"
	create_pkg_comment "pkg_install-20250417" "Package management and administration tools for pkgsrc"
	create_pkg_file "pkg_install-20250417" "sbin/pkg_add"
	create_pkg "pkg_install-20250417"

	create_pkg_buildinfo "pkgin-25.10.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=pkgtools" \
	    "PKGPATH=pkgtools/pkgin"
	create_pkg_comment "pkgin-25.10.0" "Apt / yum like tool for managing pkgsrc binary packages"
	create_pkg_file "pkgin-25.10.0" "bin/pkgin"
	create_pkg "pkgin-25.10.0" -P "pkg_install>=20250417 sqlite3>=3.50"

	create_pkg_buildinfo "mpdecimal-4.0.1" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=math" \
	    "PKGPATH=math/mpdecimal"
	create_pkg_comment "mpdecimal-4.0.1" "C/C++ arbitrary precision decimal floating point libraries"
	create_pkg_file "mpdecimal-4.0.1" "lib/libmpdec.so"
	create_pkg "mpdecimal-4.0.1"

	create_pkg_buildinfo "python312-3.12.12" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/python312"
	create_pkg_comment "python312-3.12.12" "Interpreted, interactive, object-oriented programming language"
	create_pkg_file "python312-3.12.12" "bin/python3.12"
	create_pkg "python312-3.12.12" -P "readline-[0-9]* sqlite3>=3.50"

	create_pkg_buildinfo "python313-3.13.11" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/python313"
	create_pkg_comment "python313-3.13.11" "Interpreted, interactive, object-oriented programming language"
	create_pkg_file "python313-3.13.11" "bin/python3.13"
	create_pkg "python313-3.13.11" -P "mpdecimal>=4.0.1 readline-[0-9]*"

	# llvm refreshed with new BUILD_DATE, now depends on python313
	create_pkg_buildinfo "llvm-19.1.7" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=lang" \
	    "PKGPATH=lang/llvm"
	create_pkg_comment "llvm-19.1.7" "Low Level Virtual Machine compiler infrastructure"
	create_pkg_file "llvm-19.1.7" "bin/llvm-config"
	create_pkg "llvm-19.1.7" -P "python313>=3.13"

	create_pkg_summary "${REPO_DATE}"

	#
	# Start with the first repository, we'll switch to subsequent
	# repositories by updating the symlink.
	#
	PACKAGES="${SUITE_WORKDIR}/packages"
	ln -s repo1 ${SUITE_WORKDIR}/packages
	start_httpd
}

teardown_file()
{
	stop_httpd
}

@test "${SUITE} install initial packages" {
	export PKG_PATH=${SUITE_WORKDIR}/repo1/All
	run pkg_add pkgin pkg_install
	[ $status -eq 0 ]

	run pkgin -y update
	[ $status -eq 0 ]

	run pkgin -y install llvm
	[ $status -eq 0 ]
}

@test "${SUITE} verify initial dependency tree" {
	compare_pkg_info "pkg_info.initial"
}

@test "${SUITE} switch to updated repository" {
	run rm ${SUITE_WORKDIR}/packages
	[ ${status} -eq 0 ]

	run ln -s repo2 ${SUITE_WORKDIR}/packages
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		run pkgin -fy update
		[ ${status} -eq 0 ]
	fi
}

@test "${SUITE} test first pkgin upgrade (output only)" {
	skip_if_version -lt 260100 "Unsupported"
	run pkgin -n upgrade
	[ ${status} -eq 0 ]
	file_match "upgrade-output-only.regex"
}

@test "${SUITE} test first pkgin upgrade (for package tools)" {
	skip_if_version -lt 260100 "Unsupported"
	run pkgin -y upgrade
	[ ${status} -eq 0 ]
	file_match "upgrade-actual.regex"
}

@test "${SUITE} verify pkg_info after first upgrade" {
	skip_if_version -lt 260100 "Unsupported"
	compare_pkg_info "pkg_info.final"
}

@test "${SUITE} test second pkgin upgrade (output only)" {
	skip_if_version -lt 260100 "Unsupported"
	run pkgin -n upgrade
	[ ${status} -eq 0 ]
	file_match "upgrade-rest.regex"
}

@test "${SUITE} test second pkgin upgrade (for remaining packages)" {
	skip_if_version -lt 260100 "Unsupported"
	run pkgin -y upgrade
	[ ${status} -eq 0 ]
	file_match "upgrade-rest-actual.regex"
}

@test "${SUITE} verify pkgin list" {
	skip_if_version -lt 260100 "Unsupported"
	compare_pkgin_list "pkgin-list.final"
}
