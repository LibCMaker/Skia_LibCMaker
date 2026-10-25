# ****************************************************************************
#  Project:  LibCMaker
#  Purpose:  A CMake build scripts for build libraries with CMake
#  Author:   NikitaFeodonit, nfeodonit@yandex.com
# ****************************************************************************
#    Copyright (c) 2017-2026 NikitaFeodonit
#
#    This file is part of the LibCMaker project.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published
#    by the Free Software Foundation, either version 3 of the License,
#    or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#    See the GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program. If not, see <http://www.gnu.org/licenses/>.
# ****************************************************************************


cmake_policy(PUSH)


# NOTE: Use pattern '*.gn*' for search of usage of options in Skia source tree.
# NOTE: See 'declare_args()' in 'skia/gn/BUILDCONFIG.gn',
# 'declare_args()' in 'skia/gn/skia/BUILD.gn',
# in 'skia/gn/skia/BUILD.gn' for useful args.


#-----------------------------------------------------------------------
# Library version
#-----------------------------------------------------------------------

set(Skia_VERSION "157" CACHE STRING "Skia_VERSION")
set(Skia_sha256
  "83a51e33fe5818fb6d8dd58cd4c021c410a8462a202b6bb9d65aedf44b744da4"
  CACHE STRING "Skia_sha256"
)

# set(Skia_lib_COMPONENTS
#   skia skparagraph skshaper skunicode
#   CACHE STRING "Skia_lib_COMPONENTS"
# )


#-----------------------------------------------------------------------
# Define LibCMaker dirs, includes and vars
#-----------------------------------------------------------------------


if(NOT LibCMaker_DIR)
  message(FATAL_ERROR "LibCMaker_DIR is not defined.")
endif()

include("${LibCMaker_DIR}/cmake/cmr_get_cmake_min_ver.cmake" NO_POLICY_SCOPE)
cmr_get_cmake_min_ver()
cmake_minimum_required(VERSION ${cmr_CMAKE_MIN_VER})

include("${LibCMaker_DIR}/cmake/cmr_functions.cmake")

if(NOT cmr_BUILD_MULTIPROC_CNT)
  set(cmr_BUILD_MULTIPROC_CNT "1")
endif()


#-----------------------------------------------------------------------
# Update Skia to new version
#-----------------------------------------------------------------------

if(FALSE)
# if(TRUE)
  include("${CMAKE_CURRENT_LIST_DIR}/update_Skia.cmake")
  cmr_print_status("Exit after update Skia")
  cmr_print_error("======== STOP ========")
endif()


#-----------------------------------------------------------------------
# Unpack, configure and build the required libraries
#-----------------------------------------------------------------------

include(FetchContent)

set(skia_SRC_NAME "skia-m${Skia_VERSION}")
set(skia_ARCHIVE_DIR "${CMAKE_CURRENT_LIST_DIR}/source")

FetchContent_Declare(
  Skia
  URL "${skia_ARCHIVE_DIR}/${skia_SRC_NAME}.tar.xz"
  URL_HASH SHA256=${Skia_sha256}
  OVERRIDE_FIND_PACKAGE
  SOURCE_SUBDIR not_exist
)

FetchContent_MakeAvailable(Skia)

FetchContent_GetProperties(Skia
  SOURCE_DIR Skia_FETCH_SOURCE_DIR
  BINARY_DIR Skia_FETCH_BINARY_DIR
)


#-----------------------------------------------------------------------
# Paths
#-----------------------------------------------------------------------

set(skia_PATCH_DIR  "${skia_ARCHIVE_DIR}/patch/${skia_SRC_NAME}")

set(skia_MAIN_SRC_DIR        "${Skia_FETCH_SOURCE_DIR}")
set(skia_SKIA_SRC_DIR        "${skia_MAIN_SRC_DIR}/skia")
set(skia_DEPOT_TOOLS_SRC_DIR "${skia_MAIN_SRC_DIR}/depot_tools")

set(skia_MAIN_BUILD_DIR "${Skia_FETCH_BINARY_DIR}")
set(skia_SKIA_BUILD_DIR "${skia_MAIN_BUILD_DIR}/build_skia")
set(skia_CMAKE_GEN_DIR  "${skia_MAIN_BUILD_DIR}/build_cmake_gen")

if(NOT "$ENV{PATH}" STRLESS "")
  if(CMAKE_HOST_WIN32 AND CMAKE_HOST_SYSTEM_NAME MATCHES "Windows"
      AND NOT CYGWIN)
    set(_PATH_SEP "$<SEMICOLON>")
  else()
    set(_PATH_SEP ":")
  endif()
  set(_PATH_ENV "$ENV{PATH}")
  list(JOIN _PATH_ENV "${_PATH_SEP}" _PATH)
  # Get the system search path as a list.
  #file(TO_CMAKE_PATH "$ENV{PATH}" _PATH)
endif()

set(skia_ENV
  "DEPOT_TOOLS_UPDATE=0"
  "PATH=$<SHELL_PATH:${skia_DEPOT_TOOLS_SRC_DIR}>${_PATH_SEP}${_PATH}"
)


#-----------------------------------------------------------------------
# Find required tools 1
#-----------------------------------------------------------------------

find_package(Git 2.17.1 REQUIRED)
find_package(Python REQUIRED COMPONENTS Interpreter)

if(Python_VERSION VERSION_LESS 3.9)
  cmr_print_error("depot_tools requires Python 3.9+.")
endif()

find_program(ninja_EXECUTABLE "ninja" REQUIRED)
message(STATUS "Found ninja: ${ninja_EXECUTABLE}")


#-----------------------------------------------------------------------
# Macros
#-----------------------------------------------------------------------

macro(skia_opt _option _value)

  if(DEFINED CACHE{${_option}})
    set(_opt_value ${${_option}})
  else()
    if(${_value})
      set(_opt_value "true")
    else()
      set(_opt_value "false")
    endif()
  endif()

  set(${_option} "${_opt_value}" CACHE STRING "${_option}")
  string(APPEND skia_GN_ARGS " ${_option}=${_opt_value}")
  unset(_opt_value)
endmacro()

macro(skia_not _option _out_value)
  if(${_option})
    set(${_out_value} "false")
  else()
    set(${_out_value} "true")
  endif()
endmacro()

macro(skia_string _option _value)
  string(APPEND skia_GN_ARGS " ${_option}=\"${_value}\"")
endmacro()

macro(skia_value _option _value)
  string(APPEND skia_GN_ARGS " ${_option}=${_value}")
endmacro()


#-----------------------------------------------------------------------
# LibCMaker options
#-----------------------------------------------------------------------

option(not_fvisibility_hidden_patch "not_fvisibility_hidden_patch" true)


#-----------------------------------------------------------------------
# Patches
#-----------------------------------------------------------------------

