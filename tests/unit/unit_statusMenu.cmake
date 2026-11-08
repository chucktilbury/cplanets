# Output check for tests/unit/unit_statusMenu.cw
if(NOT DEFINED EXECUTABLE)
    message(FATAL_ERROR "unit_statusMenu.cmake requires EXECUTABLE")
endif()
set(EXPECTED "true\n")
include("${CMAKE_CURRENT_LIST_DIR}/../check-output.cmake")
