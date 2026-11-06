# Output check for tests/unit/unit_libIdentity.cw (built via the test target).
if(NOT DEFINED EXECUTABLE)
    message(FATAL_ERROR "unit_libIdentity.cmake requires EXECUTABLE")
endif()
set(EXPECTED "true\n")
include("${CMAKE_CURRENT_LIST_DIR}/../check-output.cmake")
