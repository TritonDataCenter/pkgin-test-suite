#!/usr/bin/env bash
#
# Common definitions and functions used for each test suite.  As this is
# sourced via "load" it must not contain any @tests.
#

if [ -z "${SUITE}" ]; then
	echo "ERROR: SUITE is mandatory" >&2
	exit 1
fi

#
# Set up required variables.  By default each test suite run gets its own
# directory prefix to avoid clashing with previous runs if they did not clean
# up correctly.
#
: ${SUITE_WORKDIR:=${BATS_RUN_TMPDIR}/${SUITE}}

: ${LOCALBASE:=${SUITE_WORKDIR}/local}			# LOCALBASE
: ${PACKAGES:=${SUITE_WORKDIR}/packages}		# PACKAGES
: ${VARBASE:=${SUITE_WORKDIR}/var}			# VARBASE

: ${PKG_WORKDIR:=${SUITE_WORKDIR}/pkg}			# pkg_create files

: ${PKGIN:=pkgin}					# pkgin to test with
: ${PKGIN_DBDIR:=${VARBASE}/db/pkgin}			# pkgin database dir
: ${PKGIN_CACHE:=${PKGIN_DBDIR}/cache}			# download cache dir
: ${PKGIN_DB:=${PKGIN_DBDIR}/pkgin.db}			# pkgin database
: ${PKG_DBDIR:=${VARBASE}/db/pkgdb}			# pkg_install database
: ${PKG_INSTALL_DIR:=${BATS_ROOT}/bin}			# pkg_install wrappers

: ${PKG_INSTALL_LOG:=${PKGIN_DBDIR}/pkg_install-err.log} # pkg_* output log
: ${PKGIN_SQL_LOG:=${PKGIN_DBDIR}/sql.log}		# pkgin sql error log

: ${HTTPD_PORT:=$((8192 + (RANDOM % (65535 - 8192))))}}	# Default HTTP port
: ${HTTPD_ERR:=${SUITE_WORKDIR}/httpd.err}		# httpd error file
: ${HTTPD_LOG:=${SUITE_WORKDIR}/httpd.log}		# httpd log file
: ${HTTPD_PID:=${SUITE_WORKDIR}/httpd.pid}		# httpd pid file

