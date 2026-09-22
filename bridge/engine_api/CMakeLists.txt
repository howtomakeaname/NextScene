cmake_minimum_required(VERSION 3.16)

project(engine_api LANGUAGES C CXX)

if(IOS)
    add_library(engine_api STATIC
        src/engine_api.cpp
    )
elseif(ANDROID)
    # On Android, include the JNI entry point (JNI_OnLoad, Surface bridge)
    # directly in engine_api.so so that System.loadLibrary("engine_api")
    # triggers JNI_OnLoad and registers JNI native methods.
    add_library(engine_api SHARED
        src/engine_api.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/../../platforms/android/cpp/krkr2_android.cpp
    )
else()
    add_library(engine_api SHARED
        src/engine_api.cpp
    )
endif()

target_compile_features(engine_api PRIVATE cxx_std_17)

if(IOS)
    # iOS static library: ensure symbols are visible so Dart FFI
    # DynamicLibrary.process() can find them when linked into Runner
    target_compile_definitions(engine_api PRIVATE ENGINE_API_EXPORT_SYMBOLS)
else()
    target_compile_definitions(engine_api PRIVATE ENGINE_API_BUILD_SHARED)
endif()
target_include_directories(engine_api
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

if(TARGET krkr2core AND TARGET krkr2plugin)
    target_compile_definitions(engine_api PRIVATE ENGINE_API_USE_KRKR2_RUNTIME)
    target_link_libraries(engine_api PRIVATE krkr2core krkr2plugin)
endif()

# Artemis Engine backend (cpp/artemis): the same C API dispatches to it for
# `.pfs` games. Only wired when the root build enabled the vendored runtime
# (KRKR2_ENABLE_ARTEMIS) and the krkr2 EGL context manager is available.
if(TARGET artemis_core AND TARGET krkr2core)
    target_sources(engine_api PRIVATE src/artemis_runtime.cpp)
    target_compile_definitions(engine_api PRIVATE ENGINE_API_USE_ARTEMIS_RUNTIME)
    target_link_libraries(engine_api PRIVATE artemis::core)
    message(STATUS "engine_api: Artemis backend enabled")
endif()

# On Apple platforms, ANGLE GL symbols conflict with system OpenGL.framework.
# Use -force_load to ensure ANGLE's libGLESv2 and libEGL are fully linked
# so their GL/EGL functions take priority over system equivalents.
if(APPLE AND NOT ANDROID)
    find_package(unofficial-angle CONFIG QUIET)
    if(unofficial-angle_FOUND)
        # Get the actual .a file paths from the imported targets
        get_target_property(_ANGLE_GLES_LOC unofficial::angle::libGLESv2 IMPORTED_LOCATION_DEBUG)
        if(NOT _ANGLE_GLES_LOC)
            get_target_property(_ANGLE_GLES_LOC unofficial::angle::libGLESv2 IMPORTED_LOCATION_RELEASE)
        endif()
        get_target_property(_ANGLE_EGL_LOC unofficial::angle::libEGL IMPORTED_LOCATION_DEBUG)
        if(NOT _ANGLE_EGL_LOC)
            get_target_property(_ANGLE_EGL_LOC unofficial::angle::libEGL IMPORTED_LOCATION_RELEASE)
        endif()
        get_target_property(_ANGLE_LIB_LOC unofficial::angle::libANGLE IMPORTED_LOCATION_DEBUG)
        if(NOT _ANGLE_LIB_LOC)
            get_target_property(_ANGLE_LIB_LOC unofficial::angle::libANGLE IMPORTED_LOCATION_RELEASE)
        endif()

        if(_ANGLE_GLES_LOC)
            target_link_options(engine_api PRIVATE
                "LINKER:-force_load,${_ANGLE_GLES_LOC}"
            )
            message(STATUS "engine_api: force_load ANGLE libGLESv2: ${_ANGLE_GLES_LOC}")
        endif()
        if(_ANGLE_EGL_LOC)
            target_link_options(engine_api PRIVATE
                "LINKER:-force_load,${_ANGLE_EGL_LOC}"
            )
            message(STATUS "engine_api: force_load ANGLE libEGL: ${_ANGLE_EGL_LOC}")
        endif()
        if(_ANGLE_LIB_LOC)
            target_link_options(engine_api PRIVATE
                "LINKER:-force_load,${_ANGLE_LIB_LOC}"
            )
            message(STATUS "engine_api: force_load ANGLE libANGLE: ${_ANGLE_LIB_LOC}")
        endif()
    endif()
endif()

set_target_properties(engine_api PROPERTIES
    OUTPUT_NAME "engine_api"
)

# On Android, link ANGLE .so (Vulkan backend) and Android system libs
if(ANDROID)
    find_package(unofficial-angle CONFIG QUIET)
    if(unofficial-angle_FOUND)
        target_link_libraries(engine_api PRIVATE
            unofficial::angle::libEGL
            unofficial::angle::libGLESv2
        )
        message(STATUS "engine_api: Android ANGLE linked (Vulkan backend)")
    else()
        # Fallback: link system EGL/GLES2
        target_link_libraries(engine_api PRIVATE EGL GLESv2)
        message(STATUS "engine_api: Android fallback to system EGL/GLES2")
    endif()
    target_link_libraries(engine_api PRIVATE log android)
endif()

# OpenHarmony: the sysroot ships real EGL/GLESv2 — no ANGLE involved.
# Rendering goes straight to an OHNativeWindow-backed EGLSurface obtained
# from Flutter's TextureRegistry (zero-copy, same path as Android).
if(OHOS)
    target_link_libraries(engine_api PRIVATE
        EGL
        GLESv2
        GLESv3
        hilog_ndk.z
    )
    # The vcpkg static archives (ffmpeg at least) contain hand-written NEON
    # asm doing ADRP+ADD directly against global symbols (ff_cos_* and
    # friends). Those relocations are only legal when the definitions bind
    # locally within this .so — ffmpeg's own shared-library builds pass
    # -Bsymbolic for exactly this reason; a static ffmpeg linked into a
    # shared library has to do the same.
    target_link_options(engine_api PRIVATE "LINKER:-Bsymbolic")
    message(STATUS "engine_api: OHOS system EGL/GLES2 + hilog linked (-Bsymbolic)")
endif()
