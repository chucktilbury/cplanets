if(NOT DEFINED SERVER OR NOT DEFINED CLIENT OR NOT DEFINED PYTHON)
    message(FATAL_ERROR
        "test_client_pull.cmake requires SERVER, CLIENT, and PYTHON")
endif()
if(NOT DEFINED SERVER_CONFIG)
    message(FATAL_ERROR
        "test_client_pull.cmake requires SERVER_CONFIG")
endif()
execute_process(
    COMMAND "${PYTHON}"
        "${CMAKE_CURRENT_LIST_DIR}/test_client_pull.py"
        "--server" "${SERVER}"
        "--client" "${CLIENT}"
        "--server-config" "${SERVER_CONFIG}"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
    TIMEOUT 45)
if(NOT result EQUAL 0)
    message(FATAL_ERROR
        "functional_client_pull failed (${result}): ${error}\n${output}")
endif()
if(NOT "${output}" STREQUAL "ok\n")
    message(FATAL_ERROR
        "functional_client_pull unexpected stdout: [${output}]")
endif()