function(apply_skia_source_patch _name)
  set(${_name}_STAMP
    "${skia_MAIN_SRC_DIR}/stamp__patch__${_name}__.stamp"
  )
  if(NOT EXISTS ${${_name}_STAMP})
    cmr_print_status("Apply Skia source patch: '${_name}'")
    set(${_name}_FILE
      "${skia_PATCH_DIR}/${_name}"
    )
    execute_process(
      COMMAND ${GIT_EXECUTABLE} apply
        # --reverse
        ${${_name}_FILE}
      WORKING_DIRECTORY ${skia_SKIA_SRC_DIR}
      RESULT_VARIABLE res_${_name}
    )
    if (res_${_name})
      cmr_print_error("Failed patch ${_name}: ${res_${_name}}")
    endif()
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E touch ${${_name}_STAMP}
    )
  endif()
endfunction()

# apply_skia_source_patch("GN__Android_iOS__Do_not_build__skia_c_api_example.patch")
# apply_skia_source_patch("GN__Windows__Fix_MSVC_x86_build.patch")
# apply_skia_source_patch("GN__Windows__Fix_link_deps.patch")
# apply_skia_source_patch("GN__iOS__Fix_link_deps.patch")
# apply_skia_source_patch("Src__Fix_for__skia_enable_sksl.patch")
# apply_skia_source_patch("Src__Fix_for__skia_use_sfntly.patch")
# apply_skia_source_patch("Src__Windows__Fix_MSVC_shared_build.patch")
## apply_skia_source_patch("Tools__Add_depth-1_to_git-clone_for_deps.patch")

apply_skia_source_patch("Dawn__skia_use_system_dawn.patch")

# if(not_fvisibility_hidden_patch)
#   apply_skia_source_patch("GN__Not_-fvisibility_hidden.patch")
# endif()


#-----------------------------------------------------------------------
# OS specifics
#-----------------------------------------------------------------------

# TODO: is_wasm
if(WIN32)  # TODO: May be other var, see CMake docs.
  set(target_os "win")
elseif(IOS)
  set(target_os "ios")
elseif(APPLE)  # TODO: May be other var, see CMake docs.
  set(target_os "mac")
elseif(ANDROID)
  set(target_os "android")
elseif("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")  # TODO: May be other var, see CMake docs.
  set(target_os "linux")
else()
  cmr_print_error("Unsupported platform.")
endif()

set(_is_android false)
set(_is_linux   false)
set(_is_ios     false)
set(_is_mac     false)
set(_is_wasm    false)
set(_is_win     false)
set(_is_${target_os} true)

set(is_android  ${_is_android}  CACHE STRING "is_android")
set(is_linux    ${_is_linux}    CACHE STRING "is_linux")
set(is_ios      ${_is_ios}      CACHE STRING "is_ios")
set(is_mac      ${_is_mac}      CACHE STRING "is_mac")
set(is_wasm     ${_is_wasm}     CACHE STRING "is_wasm")
set(is_win      ${_is_win}      CACHE STRING "is_win")

# skia_not(is_win is_not_win)


#-----------------------------------------------------------------------
# Find required tools 2
#-----------------------------------------------------------------------

include(CheckLanguage)

check_language(ASM)
if(CMAKE_ASM_COMPILER)
  enable_language(ASM)
else()
  cmr_print_error("No ASM support.")
endif()

check_language(C)
if(CMAKE_C_COMPILER)
  enable_language(C)
else()
  cmr_print_error("No C support.")
endif()

check_language(CXX)
if(CMAKE_CXX_COMPILER)
  enable_language(CXX)
else()
  cmr_print_error("No CXX support.")
endif()


# NOTE: 2026-09: Skia requires C++20
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU"
    AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 12.0.0)
  cmr_print_error("GNU g++ compiler version 12+ is required.")
endif()

if((CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang"
     OR CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
     AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 21.0.0)
  cmr_print_error("Clang compiler version 21+ is required.")
endif()

if(MSVC AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 19.31)
  cmr_print_error("MSVC compiler version 19.31+ is required.")
endif()


if(is_linux OR is_mac OR MINGW)  # TODO: if CMake gen = "Unix Makefiles"
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU"
      OR CMAKE_CXX_COMPILER_ID STREQUAL "Clang"
      OR CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")

    if(CMAKE_CXX_COMPILER_LAUNCHER)
      set(_cc_wrapper ${CMAKE_CXX_COMPILER_LAUNCHER})
    endif()

    if(CMAKE_AR)
      set(_ar ${CMAKE_AR})
    endif()

    if(CMAKE_ASM_COMPILER)
      set(_asm ${CMAKE_ASM_COMPILER})
    endif()
    if(CMAKE_C_COMPILER)
      set(_cc ${CMAKE_C_COMPILER})
    endif()
    if(CMAKE_CXX_COMPILER)
      set(_cxx ${CMAKE_CXX_COMPILER})
    endif()

  endif()
endif()


set(_skia_use_ndk_images false)
set(ndk_api 29)

if(is_android)
  if    (CMAKE_ANDROID_ARCH_ABI STREQUAL "armeabi-v7a")
    set(target_cpu "arm")
  elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
    set(target_cpu "arm64")
  elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "x86")
    set(target_cpu "x86")
  elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "x86_64")
    set(target_cpu "x64")
  else()
    cmr_print_error("Unsupported CPU arch.")
  endif()

  set(ndk ${CMAKE_ANDROID_NDK})
  set(ndk_api ${CMAKE_SYSTEM_VERSION})

  if(is_android AND DEFINED ndk_api AND ndk_api VERSION_GREATER_EQUAL 30)
    set(_skia_use_ndk_images true)
  endif()

  # NDK r29 supports minimum Lollipop, Android 5.0, API level 21.
  if(ANDROID_NDK_MAJOR LESS 29)
    cmr_print_error("Android NDK r29+ is required.")
  endif()
endif()


# TODO:
# if(is_linux)
#   set(target_cpu "")
# endif()


if(is_ios)
  if    (ARCHS STREQUAL "armv7")
    set(target_cpu "arm")
  elseif(ARCHS STREQUAL "arm64")
    set(target_cpu "arm64")
  elseif(ARCHS STREQUAL "i386")
    set(target_cpu "x86")
  elseif(ARCHS STREQUAL "x86_64")
    set(target_cpu "x64")
  else()
    cmr_print_error("Unsupported CPU arch.")
  endif()

  if(DEPLOYMENT_TARGET)
    set(ios_min_target ${DEPLOYMENT_TARGET})
  endif()
endif()

# TODO:
# if(is_mac)
#   set(target_cpu "")
# endif()

if(XCODE)
  if(is_mac AND CMAKE_OSX_SYSROOT)
    set(xcode_sysroot ${CMAKE_OSX_SYSROOT})
  endif()
  if(is_ios AND CMAKE_OSX_SYSROOT_INT)
    set(xcode_sysroot ${CMAKE_OSX_SYSROOT_INT})
  endif()
endif()


