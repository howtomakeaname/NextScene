# cpp/artemis — Artemis Engine compatibility runtime (clean-room, GPL-3.0).
#
# Vendored from https://github.com/Weiss-UltimateSavior/artemis-compat
# (see upstream/UPSTREAM.md for the pinned commit and the local patch list).
# The upstream CLI (`artc`) and the Android JNI/NativeActivity host are not
# built here: KrKr2-Next drives the engine from bridge/engine_api instead.
#
# Targets:
#   artemis_lua51   — vendored Lua 5.1.5 (MIT), static
#   artemis_core    — pack/config/script/render/log + platform audio, static
#
# Platform notes:
#   * OHOS: GLES2 compositor enabled (ARTC_HAS_GLES), OHAudio voice backend,
#     hilog output. Consumers must make an EGL context current before
#     calling into the compositor; ARTC_OHOS_NO_GLES swaps in the math-only
#     compositor so the regressions can run from a shell (shell-spawned
#     processes cannot obtain an EGL display).
#   * other hosts: compositor is math-only and audio is a silent stub — the
#     library still builds so the bridge can be unit-tested off-device.
cmake_minimum_required(VERSION 3.16)

set(ARTC_UPSTREAM ${CMAKE_CURRENT_SOURCE_DIR}/upstream)

# ---- vendored Lua 5.1.5 (static, no standalone interpreters) ----
file(GLOB ARTC_LUA_SOURCES ${ARTC_UPSTREAM}/third_party/lua-5.1.5/src/*.c)
add_library(artemis_lua51 STATIC ${ARTC_LUA_SOURCES})
target_include_directories(artemis_lua51 PUBLIC ${ARTC_UPSTREAM}/third_party/lua-5.1.5/src)
if(UNIX)
    target_compile_definitions(artemis_lua51 PRIVATE LUA_USE_POSIX)
endif()
# Lua 5.1 predates _FORTIFY_SOURCE hardening; the NDK/OHOS defaults trip a
# false positive in the GC sweep (see upstream CMakeLists.txt).
if(ANDROID OR OHOS)
    target_compile_options(artemis_lua51 PRIVATE -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0)
endif()
# Lua is C; keep the project-wide C++ warnings from leaking in.
target_compile_options(artemis_lua51 PRIVATE -w)

# ---- core engine ----
file(GLOB_RECURSE ARTC_CORE_SOURCES CONFIGURE_DEPENDS
    ${ARTC_UPSTREAM}/src/pack/*.cpp
    ${ARTC_UPSTREAM}/src/config/*.cpp
    ${ARTC_UPSTREAM}/src/script/*.cpp
    ${ARTC_UPSTREAM}/src/log/*.cpp
    ${ARTC_UPSTREAM}/src/render/*.cpp
    ${ARTC_UPSTREAM}/src/util/*.cpp)

if(OHOS)
    list(APPEND ARTC_CORE_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/ohos/audio_ohos.cpp)
else()
    list(APPEND ARTC_CORE_SOURCES ${ARTC_UPSTREAM}/src/audio/audio.cpp)
endif()

add_library(artemis_core STATIC ${ARTC_CORE_SOURCES}
    ${ARTC_UPSTREAM}/src/audio/audio_channels.cpp
    ${ARTC_UPSTREAM}/src/audio/vorbis_stream.cpp)
target_compile_features(artemis_core PUBLIC cxx_std_17)
target_include_directories(artemis_core
    PUBLIC
        ${ARTC_UPSTREAM}/src
    PRIVATE
        ${ARTC_UPSTREAM}/src/render
        ${ARTC_UPSTREAM}/third_party)
find_package(ZLIB REQUIRED)
target_link_libraries(artemis_core PUBLIC artemis_lua51 ZLIB::ZLIB)

# The application already supplies FFmpeg through vcpkg. Standalone host
# regressions can use the system libraries without changing the app manifest.
option(ARTC_ENABLE_FFMPEG "Decode Artemis movies with FFmpeg" ON)
if(ARTC_ENABLE_FFMPEG)
    if(FFMPEG_FOUND)
        target_include_directories(artemis_core PRIVATE ${FFMPEG_INCLUDE_DIRS})
        target_link_libraries(artemis_core PUBLIC ${FFMPEG_LIBRARIES})
        target_compile_definitions(artemis_core PUBLIC ARTC_HAS_FFMPEG=1)
    elseif(NOT CMAKE_CROSSCOMPILING)
        find_package(PkgConfig QUIET)
        if(PkgConfig_FOUND)
            pkg_check_modules(ARTC_FFMPEG QUIET IMPORTED_TARGET
                libavformat libavcodec libavutil libswresample libswscale)
            if(ARTC_FFMPEG_FOUND)
                target_link_libraries(artemis_core PUBLIC PkgConfig::ARTC_FFMPEG)
                target_compile_definitions(artemis_core PUBLIC ARTC_HAS_FFMPEG=1)
            endif()
        endif()
    endif()
endif()
# The upstream code is -Wall -Wextra clean modulo a few unused-variable
# nits; silence those so the OHOS build log stays readable.
target_compile_options(artemis_core PRIVATE
    -Wno-unused-variable -Wno-unused-parameter -Wno-unused-const-variable
    -Wno-unused-function)

# Shell-spawned processes on an OHOS image cannot obtain an EGL display (the
# default display connection only exists inside an app's render session), so
# the regressions can also run there against the math-only compositor that the
# desktop headless build uses. The OHAudio backend and hilog logging stay on.
option(ARTC_OHOS_NO_GLES "Build the OHOS engine without the GLES compositor for shell-run regressions" OFF)
if(OHOS)
    target_link_libraries(artemis_core PUBLIC
        ohaudio
        hilog_ndk.z)
    if(NOT ARTC_OHOS_NO_GLES)
        target_compile_definitions(artemis_core PUBLIC ARTC_HAS_GLES=1)
        target_link_libraries(artemis_core PUBLIC
            EGL
            GLESv2)
    endif()
endif()
