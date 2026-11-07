if(NOT DEFINED EXECUTABLE OR NOT DEFINED EXPECTED)
    message(FATAL_ERROR "check-output.cmake requires EXECUTABLE and EXPECTED")
endif()
if(DEFINED CONFIG AND NOT "${CONFIG}" STREQUAL "")
    execute_process(COMMAND "${EXECUTABLE}" "--config" "${CONFIG}"
        RESULT_VARIABLE status
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
        TIMEOUT 10)
else()
    execute_process(COMMAND "${EXECUTABLE}"
        RESULT_VARIABLE status
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
        TIMEOUT 10)
endif()
if(NOT "${status}" STREQUAL "0"
        OR NOT "${output}" STREQUAL "${EXPECTED}"
        OR NOT "${error}" STREQUAL "")
    message(FATAL_ERROR
        "Unexpected output: status=${status}, stdout=[${output}], stderr=[${error}]")
endif()
