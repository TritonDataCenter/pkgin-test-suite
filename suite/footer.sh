#
# Footer section shared by test scripts.
#

#
# Kill off the httpd if used by this repository.  This is only executed
# if BATS_HTTP_PORT is set.
#
@test "${REPO_NAME} perform test suite cleanup" {
	run true
	stop_webserver
}
