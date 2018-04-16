#
# This initial test suite operates against an empty repository.
#
# While this might not appear useful, it does allow us to verify some issues,
# such as being able to initialise the pkgin database, ensure that the compat
# checks work, and verify output is as expected when there are no results.
#
# It also gives us a default repository to execute the wrapper against.
#

cat_nonexist="category-does-not-exist"
pkg_nonexist="pkg-does-not-exist"

#
# Perform the initial update and database creation.  The initial pkgin update
# should log SQL errors as the database will not exist, so also verify that the
# SQL log has been created and is not empty.
#
@test "${REPO_NAME} ensure LOCALBASE and VARBASE are wiped" {
	run rm -rf ${TEST_LOCALBASE} ${TEST_VARBASE}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]

	# pkgin needs the parent directory to exist.
	run mkdir -p ${TEST_PKGIN_DBDIR}
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}

#
# The remote repository directory will change depending on where these
# tests are being ran, and pkg_summary compression may change, so use
# simple output matches rather than a static file here.
#
# We also need to handle 0.9.4 differently as it does not initialise an
# empty database correctly so we only get "downloading pkg_summary.gz"
# for this as well as subsequent updates.
#
@test "${REPO_NAME} test initial pkgin update" {
	run pkgin update
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} = "0.9.4" ]; then
		output_match "downloading pkg_summary"
	else
		line_match 0 "processing remote summary"
		line_match 1 "downloading pkg_summary"
	fi
}
@test "${REPO_NAME} verify sql logfile creation and error logging" {
	run [ -s ${TEST_PKGIN_SQL_LOG} ]
}

#
# Verify that a subsequent update run does not re-do any database creation or
# pkg_summary processing.  The SQL log should be empty.  We also test the "up"
# alias while here.
#
@test "${REPO_NAME} test subsequent pkgin update" {
	run pkgin up
	[ ${status} -eq 0 ]
	if [ ${PKGIN_VERSION} = "0.9.4" ]; then
		output_match "downloading pkg_summary"
	else
		line_match 0 "processing remote summary"
		line_match 1 "database.*is.up-to-date"
	fi
}
@test "${REPO_NAME} verify sql logfile is empty" {
	run [ ! -s ${TEST_PKGIN_SQL_LOG} ]
}

