#!/usr/bin/env bats
#
# Test install / upgrade / remove ordering.
#

SUITE="order"

load common

INSTALL_SCRIPT="${SUITE_WORKDIR}/install-script"
INSTALL_OUTPUT="${SUITE_WORKDIR}/install-script-output"

#
# Generate repository packages.
#
setup_file()
{
	#
	# pkgin 25.5.0 has an uninitialised variable issue that this test
	# suite triggers, so we just skip that version completely.
	#
	skip_if_version -eq 250500 "uninitialised variable corruption"

	#
	# Set up the first repository.
	#
	BUILD_DATE="${BUILD_DATE_1}"
	PACKAGES="${SUITE_WORKDIR}/repo1"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg1"
	REPO_DATE="${REPO_DATE_1}"

	#
	# Create an INSTALL script
	#
	mkdir -p ${SUITE_WORKDIR}
	cat >${INSTALL_SCRIPT} <<-EOF
		#!/bin/sh
		case "\${2}" in
		PRE-INSTALL)
			echo "\$1" >>${INSTALL_OUTPUT}
			;;
		esac
	EOF

	create_pkg_buildinfo "pkg_install-1.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=pkgtools" \
	    "PKGPATH=pkgtools/pkg_install"
	create_pkg_comment "pkg_install-1.0" \
	    "Package management and administration tools for pkgsrc"
	create_pkg_preserve "pkg_install-1.0"
	create_pkg "pkg_install-1.0" -i ${INSTALL_SCRIPT}

	# Create packages
	for name in {a,b,c}; do
		# "underneath" instead of "bottom" in case there are any
		# alphanumeric sorting issues.
		for level in {underneath,middle,top}; do
			pname="${name}-${level}"
			pfull="${name}-${level}-1.0"
			create_pkg_buildinfo "${pfull}" \
			    "BUILD_DATE=${BUILD_DATE}" \
			    "CATEGORIES=cat" \
			    "PKGPATH=cat/${pname}"
			create_pkg_comment "${pfull}" "${pname}"
			case "${pname}" in
			*-underneath)
				create_pkg "${pfull}" -i ${INSTALL_SCRIPT}
				;;
			a-middle)
				create_pkg "${pfull}" \
				    -P "a-underneath>=1.0" \
				    -i ${INSTALL_SCRIPT}
				;;
			[bc]-middle)
				create_pkg "${pfull}" \
				    -P "a-underneath>=1.0 \
				        ${name}-underneath>=1.0" \
				    -i ${INSTALL_SCRIPT}
				;;
			*-top)
				create_pkg "${pfull}" \
				    -P "${name}-middle>=1.0" \
				    -i ${INSTALL_SCRIPT}
				;;
			esac
		done
	done

	create_pkg_summary "${REPO_DATE}"

	#
	# Set up the second repository.
	#
	BUILD_DATE="${BUILD_DATE_2}"
	PACKAGES="${SUITE_WORKDIR}/repo2"
	PKG_WORKDIR="${SUITE_WORKDIR}/pkg2"
	REPO_DATE="${REPO_DATE_2}"

	#
	# pkg_install should be upgraded first, but we also check that its new
	# dependency is pulled in first otherwise it could fail.
	#
	create_pkg_buildinfo "mksh-59b" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=shells" \
	    "PKGPATH=shells/mksh"
	create_pkg_comment "mksh-59b" "MirBSD Korn Shell"
	create_pkg "mksh-59b" -i ${INSTALL_SCRIPT}

	create_pkg_buildinfo "pkg_install-2.0" \
	    "BUILD_DATE=${BUILD_DATE}" \
	    "CATEGORIES=pkgtools" \
	    "PKGPATH=pkgtools/pkg_install"
	create_pkg_comment "pkg_install-2.0" \
	    "Package management and administration tools for pkgsrc"
	create_pkg_preserve "pkg_install-2.0"
	create_pkg "pkg_install-2.0" -P "mksh-[0-9]*" -i ${INSTALL_SCRIPT}

	# Create packages
	for name in {a,b,c}; do
		if [ "${name}" = "b" ]; then
			version="1.0"
		else
			version="2.0"
		fi
		# "underneath" instead of "bottom" in case there are any
		# alphanumeric sorting issues.
		for level in {underneath,middle,top}; do
			pname="${name}-${level}"
			pfull="${name}-${level}-${version}"
			create_pkg_buildinfo "${pfull}" \
			    "BUILD_DATE=${BUILD_DATE}" \
			    "CATEGORIES=cat" \
			    "PKGPATH=cat/${pname}"
			create_pkg_comment "${pfull}" "${pname}"
			case "${pname}" in
			*-underneath)
				create_pkg "${pfull}" -i ${INSTALL_SCRIPT}
				;;
			a-middle)
				create_pkg "${pfull}" \
				    -P "a-underneath>=${version}" \
				    -i ${INSTALL_SCRIPT}
				;;
			[bc]-middle)
				create_pkg "${pfull}" \
				    -P "a-underneath>=${version} \
				        ${name}-underneath>=${version}" \
				    -i ${INSTALL_SCRIPT}
				;;
			*-top)
				create_pkg "${pfull}" \
				    -P "${name}-middle>=${version}" \
				    -i ${INSTALL_SCRIPT}
				;;
			esac
		done
	done

	create_pkg_summary "${REPO_DATE}"

	PACKAGES="${SUITE_WORKDIR}/packages"
	ln -s repo1 ${SUITE_WORKDIR}/packages
	start_httpd
}

