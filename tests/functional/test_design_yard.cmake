if(NOT DEFINED SERVER OR NOT DEFINED PYTHON)
    message(FATAL_ERROR
        "test_design_yard.cmake requires SERVER and PYTHON")
endif()
execute_process(
    COMMAND "${PYTHON}"
        "${CMAKE_CURRENT_LIST_DIR}/test_design_yard.py"
        "--server" "${SERVER}"
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
