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
# XXX: must not be substring of PKGIN_DBDIR to avoid pkg_info PKG_DBDIR bugs
TEST_PKG_DBDIR?=	${TEST_VARBASE}/db/pkgdb
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
# List of test repositories.  Order is important as some tests (e.g. upgrades)
# require state from a prior test run.
#
REPOSITORIES+=		empty		# Tests against an empty repository
REPOSITORIES+=		install		# Test basic package installs
REPOSITORIES+=		upgrade		# Test package upgrades
REPOSITORIES+=		conflict	# Test package conflicts
REPOSITORIES+=		invalid		# Test invalid packages
REPOSITORIES+=		file-dl		# Test file:// downloads
REPOSITORIES+=		http-dl		# Test http:// downloads
#
# Per-repository variables and their defaults.  Repositories set their own
# using <REPO_VAR>.<repo>
#
#	REPO_NAME is used in the test suite scripts to print the name of the
#	test suite for each test.  Mandatory for each repository.
#
REPO_VARS+=		REPO_NAME
REPO_NAME.empty=	empty-repository
REPO_NAME.install=	package-installs
REPO_NAME.upgrade=	package-upgrades
REPO_NAME.conflict=	package-conflicts
REPO_NAME.invalid=	invalid-packages
REPO_NAME.file-dl=	file-downloads
REPO_NAME.http-dl=	http-downloads
#
#	REPO_PKGLIST contains a list of packages from pkg/ that are included
#	in the pkg_summary for this repository.  Mandatory, even if empty.
#	Note that pkgin-0.9.4 does not work against an empty pkgdb, so it is
#	helpful to at least install keep-1.0 via pkg_add before starting tests.
#
REPO_VARS+=		REPO_PKGLIST
REPO_PKGLIST.empty=	# no packages by design
REPO_PKGLIST.install=	keep-1.0 pkgpath-1.0 upgrade-1.0
REPO_PKGLIST.install+=	deptree-top-1.0 deptree-middle-1.0 deptree-bottom-1.0
#REPO_PKGLIST.install+=	supersedes-1.0 supersedes-dep-1.0
REPO_PKGLIST.upgrade=	keep-1.0 pkgpath-1.0 pkgpath-2.0 upgrade-2.0
REPO_PKGLIST.upgrade+=	deptree-middle-2.0 deptree-top-2.0 # supersedes-2.0
REPO_PKGLIST.conflict=	conflict-pkgcfl-1.0 conflict-plist-1.0
REPO_PKGLIST.conflict+=	provides-1.0 requires-1.0
REPO_PKGLIST.invalid=	badfilesize-1.0 badsizepkg-1.0 badsum-1.0
REPO_PKGLIST.file-dl=	keep-1.0 download-ok-1.0 download-notfound-1.0
REPO_PKGLIST.file-dl+=	download-truncate-1.0 download-mismatch-1.0
REPO_PKGLIST.http-dl=	keep-1.0 download-ok-1.0 download-notfound-1.0
REPO_PKGLIST.http-dl+=	download-truncate-1.0 download-mismatch-1.0
#
#	REPO_EPOCH is used to ensure each repository is build with different
#	date information.  This is used to generate BUILD_DATE for packages,
#	touch the pkg_summary to indicate it has been changed, and by the
#	httpd to report the last modified date of files it serves.
#
REPO_VARS+=		REPO_EPOCH
REPO_EPOCH.empty=	00
REPO_EPOCH.install=	01
REPO_EPOCH.upgrade=	02
REPO_EPOCH.conflict=	03
REPO_EPOCH.invalid=	04
REPO_EPOCH.file-dl=	05
REPO_EPOCH.http-dl=	06
#
#	REPO_URL sets the base URL for the repository.  The default uses our
#	custom httpd which helps to generate certain failure modes.
#
REPO_VARS+=		REPO_URL
REPO_URL=		http://127.0.0.1:57191
REPO_URL.file-dl=	file://
#
#	REPO_SUBST is used to supply arbitrary substitutions in the test
#	script, useful to avoid hardcoding package names etc.  This is used
#	later to substitute REPO_VARS so does not need to be added to itself.
#
REPO_SUBST=		# empty
REPO_SUBST.file-dl+=	-e 's,@PKG_OK@,download-ok-1.0,g'
REPO_SUBST.file-dl+=	-e 's,@PKG_NOTFOUND@,download-notfound-1.0,g'
REPO_SUBST.file-dl+=	-e 's,@PKG_TRUNCATE@,download-truncate-1.0,g'
REPO_SUBST.file-dl+=	-e 's,@PKG_MISMATCH@,download-mismatch-1.0,g'
REPO_SUBST.http-dl+=	-e 's,@PKG_OK@,download-ok-1.0,g'
REPO_SUBST.http-dl+=	-e 's,@PKG_NOTFOUND@,download-notfound-1.0,g'
REPO_SUBST.http-dl+=	-e 's,@PKG_TRUNCATE@,download-truncate-1.0,g'
REPO_SUBST.http-dl+=	-e 's,@PKG_MISMATCH@,download-mismatch-1.0,g'