if(is_win AND MSVC)
  if    (CMAKE_GENERATOR_PLATFORM STREQUAL "ARM")
    set(target_cpu "arm")
  elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
    set(target_cpu "arm64")
  elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "Win32")
    set(target_cpu "x86")
  elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "x64")
    set(target_cpu "x64")
  else()
    cmr_print_error("Unsupported CPU arch.")
  endif()

  # TODO: clang_win
  #  clang_win = ""
  #  clang_win_version = ""
  # NOTE: https://skia.org/docs/user/build/#highly-recommended-build-with-clang-cl

  if(cmr_WINDOWS_KITS_DIR)
    set(win_sdk ${cmr_WINDOWS_KITS_DIR})
  endif()
  if(cmr_WINDOWS_KITS_VERSION)
    set(win_sdk_version ${cmr_WINDOWS_KITS_VERSION})
  endif()
  if(cmr_VS_TOOLSET_VERSION)
    set(win_toolchain_version ${cmr_VS_TOOLSET_VERSION})
  endif()
  if(cmr_VS_TOOLSET_DIR)
    set(win_vc ${cmr_VS_TOOLSET_DIR})
  endif()
endif()


# TODO:
# Need if()-endif() ???
# if(is_wasm)
#   skia_opt( is_canvaskit ${is_wasm} )
# endif()
skia_opt( is_canvaskit false )


#-----------------------------------------------------------------------
# Compiler flags
#-----------------------------------------------------------------------

# List of flags:
#cflags = [
#   "--flag1",
#    "--flag2",
#    "--flag3",
#]

string(APPEND skia_ASFLAGS " ${CMAKE_ASM_FLAGS}")
string(APPEND skia_ASFLAGS " $<$<CONFIG:Debug>:${CMAKE_ASM_FLAGS_DEBUG}>")
string(APPEND skia_ASFLAGS " $<$<CONFIG:Release>:${CMAKE_ASM_FLAGS_RELEASE}>")

string(APPEND skia_CFLAGS " ${CMAKE_C_FLAGS}")
string(APPEND skia_CFLAGS " $<$<CONFIG:Debug>:${CMAKE_C_FLAGS_DEBUG}>")
string(APPEND skia_CFLAGS " $<$<CONFIG:Release>:${CMAKE_C_FLAGS_RELEASE}>")

string(APPEND skia_CXXFLAGS " ${CMAKE_CXX_FLAGS}")
string(APPEND skia_CXXFLAGS " $<$<CONFIG:Debug>:${CMAKE_CXX_FLAGS_DEBUG}>")
string(APPEND skia_CXXFLAGS " $<$<CONFIG:Release>:${CMAKE_CXX_FLAGS_RELEASE}>")

if(BUILD_SHARED_LIBS)  # use skia var
  string(APPEND skia_LDFLAGS " ${CMAKE_SHARED_LINKER_FLAGS}")
  string(APPEND skia_LDFLAGS " $<$<CONFIG:Debug>:${CMAKE_SHARED_LINKER_FLAGS_DEBUG}>")
  string(APPEND skia_LDFLAGS " $<$<CONFIG:Release>:${CMAKE_SHARED_LINKER_FLAGS_RELEASE}>")
else()
  # string(APPEND skia_ASFLAGS " ${CMAKE_ASM_COMPILE_OPTIONS_PIC}")
  # string(APPEND skia_CFLAGS " ${CMAKE_C_COMPILE_OPTIONS_PIC}")
  # string(APPEND skia_CXXFLAGS " ${CMAKE_CXX_COMPILE_OPTIONS_PIC}")

  string(APPEND skia_LDFLAGS " ${CMAKE_STATIC_LINKER_FLAGS}")
  string(APPEND skia_LDFLAGS " $<$<CONFIG:Debug>:${CMAKE_STATIC_LINKER_FLAGS_DEBUG}>")
  string(APPEND skia_LDFLAGS " $<$<CONFIG:Release>:${CMAKE_STATIC_LINKER_FLAGS_RELEASE}>")

  # For Android:
  #string(APPEND skia_LDFLAGS " -static-libstdc++")
endif()

if(WIN32 AND MSVC)
  set(flag_MT_MD_sfx "$<$<CONFIG:Debug>:d>")

  if(BUILD_SHARED_LIBS)
    string(APPEND skia_CPPFLAGS " /MD${flag_MT_MD_sfx}")
  else()
    string(APPEND skia_CPPFLAGS " /MT${flag_MT_MD_sfx}")
  endif()

  if(TARGETING_XP_64 OR TARGETING_XP)
    string(APPEND skia_CPPFLAGS " /D_ATL_XP_TARGETING")
  endif()
endif()

macro(cmake_args_to_gn _flags)
  if(${_flags})
    separate_arguments(${_flags} NATIVE_COMMAND ${${_flags}})
    string(JOIN "\", \"" ${_flags} ${${_flags}})
    set(${_flags} "[ \"${${_flags}}\" ]")
  endif()
endmacro()

cmake_args_to_gn(skia_ASFLAGS)
cmake_args_to_gn(skia_CPPFLAGS)
cmake_args_to_gn(skia_CFLAGS)
cmake_args_to_gn(skia_CXXFLAGS)
cmake_args_to_gn(skia_LDFLAGS)


#-----------------------------------------------------------------------
# Skia GN options
#-----------------------------------------------------------------------

set(is_debug "$<IF:$<CONFIG:Debug>,true,false>")
skia_value( is_debug ${is_debug} )

set(is_official_build "$<IF:$<CONFIG:Debug>,false,true>")
skia_value( is_official_build ${is_official_build} )

skia_opt( is_component_build ${BUILD_SHARED_LIBS} )

# dlsymutil_pool_depth = 12
# dlsymutil_pool_depth = cpu_cores - 2 = 10
# link_pool_depth = -1
# link_pool_depth = memory / 10Gb = 64 / 10 = 6


skia_opt( show_includes false )
skia_opt( third_party_isystem true )
skia_opt( werror false )

skia_string( malloc "${_malloc}" )
skia_string( sanitize "${_sanitize}" )


# Set extra_flags

if(skia_ASFLAGS)
  skia_value( extra_asmflags ${skia_ASFLAGS} )
else()
  skia_value( extra_asmflags "[ \"\" ]" )
endif()

if(skia_CPPFLAGS)
  skia_value( extra_cflags ${skia_CPPFLAGS} )
else()
  skia_value( extra_cflags "[ \"\" ]" )
endif()

if(skia_CFLAGS)
  skia_value( extra_cflags_c ${skia_CFLAGS} )
else()
  skia_value( extra_cflags_c "[ \"\" ]" )
endif()

if(skia_CXXFLAGS)
  skia_value( extra_cflags_cc ${skia_CXXFLAGS} )
else()
  skia_value( extra_cflags_cc "[ \"\" ]" )
endif()

if(skia_LDFLAGS)
  skia_value( extra_ldflags ${skia_LDFLAGS} )
else()
  skia_value( extra_ldflags "[ \"\" ]" )
endif()


# Set Skia options