#
# Test various commands against an empty installation, this ensures they handle
# empty results correctly.  For each command also test its alias.
#
@test "${REPO_NAME} test pkgin list" {
	for cmd in list ls; do
		run pkgin ${cmd}
		[ ${status} -eq 0 ]
		line_match 0 "Requested list is empty."
	done
}
@test "${REPO_NAME} test pkgin avail" {
	for cmd in avail av; do
		run pkgin ${cmd}
		[ ${status} -eq 0 ]
		line_match 0 "Requested list is empty."
	done
}
@test "${REPO_NAME} test pkgin search (no arguments)" {
	for cmd in search se; do
		run pkgin ${cmd}
		[ ${status} -eq 1 ]
		line_match 0 "pkgin: missing search string"
	done
}
@test "${REPO_NAME} test pkgin search (missing package)" {
	for cmd in search se; do
		run pkgin ${cmd} ${pkg_nonexist}
		# 0.9.4 is broken here
		if [ ${PKGIN_VERSION} = "0.9.4" ]; then
			[ ${status} -eq 0 ]
		else
			[ ${status} -eq 1 ]
			[ "${output}" = "No results found for ${pkg_nonexist}" ]
		fi
	done
}
@test "${REPO_NAME} test pkgin upgrade" {
	for cmd in upgrade ug; do
		run pkgin ${cmd}
		[ ${status} -eq 1 ]
		output_match "empty non-autoremovable package list"
	done
}
@test "${REPO_NAME} test pkgin full-upgrade" {
	for cmd in full-upgrade fug; do
		run pkgin ${cmd}
		[ ${status} -eq 1 ]
		output_match "empty non-autoremovable package list"
	done
}
@test "${REPO_NAME} test pkgin install" {
	for cmd in install in; do
		run pkgin ${cmd} ${pkg_nonexist}
		[ ${status} -eq 1 ]
		if [ ${PKGIN_VERSION} = "0.9.4" ]; then
			output_match "empty available packages list"
		else
			line_match 0 "empty available packages list"
			line_match 1 "nothing to do."
		fi
	done
}
@test "${REPO_NAME} test pkgin remove" {
	for cmd in remove rm; do
		run pkgin ${cmd} ${pkg_nonexist}
		[ ${status} -eq 1 ]
		if [ ${PKGIN_VERSION} = "0.9.4" ]; then
			output_match "pkgin: empty local package list."
		else
			[ "${output}" = "pkgin: empty local package list." ]
		fi
	done
}
@test "${REPO_NAME} test pkgin autoremove" {
	for cmd in autoremove ar; do
		run pkgin ${cmd}
		[ ${status} -eq 1 ]
		output_match "no packages have been installed"
	done
}
@test "${REPO_NAME} test pkgin show-keep" {
	for cmd in show-keep sk; do
		run pkgin ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} = "0.9.4" ]; then
			output_match "empty non-autoremovable package list"
		else
			[ "${output}" = "empty non-autoremovable package list" ]
		fi
	done
}
@test "${REPO_NAME} test pkgin show-no-keep" {
	for cmd in show-no-keep snk; do
		run pkgin ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} = "0.9.4" ]; then
			output_match "empty autoremovable package list"
		else
			[ "${output}" = "empty autoremovable package list" ]
		fi
	done
}
@test "${REPO_NAME} test pkgin export" {
	for cmd in export ex; do
		run pkgin ${cmd}
		[ ${status} -eq 1 ]
		if [ ${PKGIN_VERSION} = "0.9.4" ]; then
			output_match "pkgin: empty local package list."
		else
			[ "${output}" = "pkgin: empty local package list." ]
		fi
	done
}
@test "${REPO_NAME} test pkgin show-category" {
	for cmd in show-category sc; do
		run pkgin ${cmd} ${cat_nonexist}
		[ ${status} -eq 0 ]
	done
}
@test "${REPO_NAME} test pkgin show-pkg-category" {
	for cmd in show-pkg-category spc; do
		run pkgin ${cmd} ${pkg_nonexist}
		# 0.9.4 is broken here
		if [ ${PKGIN_VERSION} = "0.9.4" ]; then
			[ ${status} -eq 0 ]
		else
			[ ${status} -eq 1 ]
		fi
	done
}
@test "${REPO_NAME} test pkgin show-all-categories" {
	for cmd in show-all-categories sac; do
		run pkgin ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} = "0.9.4" ]; then
			output_match "No categories found."
		else
			[ "${output}" = "No categories found." ]
		fi
	done
}
@test "${REPO_NAME} test pkgin pkg-* commands (no arguments)" {
	for cmd in pkg-content pc pkg-descr pd pkg-build-defs pbd; do
		run pkgin ${cmd}
		[ ${status} -eq 1 ]
		if [ ${PKGIN_VERSION} = "0.9.4" ]; then
			output_match "pkgin: missing package name"
		else
			[ "${output}" = "pkgin: missing package name" ]
		fi
	done
}
@test "${REPO_NAME} test pkgin pkg-* commands (missing package)" {
	for cmd in pkg-content pc pkg-descr pd pkg-build-defs pbd; do
		run pkgin ${cmd} ${pkg_nonexist}
		[ ${status} -eq 1 ]
		# The "." here is deliberate, "on" (older) vs "in".
		output_match "is not available .n the repository"
	done
}
@test "${REPO_NAME} test pkgin clean" {
	for cmd in clean cl; do
		run pkgin ${cmd}
		[ ${status} -eq 0 ]
		if [ ${PKGIN_VERSION} != "0.9.4" ]; then
			[ -z "${output}" ]
		fi
	done
}
@test "${REPO_NAME} test pkgin stats" {
	# Known issue with "NULL source" mixed into the output
	skip094 known fail

	for cmd in stats st; do
		run pkgin ${cmd}
		[ ${status} -eq 0 ]
		compare_output "pkgin.stats"
	done
}
@test "${REPO_NAME} test pkgin usage" {
	# Invalid command
	run pkgin ojnk
	[ ${status} -eq 1 ]
	compare_output "pkgin.usage"

	# Test running with no commands for argc/argv usage
	run pkgin
	[ ${status} -eq 1 ]
	compare_output "pkgin.usage"

	# Explicitly asking for help should return success
	run pkgin -h
	[ ${status} -eq 0 ]
	compare_output "pkgin.usage"
}

@test "${REPO_NAME} test pkgin -v" {
	run pkgin -v
	[ ${status} -eq 0 ]
	output_match "^pkgin.*for.*using.SQLite"
}

#
# Not a pkgin test, but good to verify everything is as we expect.
#
@test "${REPO_NAME} test pkg_info" {
	run pkg_info_sorted
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}
