cmake_minimum_required(VERSION 3.24)

set(cwhip_sdk_prefix "$ENV{CWHIP_SDK}")
if(cwhip_sdk_prefix STREQUAL "")
    set(cwhip_config_home "$ENV{XDG_CONFIG_HOME}")
    if(cwhip_config_home STREQUAL "" AND NOT "$ENV{HOME}" STREQUAL "")
        set(cwhip_config_home "$ENV{HOME}/.config")
    endif()
    if(NOT cwhip_config_home STREQUAL "")
        if(NOT IS_ABSOLUTE "${cwhip_config_home}")
            message(FATAL_ERROR
                "Cannot discover sdk_prefix: config home '${cwhip_config_home}' is not absolute")
        endif()
        cmake_path(APPEND cwhip_config_home "cwhip"
            OUTPUT_VARIABLE cwhip_settings_directory)
        cmake_path(NORMAL_PATH cwhip_settings_directory)
        # EXISTS checks readability; listing lets the parser diagnose unreadable files.
        file(GLOB cwhip_settings_entries "${cwhip_settings_directory}/*")
        set(cwhip_settings "${cwhip_settings_directory}/sdk.toml")
        if(NOT "${cwhip_settings}" IN_LIST cwhip_settings_entries)
            set(cwhip_settings "${cwhip_settings_directory}/settings.toml")
        endif()
        if("${cwhip_settings}" IN_LIST cwhip_settings_entries)
            find_package(Python3 3.11 REQUIRED COMPONENTS Interpreter)
            execute_process(
                COMMAND "${Python3_EXECUTABLE}"
                    "${CMAKE_CURRENT_SOURCE_DIR}/scripts/sdk-prefix.py" "${cwhip_settings}"
                RESULT_VARIABLE cwhip_settings_result
                OUTPUT_VARIABLE cwhip_sdk_prefix
                ERROR_VARIABLE cwhip_settings_error)
            if(NOT cwhip_settings_result STREQUAL "0")
                message(FATAL_ERROR "${cwhip_settings_error}")
            endif()
        endif()
    endif()
endif()

if(NOT cwhip_sdk_prefix STREQUAL "")
    message(STATUS "Using Cwhip SDK prefix: ${cwhip_sdk_prefix}")
    unset(Cwhip_DIR CACHE)
    unset(Cwhip_DIR)
    find_package(Cwhip 0.0.2 EXACT CONFIG REQUIRED
        PATHS "${cwhip_sdk_prefix}" NO_DEFAULT_PATH)
else()
    find_package(Cwhip 0.0.2 EXACT CONFIG REQUIRED)
endif()

if(NOT "${Cwhip_SDK_ABI}" STREQUAL "numeric-v2")
    message(FATAL_ERROR
        "The selected Cwhip SDK at '${Cwhip_DIR}' has incompatible SDK ABI "
        "'${Cwhip_SDK_ABI}'; this template requires Cwhip 0.0.2 with numeric-v2. "
        "Rebuild and reinstall the numeric-v2 SDK and all native packages, "
        "then configure again. Updating source or package metadata alone is not sufficient.")
endif()

if(NOT COMMAND cwhip_apply_application_defaults)
    if(DEFINED Cwhip_PREFIX AND NOT Cwhip_PREFIX STREQUAL "")
        set(cwhip_sdk_location "at prefix '${Cwhip_PREFIX}'")
    elseif(NOT cwhip_sdk_prefix STREQUAL "")
        set(cwhip_sdk_location "at prefix '${cwhip_sdk_prefix}'")
    else()
        set(cwhip_sdk_location "with package directory '${Cwhip_DIR}'")
    endif()
    message(FATAL_ERROR
        "The selected Cwhip SDK ${cwhip_sdk_location} is missing the "
        "application-defaults capability: cwhip_apply_application_defaults(). "
        "Rebuild and reinstall an updated Cwhip SDK, then configure this project again. "
        "Updating the Cwhip source checkout alone does not update the installed SDK.")
endif()
cwhip_apply_application_defaults()

project(cplanets LANGUAGES C)

include(CTest)

set(CWHIP_BIN_DIR "${PROJECT_SOURCE_DIR}/bin" CACHE PATH
    "Directory for project executables")
set(CWHIP_LIB_DIR "${PROJECT_SOURCE_DIR}/lib" CACHE PATH
    "Directory for project libraries and archives")
