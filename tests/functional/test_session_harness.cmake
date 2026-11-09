if(NOT DEFINED SERVER OR NOT DEFINED AI OR NOT DEFINED CLIENT
        OR NOT DEFINED PYTHON OR NOT DEFINED FIXTURE)
    message(FATAL_ERROR
        "test_session_harness.cmake requires SERVER, AI, CLIENT, "
        "PYTHON, and FIXTURE")
endif()
if(NOT DEFINED SERVER_CONFIG)
    message(FATAL_ERROR
        "test_session_harness.cmake requires SERVER_CONFIG")
endif()
if(NOT DEFINED HUMAN_CONFIG)
    message(FATAL_ERROR
        "test_session_harness.cmake requires HUMAN_CONFIG")
endif()
if(NOT DEFINED WORLDS)
    set(WORLDS 12)
endif()
execute_process(
    COMMAND "${PYTHON}"
        "${CMAKE_CURRENT_LIST_DIR}/test_session_harness.py"
        "--server" "${SERVER}"
        "--ai" "${AI}"
        "--client" "${CLIENT}"
        "--server-config" "${SERVER_CONFIG}"
        "--human-config" "${HUMAN_CONFIG}"
        "--fixture" "${FIXTURE}"
        "--worlds" "${WORLDS}"
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
