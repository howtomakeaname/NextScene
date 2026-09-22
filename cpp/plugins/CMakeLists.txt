cmake_minimum_required(VERSION 3.19)
project(krkr2plugin)

add_library(${PROJECT_NAME} STATIC)

# Live2D is optional. Some platform checkouts carry only the public Cubism
# header (or no SDK at all), so keep the engine linkable with a no-op anchor
# until the complete Framework/Core package is supplied.
if(NOT OHOS AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/cubism/Framework")
    set(KRKR2_LIVE2D_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/krkrlive2d.cpp)
else()
    set(KRKR2_LIVE2D_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/krkrlive2d_stub.cpp)
endif()

target_sources(${PROJECT_NAME} PUBLIC
    scriptsEx.cpp
    win32dialog.cpp
    dirlist.cpp
    csvParser.cpp
    layerExMovie.cpp
    varfile.cpp
    saveStruct.cpp
    getabout.cpp
    addFont.cpp
    wutcwf.cpp
    windowEx.cpp
    getSample.cpp
    layerExPerspective.cpp
    fftgraph.cpp
    LayerExBase.cpp
    xp3filter.cpp
    extrans.cpp
    textrender.cpp
    alphamovie.cpp
    layerExBTOA.cpp
    layerExImage.cpp
    layerExRaster.cpp
    layerExAreaAverage.cpp
    layerExLongExposure.cpp
    ${KRKR2_LIVE2D_SOURCE}
    # Software subset of layerExDraw (GdiPlus.Appearance + Layer.drawXxx)
    # for the OHOS build, where libgdiplus is not available.
    $<$<PLATFORM_ID:OHOS>:${CMAKE_CURRENT_SOURCE_DIR}/layerExDrawLite.cpp>
    krkrgles.cpp
    drawDeviceD2DCompat.cpp
    wfBasicEffectCompat.cpp
    wfTypicalDSPCompat.cpp
)

target_include_directories(${PROJECT_NAME} PUBLIC
    ${KRKR2CORE_PATH}/
    ${KRKR2CORE_PATH}/base
    ${KRKR2CORE_PATH}/base/win32
    ${KRKR2CORE_PATH}/environ
    ${KRKR2CORE_PATH}/environ/win32
    ${KRKR2CORE_PATH}/environ/android
    ${KRKR2CORE_PATH}/environ/sdl
    ${KRKR2CORE_PATH}/msg
    ${KRKR2CORE_PATH}/msg/win32
    ${KRKR2CORE_PATH}/extension
    ${KRKR2CORE_PATH}/sound
    ${KRKR2CORE_PATH}/sound/win32
    ${KRKR2CORE_PATH}/tjs2
    ${KRKR2CORE_PATH}/utils
    ${KRKR2CORE_PATH}/utils/win32
    ${KRKR2CORE_PATH}/visual
    ${KRKR2CORE_PATH}/visual/ARM
    ${KRKR2CORE_PATH}/visual/win32
    ${KRKR2CORE_PATH}/visual/RenderScript/rs
)

add_definitions(-D__STDC_CONSTANT_MACROS -DTJS_TEXT_OUT_CRLF)

# ---------------------------------------------------------------------------
# Live2D Cubism SDK (no OHOS prebuilt Core binary — skipped entirely there)
# ---------------------------------------------------------------------------
if(NOT OHOS AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/cubism/Framework")
set(CUBISM_DIR ${CMAKE_CURRENT_SOURCE_DIR}/cubism)
set(CUBISM_CORE_DIR ${CUBISM_DIR}/Core)
set(CUBISM_FW_DIR ${CUBISM_DIR}/Framework)

file(GLOB_RECURSE CUBISM_FW_SOURCES
    ${CUBISM_FW_DIR}/*.cpp
)
# Exclude non-OpenGL renderers (already removed from tree, but safety net)
list(FILTER CUBISM_FW_SOURCES EXCLUDE REGEX ".*/D3D9/.*|.*/D3D11/.*|.*/Vulkan/.*|.*/Metal/.*|.*/Cocos2d/.*")

add_library(CubismFramework STATIC ${CUBISM_FW_SOURCES})
target_include_directories(CubismFramework PUBLIC
    ${CUBISM_FW_DIR}
    ${CUBISM_FW_DIR}/src
    ${CUBISM_CORE_DIR}/include
)
# Cubism 5-r.5 Framework only gates its GL header choice on platform macros;
# HARMONYOS_ES3 is the branch that pulls plain GLES3/GLES2-ext headers (from
# vcpkg opengl-registry) without any jni.h dependency — fits the ANGLE ES2
# offscreen renderer. ANGLE_ES2 (older local Framework trees) no longer exists.
target_compile_definitions(CubismFramework PUBLIC CSM_TARGET_HARMONYOS_ES3)

# ANGLE headers for CubismFramework's OpenGLES2 renderer
find_package(unofficial-angle CONFIG QUIET)
if(unofficial-angle_FOUND)
    target_link_libraries(CubismFramework PRIVATE
        unofficial::angle::libEGL
        unofficial::angle::libGLESv2
    )
    # EGL/GLES2 headers come from egl-registry/opengl-registry via vcpkg
    # but aren't automatically propagated to standalone static library targets.
    get_target_property(_EGL_INCS unofficial::angle::libEGL INTERFACE_INCLUDE_DIRECTORIES)
    if(_EGL_INCS)
        target_include_directories(CubismFramework PRIVATE ${_EGL_INCS})
    endif()
    if(VCPKG_INSTALLED_DIR AND VCPKG_TARGET_TRIPLET)
        target_include_directories(CubismFramework PRIVATE
            ${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/include)
    endif()
elseif(ANDROID)
    target_link_libraries(CubismFramework PRIVATE EGL GLESv2)
endif()

if(ANDROID)
    set(CUBISM_CORE_ARCH ${CMAKE_ANDROID_ARCH_ABI})
    set(CUBISM_CORE_LIB ${CUBISM_CORE_DIR}/lib/android/${CUBISM_CORE_ARCH}/libLive2DCubismCore.a)
elseif(IOS)
    set(CUBISM_CORE_LIB ${CUBISM_CORE_DIR}/lib/ios/Release-iphoneos/libLive2DCubismCore.a)
elseif(APPLE)
    if(CMAKE_OSX_ARCHITECTURES STREQUAL "x86_64")
        set(CUBISM_CORE_LIB ${CUBISM_CORE_DIR}/lib/macos/x86_64/libLive2DCubismCore.a)
    else()
        set(CUBISM_CORE_LIB ${CUBISM_CORE_DIR}/lib/macos/arm64/libLive2DCubismCore.a)
    endif()
endif()

target_link_libraries(CubismFramework PUBLIC ${CUBISM_CORE_LIB})

target_include_directories(${PROJECT_NAME} PUBLIC
    ${CUBISM_FW_DIR}
    ${CUBISM_FW_DIR}/src
    ${CUBISM_CORE_DIR}/include
)
target_compile_definitions(${PROJECT_NAME} PUBLIC CSM_TARGET_HARMONYOS_ES3)
target_link_libraries(${PROJECT_NAME} PUBLIC CubismFramework)
endif()

target_include_directories(${PROJECT_NAME} PUBLIC ${KRKR2PLUGIN_PATH} ${KRKR2PLUGIN_PATH}/simplebinder})
target_link_libraries(${PROJECT_NAME} PUBLIC krkr2core)

add_subdirectory(psdfile)
add_subdirectory(psbfile)
if(NOT OHOS AND NOT ANDROID)
    # layerex_draw depends on libgdiplus outside Windows, which is not
    # provisioned for Android or OHOS. The core GLES renderer remains
    # available on both mobile targets.
    add_subdirectory(layerex_draw)
endif()
add_subdirectory(motionplayer)
add_subdirectory(kagparserex)

#add_subdirectory(json)
add_subdirectory(fstat)
#add_subdirectory(steam)
#add_subdirectory(DrawDeviceForSteam)
target_link_libraries(${PROJECT_NAME} PUBLIC
        psdfile
        psbfile
        motionplayer
        kagparserex
        fstat
#        json steam DrawDeviceForSteam
)
if(NOT OHOS AND NOT ANDROID)
    target_link_libraries(${PROJECT_NAME} PUBLIC layerExDraw)
endif()

find_package(fmt CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE fmt::fmt)

find_package(spdlog CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE spdlog::spdlog)