get_filename_component(CWHIP_BIN_DIR "${CWHIP_BIN_DIR}" ABSOLUTE
    BASE_DIR "${PROJECT_SOURCE_DIR}")
get_filename_component(CWHIP_LIB_DIR "${CWHIP_LIB_DIR}" ABSOLUTE
    BASE_DIR "${PROJECT_SOURCE_DIR}")

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CWHIP_BIN_DIR}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CWHIP_LIB_DIR}")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CWHIP_LIB_DIR}")
foreach(configuration DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${configuration} "${CWHIP_BIN_DIR}")
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${configuration} "${CWHIP_LIB_DIR}")
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${configuration} "${CWHIP_LIB_DIR}")
endforeach()

if(NOT Cwhip_APPLICATION_OUTPUT_DIRECTORIES)
    message(FATAL_ERROR
        "The selected Cwhip SDK does not support configurable application output directories. "
        "Install an SDK that provides Cwhip_APPLICATION_OUTPUT_DIRECTORIES.")
endif()

function(cplanets_add_program target source)
    cwhip_add_program(${target}
        SOURCE "${PROJECT_SOURCE_DIR}/${source}"
        OUTPUT_DIRECTORY "${CWHIP_BIN_DIR}")
    get_target_property(_executable ${target} CWHIP_EXECUTABLE)
    set(${target}_executable "${_executable}" PARENT_SCOPE)
endfunction()

cplanets_add_program(cplanets-server src/cplanets-server.cw)
cplanets_add_program(cplanets src/cplanets.cw)
cplanets_add_program(cplanets-ai src/cplanets-ai.cw)
cplanets_add_program(cplanets-tick src/cplanets-tick.cw)
install(PROGRAMS
    "${cplanets-server_executable}"
    "${cplanets_executable}"
    "${cplanets-ai_executable}"
    "${cplanets-tick_executable}"
    DESTINATION bin)

if(BUILD_TESTING)
    set(cplanets_unit_programs
        unit_libIdentity
        unit_rng
        unit_scenarioFixture
        unit_setupLoad
        unit_galaxyStart
        unit_empirePools
        unit_travel
        unit_production
        unit_dispatch
        unit_recallCancel
        unit_stranded
        unit_combat
        unit_agreement
        unit_tradeHold
        unit_identify
        unit_ambushHalf
        unit_screen
        unit_contact
        unit_endgame
        unit_compress
        unit_envelope
        unit_verbs
        unit_serverClock
        unit_serverPresence
        unit_serverPolicy
        unit_aiConfig
        unit_aiTickSuggest
        unit_aiReaction)
    foreach(unit IN LISTS cplanets_unit_programs)
        cplanets_add_program(${unit} src/${unit}.cw)
        add_test(NAME ${unit} COMMAND "${CMAKE_COMMAND}"
            "-DEXECUTABLE=${${unit}_executable}"
            -P "${PROJECT_SOURCE_DIR}/tests/unit/${unit}.cmake")
    endforeach()
    set(cplanets_fn_programs
        fn_tickCore
        fn_takeColony
        fn_tradeAgreements
        fn_pirateIdentify
        fn_combatDesigns
        fn_contactEnd
        fn_messages
        fn_server
        fn_ai)
    foreach(fn IN LISTS cplanets_fn_programs)
        cplanets_add_program(${fn} src/${fn}.cw)
        add_test(NAME ${fn} COMMAND "${CMAKE_COMMAND}"
            "-DEXECUTABLE=${${fn}_executable}"
            -P "${PROJECT_SOURCE_DIR}/tests/fn/${fn}.cmake")
    endforeach()
    foreach(program IN ITEMS cplanets-server cplanets cplanets-ai cplanets-tick)
        add_test(NAME smoke_${program} COMMAND "${CMAKE_COMMAND}"
            "-DEXECUTABLE=${${program}_executable}"
            "-DPROGRAM=${program}"
            -P "${PROJECT_SOURCE_DIR}/tests/check-program.cmake")
    endforeach()
    find_package(Python3 3.11 REQUIRED COMPONENTS Interpreter)
    add_test(NAME functional_server_smoke COMMAND "${CMAKE_COMMAND}"
        "-DSERVER=${cplanets-server_executable}"
        "-DPYTHON=${Python3_EXECUTABLE}"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_server_smoke.cmake")
endif()
