# Build a Cwhip test program target, then run its output check.
#
# Required -D variables:
#   EXECUTABLE   — absolute path of the program binary
#   TARGET       — CMake target name that produces EXECUTABLE
#   BINARY_DIR   — project build directory
#   CHECK_SCRIPT — path to the tests/unit|fn/*.cmake output checker
#
# Optional:
#   EXPECTED is set by CHECK_SCRIPT (via check-output.cmake).

if(NOT DEFINED EXECUTABLE)
    message(FATAL_ERROR "run-program-test.cmake requires EXECUTABLE")
endif()
if(NOT DEFINED TARGET)
    message(FATAL_ERROR "run-program-test.cmake requires TARGET")
endif()
if(NOT DEFINED BINARY_DIR)
    message(FATAL_ERROR "run-program-test.cmake requires BINARY_DIR")
endif()
if(NOT DEFINED CHECK_SCRIPT)
    message(FATAL_ERROR "run-program-test.cmake requires CHECK_SCRIPT")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${BINARY_DIR}"
        --target "${TARGET}" --parallel
    RESULT_VARIABLE cplanets_build_result
    OUTPUT_VARIABLE cplanets_build_output
    ERROR_VARIABLE cplanets_build_error)
if(NOT cplanets_build_result EQUAL 0)
    message(FATAL_ERROR
        "Failed to build test target '${TARGET}':\n"
        "${cplanets_build_output}${cplanets_build_error}")
endif()

include("${CHECK_SCRIPT}")