#
# Per-package variables and their defaults.
#
#	PKG_COMMENT sets the COMMENT field for a package.
#
PKG_VARS+=			PKG_COMMENT
PKG_COMMENT.badfilesize-1.0=	"Package has a FILE_SIZE larger than available"
PKG_COMMENT.badsizepkg-1.0=	"Package has a SIZE_PKG larger than available"
PKG_COMMENT.badsum-1.0=		"Package has missing or invalid pkg_summary entries"
PKG_COMMENT.conflict-pkgcfl-1.0=\
				"Package should conflict with keep-1.0 (@pkgcfl conflict)"
PKG_COMMENT.conflict-plist-1.0=	\
				"Package should conflict with keep-1.0 (PLIST conflict)"
PKG_COMMENT.deptree-bottom-1.0=	"Package is at the bottom of a dependency tree"
PKG_COMMENT.deptree-middle-1.0=	"Package is in the middle of a dependency tree"
PKG_COMMENT.deptree-middle-2.0=	"Package is in the middle of a dependency tree"
PKG_COMMENT.deptree-top-1.0=	"Package is at the top of a dependency tree"
PKG_COMMENT.deptree-top-2.0=	"Package is at the top of a dependency tree"
PKG_COMMENT.download-mismatch-1.0=\
				"Package tests download failure (mismatch with pkg_summary)"
PKG_COMMENT.download-notfound-1.0=\
				"Package tests download failure (404 Not Found)"
PKG_COMMENT.download-ok-1.0=	"Package tests download success"
PKG_COMMENT.download-truncate-1.0=	\
				"Package tests incorrect pkgin cache"
