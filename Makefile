#
# The test suite is split up into a series of repositories that are tested
# against sequentially.  Repositories use a shared LOCALBASE / VARBASE which
# are left unmodified between repositories to test upgrade scenarios, but
# repositories may choose to remove them in order to test initialisation.
#
# Each repository has an associated bats test file located under suite/ and
# chooses from a selection of packages under pkg/ to test with.
#
# The selection of packages is used to generate a per-repository pkg_summary
# so that only the packages chosen are available.  Packages are built with
# repository-specific settings, e.g. BUILD_DATE, to test upgrade scenarios.
#


#
# Top-level variables can be overridden but probably shouldn't unless you
# really know what you are doing.
#
SYSTEM_BATS?=		${.CURDIR}/bin/bats
SYSTEM_PKGIN?=		pkgin
SYSTEM_PKG_ADD?=	pkg_add
SYSTEM_PKG_ADMIN?=	pkg_admin
SYSTEM_PKG_CREATE?=	pkg_create
SYSTEM_PKG_DELETE?=	pkg_delete
SYSTEM_PKG_INFO?=	pkg_info
#
TEST_EXPDIR?=		${.CURDIR}/exp
TEST_HTTPD?=		${.CURDIR}/bin/httpd
TEST_PACKAGEDIR?=	${.CURDIR}/pkg
TEST_SRCDIR?=		${.CURDIR}/suite
TEST_WORKDIR?=		${.CURDIR}/.work
TEST_BUILDINFO?=	${TEST_WORKDIR}/build-info.default
TEST_LOCALBASE?=	${TEST_WORKDIR}/local
TEST_VARBASE?=		${TEST_WORKDIR}/var
TEST_PKG_DBDIR?=	${TEST_VARBASE}/db/pkg
TEST_PKGIN_DBDIR?=	${TEST_VARBASE}/db/pkgin
TEST_PKGIN_DB?=		${TEST_PKGIN_DBDIR}/pkgin.db
TEST_PKGIN_CACHE?=	${TEST_PKGIN_DBDIR}/cache
TEST_PKGIN_SQL_LOG?=	${TEST_PKGIN_DBDIR}/sql.log
TEST_PKG_INSTALL_LOG?=	${TEST_PKGIN_DBDIR}/pkg_install-err.log
#
# Generate substitution variables used later.
#
.for var in SYSTEM_BATS SYSTEM_PKGIN SYSTEM_PKG_ADD SYSTEM_PKG_ADMIN \
	    SYSTEM_PKG_CREATE SYSTEM_PKG_DELETE SYSTEM_PKG_INFO
SYSTEM_SUBST+=	-e 's,@${var}@,${${var}:Q},g'
.endfor
.for var in TEST_EXPDIR TEST_HTTPD TEST_PACKAGEDIR TEST_SRCDIR TEST_WORKDIR \
	    TEST_BUILDINFO TEST_LOCALBASE TEST_VARBASE TEST_PKG_DBDIR \
	    TEST_PKGIN_DBDIR TEST_PKGIN_DB TEST_PKGIN_CACHE \
	    TEST_PKGIN_SQL_LOG TEST_PKG_INSTALL_LOG
TEST_SUBST+=	-e 's,@${var}@,${${var}:Q},g'
.endfor