skia_string( cc_wrapper "${_cc_wrapper}" )
skia_string( ar "${_ar}" )
# skia_string( asm "${_asm}" )
skia_string( cc "${_cc}" )
skia_string( cxx "${_cxx}" )
# current_cpu = ""
# current_os = ""

# host_ar = "/usr/bin/ar"
# host_cc = "/usr/bin/gcc"
# host_cxx = "/usr/bin/g++"
# host_link = "/usr/bin/g++"
# host_cpu = "x64"
# host_os = "linux"

# target_ar = "/usr/bin/ar"
# target_cc = "/usr/bin/gcc"
# target_cxx = "/usr/bin/g++"
# target_link = "/usr/bin/g++"
skia_string( target_cpu "${target_cpu}" )
skia_string( target_os "${target_os}" )

skia_string( ndk "${ndk}" )
skia_value( ndk_api ${ndk_api} )
skia_opt( skia_use_ndk_images ${_skia_use_ndk_images} )
skia_string( skia_android_serial "${_skia_android_serial}" )

skia_string( ios_min_target "${ios_min_target}" )
skia_opt( ios_use_simulator false )
skia_string( xcode_sysroot "${xcode_sysroot}" )

# clang_win = ""
# clang_win_version = ""
skia_string( win_sdk "${win_sdk}" )
skia_string( win_sdk_version "${win_sdk_version}" )
skia_string( win_toolchain_version "${win_toolchain_version}" )
skia_string( win_vc "${win_vc}" )
# skia_dwritecore_sdk = ""


# skia_system_freetype2_lib = "freetype"
# skia_system_freetype2_include_path = "/usr/include/freetype2"

# skia_emsdk_dir = "//third_party/externals/emsdk"
# skia_icu_bidi_third_party_dir = "//third_party/icu_bidi"
# skia_libgrapheme_third_party_dir = "//third_party/libgrapheme"
# skia_partition_alloc_dir = "//third_party/externals/partition_alloc"
# skia_vulkan_memory_allocator_dir = "//third_party/externals/vulkanmemoryallocator"


# Required options
skia_opt( skia_enable_fontmgr_custom_empty true )
skia_opt( skia_enable_fontmgr_custom_directory true )
skia_opt( skia_enable_fontmgr_custom_embedded true )

skia_opt( skia_enable_skottie false )
skia_opt( skia_enable_skparagraph true )
skia_opt( skia_enable_skshaper true )
skia_opt( skia_enable_skunicode true )
skia_opt( skia_enable_svg true )

skia_opt( skia_enable_pdf true )
skia_opt( skia_pdf_subset_harfbuzz true )

skia_opt( skia_enable_api_available_macro true )
skia_opt( skia_enable_bentleyottmann true )
skia_opt( skia_enable_optimize_size false )

skia_opt( skia_enable_packed_422_yuv false )
skia_opt( skia_use_dng_sdk false )
skia_opt( skia_use_ffmpeg false )
skia_opt( skia_use_jpeg_gainmaps false )
skia_opt( skia_use_libavif false )
skia_opt( skia_use_libjxl_decode false )
skia_opt( skia_use_piex false )
skia_opt( skia_use_wuffs true )


# Libraries
skia_opt( skia_use_system_expat false )
skia_opt( skia_use_system_freetype2 false )
skia_opt( skia_use_system_harfbuzz false )
skia_opt( skia_use_system_icu true )
skia_opt( skia_use_system_libjpeg_turbo false )
skia_opt( skia_use_system_libpng false )
skia_opt( skia_use_system_libwebp false )
skia_opt( skia_use_system_zlib false )

skia_opt( skia_use_expat true )
skia_opt( skia_use_freetype true )
skia_opt( skia_use_freetype_svg true )
skia_opt( skia_use_freetype_woff2 true )
skia_opt( skia_use_freetype_zlib true )
skia_opt( skia_use_freetype_zlib_bundled true )
skia_opt( skia_use_harfbuzz true )
skia_opt( skia_use_icu true )
skia_opt( skia_use_runtime_icu false )
skia_opt( skia_use_libjpeg_turbo_decode true )
skia_opt( skia_use_libjpeg_turbo_encode true )
skia_opt( skia_use_libpng_decode true )
skia_opt( skia_use_libpng_encode true )
skia_opt( skia_use_libwebp_decode true )
skia_opt( skia_use_libwebp_encode true )
skia_opt( skia_use_no_jpeg_encode false )
skia_opt( skia_use_no_png_encode false )
skia_opt( skia_use_no_webp_encode false )
skia_opt( skia_use_zlib true )


# Video card

# For Ganesh
skia_opt( skia_enable_ganesh true )

if(skia_enable_ganesh)
  if(is_android OR is_ios OR is_linux OR is_win)
    set(_skia_gl_standard "gles")
  elseif(is_mac)
    # set(_skia_gl_standard "gl")
    set(_skia_gl_standard "gles")
  elseif(is_wasm)
    set(_skia_gl_standard "webgl")
  endif()

  if(is_android OR is_linux OR is_win)
    set(_skia_use_egl true)
  else()
    set(_skia_use_egl false)
  endif()

  skia_opt( skia_use_gl true )
  skia_string( skia_gl_standard "${_skia_gl_standard}" )

  skia_opt( skia_use_angle ${is_win} )
  skia_opt( skia_use_webgl ${is_wasm} )
  skia_opt( skia_use_x11 ${is_linux} )

  skia_opt( skia_use_egl ${_skia_use_egl} )
  skia_opt( skia_use_epoxy_egl false )

  skia_opt( skia_use_direct3d false )

else()
  skia_opt( skia_use_gl false )
  skia_string( skia_gl_standard "" )
  skia_opt( skia_use_angle false )
  skia_opt( skia_use_webgl false )
  skia_opt( skia_use_x11 false )
  skia_opt( skia_use_egl false )
  skia_opt( skia_use_epoxy_egl false )
  skia_opt( skia_use_direct3d false )
endif()


# For Graphite
skia_opt( skia_enable_graphite true )

if(skia_enable_graphite)
  # if(is_android OR is_linux)
  #   set(_dawn_enable_metal true)
  # else()
  #   set(_dawn_enable_metal false)
  # endif()

  # if(is_ios OR is_mac)
  #   set(_dawn_enable_vulkan true)
  # else()
  #   set(_dawn_enable_vulkan false)
  # endif()

  # skia_opt( skia_use_dawn true )
  # skia_opt( skia_use_webgpu ${is_wasm} )
  # skia_opt( dawn_enable_d3d12 ${is_win} )
  # skia_opt( dawn_enable_metal ${_dawn_enable_metal} )
  # skia_opt( dawn_enable_vulkan ${_dawn_enable_vulkan} )

  # skia_opt( skia_enable_precompile true )
  # skia_opt( skia_enable_sparse_strips false )

  # skia_opt( dawn_enable_d3d11 false )
  # skia_opt( dawn_enable_opengles false )


  skia_opt( skia_use_dawn true )
  skia_opt( skia_use_system_dawn true )
  skia_opt( skia_use_webgpu ${is_wasm} )
  skia_opt( dawn_enable_d3d11 ${DAWN_ENABLE_D3D11} )
  skia_opt( dawn_enable_d3d12 ${DAWN_ENABLE_D3D12} )
  skia_opt( dawn_enable_metal ${DAWN_ENABLE_METAL} )
  skia_opt( dawn_enable_opengles ${DAWN_ENABLE_OPENGLES} )
  skia_opt( dawn_enable_vulkan ${DAWN_ENABLE_VULKAN} )
  skia_opt( dawn_use_agility_sdk ${DAWN_USE_AGILITY_SDK} )

  skia_opt( skia_enable_precompile true )
  skia_opt( skia_enable_sparse_strips false )

