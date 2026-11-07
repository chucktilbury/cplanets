if(NOT DEFINED SERVER)
    message(FATAL_ERROR "test_cli_config_defaults.cmake requires SERVER")
endif()
if(NOT DEFINED AI)
    message(FATAL_ERROR "test_cli_config_defaults.cmake requires AI")
endif()
if(NOT DEFINED CLIENT)
    message(FATAL_ERROR "test_cli_config_defaults.cmake requires CLIENT")
endif()
if(NOT DEFINED TICK)
    message(FATAL_ERROR "test_cli_config_defaults.cmake requires TICK")
endif()
if(NOT DEFINED PYTHON)
    message(FATAL_ERROR "test_cli_config_defaults.cmake requires PYTHON")
endif()
if(NOT DEFINED HUMAN_CONFIG)
    message(FATAL_ERROR
        "test_cli_config_defaults.cmake requires HUMAN_CONFIG")
endif()
if(NOT DEFINED TICK_CONFIG)
    message(FATAL_ERROR
        "test_cli_config_defaults.cmake requires TICK_CONFIG")
endif()

execute_process(
    COMMAND "${PYTHON}"
        "${CMAKE_CURRENT_LIST_DIR}/test_cli_config_defaults.py"
        "--server" "${SERVER}"
        "--ai" "${AI}"
        "--client" "${CLIENT}"
        "--tick" "${TICK}"
        "--human-config" "${HUMAN_CONFIG}"
        "--tick-config" "${TICK_CONFIG}"
    RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "functional_cli_config_defaults failed (rc=${_rc})")
endif()