#
# Set some per-repository and per-package build variables used later.
#
REPOSITORIES=			repo-0 repo-1 repo-2 repo-3 repo-4 repo-5 repo-6
#
# Repositories have a specific set of packages available, to enable testing of
# various scenarios.
#
#	repo-0	Empty package list, tests initialisation.
#	repo-1	Initial package list, basic installs and downloads.
#	repo-2	Upgraded package list, upgrades and removals.
#	repo-3	Conflicts.
#	repo-4	Removals.
#	repo-5	Download failures.
#
REPO_PKGLIST.repo-0=		# empty
#
REPO_PKGLIST.repo-1=		keep-1.0 pkgpath-1.0 upgrade-1.0 builddate-1.0
REPO_PKGLIST.repo-1+=		deptree-top-1.0 deptree-middle-1.0
REPO_PKGLIST.repo-1+=		deptree-bottom-1.0
REPO_PKGLIST.repo-1+=		supersedes-1.0 supersedes-dep-1.0
#
REPO_PKGLIST.repo-2=		keep-1.0 pkgpath-2.0 upgrade-2.0 builddate-1.0
REPO_PKGLIST.repo-2+=		deptree-middle-2.0 deptree-top-2.0 supersedes-2.0
#
REPO_PKGLIST.repo-3=		conflict-pkgcfl-1.0 conflict-plist-1.0
REPO_PKGLIST.repo-3+=		provides-1.0 requires-1.0
#
REPO_PKGLIST.repo-4=		keep-1.0 download-ok-1.0 download-notfound-1.0
#
REPO_PKGLIST.repo-5=		download-ok-1.0 download-notfound-1.0
REPO_PKGLIST.repo-5+=		download-truncate-1.0 download-mismatch-1.0
#
REPO_PKGLIST.repo-6=		badfilesize-1.0 badsizepkg-1.0
#
# Ensure that BUILD_DATE changes between repo-1 and repo-2 so that we can test
# the refresh functionality.  Set the default somewhere in between to test for
# it going backwards (currently unsupported, it's just a string compare).
#
REPO_VARS+=			REPO_BUILD_DATE
REPO_BUILD_DATE.repo-1=		2018-02-26 12:34:56 +0000
REPO_BUILD_DATE.repo-2=		2018-02-26 12:34:58 +0000
REPO_BUILD_DATE=		2018-02-26 12:34:57 +0000
#
# Repository URL.  This is handled specially later to extract the port, etc.
# If left undefined then a plain path is used.
#
REPO_VARS+=			REPO_URL
REPO_URL.repo-0=		http://127.0.0.1:57190
REPO_URL.repo-1=		http://127.0.0.1:57191
REPO_URL.repo-2=		file://
REPO_URL.repo-5=		http://127.0.0.1:57195
REPO_URL.repo-6=		http://127.0.0.1:57196
#
# Test different pkg_summary compression schemes.
#
REPO_SUM_COMPRESSION.repo-5=	bzip2 gzip
REPO_SUM_COMPRESSION=		gzip
#
# Per-package package compression.  This is important for the BUILD_DATE test
# as we need to ensure that nothing other than the BUILD_DATE changes, and if
# using compression the FILE_SIZE might change too and mask failure modes.
#
PKG_VARS+=			PKG_COMPRESSION
PKG_COMPRESSION.builddate-1.0=	none
PKG_COMPRESSION=		gzip
#
# Create some absurd sizes to test failure scenarios.
#
REPO_FILTER.repo-6=		awk '/^PKGNAME/{p=($$1 ~ /=badfilesize/) ? 1 : 0} /^FILE_SIZE/ {if (p) {sub(/=.*/, "=09876543210987654321")}} {print}'
PKG_SIZE_PKG.badsizepkg-1.0=	12345678901234567890

#
# All configuration should be done by this point.  Start generating the test
# suite files.
#
# Top-level targets.  Add some helpful aliases, because why not.
#
all check test: bats-test
tap: bats-tap


#
# Generate the default build-info file.  This contains the absolute minimum
# required by pkg_install to create a valid package, and the values are taken
# directly from the system pkg_install.  This ensures we use the correct values
# for MACHINE_ARCH, OPSYS, etc.
#
BI_VARS=	MACHINE_ARCH OPSYS OS_VERSION PKGTOOLS_VERSION
.for var in ${BI_VARS}
BI_${var}!=	${SYSTEM_PKG_INFO} -Q ${var} pkg_install
.endfor
${TEST_BUILDINFO}: ${.MAKE.MAKEFILES}
	@mkdir -p ${.TARGET:H:Q}
	@rm -f ${.TARGET:Q}
.for var in ${BI_VARS}
	@echo '${var}=${BI_${var}:Q}' >>${.TARGET:Q}
.endfor