PKG_COMMENT.keep-1.0=		"Package should remain at all times"
PKG_COMMENT.pkgpath-1.0=	"Package should not be upgraded by newer pkgpath"
PKG_COMMENT.pkgpath-2.0=	"Package should not be upgraded by newer pkgpath"
PKG_COMMENT.provides-1.0=	"Package provides libprovides.so"
PKG_COMMENT.requires-1.0=	"Package requires libprovides.so"
PKG_COMMENT.supersedes-1.0=	"Package will be superseded by 2.0"
PKG_COMMENT.supersedes-2.0=	"Package supersedes both supersedes-1.0 and supersedes-dep-1.0"
PKG_COMMENT.supersedes-dep-1.0=	"Dependency of supersedes-1.0, conflicts with supersedes-2.0"
PKG_COMMENT.upgrade-1.0=	"Package should be upgraded to newer upgrade"
PKG_COMMENT.upgrade-2.0=	"Package should be upgraded over older upgrade package"
#
#	PKG_COMPRESSION sets the compression type for a package.  Default is
#	"none" as packages may be dependent upon FILE_SIZE which can differ
#	depending on various things.
#
PKG_VARS+=			PKG_COMPRESSION
PKG_COMPRESSION=		none
#
#	PKG_SUMFILTER is a command that the "pkg_info -X" summary generation
#	is passed through, allowing for modifications to the data.  Note that
#	calling pkg_info within a test run will still return the original data,
#	which is why we have PKG_PKGPATH etc below to enforce both.
#
PKG_VARS+=			PKG_SUMFILTER
PKG_SUMFILTER=			cat
PKG_SUMFILTER.badfilesize-1.0=	sed -e '/^FILE_SIZE/s/=.*/=987654321987654321/'
PKG_SUMFILTER.badsizepkg-1.0=	sed -e '/^SIZE_PKG/s/=.*/=123456789123456789/'
PKG_SUMFILTER.badsum-1.0=	sed -e '/^BUILD_DATE/d'
#
#	PKG_PKGPATH sets PKGPATH for the specified package, otherwise a default
#	of "testsuite/<pkg>" is used.
#
PKG_VARS+=			PKG_PKGPATH
PKG_PKGPATH.pkgpath-1.0=	testsuite/pkgpath1
PKG_PKGPATH.pkgpath-2.0=	testsuite/pkgpath2
#
#	Mark package as PRESERVE, i.e. should not be deleted.
#
PKG_VARS+=			PKG_PRESERVE
PKG_PRESERVE.keep-1.0=		# defined


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
# required by pkg_install to create a valid package.  Unfortunately we can't
# determine these from pkg_install as it may be part of the base system, so
# we have to somewhat hardcode for now.
#
BI_VARS=	MACHINE_ARCH OPSYS OS_VERSION PKGTOOLS_VERSION
BI_MACHINE_ARCH=	${MACHINE_ARCH}
BI_OPSYS!=		uname -s
BI_OS_VERSION!=		uname -r
BI_PKGTOOLS_VERSION=	20091115
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
REPO_BINDIR.${repo}=		${TEST_WORKDIR}/${repo}/bin
REPO_EXPDIR.${repo}=		${TEST_EXPDIR}/${repo}
REPO_OUTDIR.${repo}=		${TEST_WORKDIR}/${repo}/out
REPO_WRKDIR.${repo}=		${TEST_WORKDIR}/${repo}
REPO_PACKAGES.${repo}=		${TEST_WORKDIR}/${repo}/packages
REPO_PKG_INSTALL_DIR.${repo}=	${REPO_BINDIR.${repo}}
#
.  if !defined(REPO_URL.${repo})
REPO_URL.${repo}=		${REPO_URL}
.  endif
.  if !empty(REPO_URL.${repo}:Mhttp*)
REPO_HTTP_PORT.${repo}=		${REPO_URL.${repo}:C/.*://}
REPO_PKG_PATH.${repo}=		${REPO_URL.${repo}}
.  elif !empty(REPO_URL.${repo}:Mfile*)
REPO_HTTP_PORT.${repo}=
REPO_PKG_PATH.${repo}=		file://${REPO_PACKAGES.${repo}:Q}
.  endif
#
# Time formats.  BUILD_DATE for pkg_create matching what pkgsrc uses,
# HTTPD_TIME in HTTP format for the httpd, and TOUCH for touch(1).
#
REPO_BUILD_DATE.${repo}=	2018-02-26 12:34:${REPO_EPOCH.${repo}} +0000
REPO_HTTPD_TIME.${repo}=	Mon, 26 Feb 2018 12:34:${REPO_EPOCH.${repo}} GMT
REPO_TOUCH.${repo}=		201802261234.${REPO_EPOCH.${repo}}
#
REPO_VARS+=			REPO_BINDIR REPO_EXPDIR REPO_OUTDIR
REPO_VARS+=			REPO_WRKDIR REPO_PACKAGES REPO_PKG_INSTALL_DIR
REPO_VARS+=			REPO_HTTP_PORT REPO_PKG_PATH
REPO_VARS+=			REPO_BUILD_DATE REPO_LAST_MODIFIED REPO_TOUCH
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
	@echo "=> Generating ${.TARGET:Q}"
	@mkdir -p ${.TARGET:H:Q}
	@echo "#!/bin/sh" >${.TARGET:Q}
	@echo ": \$${PKG_PATH:=${REPO_PKG_PATH.${repo}}}" >>${.TARGET:Q}
	@echo ": \$${PKG_DBDIR:=${TEST_PKG_DBDIR}}" >>${.TARGET:Q}
	@echo "env PKG_PATH=\$${PKG_PATH} \\" >>${.TARGET:Q}
	@echo "    ${SYSTEM_${pkgcmd:tu}} -K \$${PKG_DBDIR}" \
		   "${REPO_${pkgcmd:tu}_ARGS.${repo}}" \
		   "\"\$$@\"" >>${.TARGET:Q}
	@chmod +x ${.TARGET:Q}
.  endfor
REPO_PKGIN.${repo}=		${REPO_BINDIR.${repo}}/pkgin
REPO_DEPS.${repo}+=		${REPO_PKGIN.${repo}}
REPO_VARS+=			REPO_PKGIN
${REPO_PKGIN.${repo}}: ${.MAKE.MAKEFILES}
	@echo "=> Generating ${.TARGET:Q}"
	@mkdir -p ${.TARGET:H:Q}
	@echo "#!/bin/sh" >${.TARGET:Q}
	@echo ": \$${PKGIN_DBDIR:=${TEST_PKGIN_DBDIR}}" >>${.TARGET:Q}
	@echo ": \$${PKG_INSTALL_DIR:=${REPO_BINDIR.${repo}}}" >>${.TARGET:Q}
	@echo ": \$${PKG_DBDIR:=${TEST_PKG_DBDIR}}" >>${.TARGET:Q}
	@echo ": \$${PKG_REPOS:=${REPO_PKG_PATH.${repo}}}" >>${.TARGET:Q}
	@echo ": \$${SYSTEM_PKGIN:=${SYSTEM_PKGIN}}" >>${.TARGET:Q}
	@echo "env PKGIN_DBDIR=\$${PKGIN_DBDIR} \\" >>${.TARGET:Q}
	@echo "    PKG_INSTALL_DIR=\$${PKG_INSTALL_DIR} \\" >>${.TARGET:Q}
	@echo "    PKG_DBDIR=\$${PKG_DBDIR} \\" >>${.TARGET:Q}
	@echo "    PKG_REPOS=\$${PKG_REPOS} \\" >>${.TARGET:Q}
	@echo "    \$${SYSTEM_PKGIN} \"\$$@\"" >>${.TARGET:Q}
	@chmod +x ${.TARGET:Q}
REPO_HTTPD.${repo}=		${REPO_BINDIR.${repo}}/httpd
REPO_DEPS.${repo}+=		${REPO_HTTPD.${repo}}
REPO_VARS+=			REPO_HTTPD
${REPO_HTTPD.${repo}}: ${.MAKE.MAKEFILES}
	@echo "=> Generating ${.TARGET:Q}"
	@mkdir -p ${.TARGET:H:Q}
	@echo "#!/bin/sh" >${.TARGET:Q}
	@echo ": \$${REPO_HTTP_PORT:=${REPO_HTTP_PORT.${repo}:Q}}" >>${.TARGET:Q}
	@echo ": \$${REPO_HTTPD_TIME:=${REPO_HTTPD_TIME.${repo}}}" >>${.TARGET:Q}
	@echo ": \$${REPO_HTTPD_ERR:=${REPO_OUTDIR.${repo}:Q}/httpd.err}" >>${.TARGET:Q}
	@echo ": \$${REPO_HTTPD_LOG:=${REPO_OUTDIR.${repo}:Q}/httpd.log}" >>${.TARGET:Q}
	@echo ": \$${REPO_PACKAGES:=${REPO_PACKAGES.${repo}:Q}}" >>${.TARGET:Q}
	@echo ": \$${TEST_HTTPD:=${TEST_HTTPD:Q}}" >>${.TARGET:Q}
	@echo "export REPO_PACKAGES REPO_HTTPD_TIME" >>${.TARGET:Q}
	@echo "export REPO_HTTPD_ERR REPO_HTTPD_LOG" >>${.TARGET:Q}
	@echo "sockopts=\"reuseaddr,fork,keepalive\"" >>${.TARGET:Q}
	# Uses "exec" to ensure pid passed back via $! is correct.
	@echo "exec socat tcp-listen:\$${REPO_HTTP_PORT},\$${sockopts}" \
		"system:\"\$${TEST_HTTPD}\"" >>${.TARGET:Q}
	@chmod +x ${.TARGET:Q}
#
# Generate REPO_VARS
#
.  for var in ${REPO_VARS}
REPO_SUBST.${repo}+=		-e 's,@${var}@,${${var}.${repo}:Q},g'
.  endfor
#
# Generate packages.  The eventual artefects are the individual pkg-summary
# files, rather than the package files.  This allows us to easily modify the
# pkg-summary files to provide bogus values.
#
.  for pkg in ${REPO_PKGLIST.${repo}}
PKG_PKGDIR.${repo}.${pkg}=	${TEST_PACKAGEDIR}/${pkg}
PKG_BUILDINFO.${repo}.${pkg}=	${PKG_PKGDIR.${repo}.${pkg}}/BUILD_INFO
PKG_FILES.${repo}.${pkg}=	${PKG_PKGDIR.${repo}.${pkg}}/files
PKG_PLIST.${repo}.${pkg}=	${PKG_PKGDIR.${repo}.${pkg}}/PLIST
PKGFILE.${repo}.${pkg}=		${REPO_PACKAGES.${repo}}/${pkg}.tgz
PKGSUMFILE.${repo}.${pkg}=	${REPO_WRKDIR.${repo}}/pkg-summary/${pkg}
PKGSUMFILES.${repo}+=		${PKGSUMFILE.${repo}.${pkg}}
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
	@mkdir -p ${.TARGET:H:Q}
	@cat ${TEST_BUILDINFO} >${.TARGET:Q}
	@echo "BUILD_DATE=${REPO_BUILD_DATE.${repo}}" >>${.TARGET:Q}
	@echo "PKGPATH=${PKG_PKGPATH.${pkg}:Utestsuite/${pkg:C/-[0-9].*$//}}" >>${.TARGET:Q}
.    if exists(${PKG_BUILDINFO.${repo}.${pkg}})
	@sed ${SYSTEM_SUBST} ${TEST_SUBST} ${REPO_SUBST.${repo}} \
		${PKG_SUBST.${repo}.${pkg}} ${PKG_BUILDINFO.${repo}.${pkg}} \
		>>${.TARGET:Q}
.    endif
#
#  - Generate COMMENT.  This triples up as the DESCR and PKG_PRESERVE file.
#
REPOPKG_COMMENT.${repo}.${pkg}:=	${REPO_WRKDIR.${repo}}/comment/${pkg}
${REPOPKG_COMMENT.${repo}.${pkg}}:
	@mkdir -p ${.TARGET:H:Q}
	@echo ${PKG_COMMENT.${pkg}} >>${.TARGET:Q}
#
#  - Generate files.
#
.    if exists(${PKG_FILES.${repo}.${pkg}})
REPOPKG_FILES.${repo}.${pkg}:=		${PKG_FILES.${repo}.${pkg}}
.    else
REPOPKG_FILES.${repo}.${pkg}:=		${REPO_WRKDIR.${repo}}/files/${pkg}
${REPOPKG_FILES.${repo}.${pkg}}:
	@mkdir -p ${.TARGET:Q}/share/doc
	@echo ${pkg} >${.TARGET:Q}/share/doc/${pkg:C/-[0-9].*//}
.    endif
#
#  - Generate PLIST.
#
REPOPKG_PLIST.${repo}.${pkg}:=		${REPO_WRKDIR.${repo}}/plist/${pkg}
${REPOPKG_PLIST.${repo}.${pkg}}: ${REPOPKG_FILES.${repo}.${pkg}}
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
.  if defined(PKG_SIZEPKG.${pkg})
	@echo ${PKG_SIZEPKG.${pkg}} >${.TARGET}
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
${PKGFILE.${repo}.${pkg}}: ${REPOPKG_COMMENT.${repo}.${pkg}}
${PKGFILE.${repo}.${pkg}}: ${REPOPKG_PLIST.${repo}.${pkg}}
	@echo '=> Generating ${.TARGET:Q}'
	@mkdir -p ${.TARGET:H:Q}
	# pkg_create can fail and leave files around.
	@if ! ${SYSTEM_PKG_CREATE} \
	    -B ${REPOPKG_BUILDINFO.${repo}.${pkg}} \
	    -c ${REPOPKG_COMMENT.${repo}.${pkg}} \
	    -d ${REPOPKG_COMMENT.${repo}.${pkg}} \
	    -F ${PKG_COMPRESSION.${pkg}:U${PKG_COMPRESSION}} \
	    -f ${REPOPKG_PLIST.${repo}.${pkg}} \
	    -I ${TEST_LOCALBASE} \
	    ${PKG_PRESERVE.${pkg}:D -n ${REPOPKG_COMMENT.${repo}.${pkg}}} \
	    -p ${REPOPKG_FILES.${repo}.${pkg}} \
	    -s ${PKGREPO_SIZEPKG.${repo}.${pkg}} \
	    ${.TARGET:Q}; then \
		rm -f ${.TARGET:Q}; exit 1; \
	fi
#
#  - Generate per-package pkg_summary files
#
${PKGSUMFILE.${repo}.${pkg}}: ${PKGFILE.${repo}.${pkg}}
	@echo '=> Generating ${.TARGET:Q}'
	@mkdir -p ${.TARGET:H:Q}
	@${SYSTEM_PKG_INFO} -X ${PKGFILE.${repo}.${pkg}} \
	    | ${PKG_SUMFILTER.${pkg}:U${PKG_SUMFILTER}} >${.TARGET:Q}
.  endfor
#
# Generate pkg_summary files for each repository.
#
_COMPRESS_CMD.gzip=	gzip -9
_COMPRESS_OUT.gzip=	pkg_summary.gz
_COMPRESS_CMD.bzip2=	bzip2 -9
_COMPRESS_OUT.bzip2=	pkg_summary.bz2
.  for c in gzip bzip2
REPO_DEPS.${repo}+=		${REPO_PACKAGES.${repo}}/${_COMPRESS_OUT.${c}}
${REPO_PACKAGES.${repo}}/${_COMPRESS_OUT.${c}}: ${PKGSUMFILES.${repo}}
	@echo '=> Generating ${.TARGET:Q}'
	@mkdir -p ${.TARGET:H:Q}
.    if defined(PKGSUMFILES.${repo})
	@cat ${PKGSUMFILES.${repo}} | ${_COMPRESS_CMD.${c}} >${.TARGET:Q}
.    else
	@echo | ${_COMPRESS_CMD.${c}} >${.TARGET:Q}
.    endif
	@touch -t ${REPO_TOUCH.${repo}} ${.TARGET:Q}
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
