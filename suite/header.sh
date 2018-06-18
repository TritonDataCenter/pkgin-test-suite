#!/usr/bin/env bats
#

#
# Common generated section shared by test scripts.  The following variables
# are generated at build time.
#
# - Global TEST_* vars
#
: ${TEST_LOCALBASE:=@TEST_LOCALBASE@}
: ${TEST_VARBASE:=@TEST_VARBASE@}
: ${TEST_PKG_DBDIR:=@TEST_PKG_DBDIR@}
: ${TEST_PKGIN_DBDIR:=@TEST_PKGIN_DBDIR@}
: ${TEST_PKGIN_DB:=@TEST_PKGIN_DB@}
: ${TEST_PKGIN_CACHE:=@TEST_PKGIN_CACHE@}
: ${TEST_PKGIN_SQL_LOG:=@TEST_PKGIN_SQL_LOG@}
: ${TEST_PKG_INSTALL_LOG:=@TEST_PKG_INSTALL_LOG@}
#
# - Repo-specific REPO_* vars
#
: ${REPO_NAME:=@REPO_NAME@}
: ${REPO_EXPDIR:=@REPO_EXPDIR@}
: ${REPO_OUTDIR:=@REPO_OUTDIR@}
: ${REPO_BUILD_DATE:=@REPO_BUILD_DATE@}
#
: ${REPO_PACKAGES:=@REPO_PACKAGES@}
: ${REPO_PKGIN:=@REPO_PKGIN@}
: ${REPO_PKG_ADD:=@REPO_PKG_ADD@}
: ${REPO_PKG_DELETE:=@REPO_PKG_DELETE@}
: ${REPO_PKG_INFO:=@REPO_PKG_INFO@}
: ${REPO_PKG_PATH:=@REPO_PKG_PATH@}
: ${REPO_HTTP_PORT:=@REPO_HTTP_PORT@}
: ${REPO_HTTPD:=@REPO_HTTPD@}
#
#
# Don't add any commands here, this file will be evaluated for every single
# test.  Instead put any startup configuration in the test run at the bottom.
#
# Except we need to get the pkgin version to adjust certain test results.  Use
# a merged version format so we can do integer comparisons.
#
PKGIN_V=$(${REPO_PKGIN} -v | awk '{print $2}')
PKGIN_MAJOR=$(IFS="."; set -- ${PKGIN_V}; echo $1)
PKGIN_MINOR=$(IFS="."; set -- ${PKGIN_V}; echo $2)
PKGIN_PATCH=$(IFS="."; set -- ${PKGIN_V}; echo $3)
PKGIN_VERSION=$(printf "%02d%02d%02d" ${PKGIN_MAJOR} ${PKGIN_MINOR} ${PKGIN_PATCH})

