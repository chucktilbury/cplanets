if(NOT DEFINED SERVER OR NOT DEFINED PYTHON)
    message(FATAL_ERROR
        "test_server_smoke.cmake requires SERVER and PYTHON")
endif()
if(NOT DEFINED SERVER_CONFIG)
    message(FATAL_ERROR
        "test_server_smoke.cmake requires SERVER_CONFIG")
endif()
execute_process(
    COMMAND "${PYTHON}"
        "${CMAKE_CURRENT_LIST_DIR}/test_server_smoke.py"
        "--server" "${SERVER}"
        "--server-config" "${SERVER_CONFIG}"
    RESULT_VARIABLE status
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
    TIMEOUT 30)
if(NOT "${status}" STREQUAL "0"
        OR NOT "${output}" STREQUAL "true\n"
        OR NOT "${error}" STREQUAL "")
    message(FATAL_ERROR
        "Unexpected output: status=${status}, stdout=[${output}], "
        "stderr=[${error}]")
endif()
