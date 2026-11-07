if(NOT DEFINED CLIENT OR NOT DEFINED PYTHON)
    message(FATAL_ERROR
        "test_client_connect_fail.cmake requires CLIENT and PYTHON")
endif()
execute_process(
    COMMAND "${PYTHON}"
        "${CMAKE_CURRENT_LIST_DIR}/test_client_connect_fail.py"
        "--client" "${CLIENT}"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
    TIMEOUT 30)
if(NOT result EQUAL 0)
    message(FATAL_ERROR
        "functional_client_connect_fail failed (${result}): "
        "${error}\n${output}")
endif()
if(NOT "${output}" STREQUAL "ok\n")
    message(FATAL_ERROR
        "functional_client_connect_fail unexpected stdout: "
        "[${output}]")
endif()
