# NextScene embeds the same core that produces upstream's Android library.
# For joint development pass -DNEXTSCENE_ARTEMIS_SOURCE_DIR=/path/to/checkout.
cmake_minimum_required(VERSION 3.16)
set(NEXTSCENE_ARTEMIS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/upstream" CACHE PATH
    "artemis-compat checkout (defaults to the pinned submodule)")
if(NOT EXISTS "${NEXTSCENE_ARTEMIS_SOURCE_DIR}/src/core/engine_context.h")
    message(FATAL_ERROR "Artemis sources are missing or too old. Run git submodule update --init --recursive, or set NEXTSCENE_ARTEMIS_SOURCE_DIR.")
endif()
set(ARTC_BUILD_CLI OFF)
set(ARTC_BUILD_JNI OFF)
set(ARTC_BUILD_MAC_HOST OFF)
# Explicit test-only headless mode for hdc shell; production retains GLES.
option(ARTC_OHOS_NO_GLES "Use headless rendering for OHOS shell regressions" OFF)
if(OHOS AND ARTC_OHOS_NO_GLES)
    set(ARTC_GRAPHICS_BACKEND HEADLESS)
endif()
# The engine must use the host's EGL implementation. Mixing system EGL and
# ANGLE in one process produces contexts the other library cannot consume.
if(TARGET unofficial::angle::libEGL AND NOT OHOS)
    find_path(NEXTSCENE_GLES_INCLUDE_DIR GLES2/gl2.h REQUIRED)
    find_path(NEXTSCENE_EGL_INCLUDE_DIR EGL/egl.h REQUIRED)
    add_library(nextscene_artemis_gles INTERFACE)
    target_include_directories(nextscene_artemis_gles INTERFACE
        "${NEXTSCENE_GLES_INCLUDE_DIR}" "${NEXTSCENE_EGL_INCLUDE_DIR}")
    target_link_libraries(nextscene_artemis_gles INTERFACE
        unofficial::angle::libEGL unofficial::angle::libGLESv2)
    set(ARTC_GRAPHICS_BACKEND GLES)
    set(ARTC_GLES_TARGET nextscene_artemis_gles)
endif()
add_subdirectory("${NEXTSCENE_ARTEMIS_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/upstream")
