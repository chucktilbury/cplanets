if(NOT DEFINED SERVER OR NOT DEFINED PYTHON)
    message(FATAL_ERROR
        "test_setup_path.cmake requires SERVER and PYTHON")
endif()
set(_fixture_args "")
if(DEFINED FIXTURE AND NOT "${FIXTURE}" STREQUAL "")
    set(_fixture_args "--fixture" "${FIXTURE}")
endif()
execute_process(
    COMMAND "${PYTHON}"
        "${CMAKE_CURRENT_LIST_DIR}/test_setup_path.py"
        "--server" "${SERVER}"
        ${_fixture_args}
    RESULT_VARIABLE status
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
    TIMEOUT 45)
if(NOT "${status}" STREQUAL "0"
        OR NOT "${output}" STREQUAL "true\n"
        OR NOT "${error}" STREQUAL "")
    message(FATAL_ERROR
        "Unexpected output: status=${status}, stdout=[${output}], "
        "stderr=[${error}]")
endif()
