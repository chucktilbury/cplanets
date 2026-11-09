if(NOT DEFINED SERVER OR NOT DEFINED PYTHON)
    message(FATAL_ERROR
        "test_lobby_hold.cmake requires SERVER and PYTHON")
endif()
if(NOT DEFINED SERVER_CONFIG)
    message(FATAL_ERROR
        "test_lobby_hold.cmake requires SERVER_CONFIG")
endif()
if(NOT DEFINED FIXTURE)
    set(FIXTURE "")
endif()
execute_process(
    COMMAND "${PYTHON}"
        "${CMAKE_CURRENT_LIST_DIR}/test_lobby_hold.py"
        "--server" "${SERVER}"
        "--server-config" "${SERVER_CONFIG}"
        "--fixture" "${FIXTURE}"
    RESULT_VARIABLE status
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
    TIMEOUT 60)
if(NOT "${status}" STREQUAL "0"
        OR NOT "${output}" STREQUAL "true\n"
        OR NOT "${error}" STREQUAL "")
    message(FATAL_ERROR
        "Unexpected output: status=${status}, stdout=[${output}], "
        "stderr=[${error}]")
endif()