else()
  skia_opt( skia_use_dawn false )
  skia_opt( skia_use_system_dawn false )
  skia_opt( skia_use_webgpu false )
  skia_opt( dawn_enable_d3d11 false )
  skia_opt( dawn_enable_d3d12 false )
  skia_opt( dawn_enable_metal false )
  skia_opt( dawn_enable_opengles false )
  skia_opt( dawn_enable_vulkan false )
  skia_opt( dawn_use_agility_sdk false )
  skia_opt( skia_enable_precompile false )
  skia_opt( skia_enable_sparse_strips false )
endif()


# For Ganesh or Graphite
if(skia_enable_ganesh OR skia_enable_graphite)
  skia_opt( skia_generate_workarounds true )

  skia_opt( skia_use_metal false )
  skia_opt( skia_use_vulkan false )

  skia_opt( skia_use_vma ${skia_use_vulkan} )

else()
  skia_opt( skia_generate_workarounds false )
  skia_opt( skia_use_metal false )
  skia_opt( skia_use_vulkan false )
  skia_opt( skia_use_vma false )
endif()


# Experimental
skia_opt( skia_enable_threadlocal_strikecache false )


# Unnecessary options
# TODO: experimental to Experimental

skia_opt( is_trivial_abi false )

skia_opt( skia_enable_android_utils false )
skia_opt( skia_enable_winuwp false )

skia_opt( skia_include_multiframe_procs false )

skia_opt( skia_use_bidi false )
skia_opt( skia_use_client_icu false )
skia_opt( skia_use_libgrapheme false )
skia_opt( skia_use_partition_alloc false )
skia_opt( skia_use_sfml false )
skia_opt( skia_use_xps false )

skia_opt( skia_build_rust_targets false )
skia_opt( skia_use_rust_bmp_decode false )
skia_opt( skia_use_rust_exif false )
skia_opt( skia_use_rust_icc false )
skia_opt( skia_use_rust_ico_decode false )
skia_opt( skia_use_rust_jpeg_decode false )
skia_opt( skia_use_rust_jpeg_encode false )
skia_opt( skia_use_rust_png_decode false )
skia_opt( skia_use_rust_png_encode false )
skia_opt( skia_use_rust_png_for_android false )
skia_opt( skia_use_crabbyavif false )
skia_opt( skia_use_fontations false )
skia_opt( skia_use_icu4x false )

# Unnecessary options: Fonts
skia_opt( skia_use_fontconfig false )
skia_opt( skia_enable_fontmgr_fontconfig false )
skia_opt( skia_enable_fontmgr_FontConfigInterface false )
skia_opt( skia_enable_fontmgr_android false )
skia_opt( skia_enable_fontmgr_android_ndk false )
skia_opt( skia_enable_fontmgr_win false )
skia_opt( skia_enable_fontmgr_win_gdi false )
skia_opt( skia_use_apple_unicode false )
skia_opt( skia_use_fonthost_mac false )

skia_opt( skia_enable_fontmgr_empty false )
skia_opt( skia_enable_fontmgr_fontations_empty false )

skia_opt( skia_use_fixed_gamma_text false )
skia_opt( skia_use_lcd_text_3x_filter false )

# Unnecessary options: Video card
skia_opt( skia_compile_modules false )
skia_opt( skia_disable_vma_stl_shared_mutex false )
skia_opt( skia_enable_discrete_gpu false )
skia_opt( skia_enable_vello_shaders false )
skia_opt( skia_lex false )


# For testing.
skia_opt( skia_enable_tools false )
skia_opt( skia_tools_require_resources false )

skia_opt( skia_compile_sksl_tests false )
skia_opt( skia_enable_skshaper_tests false )
skia_opt( skunicode_tests_enabled false )

skia_opt( paragraph_bench_enabled false )
skia_opt( paragraph_gms_enabled false )
skia_opt( paragraph_tests_enabled false )

skia_opt( use_libfuzzer false )
skia_opt( skia_build_fuzzers false )
skia_opt( skia_provide_default_fuzz_engine false )

skia_opt( skia_use_lua false )


# For debugging.
skia_opt( skia_build_for_debugger false )

skia_opt( skia_enable_direct3d_debug_layer false )
skia_opt( skia_enable_metal_debug_info false )
skia_opt( skia_enable_vulkan_debug_layers false )

skia_opt( skia_disable_tracing true )
skia_opt( skia_dump_tasks false )
skia_opt( skia_print_native_shaders false )
skia_opt( skia_print_sksl_shaders false )

skia_opt( skia_enable_gpu_debug_layers false )
skia_opt( skia_enable_pipeline_label_tracing false )
skia_opt( skia_enable_spirv_validation false )

skia_opt( skia_android_framework_use_perfetto false )
skia_opt( skia_use_perfetto false )
skia_opt( skia_use_pprof false )
skia_opt( skia_use_safe_libcxx false )


#-----------------------------------------------------------------------
# Find required tools 3
#-----------------------------------------------------------------------