#
# These functions are called at the start and end of each test case.
#
setup()
{
	set -eu
}
teardown()
{
	# Debug output, only shown on test failure.  Requires a patched copy
	# of bats to save the variable state.
	echo cmd=${bats_save_cmd}
	echo status=${bats_save_status}
	for ((i=0; i<=$((${#bats_save_lines[@]} - 1)); i++)); do
		echo "line${i}=${bats_save_lines[${i}]}"
	done
	set +eu
}

#
# httpd server for ${REPO_PACKAGES}
#
httpd_pidfile="${REPO_OUTDIR}/httpd.pid"
start_webserver()
{
	if [ -n "${REPO_HTTP_PORT}" -a -n "${REPO_HTTPD}" ]; then
		${REPO_HTTPD} &
		echo "$!" >${httpd_pidfile}
	fi
}
stop_webserver()
{
	if [ -n "${REPO_HTTP_PORT}" -a -n "${REPO_HTTPD}" ]; then
		httpd_pid=$(<${httpd_pidfile})
		if [ -n "${httpd_pid}" ]; then
			kill ${httpd_pid}
			wait ${httpd_pid} 2>/dev/null || true
		fi
		rm -f ${httpd_pidfile}
	fi
}

#
# pkgin 0.9 cannot detect pkgdb changes with greater granularity than 1 second,
# so we need to ensure that any operations that modify the pkgdb wait until at
# least a second has passed since the last change.
#
# This ensures that subsequent pkgin calls will detect it has been modified,
# and thus the output will be deterministic.  Otherwise, for example, the
# "processing local summary" messages may be missing, causing exp failures.
#
sleep_pkgdb_if_required()
{
	if [ ${PKGIN_VERSION} -lt 001000 -a -d ${TEST_PKG_DBDIR} ]; then
		out=$(find ${TEST_PKG_DBDIR} -depth 0 -mtime +1s)
		if [ -z "${out}" ]; then
			# Two seconds are required to avoid rounding errors.
			sleep 2
		fi
	fi
}
#
# Command wrappers to ensure we run the right bits and to simplify tests.
#
pkg_add()
{
	sleep_pkgdb_if_required
	${REPO_PKG_ADD} "$@"
}
pkg_delete()
{
	sleep_pkgdb_if_required
	${REPO_PKG_DELETE} "$@"
}
pkg_info()
{
	${REPO_PKG_INFO} "$@"
}
pkgin()
{
	sleep_pkgdb_if_required
	${REPO_PKGIN} "$@"
}
#
# The bats "run" command doesn't support pipes, so we have to construct
# functions for some tests we want to perform.
#
pkg_info_sorted()
{
	${REPO_PKG_INFO} "$@" | sort
}
pkgin_sorted()
{
	${REPO_PKGIN} "$@" | sort
}
pkgin_autoremove()
{
	# XXX; -y should just work imho
	echo "y" | pkgin autoremove
}
#
# Wrappers for broken commands.
#
gnudiff()
{
	if diff --version >/dev/null 2>&1; then
		diff "$@"
	else
		gdiff "$@"
	fi
}

#
# Many tests will compare pkg_info and pkgin output to what is expected, so it
# makes sense to have a functions for them.
#
compare_output()
{
	outfile=$1; shift
	matchfile="${REPO_EXPDIR}/${outfile}"

	# This function expects that a command has just been executed.
	echo "${output}" >${REPO_OUTDIR}/${outfile}

	# Look for version-specific override directories if available.
	for versdir in ${PKGIN_MAJOR}.${PKGIN_MINOR}.${PKGIN_PATCH} \
		       ${PKGIN_MAJOR}.${PKGIN_MINOR}; do
		if [ -f "${REPO_EXPDIR}/${versdir}/${outfile}" ]; then
			matchfile="${REPO_EXPDIR}/${versdir}/${outfile}"
			break
		fi
	done

	run gnudiff -u ${matchfile} ${REPO_OUTDIR}/${outfile}
	[ "$status" -eq 0 ]
	[ -z "${output}" ]
}
compare_pkg_info()
{
	outfile=$1; shift

	run pkg_info_sorted
	[ "$status" -eq 0 ]

	compare_output ${outfile}

}
compare_pkgin_list()
{
	outfile=$1; shift

	run pkgin list
	[ "$status" -eq 0 ]

	compare_output ${outfile}
}

#
# Helpful debug functions for when things go wrong.
#
pkgdbsql()
{
	sqlite3 ${TEST_PKGIN_DB} "$@"
}

#
# See sstephenson/bats#49 for why we can't just use [[ ]]
#
output_match()
{
	[[ ${output} =~ $1 ]] || false
}
output_not_match()
{
	[[ ! ${output} =~ $1 ]] || false
}
line_match()
{
	lineno=$1; shift

	[ ${#lines[@]} -gt ${lineno} ]
	[[ ${lines[${lineno}]} =~ $1 ]] || false
}
#
# Match output against a file containing regular expressions.  By default a
# strict order is checked, as well as an exact match in the number of lines
# in the output.  Sometimes the output order is non-deterministic, in which
# case the "-I" option will ignore the ordering, but will still require the
# number of lines to match.
#
file_match()
{
	order=true
	nl=0

	if [ "$1" = "-I" ]; then
		order=false
		shift
	fi

	filename="$1"; shift
	matchfile="${REPO_EXPDIR}/${filename}"

	# Look for version-specific override directories if available.
	for versdir in ${PKGIN_MAJOR}.${PKGIN_MINOR}.${PKGIN_PATCH} \
		       ${PKGIN_MAJOR}.${PKGIN_MINOR}; do
		if [ -f "${REPO_EXPDIR}/${versdir}/${filename}" ]; then
			matchfile="${REPO_EXPDIR}/${versdir}/${filename}"
			break
		fi
	done

	while read match; do
		if ${order}; then
			line_match ${nl} "${match}"
		else
			output_match "${match}"
		fi
		nl=$((nl + 1))
	done < ${matchfile}
	[ ${#lines[@]} -eq ${nl} ]
}

#
# Skip tests unsuitable for the current release.
#
skip_if_version()
{
	operand=$1; shift
	release=$1; shift

	if [ ${PKGIN_VERSION} ${operand} ${release} ]; then
		skip "$@"
	fi
}

#
# Put anything here that needs to be done at the start of each test run.
#
@test "${REPO_NAME} perform test suite setup" {
	# Ensure clean output directory for each run
	run rm -rf ${REPO_OUTDIR}
	[ $status -eq 0 ]
	run mkdir -p ${REPO_OUTDIR}
	[ $status -eq 0 ]

	# This can't go as a "run" item for some reason, probably to do with
	# output redirection and background processes.  The server is only
	# started if REPO_HTTP_PORT is set.
	start_webserver
}
