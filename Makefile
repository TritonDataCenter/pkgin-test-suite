#
# The pkgin test suite.  Uses https://github.com/bats-core/bats-core for the
# test files, located under the suite/ directory.
#

BATS?=		bin/bats
BATS_JOBS?=	-j 1
PKGIN?=		pkgin

SUITES=		autoremove break-depends categories conflict empty
SUITES+=	file-dl file-size http-dl invalid order provreq
SUITES+=	install partial-upgrade upgrade
SUITES+=	switch-repo

#
# All configuration should be done by this point.  Start generating the test
# suite files.
#
# Top-level targets.  Add some helpful aliases, because why not.
#
all check test: bats-test
tap: bats-tap

.PHONY: check-deps
check-deps:
	@if ! command -v socat >/dev/null; then \
		echo "socat is required to run the test suite"; \
		false; \
	fi

.PHONY: ${SUITES}
${SUITES}: check-deps
	@echo '=> Running $@ test suite with PKGIN=${PKGIN}'
	@PKGIN=${PKGIN} ${BATS} ${BATS_JOBS} suite/$@.bats

.PHONY: bats-test
bats-test: check-deps
	@echo '=> Running test suite with PKGIN=${PKGIN}'
	@PKGIN=${PKGIN} ${BATS} ${BATS_JOBS} suite/*.bats

.PHONY: bats-tap
bats-tap: check-deps
	@echo '=> Running test suite with PKGIN=${PKGIN} (tap output)'
	@PKGIN=${PKGIN} ${BATS} ${BATS_JOBS} --tap suite/*.bats

#
# Helpful debug targets.
#
show-var:
	@echo ${${VARNAME}:Q}