#
# Generate the repositories.
#
.for repo in ${REPOSITORIES}
REPO_NAME.${repo}=		${repo}
REPO_BINDIR.${repo}=		${TEST_WORKDIR}/${repo}/bin
REPO_EXPDIR.${repo}=		${TEST_EXPDIR}/${repo}
REPO_OUTDIR.${repo}=		${TEST_WORKDIR}/${repo}/out
REPO_WRKDIR.${repo}=		${TEST_WORKDIR}/${repo}
REPO_PACKAGES.${repo}=		${TEST_WORKDIR}/${repo}/packages
REPO_PKG_INSTALL_DIR.${repo}=	${REPO_BINDIR.${repo}}
#
.  if !empty(REPO_URL.${repo}:Mhttp*)
REPO_HTTP_PORT.${repo}=		${REPO_URL.${repo}:C/.*://}
REPO_PKG_PATH.${repo}=		${REPO_URL.${repo}}
.  elif !empty(REPO_URL.${repo}:Mfile*)
REPO_HTTP_PORT.${repo}=
REPO_PKG_PATH.${repo}=		${REPO_URL.${repo}}${REPO_PACKAGES.${repo}:Q}
.  else
REPO_HTTP_PORT.${repo}=
REPO_PKG_PATH.${repo}=		${REPO_PACKAGES.${repo}:Q}
.  endif
#
REPO_VARS+=			REPO_NAME REPO_BINDIR REPO_EXPDIR REPO_OUTDIR
REPO_VARS+=			REPO_WRKDIR REPO_PACKAGES REPO_PKG_INSTALL_DIR
REPO_VARS+=			REPO_HTTP_PORT REPO_PKG_PATH
#
# Generate pkg* wrappers.  Each repository gets its own wrapper so that we
# can run them standalone if necessary as it is helpful for debugging.
#
REPO_PKG_ADD_ARGS.${repo}=	-C /dev/null
REPO_PKG_ADMIN_ARGS.${repo}=	-C /dev/null
.  for pkgcmd in pkg_add pkg_admin pkg_create pkg_delete pkg_info
REPO_${pkgcmd:tu}.${repo}=	${REPO_BINDIR.${repo}}/${pkgcmd}
REPO_DEPS.${repo}+=		${REPO_${pkgcmd:tu}.${repo}}
REPO_VARS+=			REPO_${pkgcmd:tu}
${REPO_${pkgcmd:tu}.${repo}}: ${.MAKE.MAKEFILES}
	@echo '=> Generating ${.TARGET:Q}'
	@mkdir -p ${.TARGET:H:Q}
	@echo '#!/bin/sh' >${.TARGET:Q}
	@echo ': $${PKG_PATH:=${REPO_PKG_PATH.${repo}}}' >>${.TARGET:Q}
	@echo ': $${PKG_DBDIR:=${TEST_PKG_DBDIR}}' >>${.TARGET:Q}
	@echo 'env PKG_PATH=$${PKG_PATH} \\' >>${.TARGET:Q}
	@echo '    ${SYSTEM_${pkgcmd:tu}} -K $${PKG_DBDIR}' \
		   '${REPO_${pkgcmd:tu}_ARGS.${repo}}' \
		   '"$$@"' >>${.TARGET:Q}
	@chmod +x ${.TARGET:Q}
.  endfor
REPO_PKGIN.${repo}=		${REPO_BINDIR.${repo}}/pkgin
REPO_DEPS.${repo}+=		${REPO_PKGIN.${repo}}
REPO_VARS+=			REPO_PKGIN
${REPO_PKGIN.${repo}}: ${.MAKE.MAKEFILES}
	@echo '=> Generating ${.TARGET:Q}'
	@mkdir -p ${.TARGET:H:Q}
	@echo '#!/bin/sh' >${.TARGET:Q}
	@echo ': $${PKGIN_DBDIR:=${TEST_PKGIN_DBDIR}}' >>${.TARGET:Q}
	@echo ': $${PKG_INSTALL_DIR:=${REPO_BINDIR.${repo}}}' >>${.TARGET:Q}
	@echo ': $${PKG_DBDIR:=${TEST_PKG_DBDIR}}' >>${.TARGET:Q}
	@echo ': $${PKG_REPOS:=${REPO_PKG_PATH.${repo}}}' >>${.TARGET:Q}
	@echo 'env PKGIN_DBDIR=$${PKGIN_DBDIR} \\' >>${.TARGET:Q}
	@echo '    PKG_INSTALL_DIR=$${PKG_INSTALL_DIR} \\' >>${.TARGET:Q}
	@echo '    PKG_DBDIR=$${PKG_DBDIR} \\' >>${.TARGET:Q}
	@echo '    PKG_REPOS=$${PKG_REPOS} \\' >>${.TARGET:Q}
	@echo '    ${SYSTEM_PKGIN} "$$@"' >>${.TARGET:Q}
	@chmod +x ${.TARGET:Q}
REPO_HTTPD.${repo}=		${REPO_BINDIR.${repo}}/httpd
REPO_DEPS.${repo}+=		${REPO_HTTPD.${repo}}
REPO_VARS+=			REPO_HTTPD
${REPO_HTTPD.${repo}}: ${.MAKE.MAKEFILES}
	@echo '=> Generating ${.TARGET:Q}'
	@mkdir -p ${.TARGET:H:Q}
	@echo '#!/bin/sh' >${.TARGET:Q}
	@echo ': $${REPO_HTTP_PORT:=${REPO_HTTP_PORT.${repo}:Q}}' >>${.TARGET:Q}
	@echo ': $${REPO_HTTPD_ERR:=${REPO_OUTDIR.${repo}:Q}/httpd.err}' >>${.TARGET:Q}
	@echo ': $${REPO_HTTPD_LOG:=${REPO_OUTDIR.${repo}:Q}/httpd.log}' >>${.TARGET:Q}
	@echo ': $${REPO_PACKAGES:=${REPO_PACKAGES.${repo}:Q}}' >>${.TARGET:Q}
	@echo ': $${TEST_HTTPD:=${TEST_HTTPD:Q}}' >>${.TARGET:Q}
	@echo 'sockopts="reuseaddr,reuseport,fork,keepalive"' >>${.TARGET:Q}
	@echo 'pkgopts="-p $${REPO_PACKAGES}"' >>${.TARGET:Q}
	@echo 'dbgopts="-d $${REPO_HTTPD_LOG} -e $${REPO_HTTPD_ERR}"' >>${.TARGET:Q}
	# Uses 'exec' to ensure pid passed back via $! is correct.
	@echo 'exec socat tcp-listen:$${REPO_HTTP_PORT},$${sockopts}' \
		'system:"$${TEST_HTTPD} $${pkgopts} $${dbgopts}"' >>${.TARGET:Q}
	@chmod +x ${.TARGET:Q}
#
# Generate REPO_VARS
#
.  for var in ${REPO_VARS}
REPO_SUBST.${repo}+=		-e 's,@${var}@,${${var}.${repo}:Q},g'
.  endfor
#
# Generate packages
#
.  for pkg in ${REPO_PKGLIST.${repo}}
PKG_PKGDIR.${repo}.${pkg}=	${TEST_PACKAGEDIR}/${pkg}
PKG_BUILDINFO.${repo}.${pkg}=	${PKG_PKGDIR.${repo}.${pkg}}/BUILD_INFO
PKG_COMMENT.${repo}.${pkg}=	${PKG_PKGDIR.${repo}.${pkg}}/COMMENT
PKG_DESCR.${repo}.${pkg}=	${PKG_COMMENT.${repo}.${pkg}}
PKG_FILES.${repo}.${pkg}=	${PKG_PKGDIR.${repo}.${pkg}}/files
PKG_PLIST.${repo}.${pkg}=	${PKG_PKGDIR.${repo}.${pkg}}/PLIST
PKGFILE.${repo}.${pkg}=		${REPO_PACKAGES.${repo}}/${pkg}.tgz
PKGFILES.${repo}+=		${PKGFILE.${repo}.${pkg}}
#
# Generate PKG_VARS
#
.  for var in ${PKG_VARS}
PKG_SUBST.${repo}.${pkg}+=	-e 's,@${var}@,${${var}.${pkg}:Q},g'
.  endfor
#
#  - Generated combined +BUILD_INFO file.
#
REPOPKG_BUILDINFO.${repo}.${pkg}:=	${REPO_WRKDIR.${repo}}/build-info/${pkg}
.    if exists(${PKG_BUILDINFO.${repo}.${pkg}})
${REPOPKG_BUILDINFO.${repo}.${pkg}}: ${PKG_BUILDINFO.${repo}.${pkg}}
.    endif
${REPOPKG_BUILDINFO.${repo}.${pkg}}: ${TEST_BUILDINFO}
	#@echo '=> Generating ${.TARGET:Q}'
	@mkdir -p ${.TARGET:H:Q}
	@cat ${TEST_BUILDINFO} >${.TARGET:Q}
.    if exists(${PKG_BUILDINFO.${repo}.${pkg}})
	@sed ${SYSTEM_SUBST} ${TEST_SUBST} ${REPO_SUBST.${repo}} \
		${PKG_SUBST.${repo}${pkg}} ${PKG_BUILDINFO.${repo}.${pkg}} \
		>>${.TARGET:Q}
.    endif
#
#  - Generate files.
#
.    if exists(${PKG_FILES.${repo}.${pkg}})
REPOPKG_FILES.${repo}.${pkg}:=		${PKG_FILES.${repo}.${pkg}}
.    else
REPOPKG_FILES.${repo}.${pkg}:=		${REPO_WRKDIR.${repo}}/files/${pkg}
${REPOPKG_FILES.${repo}.${pkg}}:
	#@echo '=> Generating ${.TARGET:Q}'
	@mkdir -p ${.TARGET:Q}/share/doc
	@echo ${pkg} >${.TARGET:Q}/share/doc/${pkg:C/-[0-9].*//}
.    endif
#
#  - Generate PLIST.
#
REPOPKG_PLIST.${repo}.${pkg}:=		${REPO_WRKDIR.${repo}}/plist/${pkg}
${REPOPKG_PLIST.${repo}.${pkg}}: ${REPOPKG_FILES.${repo}.${pkg}}
	#@echo '=> Generating ${.TARGET:Q}'
	@mkdir -p ${.TARGET:H:Q}
	@(cd ${REPOPKG_FILES.${repo}.${pkg}}; find * -type f) >${.TARGET:Q}
.    if exists(${PKG_PLIST.${repo}.${pkg}})
	@cat ${PKG_PLIST.${repo}.${pkg}} >>${.TARGET:Q}
.    endif
#
#  - Generate +SIZE_PKG file.  Only handles static files for now.
#
PKGREPO_SIZEPKG.${repo}.${pkg}=	${REPO_WRKDIR.${repo}}/size-pkg/${pkg}
${PKGREPO_SIZEPKG.${repo}.${pkg}}: ${REPOPKG_PLIST.${repo}.${pkg}}
	@mkdir -p ${.TARGET:H:Q}
.  if defined(PKG_SIZE_PKG.${pkg})
	@echo ${PKG_SIZE_PKG.${pkg}} >${.TARGET}
.  else
	@cat ${REPOPKG_PLIST.${repo}.${pkg}} | \
	    awk '/^@/ { next } \
		 { print $$0 }' | \
	    sort -u | sed -e 's,^,${REPOPKG_FILES.${repo}.${pkg}}/,' | \
	    xargs -n 256 ls -ld 2>/dev/null | \
	    awk 'BEGIN { s = 0 } { s += $$5 } END { print s }' \
	      > ${.TARGET}
.  endif
#
#  - Generate package.
#
${PKGFILE.${repo}.${pkg}}: ${REPOPKG_BUILDINFO.${repo}.${pkg}}
${PKGFILE.${repo}.${pkg}}: ${PKGREPO_SIZEPKG.${repo}.${pkg}}
${PKGFILE.${repo}.${pkg}}: ${PKGREPO_FILES.${repo}.${pkg}}
${PKGFILE.${repo}.${pkg}}: ${PKG_COMMENT.${repo}.${pkg}} ${PKG_DESCR.${repo}.${pkg}}
${PKGFILE.${repo}.${pkg}}: ${REPOPKG_PLIST.${repo}.${pkg}}
	@echo '=> Generating ${.TARGET:Q}'
	@mkdir -p ${.TARGET:H:Q}
	# pkg_create can fail and leave files around.
	@if ! ${SYSTEM_PKG_CREATE} \
	    -B ${REPOPKG_BUILDINFO.${repo}.${pkg}} \
	    -c ${PKG_COMMENT.${repo}.${pkg}} \
	    -d ${PKG_DESCR.${repo}.${pkg}} \
	    -F ${PKG_COMPRESSION.${pkg}:U${PKG_COMPRESSION}} \
	    -f ${REPOPKG_PLIST.${repo}.${pkg}} \
	    -I ${TEST_LOCALBASE} \
	    -p ${REPOPKG_FILES.${repo}.${pkg}} \
	    -s ${PKGREPO_SIZEPKG.${repo}.${pkg}} \
	    ${.TARGET:Q}; then \
		rm -f ${.TARGET:Q}; exit 1; \
	fi
.  endfor
#
# Generate pkg_summary files for each repository.
#
_COMPRESS_CMD.gzip=	gzip -9
_COMPRESS_OUT.gzip=	pkg_summary.gz
_COMPRESS_CMD.bzip2=	bzip2 -9
_COMPRESS_OUT.bzip2=	pkg_summary.bz2
.  for c in gzip bzip2
.    if !empty(REPO_SUM_COMPRESSION.${repo}:U${REPO_SUM_COMPRESSION}:M${c})
REPO_DEPS.${repo}+=		${REPO_PACKAGES.${repo}}/${_COMPRESS_OUT.${c}}
${REPO_PACKAGES.${repo}}/${_COMPRESS_OUT.${c}}: ${PKGFILES.${repo}}
	@echo '=> Generating ${.TARGET:Q}'
	@mkdir -p ${.TARGET:H:Q}
.      if defined(PKGFILES.${repo})
	@${SYSTEM_PKG_INFO} -X ${PKGFILES.${repo}} \
		| ${REPO_FILTER.${repo}:Ucat} \
		| ${_COMPRESS_CMD.${c}} >${.TARGET:Q}
.      else
	@echo | ${_COMPRESS_CMD.${c}} >${.TARGET:Q}
.      endif
.    endif
.  endfor
#
# Generate per-repository bats test scripts.
#
BATS_HEADER=			${TEST_SRCDIR}/header.sh
BATS_FOOTER=			${TEST_SRCDIR}/footer.sh
BATS_TESTRUN.${repo}=		${REPO_BINDIR.${repo}}/test-run
BATS_SRC.${repo}=		${TEST_SRCDIR}/${repo}.sh
BATS_TESTS+=			${BATS_TESTRUN.${repo}}
${BATS_TESTRUN.${repo}}: ${.MAKE.MAKEFILES}
${BATS_TESTRUN.${repo}}: ${REPO_DEPS.${repo}}
${BATS_TESTRUN.${repo}}: ${BATS_HEADER} ${BATS_SRC.${repo}} ${BATS_FOOTER}
	@echo '=> Generating ${.TARGET:Q}'
	@mkdir -p ${.TARGET:H:Q}
	@sed ${SYSTEM_SUBST} ${TEST_SUBST} ${REPO_SUBST.${repo}} \
		${BATS_HEADER} ${BATS_SRC.${repo}} ${BATS_FOOTER} \
		>${.TARGET:Q}
.endfor

#
# Always run the tests.  The tests themselves ensure a clean LOCALBASE
# prior to each run.
#
.PHONY: bats-test
bats-test: ${BATS_TESTS}
	@echo '=> Running test suite'
	@${SYSTEM_BATS} ${BATS_TESTS}

.PHONY: bats-tap
bats-tap: ${BATS_TESTS}
	@echo '=> Running test suite (tap output)'
	@${SYSTEM_BATS} --tap ${BATS_TESTS}

clean:
	@echo '=> Cleaning work directory'
	@rm -rf ${TEST_WORKDIR:U/nonexistent}

#
# Helpful debug targets.
#
show-var:
	@echo ${${VARNAME}:Q}
