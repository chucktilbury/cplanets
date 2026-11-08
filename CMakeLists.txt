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

# Non-blocking stdin poll for the serve-time status menu (ServerListen).
add_library(cplanets_native OBJECT
    "${PROJECT_SOURCE_DIR}/src/native/stdinPoll.c")
target_include_directories(cplanets_native PRIVATE
    "${Cwhip_INCLUDE_DIR}")

function(cplanets_add_program target source)
    cwhip_add_program(${target}
        SOURCE "${PROJECT_SOURCE_DIR}/${source}"
        OUTPUT_DIRECTORY "${CWHIP_BIN_DIR}"
        OBJECTS $<TARGET_OBJECTS:cplanets_native>
        DEPENDS cplanets_native)
    get_target_property(_executable ${target} CWHIP_EXECUTABLE)
    set(${target}_executable "${_executable}" PARENT_SCOPE)
endfunction()

# Unit/fn programs live under tests/ and must not join the default ALL
# build. Real SDKs expose Cwhip_COMPILER; discovery stubs do not — fall
# back to cwhip_add_program so mock configure still registers CTest.
# Includes resolve through `cwhip -p ${src}` so lib/ai/client/server
# keep living under src/ while the program SOURCE sits in tests/.
function(cplanets_add_test_program target source)
    if(NOT Cwhip_COMPILER)
        cwhip_add_program(${target}
            SOURCE "${PROJECT_SOURCE_DIR}/${source}"
            OUTPUT_DIRECTORY "${CWHIP_BIN_DIR}"
            OBJECTS $<TARGET_OBJECTS:cplanets_native>
            DEPENDS cplanets_native)
        get_target_property(_executable ${target} CWHIP_EXECUTABLE)
        set(${target}_executable "${_executable}" PARENT_SCOPE)
        return()
    endif()

    get_filename_component(source_abs "${PROJECT_SOURCE_DIR}/${source}" ABSOLUTE)
    get_filename_component(source_dir "${source_abs}" DIRECTORY)
    get_filename_component(source_name "${source_abs}" NAME)
    if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
        message(FATAL_ERROR "Cwhip applications require an out-of-source CMake build")
    endif()
    if(NOT EXISTS "${source_abs}")
        message(FATAL_ERROR
            "cplanets_add_test_program requires an existing source file: ${source_abs}")
    endif()

    set(output_directory "${CWHIP_BIN_DIR}")
    set(work "${CMAKE_CURRENT_BINARY_DIR}/${target}-project")
    set(output "${output_directory}/${target}")
    set(src_root "${PROJECT_SOURCE_DIR}/src")
    file(MAKE_DIRECTORY "${work}/home" "${work}/xdg" "${work}/data"
        "${work}/cache" "${work}/state" "${work}/modules")

    # Stage only the test program directory (not all of src/). Production
    # code is reached via -p ${src_root}.
    set(_cwhip_collect_sources_fn "_cwhip_collect_sources")
    if(NOT COMMAND ${_cwhip_collect_sources_fn})
        message(FATAL_ERROR
            "Cwhip SDK is missing _cwhip_collect_sources(); cannot stage test programs")
    endif()
    _cwhip_collect_sources("${source_dir}" inputs)
    file(GLOB_RECURSE src_inputs CONFIGURE_DEPENDS
        "${src_root}/lib/*"
        "${src_root}/ai/*"
        "${src_root}/client/*"
        "${src_root}/server/*"
        "${src_root}/native/*")
    file(GLOB_RECURSE sdk_inputs CONFIGURE_DEPENDS
        "${Cwhip_INCLUDE_DIR}/*" "${Cwhip_MODULE_DIR}/*" "${Cwhip_BUILTIN_DIR}/*")
    file(GENERATE OUTPUT "${work}/inputs.txt" CONTENT "${inputs}\n${src_inputs}\n${sdk_inputs}\n")
    file(GENERATE OUTPUT "${work}/source-inputs.cmake" CONTENT "set(inputs [==[${inputs}]==])\n")
    set(stage_sources "${Cwhip_DIR}/CwhipStageSources.cmake")
    get_filename_component(runtime_dir "${Cwhip_RUNTIME_LIBRARY}" DIRECTORY)
    set(environment "${CMAKE_COMMAND}" -E env
        --unset=CWHIP_MODULE_DIR --unset=CWHIP_PACKAGE_PATH --unset=CWHIP_MODULE_REGISTRY
        --unset=DESTDIR --unset=XDG_RUNTIME_DIR
        "HOME=${work}/home" "XDG_CONFIG_HOME=${work}/xdg" "PYTHONDONTWRITEBYTECODE=1"
        "XDG_DATA_HOME=${work}/data" "XDG_CACHE_HOME=${work}/cache"
        "XDG_STATE_HOME=${work}/state"
        "CWHIP_HOME=${Cwhip_PREFIX}"
        "CWHIP_INCLUDE_DIR=${Cwhip_INCLUDE_DIR}"
        "CWHIP_RUNTIME_DIR=${runtime_dir}"
        "CWHIP_BUILTIN_DIR=${Cwhip_BUILTIN_DIR}"
        "CWHIP_STDLIB_MODULE_DIR=${Cwhip_MODULE_DIR}" "CC=${Cwhip_CLANG_EXECUTABLE}")
    add_custom_command(OUTPUT "${work}/cwhip-pkg.toml" "${work}/cwhip-pkg.lock"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${work}/home" "${work}/xdg"
            "${work}/data" "${work}/cache" "${work}/state" "${work}/modules"
        COMMAND "${CMAKE_COMMAND}" -E rm -f "${work}/cwhip-pkg.toml" "${work}/cwhip-pkg.lock"
        COMMAND ${environment} "${Python3_EXECUTABLE}" "${Cwhip_PACKAGE_TOOL}" init "${work}"
        DEPENDS "${Cwhip_PACKAGE_TOOL}" ${sdk_inputs} "${work}/inputs.txt"
        VERBATIM)
    set(_cwhip_debug_flags)
    string(TOUPPER "${CMAKE_BUILD_TYPE}" _cwhip_build_type_upper)
    if(_cwhip_build_type_upper STREQUAL "DEBUG" OR
       _cwhip_build_type_upper STREQUAL "RELWITHDEBINFO")
        set(_cwhip_debug_flags -g)
    endif()
    add_custom_command(OUTPUT "${output}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${output_directory}"
        COMMAND "${CMAKE_COMMAND}" "-Dsource_dir=${source_dir}"
            "-Doutput_dir=${work}/src" "-Dinventory=${work}/source-inputs.cmake"
            -P "${stage_sources}"
        COMMAND ${environment} "${Cwhip_COMPILER}" "${work}/src/${source_name}"
            -M "${Cwhip_MODULE_DIR}" -p "${src_root}" ${_cwhip_debug_flags}
            -o "${output}" $<TARGET_OBJECTS:cplanets_native>
        DEPENDS "${Cwhip_COMPILER}" "${Cwhip_RUNTIME_LIBRARY}" ${sdk_inputs}
            ${inputs} ${src_inputs} "${work}/inputs.txt" "${work}/source-inputs.cmake"
            "${stage_sources}" cplanets_native
            "${work}/cwhip-pkg.toml" "${work}/cwhip-pkg.lock"
        WORKING_DIRECTORY "${work}" COMMAND_EXPAND_LISTS VERBATIM)
    # No ALL — production `build` must not compile unit/fn programs.
    add_custom_target(${target} DEPENDS "${output}")
    if(TARGET cwhip_language_resources)
        add_dependencies(${target} cwhip_language_resources)
    endif()
    add_dependencies(${target} cplanets_native)
    set_property(TARGET ${target} PROPERTY CWHIP_EXECUTABLE "${output}")
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_CLEAN_FILES
        "${work}/src" "${work}/home" "${work}/xdg" "${work}/data"
        "${work}/cache" "${work}/state" "${work}/modules")
    set(${target}_executable "${output}" PARENT_SCOPE)
