if(NOT DEFINED AI)
    message(FATAL_ERROR "test_ai_verbose.cmake requires AI")
endif()
if(NOT DEFINED PYTHON)
    message(FATAL_ERROR "test_ai_verbose.cmake requires PYTHON")
endif()
if(NOT DEFINED CONFIG)
    message(FATAL_ERROR "test_ai_verbose.cmake requires CONFIG")
endif()

execute_process(
    COMMAND "${PYTHON}"
        "${CMAKE_CURRENT_LIST_DIR}/test_ai_verbose.py"
        "--ai" "${AI}"
        "--config" "${CONFIG}"
    RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "functional_ai_verbose failed (rc=${_rc})")
endif()