if(skia_use_icu AND skia_use_system_icu)

  macro(get_icu_target_properties name)
    get_target_property(icu_${name}_compile_defs ICU::${name}
      INTERFACE_COMPILE_DEFINITIONS
    )
    if(NOT icu_${name}_compile_defs)
      cmr_print_error("icu_${name}_compile_defs is NOTFOUND")
    endif()

    if((NOT ${name} STREQUAL "data") AND (NOT ${name} STREQUAL "tu"))
      get_target_property(icu_${name}_includes ICU::${name}
        INTERFACE_INCLUDE_DIRECTORIES
      )
      if(NOT icu_${name}_includes)
        cmr_print_error("icu_${name}_includes is NOTFOUND")
      endif()
    endif()

    get_target_property(icu_${name}_location ICU::${name}
      IMPORTED_LOCATION
    )
    if(NOT icu_${name}_location)
      cmr_print_error("icu_${name}_location is NOTFOUND")
    endif()

    if(is_win AND BUILD_SHARED_LIBS)
      get_target_property(icu_${name}_implib ICU::${name}
        IMPORTED_IMPLIB
      )
      if(NOT icu_${name}_implib)
        cmr_print_error("icu_${name}_implib is NOTFOUND")
      endif()
    endif()

    # TODO: ICU PDB
  endmacro()


  find_package(ICU REQUIRED)
  get_icu_target_properties(data)
  get_icu_target_properties(uc)
  get_icu_target_properties(i18n)
  get_icu_target_properties(io)


  list(APPEND icu_compile_defs ${icu_io_compile_defs})
  list(APPEND icu_compile_defs ${icu_i18n_compile_defs})
  list(APPEND icu_compile_defs ${icu_uc_compile_defs})
  list(APPEND icu_compile_defs ${icu_data_compile_defs})

  list(JOIN icu_compile_defs "\", \"-D" icu_compile_defs)
  set(icu_compile_defs "[ \"-D${icu_compile_defs}\" ]")
  string(APPEND skia_GN_ARGS " extra_cflags += ${icu_compile_defs}")


  list(APPEND icu_includes ${icu_io_includes})
  list(APPEND icu_includes ${icu_i18n_includes})
  list(APPEND icu_includes ${icu_uc_includes})

  list(JOIN icu_includes "\", \"-isystem " icu_includes)
  set(icu_includes "[ \"-isystem ${icu_includes}\" ]")
  string(APPEND skia_GN_ARGS " extra_cflags += ${icu_includes}")


  list(APPEND icu_location ${icu_io_location})
  list(APPEND icu_location ${icu_i18n_location})
  list(APPEND icu_location ${icu_uc_location})
  list(APPEND icu_location ${icu_data_location})

  list(JOIN icu_location "\", \"" icu_location)
  set(icu_location "[ \"${icu_location}\" ]")
  string(APPEND skia_GN_ARGS " extra_ldflags += ${icu_location}")


  if(is_win AND BUILD_SHARED_LIBS)
    list(APPEND icu_implib ${icu_io_implib})
    list(APPEND icu_implib ${icu_i18n_implib})
    list(APPEND icu_implib ${icu_uc_implib})
    list(APPEND icu_implib ${icu_data_implib})

    list(JOIN icu_implib "\", \"" icu_implib)
    set(icu_implib "[ \"${icu_implib}\" ]")
    # string(APPEND skia_GN_ARGS " ??? += ${icu_implib}")
  endif()
endif()


if(skia_use_dawn AND skia_use_system_dawn)
  find_package(Dawn REQUIRED)
  set(_dawn "dawn::webgpu_dawn")

  set(dawn_includes "[ \"-I$<JOIN:$<TARGET_PROPERTY:${_dawn},INTERFACE_INCLUDE_DIRECTORIES>,\", \"-I>\" ]")
  string(APPEND skia_GN_ARGS " extra_cflags += ${dawn_includes}")

  set(dawn_location "[ \"$<TARGET_LINKER_FILE:${_dawn}>\" ]")
  string(APPEND skia_GN_ARGS " extra_ldflags += ${dawn_location}")

  set(dawn_location_DIR "[ \"-L$<TARGET_LINKER_FILE_DIR:${_dawn}>\" ]")
  string(APPEND skia_GN_ARGS " extra_ldflags += ${dawn_location_DIR}")
endif()


#-----------------------------------------------------------------------
# Configure and build
#-----------------------------------------------------------------------

cmr_print_value(skia_GN_ARGS)

if(skia_use_icu AND skia_use_system_icu)
  list(APPEND depends_icu ICU::io ICU::i18n ICU::uc ICU::data)
endif()

if(skia_use_dawn AND skia_use_system_dawn)
  set(depends_dawn dawn::webgpu_dawn)
endif()

set(configure_STAMP "${skia_MAIN_SRC_DIR}/stamp__skia_configure.stamp")
add_custom_command(OUTPUT ${configure_STAMP}
  COMMAND ${CMAKE_COMMAND} -E make_directory ${skia_SKIA_BUILD_DIR}
  COMMAND ${CMAKE_COMMAND} -E env ${skia_ENV}
    bin/gn gen ${skia_SKIA_BUILD_DIR} "--args=${skia_GN_ARGS}"
  COMMAND ${CMAKE_COMMAND} -E touch ${configure_STAMP}
  WORKING_DIRECTORY ${skia_SKIA_SRC_DIR}
  VERBATIM
  COMMENT "Configure Skia"
  DEPENDS ${depends_icu} ${depends_dawn}
)

# NOTE: This is for debug.
set(configure_debug_helpers_STAMP
  "${skia_MAIN_SRC_DIR}/stamp__skia_configure_debug_helpers.stamp"
)
add_custom_command(OUTPUT ${configure_debug_helpers_STAMP}
  COMMAND ${CMAKE_COMMAND} -E env ${skia_ENV}
    bin/gn help all
        > "gn_help_all.txt"
  COMMAND ${CMAKE_COMMAND} -E env ${skia_ENV}
    bin/gn ls ${skia_SKIA_BUILD_DIR}
        > "gn_list_of_all_available_targets.txt"
  COMMAND ${CMAKE_COMMAND} -E env ${skia_ENV}
    bin/gn args ${skia_SKIA_BUILD_DIR} "--help"
        > "gn_args_--help.txt"
  COMMAND ${CMAKE_COMMAND} -E env ${skia_ENV}
    bin/gn args ${skia_SKIA_BUILD_DIR} "--list"
        > "gn_args_--list.txt"
  COMMAND ${CMAKE_COMMAND} -E env ${skia_ENV}
    bin/gn args ${skia_SKIA_BUILD_DIR} "--list" "--short"
        > "gn_args_--list_--short.txt"

  COMMAND ${CMAKE_COMMAND} -E make_directory "${skia_CMAKE_GEN_DIR}/CMakeDebug"
  COMMAND ${CMAKE_COMMAND} -E env ${skia_ENV}
    bin/gn gen "${skia_CMAKE_GEN_DIR}/CMakeDebug"
      "--args=${skia_GN_ARGS}"
      "--ide=json"
      "--json-ide-script=${skia_SKIA_SRC_DIR}/gn/gn_to_cmake.py"

  COMMAND ${CMAKE_COMMAND} -E touch ${configure_debug_helpers_STAMP}
  WORKING_DIRECTORY ${skia_SKIA_SRC_DIR}
  VERBATIM
  COMMENT "Configure Skia debug helpers"
  DEPENDS ${configure_STAMP}
)

if(CMAKE_VERBOSE_MAKEFILE)
  set(verbose_ninja "-v")
endif()

set(build_STAMP "${skia_MAIN_SRC_DIR}/stamp__skia_build.stamp")
add_custom_command(OUTPUT ${build_STAMP}
  COMMAND ${CMAKE_COMMAND} -E env ${skia_ENV}
    ${ninja_EXECUTABLE}
      "-j" "${cmr_BUILD_MULTIPROC_CNT}"
      "-C" "${skia_SKIA_BUILD_DIR}"
      ${verbose_ninja}
  COMMAND ${CMAKE_COMMAND} -E touch ${build_STAMP}
  WORKING_DIRECTORY ${skia_SKIA_SRC_DIR}
  VERBATIM
  COMMENT "Build Skia"
  DEPENDS ${configure_STAMP}
)