endfunction()

function(cplanets_add_cw_test name kind)
    cplanets_add_test_program(${name} tests/${kind}/${name}.cw)
    set(${name}_executable "${${name}_executable}" PARENT_SCOPE)
    add_test(NAME ${name} COMMAND "${CMAKE_COMMAND}"
        "-DEXECUTABLE=${${name}_executable}"
        "-DTARGET=${name}"
        "-DBINARY_DIR=${CMAKE_BINARY_DIR}"
        "-DCHECK_SCRIPT=${PROJECT_SOURCE_DIR}/tests/${kind}/${name}.cmake"
        -P "${PROJECT_SOURCE_DIR}/tests/run-program-test.cmake")
    if(TARGET test)
        add_dependencies(test ${name})
    endif()
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
        unit_homeOnConnect
        unit_empirePools
        unit_travel
        unit_production
        unit_dispatch
        unit_splitDispatch
        unit_orderReject
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
        unit_serverVerbose
        unit_serverConfig
        unit_statusMenu
        unit_aiConfig
        unit_aiExploreStop
        unit_aiVerbose
        unit_aiTickSuggest
        unit_aiReaction
        unit_aiStatusMenu
        unit_clientConfig
        unit_clientLivability
        unit_clientPolicy
        unit_clientPublishDecode
        unit_mapMath)
    foreach(unit IN LISTS cplanets_unit_programs)
        cplanets_add_cw_test(${unit} unit)
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
        fn_ai
        fn_client
        fn_listChrome)
    foreach(fn IN LISTS cplanets_fn_programs)
        cplanets_add_cw_test(${fn} fn)
    endforeach()
    set(_smoke_configs
        cplanets-server|server-default.cfg
        cplanets|human-default.cfg
        cplanets-ai|ai-default.cfg
        cplanets-tick|tick-default.cfg)
    foreach(entry IN LISTS _smoke_configs)
        string(REPLACE "|" ";" _parts "${entry}")
        list(GET _parts 0 program)
        list(GET _parts 1 _cfg_name)
        add_test(NAME smoke_${program} COMMAND "${CMAKE_COMMAND}"
            "-DEXECUTABLE=${${program}_executable}"
            "-DPROGRAM=${program}"
            "-DCONFIG=${PROJECT_SOURCE_DIR}/config/${_cfg_name}"
            -P "${PROJECT_SOURCE_DIR}/tests/check-program.cmake")
    endforeach()
    find_package(Python3 3.11 REQUIRED COMPONENTS Interpreter)
    add_test(NAME functional_server_smoke COMMAND "${CMAKE_COMMAND}"
        "-DSERVER=${cplanets-server_executable}"
        "-DPYTHON=${Python3_EXECUTABLE}"
        "-DSERVER_CONFIG=${PROJECT_SOURCE_DIR}/config/server-default.cfg"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_server_smoke.cmake")
    add_test(NAME functional_server_verbose COMMAND "${CMAKE_COMMAND}"
        "-DSERVER=${cplanets-server_executable}"
        "-DPYTHON=${Python3_EXECUTABLE}"
        "-DSERVER_CONFIG=${PROJECT_SOURCE_DIR}/config/server-default.cfg"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_server_verbose.cmake")
    add_test(NAME functional_ai_verbose COMMAND "${CMAKE_COMMAND}"
        "-DAI=${cplanets-ai_executable}"
        "-DPYTHON=${Python3_EXECUTABLE}"
        "-DCONFIG=${PROJECT_SOURCE_DIR}/config/ai-default.cfg"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_ai_verbose.cmake")
    add_test(NAME functional_setup_path COMMAND "${CMAKE_COMMAND}"
        "-DSERVER=${cplanets-server_executable}"
        "-DPYTHON=${Python3_EXECUTABLE}"
        "-DSERVER_CONFIG=${PROJECT_SOURCE_DIR}/config/server-default.cfg"
        "-DFIXTURE=${PROJECT_SOURCE_DIR}/scenarios/closed-default.setup"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_setup_path.cmake")
    add_test(NAME functional_client_once COMMAND "${CMAKE_COMMAND}"
        "-DCLIENT=${cplanets_executable}"
        "-DPYTHON=${Python3_EXECUTABLE}"
        "-DCLIENT_CONFIG=${PROJECT_SOURCE_DIR}/config/human-default.cfg"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_client_once.cmake")
    add_test(NAME functional_client_pull COMMAND "${CMAKE_COMMAND}"
        "-DSERVER=${cplanets-server_executable}"
        "-DCLIENT=${cplanets_executable}"
        "-DPYTHON=${Python3_EXECUTABLE}"
        "-DSERVER_CONFIG=${PROJECT_SOURCE_DIR}/config/server-default.cfg"
        "-DFIXTURE=${PROJECT_SOURCE_DIR}/scenarios/tuning-small.setup"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_client_pull.cmake")
    add_test(NAME functional_client_connect_fail COMMAND "${CMAKE_COMMAND}"
        "-DCLIENT=${cplanets_executable}"
        "-DPYTHON=${Python3_EXECUTABLE}"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_client_connect_fail.cmake")
    add_test(NAME functional_list_chrome COMMAND "${CMAKE_COMMAND}"
        "-DSERVER=${cplanets-server_executable}"
        "-DPYTHON=${Python3_EXECUTABLE}"
        "-DSERVER_CONFIG=${PROJECT_SOURCE_DIR}/config/server-default.cfg"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_list_chrome.cmake")
    add_test(NAME functional_design_yard COMMAND "${CMAKE_COMMAND}"
        "-DSERVER=${cplanets-server_executable}"
        "-DPYTHON=${Python3_EXECUTABLE}"
        "-DSERVER_CONFIG=${PROJECT_SOURCE_DIR}/config/server-default.cfg"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_design_yard.cmake")
    add_test(NAME functional_session_harness COMMAND "${CMAKE_COMMAND}"
        "-DSERVER=${cplanets-server_executable}"
        "-DAI=${cplanets-ai_executable}"
        "-DCLIENT=${cplanets_executable}"
        "-DPYTHON=${Python3_EXECUTABLE}"
        "-DSERVER_CONFIG=${PROJECT_SOURCE_DIR}/config/server-default.cfg"
        "-DFIXTURE=${PROJECT_SOURCE_DIR}/scenarios/tuning-small.setup"
        "-DWORLDS=12"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_session_harness.cmake")
    add_test(NAME functional_cli_config_defaults COMMAND "${CMAKE_COMMAND}"
        "-DSERVER=${cplanets-server_executable}"
        "-DAI=${cplanets-ai_executable}"
        "-DCLIENT=${cplanets_executable}"
        "-DTICK=${cplanets-tick_executable}"
        "-DPYTHON=${Python3_EXECUTABLE}"
        "-DHUMAN_CONFIG=${PROJECT_SOURCE_DIR}/config/human-default.cfg"
        "-DTICK_CONFIG=${PROJECT_SOURCE_DIR}/config/tick-default.cfg"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_cli_config_defaults.cmake")
    add_test(NAME functional_status_menu COMMAND "${CMAKE_COMMAND}"
        "-DSERVER=${cplanets-server_executable}"
        "-DSERVER_CONFIG=${PROJECT_SOURCE_DIR}/config/server-default.cfg"
        "-DPYTHON=${Python3_EXECUTABLE}"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_status_menu.cmake")
    add_test(NAME functional_ai_status_menu COMMAND "${CMAKE_COMMAND}"
        "-DSERVER=${cplanets-server_executable}"
        "-DAI=${cplanets-ai_executable}"
        "-DSERVER_CONFIG=${PROJECT_SOURCE_DIR}/config/server-default.cfg"
        "-DPYTHON=${Python3_EXECUTABLE}"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_ai_status_menu.cmake")
    add_test(NAME functional_ai_serve_continuous COMMAND "${CMAKE_COMMAND}"
        "-DSERVER=${cplanets-server_executable}"
        "-DAI=${cplanets-ai_executable}"
        "-DSERVER_CONFIG=${PROJECT_SOURCE_DIR}/config/server-default.cfg"
        "-DPYTHON=${Python3_EXECUTABLE}"
        -P "${PROJECT_SOURCE_DIR}/tests/functional/test_ai_serve_continuous.cmake")
endif()
