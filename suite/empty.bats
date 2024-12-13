#!/usr/bin/env bats
#
# This initial test suite operates against an empty repository.
#
# While this might not appear useful, it does allow us to verify some issues,
# such as being able to initialise the pkgin database, ensure that the compat
# checks work, and verify output is as expected when there are no results.
#

SUITE="empty"

load common

setup_file() {
	mkdir -p ${PACKAGES}/All
	echo "" | gzip -9 >${PACKAGES}/All/pkg_summary.gz
	start_httpd
}

teardown_file() {
	stop_httpd
}

# pkgin 0.8.0 and earlier need "-y" to get past "Database needs to be updated"
# prompts which happen every time with an empty database.
if [ ${PKGIN_VERSION} -lt 000900 ]; then
	yflag="-y"
else
	yflag=
fi

#
# pkgin will not recursively create directories as required, and as we're
# starting with a completely empty target there is no /var/db, so we need to
# help it out.  In other test suites we often use pkg_add to install the first
# package and that will create /var/db/pkgdb, so this is not necessary.
#
@test "${SUITE} create required directories" {
	run mkdir -p $(dirname ${PKGIN_DBDIR})
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}

#
# Perform the initial update and database creation.  The initial pkgin update
# should log SQL errors as the database will not exist, so also verify that the
# SQL log has been created and is not empty.
#
# The remote repository directory will change depending on where these
# tests are being ran, and pkg_summary compression may change, so use
# simple output matches rather than a static file here.
#
# We also need to handle 0.9.4 and earlier differently as they do not
# initialise an empty database correctly, so we only get downloading messages
# for this as well as subsequent updates.
#
@test "${SUITE} test initial pkgin update" {
	run pkgin ${yflag} update
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} -lt 000700 ]; then
		output_match "downloading pkg_summary"
		output_match "updating database"
	elif [ ${PKGIN_VERSION} -lt 001000 ]; then
		output_match "download started."
		output_match "download ended."
	else
		line_match 0 "processing remote summary"
		line_match 1 "downloading pkg_summary"
	fi
}
@test "${SUITE} verify sql logfile creation and error logging" {
	run [ -s ${PKGIN_SQL_LOG} ]
}

#
# Verify that a subsequent update run does not re-do any database creation or
# pkg_summary processing.  The SQL log should be empty.  We also test the "up"
# alias while here.
#
@test "${SUITE} test subsequent pkgin update" {
	run pkgin ${yflag} update
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} -lt 000700 ]; then
		output_match "downloading pkg_summary"
		output_match "updating database"
	elif [ ${PKGIN_VERSION} -lt 001000 ]; then
		output_match "download started."
		output_match "download ended."
	else
		line_match 0 "processing remote summary"
		line_match 1 "database.*is.up-to-date"
	fi
}
@test "${SUITE} verify sql logfile is empty" {
	run [ ! -s ${PKGIN_SQL_LOG} ]
}

