if(NOT DEFINED CLIENT OR NOT DEFINED PYTHON)
    message(FATAL_ERROR
        "test_client_once.cmake requires CLIENT and PYTHON")
endif()
if(NOT DEFINED CLIENT_CONFIG)
    message(FATAL_ERROR
        "test_client_once.cmake requires CLIENT_CONFIG")
endif()
execute_process(
    COMMAND "${PYTHON}"
        "${CMAKE_CURRENT_LIST_DIR}/test_client_once.py"
        "--client" "${CLIENT}"
        "--client-config" "${CLIENT_CONFIG}"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error)
if(NOT result EQUAL 0)
    message(FATAL_ERROR
        "functional_client_once failed (${result}): ${error}\n${output}")
endif()