teardown_file()
{
	stop_httpd
}

#
# Common functions used in this file to verify that the install script was only
# called once per package.  remove_script_output() should be prior to every run
# so that previous results do not affect output.
#
verify_install_script_output()
{
	run bash -c "sort ${INSTALL_OUTPUT} | uniq -c | sort -n"
	output_match " 1 "
	output_not_match " [2-9] "
}
remove_script_output()
{
	run rm -f ${INSTALL_OUTPUT}
}

@test "${SUITE} install initial package" {
	export PKG_PATH=${SUITE_WORKDIR}/repo1/All
	run pkg_add pkg_install
	[ ${status} -eq 0 ]
	[ -z "${output}" ]
}

#
# There's no way to tell pkg_add to not automatically pull in dependencies so
# we can't set PKGIN_FORCE_PKG_ORDERING and see what breaks, so instead we use
# an INSTALL script to write to a file and then count how many times each
# package has appended itself.
#
# Any duplicates means the package has been installed multiple times and the
# install ordering was incorrect.
#
@test "${SUITE} install remaining packages" {
	remove_script_output
	run pkgin -y install a-top b-top c-top
	[ ${status} -eq 0 ]
	output_match_clean_pkg_install
	#
	# This was broken in 20.7.0 which attempted to fix install ordering
	# but actually made it worse.  Fixed in 23.8.0.
	#
	if [ ${PKGIN_VERSION} -lt 200700 -o ${PKGIN_VERSION} -ge 230800 ]; then
		verify_install_script_output
	fi
}

@test "${SUITE} switch repository" {
	run rm ${SUITE_WORKDIR}/packages
	[ ${status} -eq 0 ]

	run ln -s repo2 ${SUITE_WORKDIR}/packages
	[ ${status} -eq 0 ]

	if [ ${PKGIN_VERSION} -lt 001000 ]; then
		# Needs an explicit update after repo switch.
		run pkgin -fy update
		[ ${status} -eq 0 ]
	fi

}

@test "${SUITE} test partial pkgin install" {
	remove_script_output
	run pkgin -y install pkg_install
	# Versions earlier than 0.11.0 fail to perform partial installs.
	if [ ${PKGIN_VERSION} -ge 001100 ]; then
		[ ${status} -eq 0 ]
		output_match_clean_pkg_install
	fi
	#
	# Broken since 0.11.0 with in-place upgrades, fixed in 23.8.0.
	#
	if [ ${PKGIN_VERSION} -lt 001100 -o ${PKGIN_VERSION} -ge 230800 ]; then
		verify_install_script_output
	fi
}

@test "${SUITE} run pkgin upgrade" {
	remove_script_output
	run pkgin -y full-upgrade
	# pkgin 0.7.0 fails to upgrade pkg_install correctly
	if [ ${PKGIN_VERSION} -ne 000700 ]; then
		[ ${status} -eq 0 ]
		output_match_clean_pkg_install
	fi
	#
	# Broken since 0.11.0 with in-place upgrades, fixed in 23.8.0.
	#
	if [ ${PKGIN_VERSION} -lt 001100 -o ${PKGIN_VERSION} -ge 230800 ]; then
		verify_install_script_output
	fi
}

@test "${SUITE} run pkgin remove b-* packages" {
	export PKGIN_FORCE_PKG_ORDERING=1
	run pkgin -y remove b-underneath
	[ ${status} -eq 0 ]
	output_match "3 package.* to delete"
	output_match_clean_pkg_install
}

@test "${SUITE} run pkgin remove {a,c}-* packages" {
	export PKGIN_FORCE_PKG_ORDERING=1
	run pkgin -y remove a-underneath
	[ ${status} -eq 0 ]
	output_match "5 package.* to delete"
	output_match_clean_pkg_install
}

# Should be only c-underneath left
@test "${SUITE} run pkgin remove final package" {
	export PKGIN_FORCE_PKG_ORDERING=1
	# Older do not support autoremove correctly.
	if [ ${PKGIN_VERSION} -le 001102 ]; then
		run pkgin -y remove c-underneath
		[ ${status} -eq 0 ]
		output_match "1 package.* to.* delete"
		output_match "removing c-underneath-2.0"
		output_match_clean_pkg_install
	else
		run pkgin -y autoremove
		[ ${status} -eq 0 ]
		output_match "1 package.* to.* autoremove"
		output_match_clean_pkg_install
	fi
}

@test "${SUITE} verify we cannot remove pkg_install" {
	run pkgin -y remove pkg_install
	[ ${status} -eq 0 ]
}

@test "${SUITE} verify pkg_info" {
	skip_if_version -eq 000700 "fails to upgrade pkg_install"
	compare_pkg_info "pkg_info.final"
}