add_custom_target(build_skia ALL
  DEPENDS ${build_STAMP}
  # DEPENDS ${configure_debug_helpers_STAMP}  # NOTE: This is for debug.
  COMMENT "build_skia target"
)


#-----------------------------------------------------------------------
# Install
#-----------------------------------------------------------------------

include(GNUInstallDirs)

set(lib_PFX_SHARED ${CMAKE_SHARED_LIBRARY_PREFIX})
set(lib_SFX_SHARED ${CMAKE_SHARED_LIBRARY_SUFFIX})
set(lib_PFX_STATIC ${CMAKE_STATIC_LIBRARY_PREFIX})
set(lib_SFX_STATIC ${CMAKE_STATIC_LIBRARY_SUFFIX})

if(BUILD_SHARED_LIBS)
  set(lib_PFX ${lib_PFX_SHARED})
  set(lib_SFX ${lib_SFX_SHARED})
  if(is_mac OR is_ios)
    set(lib_SFX ".so")
  endif()
else()
  set(lib_PFX ${lib_PFX_STATIC})
  set(lib_SFX ${lib_SFX_STATIC})
endif()

set(skia_INSTALL_INCLUDE_DIR "${CMAKE_INSTALL_INCLUDEDIR}/skia")
set(skia_INSTALL_MODULES_DIR "${skia_INSTALL_INCLUDE_DIR}/modules")
set(skia_INSTALL_BIN_DIR "${CMAKE_INSTALL_BINDIR}")
set(skia_INSTALL_LIB_DIR "${CMAKE_INSTALL_LIBDIR}")
set(skia_INSTALL_PDB_DIR "${CMAKE_INSTALL_BINDIR}")
set(skia_INSTALL_DLL_DIR
  "$<IF:$<AND:$<BOOL:${is_win}>,$<BOOL:${BUILD_SHARED_LIBS}>>,${skia_INSTALL_BIN_DIR},${skia_INSTALL_LIB_DIR}>"
)


set(skia_FILE_NAME "${lib_PFX}skia${lib_SFX}")
set(skia_DLL_LIB_FILE_NAME "skia.dll.lib")
set(skia_DLL_PDB_FILE_NAME "skia.dll.pdb")

set(bentleyottmann_FILE_NAME "${lib_PFX}bentleyottmann${lib_SFX}")
set(bentleyottmann_DLL_LIB_FILE_NAME "bentleyottmann.dll.lib")
set(bentleyottmann_DLL_PDB_FILE_NAME "bentleyottmann.dll.pdb")

set(skparagraph_FILE_NAME "${lib_PFX}skparagraph${lib_SFX}")
set(skparagraph_DLL_LIB_FILE_NAME "skparagraph.dll.lib")
set(skparagraph_DLL_PDB_FILE_NAME "skparagraph.dll.pdb")

set(skshaper_FILE_NAME "${lib_PFX}skshaper${lib_SFX}")
set(skshaper_DLL_LIB_FILE_NAME "skshaper.dll.lib")
set(skshaper_DLL_PDB_FILE_NAME "skshaper.dll.pdb")

set(skunicode_core_FILE_NAME "${lib_PFX}skunicode_core${lib_SFX}")
set(skunicode_core_DLL_LIB_FILE_NAME "skunicode_core.dll.lib")
set(skunicode_core_DLL_PDB_FILE_NAME "skunicode_core.dll.pdb")

set(skunicode_icu_FILE_NAME "${lib_PFX}skunicode_icu${lib_SFX}")
set(skunicode_icu_DLL_LIB_FILE_NAME "skunicode_icu.dll.lib")
set(skunicode_icu_DLL_PDB_FILE_NAME "skunicode_icu.dll.pdb")

set(svg_FILE_NAME "${lib_PFX}svg${lib_SFX}")
set(svg_DLL_LIB_FILE_NAME "svg.dll.lib")
set(svg_DLL_PDB_FILE_NAME "svg.dll.pdb")

# # TODO: icudata_FILE_NAME
# # TODO: generator expr (if android, android_small, cast, common, ios in <skia/third_party/externals/icu>) for icudtb.dat and icudtl_extra.dat
set(icudata_FILE_NAME "icudtl.dat")


install(
  DIRECTORY
    "${skia_SKIA_SRC_DIR}/experimental"
    "${skia_SKIA_SRC_DIR}/include"
    "${skia_SKIA_SRC_DIR}/platform_tools"
    "${skia_SKIA_SRC_DIR}/src"
      DESTINATION "${skia_INSTALL_INCLUDE_DIR}"
  FILES_MATCHING PATTERN "*.h"
)
install(
  FILES "${skia_SKIA_BUILD_DIR}/${skia_FILE_NAME}"
  DESTINATION "${skia_INSTALL_DLL_DIR}"
)
if(is_component_build AND is_win)
  install(
    FILES "${skia_SKIA_BUILD_DIR}/${skia_DLL_LIB_FILE_NAME}"
    DESTINATION "${skia_INSTALL_LIB_DIR}"
  )
  install(
    FILES "$<$<CONFIG:Debug>:${skia_SKIA_BUILD_DIR}/${skia_DLL_PDB_FILE_NAME}>"
    DESTINATION "${skia_INSTALL_PDB_DIR}"
  )
endif()


if(skia_enable_bentleyottmann)
  install(
    DIRECTORY "${skia_SKIA_SRC_DIR}/modules/skshaper/include"
    DESTINATION "${skia_INSTALL_MODULES_DIR}/skshaper"
    FILES_MATCHING PATTERN "*.h"
  )
  install(
    FILES "${skia_SKIA_BUILD_DIR}/${bentleyottmann_FILE_NAME}"
    DESTINATION "${skia_INSTALL_DLL_DIR}"
  )
  if(is_component_build AND is_win)
    install(
      FILES "${skia_SKIA_BUILD_DIR}/${bentleyottmann_DLL_LIB_FILE_NAME}"
      DESTINATION "${skia_INSTALL_LIB_DIR}"
    )
    install(
      FILES "$<$<CONFIG:Debug>:${skia_SKIA_BUILD_DIR}/${bentleyottmann_DLL_PDB_FILE_NAME}>"
      DESTINATION "${skia_INSTALL_PDB_DIR}"
    )
  endif()
endif()


