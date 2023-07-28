#!/usr/bin/env bats
#
# Switch PKG_REPOS between updates.  Verifies database changes where obsolete
# entries are deleted.
#

SUITE="switch-repo"

load common

setup_file()
{
	#
	# The first repository contains at least two entries for each table
	# we are interested in.
	#
	PACKAGES="${SUITE_WORKDIR}/repo1"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg1"

	create_pkg_buildinfo "libobsolete-1.0" \
	    "PROVIDES=libobsolete.so" \
	    "REQUIRES=/" \
	    "PKGPATH=cat/libobsolete"
	create_pkg_comment "libobsolete-1.0" "Obsolete library"
	create_pkg "libobsolete-1.0" -C "libnew-[0-9]*"

	create_pkg_buildinfo "libfoo-1.0" \
	    "PROVIDES=libfoo.so" \
	    "REQUIRES=/" \
	    "SUPERSEDES=libobsolete-[0-9]*" \
	    "PKGPATH=cat/libfoo"
	create_pkg_comment "libfoo-1.0" "New library foo"
	create_pkg "libfoo-1.0" -C "libobsolete-[0-9]*"

	create_pkg_buildinfo "libbar-1.0" \
	    "PROVIDES=libbar.so" \
	    "REQUIRES=/" \
	    "SUPERSEDES=libobsolete-[0-9]*" \
	    "PKGPATH=cat/libbar"
	create_pkg_comment "libbar-1.0" "New library bar"
	create_pkg "libbar-1.0" -C "libobsolete-[0-9]*"

	create_pkg_buildinfo "app-1.0" \
	    "PKGPATH=cat/app"
	create_pkg_comment "app-1.0" "An application"
	create_pkg "app-1.0" -P "libfoo-[0-9]* libbar-[0-9]*"

	create_pkg_summary

	#
	# The second repository contains fewer entries for each table.
	#
	PACKAGES="${SUITE_WORKDIR}/repo2"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg2"

	create_pkg_buildinfo "libnew-2.0" \
	    "PROVIDES=libnew2.so" \
	    "REQUIRES=/" \
	    "SUPERSEDES=libobsolete-[0-9]*" \
	    "PKGPATH=cat/libnew"
	create_pkg_comment "libnew-2.0" "New library"
	create_pkg "libnew-2.0" -C "libobsolete-[0-9]*"

	create_pkg_buildinfo "app-2.0" \
	    "PKGPATH=cat/app"
	create_pkg_comment "app-2.0" "An application"
	create_pkg "app-2.0" -P "libnew-[0-9]*"

	create_pkg_summary

}

@test "${SUITE} configure first repository" {
	export PKG_PATH=${SUITE_WORKDIR}/repo1/All
	export PKG_REPOS=file://${PKG_PATH}

	run pkg_add app
	[ ${status} -eq 0 ]

	run pkgin -fy update
	[ ${status} -eq 0 ]
}

@test "${SUITE} verify first repository database" {
	skip_if_version -le 000904 "unsupported"

	if [ ${PKGIN_VERSION} -le 221000 ]; then
		ldeps="local_deps"
		rdeps="remote_deps"
	else
		ldeps="local_depends"
		rdeps="remote_depends"
	fi

	run pkgdbsql "SELECT COUNT(*) FROM local_conflicts;"
	[ ${status} -eq 0 ]
	output_match "2"

	run pkgdbsql "SELECT COUNT(*) FROM remote_conflicts;"
	[ ${status} -eq 0 ]
	output_match "3"

	run pkgdbsql "SELECT COUNT(*) FROM ${ldeps};"
	[ ${status} -eq 0 ]
	output_match "2"

	run pkgdbsql "SELECT COUNT(*) FROM ${rdeps};"
	[ ${status} -eq 0 ]
	output_match "2"

	run pkgdbsql "SELECT COUNT(*) FROM local_provides;"
	[ ${status} -eq 0 ]
	output_match "2"

	run pkgdbsql "SELECT COUNT(*) FROM remote_provides;"
	[ ${status} -eq 0 ]
	output_match "3"

	run pkgdbsql "SELECT COUNT(*) FROM local_requires;"
	[ ${status} -eq 0 ]
	output_match "2"

	run pkgdbsql "SELECT COUNT(*) FROM remote_requires;"
	[ ${status} -eq 0 ]
	output_match "3"

	if [ ${PKGIN_VERSION} -gt 221000 ]; then
		run pkgdbsql "SELECT COUNT(*) FROM remote_supersedes;"
		[ ${status} -eq 0 ]
		output_match "2"
	fi
}

@test "${SUITE} switch to second repository" {
	export PKG_PATH=${SUITE_WORKDIR}/repo2/All
	export PKG_REPOS=file://${PKG_PATH}

	run pkgin -fy update
	[ ${status} -eq 0 ]

	#
	# Older versions cannot handle the upgrade.
	#
	if [ ${PKGIN_VERSION} -lt 001103 ]; then
		run pkg_add -U app
		[ ${status} -eq 0 ]

		run pkg_delete libfoo libbar
		[ ${status} -eq 0 ]

		run pkgin -fy update
		[ ${status} -eq 0 ]
	else
		run pkgin -y upgrade
		[ ${status} -eq 0 ]
		output_match_clean_pkg_install

		run pkgin -y autoremove
		[ ${status} -eq 0 ]
		output_match_clean_pkg_install
	fi

	#
	# Various versions up to and including 21.12.0 have SQL errors with bad
	# format strings, just ignore all older versions even though there are
	# a few that are ok.
	#
	if [ ${PKGIN_VERSION} -gt 211200 ]; then
		run [ ! -s ${PKGIN_SQL_LOG} ]
		[ ${status} -eq 0 ]
	fi
}

@test "${SUITE} verify second repository database" {
	skip_if_version -le 001001 "unsupported or incorrect results"

	if [ ${PKGIN_VERSION} -le 221000 ]; then
		ldeps="local_deps"
		rdeps="remote_deps"
	else
		ldeps="local_depends"
		rdeps="remote_depends"
	fi

	run pkgdbsql "SELECT COUNT(*) FROM local_conflicts;"
	[ ${status} -eq 0 ]
	output_match "1"

	run pkgdbsql "SELECT COUNT(*) FROM remote_conflicts;"
	[ ${status} -eq 0 ]
	output_match "1"

	run pkgdbsql "SELECT COUNT(*) FROM ${ldeps};"
	[ ${status} -eq 0 ]
	output_match "1"

	run pkgdbsql "SELECT COUNT(*) FROM ${rdeps};"
	[ ${status} -eq 0 ]
	output_match "1"

	run pkgdbsql "SELECT COUNT(*) FROM local_provides;"
	[ ${status} -eq 0 ]
	output_match "1"

	run pkgdbsql "SELECT COUNT(*) FROM remote_provides;"
	[ ${status} -eq 0 ]
	output_match "1"

	if [ ${PKGIN_VERSION} -gt 221000 ]; then
		run pkgdbsql "SELECT COUNT(*) FROM remote_supersedes;"
		[ ${status} -eq 0 ]
		output_match "1"
	fi
}