: ${PKG_REPOS=http://localhost:${HTTPD_PORT}}

export PKGIN PKGIN_DBDIR PKG_DBDIR PKG_INSTALL_DIR PKG_REPOS PACKAGES

#
# It is common in many tests to set up multiple repositories with different
# BUILD_DATE and pkg_summary modification times to simulate real-world upgrade
# scenarios.  These variables help to ensure they are set consistently and
# avoid duplication across test suites.
#
# The REPO_DATE_* variables are used as the arguments to "touch -d" to set
# pkg_summary modification time so that Last-Modified changes across
# repositories.
#
export BUILD_DATE_1="1970-01-01 01:01:01 +0000"
export BUILD_DATE_2="1970-02-02 02:02:02 +0000"
export BUILD_DATE_3="1970-03-03 03:03:03 +0000"
export BUILD_DATE_4="1970-04-04 04:04:04 +0000"
#
export REPO_DATE_1="1970-01-01T01:01:01"
export REPO_DATE_2="1970-02-02T02:02:02"
export REPO_DATE_3="1970-03-03T03:03:03"
export REPO_DATE_4="1970-04-04T04:04:04"

#
# Parallel test runs are only supported across test suites.  Individual tests
# within each test suite cannot be run parallel, at least in the vast majority
# of cases, as they depend on state left by previous tests.
#
export BATS_NO_PARALLELIZE_WITHIN_FILE=true

#
# Sanity check variable to ensure that any wrapper scripts are being called
# with the proper environment set.
#
export BATS_PKGIN_TEST_SUITE=1

#
# Calculate the pkgin version number as a lot of tests change behaviour based
# on the running version.
#
PKGIN_V=$(${BATS_ROOT}/bin/pkgin -v | awk '{sub(/-dev/, "", $2); print $2}')
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
	# Print output on test failure for easier debugging.
	if [ ${BATS_ERROR_STATUS} -ne 0 ]; then
		for ((i=0; i < $((${#lines[@]})); i++)); do
			printf "%6d %s\n" "$(($i + 1))" "${lines[${i}]}"
		done
	fi

	set +eu
}

#
# httpd server for ${PACKAGES}
#
start_httpd()
{
	export REPO_PACKAGES="${PACKAGES}/All"
	export HTTPD_ERR HTTPD_LOG
	exec socat TCP4-LISTEN:${HTTPD_PORT},reuseaddr,fork,keepalive system:"${BATS_ROOT}/bin/httpd" 3>&- &
	echo "$!" >${HTTPD_PID}
}
stop_httpd()
{
	if [ -f ${HTTPD_PID} ]; then
		local pid=$(<${HTTPD_PID})
		if [ -n "${pid}" ]; then
			kill ${pid}
			wait ${pid} 2>/dev/null || true
		fi
		rm -f ${HTTPD_PID}
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
	if [ ${PKGIN_VERSION} -ge 001000 ]; then
		return
	fi

	if [ -d ${PKG_DBDIR} ]; then
		local out=$(find ${PKG_DBDIR} -depth 0 -mtime +1s)
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
	${BATS_ROOT}/bin/pkg_add "$@"
}
pkg_create()
{
	${BATS_ROOT}/bin/pkg_create "$@"
}
pkg_delete()
{
	sleep_pkgdb_if_required
	${BATS_ROOT}/bin/pkg_delete "$@"
}
pkg_info()
{
	${BATS_ROOT}/bin/pkg_info "$@"
}
pkgin()
{
	sleep_pkgdb_if_required
	${BATS_ROOT}/bin/pkgin "$@"
}
#
# Concatenate the required BUILD_INFO variables with user-supplied arguments
# and output to a per-package build-info file.
#
create_pkg_buildinfo()
{
	if [ $# -lt 1 ]; then
		echo "usage: create_pkg_buildinfo <pkg> [<KEY=value> ...]" >&2
		exit 1
	fi

	local pkg=$1; shift
	local build_info="${PKG_WORKDIR}/${pkg}/build-info"

	mkdir -p ${PKG_WORKDIR}/${pkg}

	if [ -n "${MACHINE_ARCH}" ]; then
		echo "MACHINE_ARCH=${MACHINE_ARCH}" >>${build_info}
	else
		echo "MACHINE_ARCH=$(bmake -V MACHINE_ARCH)" >>${build_info}
	fi
	echo "OPSYS=$(uname -s)" >>${build_info}
	echo "OS_VERSION=$(uname -r | sed -e 's/-.*//')" >>${build_info}
	echo "PKGTOOLS_VERSION=20091115" >>${build_info}

	for arg; do
		echo ${arg} >>${build_info}
	done
}
create_pkg_comment()
{
	if [ $# -ne 2 ]; then
		echo "usage: create_pkg_comment <pkg> <comment>" >&2
		exit 1
	fi

	local pkg=$1; shift
	local comment=$1; shift

	mkdir -p ${PKG_WORKDIR}/${pkg}

	echo "${comment}" >${PKG_WORKDIR}/${pkg}/comment
}

create_pkg_descr()
{
	if [ $# -lt 2 ]; then
		echo "usage: create_pkg_descr <pkg> [<descr> ...]" >&2
		exit 1
	fi

	local pkg=$1; shift

	mkdir -p ${PKG_WORKDIR}/${pkg}

	for descr; do
		echo "${descr}" >>${PKG_WORKDIR}/${pkg}/descr
	done
}
#
# Create a file for a particular package.  If the contents are not specified
# then the file simply contains the package name.
#
create_pkg_file()
{
	if [ $# -lt 2 ]; then
		echo "usage: create_pkg_file <pkg> <file> [<contents> ...]" >&2
		exit 1
	fi

	local pkg=$1; shift
	local filename=$1; shift
	local filesdir="${PKG_WORKDIR}/${pkg}/files"

	mkdir -p ${filesdir}/$(dirname ${filename})

	if [ $# -eq 0 ]; then
		echo "${pkg}" >${filesdir}/${filename}
	else
		for arg; do
			echo "${arg}" >>${filesdir}/${filename}
		done
	fi
}
#
# The contents of the preserve file are not relevant, it just has to exist,
# which makes creating it a bit janky, so just have this function that creates
# something that create_pkg() can find to simplify things.
#
create_pkg_preserve()
{
	if [ $# -ne 1 ]; then
		echo "usage: create_pkg_preserve <pkg>" >&2
		exit 1
	fi

	local pkg=$1; shift

	mkdir -p ${PKG_WORKDIR}/${pkg}
	echo "These contents are ignored" >${PKG_WORKDIR}/${pkg}/preserve
}

#
# Create pkg_summary.gz.  If an argument is supplied it is expected to be a
# valid time string argument for "touch -d" to set the timestamp on
# pkg_summary.gz for its Last-Modified header which needs to be different for
# pkgin to detect a remote repository update.
#
create_pkg_summary()
{
	(
		cd ${PACKAGES}/All
		cat ../pkginfo/* >pkg_summary
		gzip -9 > pkg_summary.gz < pkg_summary
		if [ -n "$1" ]; then
			touch -d "$1" pkg_summary.gz
		fi
	)
}

#
# Override the SIZE_PKG calculation.
#
create_pkg_size()
{
	if [ $# -ne 2 ]; then
		echo "usage: create_pkg_size <pkg> <size>" >&2
		exit 1
	fi

	local pkg=$1; shift
	local size=$1; shift
	local pkgdir="${PKG_WORKDIR}/${pkg}"

	echo ${size} >${pkgdir}/size-pkg
}

#
# pkg_summary filter for a package, a list of sed(1) commands.
#
create_pkg_filter()
{
	if [ $# -lt 2 ]; then
		echo "usage: create_pkg_filter <pkg> <filter> [...]" >&2
		exit 1
	fi

	local pkg=$1; shift
	local pkgdir="${PKG_WORKDIR}/${pkg}"

	for filter; do
		echo "${filter}" >>${pkgdir}/filter
	done
}

#
# Wrapper to help create a package from directory.
#
create_pkg()
{
	if [ $# -lt 1 ]; then
		echo "usage: create_pkg <pkg> [<pkg_create arg> ...]" >&2
		exit 1
	fi

	local pkg=$1; shift
	local pkgdir="${PKG_WORKDIR}/${pkg}"
	local extra_args=""

	# Check for mandatory files.
	for file in build-info comment; do
		if [ ! -f ${pkgdir}/${file} ]; then
			echo "ERROR: Missing ${file} file for ${pkg}" >&2
			exit 1
		fi
	done

	# If DESCR is not specified then just re-use the comment.
	if [ ! -f ${pkgdir}/descr ]; then
		cp ${pkgdir}/comment ${pkgdir}/descr
	fi

	# Generate metadata if package contains files.
	if [ -d ${pkgdir}/files ]; then
		(
			cd ${pkgdir}/files
			find * -type f >>${pkgdir}/plist
			if [ ! -f ${pkgdir}/size-pkg ]; then
				find * -type f | xargs ls -ld \
				    | awk '{ t += $5 } END { print t }' \
				    >${pkgdir}/size-pkg
			fi
		)
	else
		>${pkgdir}/plist
	fi
	if [ ! -f ${pkgdir}/size-pkg ]; then
		echo 0 >${pkgdir}/size-pkg
	fi

	#
	# If a "preserve" file exists then pass -n.
	#
	if [ -f ${pkgdir}/preserve ]; then
		extra_args="${extra_args} -n ${pkgdir}/preserve"
	fi

	mkdir -p ${PACKAGES}/All
	pkg_create \
	    -B ${pkgdir}/build-info \
	    -c ${pkgdir}/comment \
	    -d ${pkgdir}/descr \
	    -f ${pkgdir}/plist \
	    -I ${LOCALBASE} \
	    -p ${pkgdir}/files \
	    -s ${pkgdir}/size-pkg \
	    ${extra_args} \
	    "$@" ${PACKAGES}/All/${pkg}.tgz

	mkdir -p ${PACKAGES}/pkginfo
	if [ -f ${pkgdir}/filter ]; then
		pkg_info -X ${PACKAGES}/All/${pkg}.tgz | \
		    sed -f ${pkgdir}/filter >${PACKAGES}/pkginfo/${pkg}
	else
		pkg_info -X ${PACKAGES}/All/${pkg}.tgz \
		    >${PACKAGES}/pkginfo/${pkg}
	fi
}

#
# The bats "run" command doesn't support pipes, so we have to construct
# functions for some tests we want to perform.
#
pkg_info_sorted()
{
	pkg_info "$@" | sort
}
pkgin_sorted()
{
	pkgin "$@" | sort
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
	if [ $# -eq 2 ]; then
		versdir=$1; shift
		outfile=$1; shift
		matchfile="${BATS_ROOT}/exp/${SUITE}/${versdir}/${outfile}"
	else
		outfile=$1; shift
		matchfile="${BATS_ROOT}/exp/${SUITE}/${outfile}"
	fi

	# This function expects that a command has just been executed.
	echo "${output}" >${BATS_RUN_TMPDIR}/${SUITE}/${outfile}

	run gnudiff -u ${matchfile} ${BATS_RUN_TMPDIR}/${SUITE}/${outfile}
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
	sqlite3 ${PKGIN_DB} "$@"
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

	if [ $# -eq 2 ]; then
		versdir=$1; shift
		outfile=$1; shift
		matchfile="${BATS_ROOT}/exp/${SUITE}/${versdir}/${outfile}"
	else
		outfile=$1; shift
		matchfile="${BATS_ROOT}/exp/${SUITE}/${outfile}"
	fi


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
# Common output matches
#
output_match_clean_pkg_install()
{
	#
	# There are often multiple output lines so we need to check for both
	# positive and negative matches.
	#
	output_match "pkg_install warnings: 0, errors: 0"
	output_not_match "pkg_install warnings: [1-9]"
	output_not_match "pkg_install .*errors: [1-9]"
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
