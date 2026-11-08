if(NOT DEFINED SERVER OR NOT DEFINED AI OR NOT DEFINED PYTHON)
    message(FATAL_ERROR
        "test_ai_serve_continuous.cmake requires SERVER, AI, and PYTHON")
endif()
if(NOT DEFINED SERVER_CONFIG)
    message(FATAL_ERROR
        "test_ai_serve_continuous.cmake requires SERVER_CONFIG")
endif()
execute_process(
    COMMAND "${PYTHON}"
        "${CMAKE_CURRENT_LIST_DIR}/test_ai_serve_continuous.py"
        "--server" "${SERVER}"
        "--ai" "${AI}"
        "--server-config" "${SERVER_CONFIG}"
    RESULT_VARIABLE status
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
    TIMEOUT 90)
if(NOT "${status}" STREQUAL "0"
        OR NOT "${output}" STREQUAL "true\n"
        OR NOT "${error}" STREQUAL "")
    message(FATAL_ERROR
        "Unexpected output: status=${status}, stdout=[${output}], "
        "stderr=[${error}]")
endif()
