#
# Test removal scenarios.  This relies on being ran immediately after the
# upgrade tests.
#

#
# After the upgrades, deptree-bottom is no longer required, and is missing
# from this repository.  Check that we don't trigger the "no associated repo"
# error.
#
@test "${REPO_NAME} test removal of package no longer available" {
	run pkgin -y autoremove
	[ ${status} -eq 123 ]
}
@test "${REPO_NAME} test removal of package" {
	run pkgin -y rm deptree-bottom
	[ ${status} -eq 123 ]
}