#
# Test various commands against an empty installation, this ensures they handle
# empty results correctly.  For each command also test its alias.
#
@test "${SUITE} test pkgin list" {
	for cmd in list ls; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} -lt 000700 ]; then
			output_match "Requested list is empty."
		else
			line_match 0 "Requested list is empty."
		fi
	done
}
@test "${SUITE} test pkgin avail" {
	for cmd in avail av; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} -lt 000700 ]; then
			output_match "Requested list is empty."
		else
			line_match 0 "Requested list is empty."
		fi
	done
}
@test "${SUITE} test pkgin search (no arguments)" {
	for cmd in search se; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 1 ]
		if [ ${PKGIN_VERSION} -lt 000700 ]; then
			output_match "missing search string"
		else
			line_match 0 "pkgin.*: missing search string"
		fi
	done
}
@test "${SUITE} test pkgin search (missing package)" {
	for cmd in search se; do
		run pkgin ${yflag} ${cmd} pkg-does-not-exist
		# 0.9.4 and earlier are broken here
		if [ ${PKGIN_VERSION} -lt 001000 ]; then
			[ ${status} -eq 0 ]
		else
			[ ${status} -eq 1 ]
			[ "${output}" = "No results found for pkg-does-not-exist" ]
		fi
	done
}
@test "${SUITE} test pkgin upgrade" {
	for cmd in upgrade ug; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 1 ]
		output_match "empty non-autoremovable package list"
	done
}
@test "${SUITE} test pkgin full-upgrade" {
	for cmd in full-upgrade fug; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 1 ]
		output_match "empty non-autoremovable package list"
	done
}
@test "${SUITE} test pkgin install" {
	for cmd in install in; do
		run pkgin ${yflag} ${cmd} pkg-does-not-exist
		[ ${status} -eq 1 ]
		if [ ${PKGIN_VERSION} -lt 001000 ]; then
			output_match "empty available packages list"
		elif [ ${PKGIN_VERSION} -le 200501 ]; then
			line_match 0 "empty available packages list"
			line_match 1 "nothing to do."
		else
			[ "${output}" = "empty available packages list" ]
		fi
	done
}
@test "${SUITE} test pkgin remove" {
	for cmd in remove rm; do
		run pkgin ${yflag} ${cmd} pkg-does-not-exist
		[ ${status} -eq 1 ]
		# Apparently errx() on Linux ignores setprogname()
		output_match "empty local package list"
	done
}
@test "${SUITE} test pkgin autoremove" {
	for cmd in autoremove ar; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 1 ]
		# installed with pkgin (0.9) | marked as keepable (0.10+)
		output_match "no packages have been installed|marked"
	done
}
@test "${SUITE} test pkgin show-keep" {
	for cmd in show-keep sk; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} -lt 001000 ]; then
			output_match "empty non-autoremovable package list"
		else
			[ "${output}" = "empty non-autoremovable package list" ]
		fi
	done
}
@test "${SUITE} test pkgin show-no-keep" {
	for cmd in show-no-keep snk; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} -lt 001000 ]; then
			output_match "empty autoremovable package list"
		else
			[ "${output}" = "empty autoremovable package list" ]
		fi
	done
}
@test "${SUITE} test pkgin export" {
	for cmd in export ex; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 1 ]
		# Apparently errx() on Linux ignores setprogname()
		output_match "empty local package list"
	done
}
@test "${SUITE} test pkgin show-category" {
	for cmd in show-category sc; do
		run pkgin ${yflag} ${cmd} category-does-not-exist
		[ ${status} -eq 0 ]
	done
}
@test "${SUITE} test pkgin show-pkg-category" {
	for cmd in show-pkg-category spc; do
		run pkgin ${yflag} ${cmd} pkg-does-not-exist
		# 0.9.4 and earlier are broken here
		if [ ${PKGIN_VERSION} -lt 001000 ]; then
			[ ${status} -eq 0 ]
		else
			[ ${status} -eq 1 ]
		fi
	done
}
@test "${SUITE} test pkgin show-all-categories" {
	for cmd in show-all-categories sac; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} -lt 001000 ]; then
			output_match "No categories found."
		else
			[ "${output}" = "No categories found." ]
		fi
	done
}
@test "${SUITE} test pkgin pkg-* commands (no arguments)" {
	for cmd in pkg-content pc pkg-descr pd pkg-build-defs pbd; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 1 ]
		# Apparently errx() on Linux ignores setprogname()
		output_match "missing package name"
	done
}
@test "${SUITE} test pkgin pkg-* commands (missing package)" {
	for cmd in pkg-content pc pkg-descr pd pkg-build-defs pbd; do
		run pkgin ${yflag} ${cmd} pkg-does-not-exist
		[ ${status} -eq 1 ]
		# The "." here is deliberate, "on" (older) vs "in".
		output_match "is not available .n the repository"
	done
}
@test "${SUITE} test pkgin clean" {
	for cmd in clean cl; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} -ge 001000 ]; then
			[ -z "${output}" ]
		fi
	done
}
@test "${SUITE} test pkgin stats" {
	# Known issue with "NULL source" mixed into the output
	skip_if_version -lt 001000 "known fail"

	for cmd in stats st; do
		run pkgin ${yflag} ${cmd}
		[ ${status} -eq 0 ]
		compare_output "pkgin.stats"
	done
}
@test "${SUITE} test pkgin usage (invalid command)" {
	# Invalid command
	run pkgin ${yflag} ojnk
	[ ${status} -eq 1 ]

	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		output_match "Usage: pkgin.*"
		output_match "Commands and shortcuts."
		output_match "list.*"
	elif [ ${PKGIN_VERSION} -lt 001300 ]; then
		compare_output "0.12" "pkgin.usage"
	elif [ ${PKGIN_VERSION} -le 200501 ]; then
		compare_output "20.5.1" "pkgin.usage"
	elif [ ${PKGIN_VERSION} -le 211200 ]; then
		compare_output "21.12.0" "pkgin.usage"
	else
		compare_output "pkgin.usage"
	fi

}
@test "${SUITE} test pkgin usage (no command)" {
	run pkgin
	[ ${status} -eq 1 ]

	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		output_match "Usage: pkgin.*"
		output_match "Commands and shortcuts."
		output_match "list.*"
	elif [ ${PKGIN_VERSION} -lt 001300 ]; then
		compare_output "0.12" "pkgin.usage"
	elif [ ${PKGIN_VERSION} -le 200501 ]; then
		compare_output "20.5.1" "pkgin.usage"
	elif [ ${PKGIN_VERSION} -le 211200 ]; then
		compare_output "21.12.0" "pkgin.usage"
	else
		compare_output "pkgin.usage"
	fi
}
@test "${SUITE} test pkgin -h" {
	# 0.9 exits failure and changes the output slightly, just skip.
	skip_if_version -lt 001000
	run pkgin -h
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -lt 001300 ]; then
		compare_output "0.12" "pkgin.usage"
	elif [ ${PKGIN_VERSION} -le 200501 ]; then
		compare_output "20.5.1" "pkgin.usage"
	elif [ ${PKGIN_VERSION} -le 211200 ]; then
		compare_output "21.12.0" "pkgin.usage"
	else
		compare_output "pkgin.usage"
	fi
}
@test "${SUITE} test pkgin -v" {
	run pkgin -v
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} -lt 200000 ]; then
		output_match "^pkgin.*for.*using.SQLite"
	else
		output_match "^pkgin.*using.SQLite"
	fi
}

#
# Not a pkgin test, but good to verify everything is as we expect.
#
@test "${SUITE} test pkg_info" {
	run pkg_info_sorted
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}
