# Cwhip stages the SOURCE file's directory, so the unit program lives at
# src/unit_libIdentity.cw (next to lib/) and this wrapper runs it.
if(NOT DEFINED EXECUTABLE)
    message(FATAL_ERROR "unit_libIdentity.cmake requires EXECUTABLE")
endif()
set(EXPECTED "true\n")
include("${CMAKE_CURRENT_LIST_DIR}/../check-output.cmake")