if(skia_enable_skparagraph AND skia_enable_skshaper AND skia_use_icu AND skia_use_harfbuzz)
  install(
    DIRECTORY "${skia_SKIA_SRC_DIR}/modules/skparagraph/include"
    DESTINATION "${skia_INSTALL_MODULES_DIR}/skparagraph"
    FILES_MATCHING PATTERN "*.h"
  )
  install(
    FILES "${skia_SKIA_BUILD_DIR}/${skparagraph_FILE_NAME}"
    DESTINATION "${skia_INSTALL_DLL_DIR}"
  )
  if(is_component_build AND is_win)
    install(
     FILES "${skia_SKIA_BUILD_DIR}/${skparagraph_DLL_LIB_FILE_NAME}"
     DESTINATION "${skia_INSTALL_LIB_DIR}"
    )
    install(
      FILES "$<$<CONFIG:Debug>:${skia_SKIA_BUILD_DIR}/${skparagraph_DLL_PDB_FILE_NAME}>"
      DESTINATION "${skia_INSTALL_PDB_DIR}"
    )
  endif()
endif()


if(skia_enable_skshaper)
  install(
    DIRECTORY "${skia_SKIA_SRC_DIR}/modules/skshaper/include"
    DESTINATION "${skia_INSTALL_MODULES_DIR}/skshaper"
    FILES_MATCHING PATTERN "*.h"
  )
  install(
    FILES "${skia_SKIA_BUILD_DIR}/${skshaper_FILE_NAME}"
    DESTINATION "${skia_INSTALL_DLL_DIR}"
  )
  if(is_component_build AND is_win)
    install(
      FILES "${skia_SKIA_BUILD_DIR}/${skshaper_DLL_LIB_FILE_NAME}"
      DESTINATION "${skia_INSTALL_LIB_DIR}"
    )
    install(
      FILES "$<$<CONFIG:Debug>:${skia_SKIA_BUILD_DIR}/${skshaper_DLL_PDB_FILE_NAME}>"
      DESTINATION "${skia_INSTALL_PDB_DIR}"
    )
  endif()
endif()


if(skia_enable_skunicode)
  install(
    DIRECTORY "${skia_SKIA_SRC_DIR}/modules/skunicode/include"
    DESTINATION "${skia_INSTALL_MODULES_DIR}/skunicode"
    FILES_MATCHING PATTERN "*.h"
  )
  install(
    FILES "${skia_SKIA_BUILD_DIR}/${skunicode_core_FILE_NAME}"
    DESTINATION "${skia_INSTALL_DLL_DIR}"
  )
  if(is_component_build AND is_win)
    install(
      FILES "${skia_SKIA_BUILD_DIR}/${skunicode_core_DLL_LIB_FILE_NAME}"
      DESTINATION "${skia_INSTALL_LIB_DIR}"
    )
    install(
      FILES "$<$<CONFIG:Debug>:${skia_SKIA_BUILD_DIR}/${skunicode_core_DLL_PDB_FILE_NAME}>"
      DESTINATION "${skia_INSTALL_PDB_DIR}"
    )
  endif()

  if(skia_use_icu)
    install(
      FILES "${skia_SKIA_BUILD_DIR}/${skunicode_icu_FILE_NAME}"
      DESTINATION "${skia_INSTALL_DLL_DIR}"
    )
    if(is_component_build AND is_win)
      install(
        FILES "${skia_SKIA_BUILD_DIR}/${skunicode_icu_DLL_LIB_FILE_NAME}"
        DESTINATION "${skia_INSTALL_LIB_DIR}"
      )
      install(
        FILES "$<$<CONFIG:Debug>:${skia_SKIA_BUILD_DIR}/${skunicode_icu_DLL_PDB_FILE_NAME}>"
        DESTINATION "${skia_INSTALL_PDB_DIR}"
      )
    endif()
  endif()
endif()


if(skia_enable_svg AND skia_use_expat)
  install(
    DIRECTORY "${skia_SKIA_SRC_DIR}/modules/svg/include"
    DESTINATION "${skia_INSTALL_MODULES_DIR}/svg"
    FILES_MATCHING PATTERN "*.h"
  )
  install(
    FILES "${skia_SKIA_BUILD_DIR}/${svg_FILE_NAME}"
    DESTINATION "${skia_INSTALL_DLL_DIR}"
  )
  if(is_component_build AND is_win)
    install(
      FILES "${skia_SKIA_BUILD_DIR}/${svg_DLL_LIB_FILE_NAME}"
      DESTINATION "${skia_INSTALL_LIB_DIR}"
    )
    install(
      FILES "$<$<CONFIG:Debug>:${skia_SKIA_BUILD_DIR}/${svg_DLL_PDB_FILE_NAME}>"
      DESTINATION "${skia_INSTALL_PDB_DIR}"
    )
  endif()
endif()


if(skia_use_icu AND NOT skia_use_system_icu)
  install(
    FILES
      "${skia_SKIA_BUILD_DIR}/${icudata_FILE_NAME}"
    DESTINATION "${skia_INSTALL_DLL_DIR}"
  )
endif()


#-----------------------------------------------------------------------
# Install SkiaConfig.in.cmake
#-----------------------------------------------------------------------

include(CMakePackageConfigHelpers)

set(cmake_gen_config OFF)

configure_package_config_file(
  "${CMAKE_CURRENT_LIST_DIR}/SkiaConfig.in.cmake"
  "${skia_CMAKE_GEN_DIR}/SkiaConfig.gen.cmake"
  INSTALL_DESTINATION "${skia_INSTALL_LIB_DIR}/cmake/Skia"
  PATH_VARS
    CMAKE_INSTALL_INCLUDEDIR
    skia_INSTALL_INCLUDE_DIR
    skia_INSTALL_MODULES_DIR
    skia_INSTALL_BIN_DIR
    skia_INSTALL_DLL_DIR
    skia_INSTALL_LIB_DIR
    skia_INSTALL_PDB_DIR
)

write_basic_package_version_file(
  "${skia_CMAKE_GEN_DIR}/SkiaConfigVersion.cmake"
  VERSION ${Skia_VERSION}
  COMPATIBILITY "SameFullVersion"
)

file(GENERATE
  OUTPUT "${skia_CMAKE_GEN_DIR}/SkiaConfig.cmake"
  INPUT "${skia_CMAKE_GEN_DIR}/SkiaConfig.gen.cmake"
  NO_SOURCE_PERMISSIONS
  NEWLINE_STYLE UNIX
)

install(
  FILES
    "${skia_CMAKE_GEN_DIR}/SkiaConfig.cmake"
    "${skia_CMAKE_GEN_DIR}/SkiaConfigVersion.cmake"
  DESTINATION "${skia_INSTALL_LIB_DIR}/cmake/Skia"
)


#-----------------------------------------------------------------------
# SkiaConfig.in.cmake to build in sorce tree
#-----------------------------------------------------------------------

set(cmake_gen_config ON)

configure_package_config_file(
  "${CMAKE_CURRENT_LIST_DIR}/SkiaConfig.in.cmake"
  "${skia_CMAKE_GEN_DIR}/SkiaConfig-configure.cmake"
  INSTALL_DESTINATION "${skia_CMAKE_GEN_DIR}"
  # INSTALL_PREFIX "/root"
  NO_SET_AND_CHECK_MACRO
)

include("${skia_CMAKE_GEN_DIR}/SkiaConfig-configure.cmake")


cmake_policy(POP)
