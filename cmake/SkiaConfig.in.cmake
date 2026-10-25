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

@PACKAGE_INIT@


#if(cmake_gen_config)
if(@cmake_gen_config@)
  macro(set_and_check _var _file)
    set(${_var} "${_file}")
  endmacro()
endif()


#
# CMakePackageConfigHelpers
# -------------------------------------



#-----------------------------------------------------------------------
# Find external libraries and set public defines
#

# NOTE: Use pattern '*.gn*' for search of usage of options in Skia source tree.


#if(cmake_gen_config)
if(@cmake_gen_config@)
  set(skia_INCLUDE_DIR "${skia_SKIA_SRC_DIR}")
  set(skia_MODULES_DIR "${skia_SKIA_SRC_DIR}/modules")
  set(skia_BIN_DIR "${skia_SKIA_BUILD_DIR}")
  set(skia_DLL_DIR "${skia_SKIA_BUILD_DIR}")
  set(skia_LIB_DIR "${skia_SKIA_BUILD_DIR}")
  set(skia_PDB_DIR "${skia_SKIA_BUILD_DIR}")
else()
  set(skia_INCLUDE_DIR "@PACKAGE_skia_INSTALL_INCLUDE_DIR@")
  set(skia_MODULES_DIR "@PACKAGE_skia_INSTALL_MODULES_DIR@")
  set(skia_BIN_DIR "@PACKAGE_skia_INSTALL_BIN_DIR@")
  set(skia_DLL_DIR "@PACKAGE_skia_INSTALL_DLL_DIR@")
  set(skia_LIB_DIR "@PACKAGE_skia_INSTALL_LIB_DIR@")
  set(skia_PDB_DIR "@PACKAGE_skia_INSTALL_PDB_DIR@")
endif()


#if(is_win)
if(@is_win@)
  if(cmr_WINDOWS_KITS_DIR)
    set(_win_kit_dir "${cmr_WINDOWS_KITS_DIR}")
  else()
    set(_win_kit_dir "@cmr_WINDOWS_KITS_DIR@")
  endif()
  if(cmr_WINDOWS_KITS_VERSION)
    set(_win_kit_ver "${cmr_WINDOWS_KITS_VERSION}")
  else()
    set(_win_kit_ver "@cmr_WINDOWS_KITS_VERSION@")
  endif()
  set(_win_kit_arch "@target_cpu@")

  include(cmr_msvc_utils)
  get_windows_kits_library_dirs(${_win_kit_dir} ${_win_kit_ver} ${_win_kit_arch} _windows_kits_library_dirs)
endif()

macro(skia_find_library name)
  if(NOT TARGET "SkiaInternal_${name}")
    find_library(${name}_LIB
      NAMES "${name}"
      REQUIRED
    )
    add_library("SkiaInternal_${name}" UNKNOWN IMPORTED)
    set_target_properties("SkiaInternal_${name}" PROPERTIES
      IMPORTED_LOCATION "${${name}_LIB}"
    )
  endif()
endmacro()

macro(skia_find_library_win name)
  if(NOT TARGET "SkiaInternal_${name}")
    find_library(${name}_LIB
      NAMES "${name}.lib"
      PATHS ${_windows_kits_library_dirs}
      REQUIRED
    )
    add_library("SkiaInternal_${name}" UNKNOWN IMPORTED)
    set_target_properties("SkiaInternal_${name}" PROPERTIES
      IMPORTED_LOCATION "${${name}_LIB}"
    )
  endif()
endmacro()

macro(skia_find_framework name)
  if(NOT TARGET "SkiaInternal_${name}")
    find_library(${name}_LIB
      NAMES "${name}"
      REQUIRED
    )

    if(${name}_LIB MATCHES "/([^/]+)\\.framework$")
      set(${name}_LIB_FW "${${name}_LIB}/${CMAKE_MATCH_1}")
      if(EXISTS "${${name}_LIB_FW}.tbd")
        string(APPEND ${name}_LIB_FW ".tbd")
      endif()
      set(${name}_LIB "${${name}_LIB_FW}")
    endif()

    add_library("SkiaInternal_${name}" UNKNOWN IMPORTED)
    set_target_properties("SkiaInternal_${name}" PROPERTIES
      IMPORTED_LOCATION "${${name}_LIB}"
    )
  endif()
endmacro()


#if(BUILD_SHARED_LIBS)
if(@BUILD_SHARED_LIBS@)
  set(lib_type SHARED)
else()
  set(lib_type STATIC)
endif()


# -------------------------------------
# BUILD.gn
# -------------------------------------

#skia_component("skia")
add_library(Skia::skia ${lib_type} IMPORTED)

#if(cmake_gen_config)
if(@cmake_gen_config@)
  add_dependencies(Skia::skia build_skia)
endif()

set_property(TARGET Skia::skia APPEND PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "${skia_INCLUDE_DIR}"
)

set_and_check(skia_LIB "${skia_DLL_DIR}/@skia_FILE_NAME@")
set_target_properties(Skia::skia PROPERTIES
  IMPORTED_LOCATION "${skia_LIB}"
)

#if(is_win AND is_component_build)
if(@is_win@ AND @is_component_build@)
  set_and_check(skia_DLL_LIB "${skia_LIB_DIR}/@skia_DLL_LIB_FILE_NAME@")
  set_target_properties(Skia::skia PROPERTIES
    IMPORTED_IMPLIB "${skia_DLL_LIB}"
  )
endif()

#if(NOT is_component_build)
if(NOT @is_component_build@)
  set_target_properties(Skia::skia PROPERTIES
    IMPORTED_NO_SONAME ON
    # NOTE: 2026-09: Skia requires C++20
    INTERFACE_COMPILE_FEATURES "cxx_std_20"
    IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
  )
endif()


# #if(is_win)
# if(@is_win@)
#   skia_find_library_win("Ole32")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_Ole32
#   )

#   skia_find_library_win("OleAut32")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_OleAut32
#   )

# else()
#   skia_find_library("dl")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_dl
#   )
# endif()

# #if(is_android)
# if(@is_android@)
#   skia_find_library("EGL")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_EGL
#   )
#   skia_find_library("GLESv2")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_GLESv2
#   )
#   skia_find_library("log")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_log
#   )
# endif()

# #if(is_linux OR target_cpu STREQUAL "wasm")
# if(@is_linux@ OR "@target_cpu@" STREQUAL "wasm")
#   #if(skia_use_egl)
#   if(@skia_use_egl@)
#     skia_find_library("GLESv2")
#     set_property(TARGET Skia::skia APPEND PROPERTY
#       INTERFACE_LINK_LIBRARIES
#         SkiaInternal_GLESv2
#     )
#   endif()
# endif()

# #if(is_mac)
# if(@is_mac@)
#   skia_find_framework("ApplicationServices")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_ApplicationServices
#   )
#   skia_find_framework("OpenGL")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_OpenGL
#   )
# endif()

# #if(is_ios)
# if(@is_ios@)
#   skia_find_framework("CoreFoundation")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_CoreFoundation
#   )
#   skia_find_framework("CoreGraphics")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_CoreGraphics
#   )
#   skia_find_framework("CoreText")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_CoreText
#   )
#   skia_find_framework("ImageIO")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_ImageIO
#   )
#   skia_find_framework("MobileCoreServices")
#   set_property(TARGET Skia::skia APPEND PROPERTY
#     INTERFACE_LINK_LIBRARIES
#       SkiaInternal_MobileCoreServices
#   )
# endif()

# -------------------------------------
# END of BUILD.gn
# -------------------------------------


# -------------------------------------
# /modules
# -------------------------------------

#if(skia_enable_bentleyottmann)
if(@skia_enable_bentleyottmann@)
  add_library(Skia::bentleyottmann ${lib_type} IMPORTED)

  set_property(TARGET Skia::bentleyottmann APPEND PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "${skia_MODULES_DIR}/bentleyottmann/include"
  )

  set_and_check(bentleyottmann_LIB "${skia_LIB_DIR}/@bentleyottmann_FILE_NAME@")
  set_target_properties(Skia::bentleyottmann PROPERTIES
    IMPORTED_LOCATION "${bentleyottmann_LIB}"
  )

  #if(is_win AND is_component_build)
  if(@is_win@ AND @is_component_build@)
    set_and_check(bentleyottmann_DLL_LIB "${skia_LIB_DIR}/@bentleyottmann_DLL_LIB_FILE_NAME@")
    set_target_properties(Skia::bentleyottmann PROPERTIES
      IMPORTED_IMPLIB "${bentleyottmann_DLL_LIB}"
    )
  endif()

  set_property(TARGET Skia::bentleyottmann APPEND PROPERTY
    INTERFACE_LINK_LIBRARIES
      Skia::skia
  )
endif()


#if(skia_enable_skunicode)
if(@skia_enable_skunicode@)
  add_library(Skia::skunicode ${lib_type} IMPORTED)

  set_property(TARGET Skia::skunicode APPEND PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "${skia_MODULES_DIR}/skunicode/include"
  )

  set_and_check(skunicode_core_LIB "${skia_DLL_DIR}/@skunicode_core_FILE_NAME@")
  set_target_properties(Skia::skunicode PROPERTIES
    IMPORTED_LOCATION "${skunicode_core_LIB}"
  )

  #if(is_win AND is_component_build)
  if(@is_win@ AND @is_component_build@)
    set_and_check(skunicode_core_DLL_LIB "${skia_LIB_DIR}/@skunicode_core_DLL_LIB_FILE_NAME@")
    set_target_properties(Skia::skunicode PROPERTIES
      IMPORTED_IMPLIB "${skunicode_core_DLL_LIB}"
    )
  endif()

  set_property(TARGET Skia::skunicode APPEND PROPERTY
    INTERFACE_LINK_LIBRARIES
      Skia::skia
  )

  #if(skia_use_icu)
  if(@skia_use_icu@)
    add_library(Skia::skunicode_icu ${lib_type} IMPORTED)

    set_property(TARGET Skia::skunicode_icu APPEND PROPERTY
      INTERFACE_INCLUDE_DIRECTORIES "${skia_MODULES_DIR}/skunicode/include"
    )

    set_and_check(skunicode_icu_LIB "${skia_DLL_DIR}/@skunicode_icu_FILE_NAME@")
    set_target_properties(Skia::skunicode_icu PROPERTIES
      IMPORTED_LOCATION "${skunicode_icu_LIB}"
    )

    #if(is_win AND is_component_build)
    if(@is_win@ AND @is_component_build@)
      set_and_check(skunicode_icu_DLL_LIB "${skia_LIB_DIR}/@skunicode_icu_DLL_LIB_FILE_NAME@")
      set_target_properties(Skia::skunicode_icu PROPERTIES
        IMPORTED_IMPLIB "${skunicode_icu_DLL_LIB}"
      )
    endif()

    set_property(TARGET Skia::skunicode_icu APPEND PROPERTY
      INTERFACE_LINK_LIBRARIES
        Skia::skunicode
    )
  endif()
endif()


#if(skia_enable_skshaper)
if(@skia_enable_skshaper@)
  add_library(Skia::skshaper ${lib_type} IMPORTED)

  set_property(TARGET Skia::skshaper APPEND PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "${skia_MODULES_DIR}/skshaper/include"
  )

  set_and_check(skshaper_LIB "${skia_DLL_DIR}/@skshaper_FILE_NAME@")
  set_target_properties(Skia::skshaper PROPERTIES
    IMPORTED_LOCATION "${skshaper_LIB}"
  )

  #if(is_win AND is_component_build)
  if(@is_win@ AND @is_component_build@)
    set_and_check(skshaper_DLL_LIB "${skia_LIB_DIR}/@skshaper_DLL_LIB_FILE_NAME@")
    set_target_properties(Skia::skshaper PROPERTIES
      IMPORTED_IMPLIB "${skshaper_DLL_LIB}"
    )
  endif()

  set_property(TARGET Skia::skshaper APPEND PROPERTY
    INTERFACE_LINK_LIBRARIES
      Skia::skia
  )

  #if(skia_use_icu AND skia_use_harfbuzz)
  if(@skia_use_icu@ AND @skia_use_harfbuzz@)
    set_property(TARGET Skia::skshaper APPEND PROPERTY
      INTERFACE_LINK_LIBRARIES Skia::skunicode_icu
    )
  endif()
endif()


#if(skia_enable_skparagraph AND skia_enable_skshaper AND skia_use_icu AND skia_use_harfbuzz)
if(@skia_enable_skparagraph@ AND @skia_enable_skshaper@ AND @skia_use_icu@ AND @skia_use_harfbuzz@)
  add_library(Skia::skparagraph ${lib_type} IMPORTED)

  set_property(TARGET Skia::skparagraph APPEND PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "${skia_MODULES_DIR}/skparagraph/include"
  )

  set_and_check(skparagraph_LIB "${skia_DLL_DIR}/@skparagraph_FILE_NAME@")
  set_target_properties(Skia::skparagraph PROPERTIES
    IMPORTED_LOCATION "${skparagraph_LIB}"
  )

  #if(is_win AND is_component_build)
  if(@is_win@ AND @is_component_build@)
    set_and_check(skparagraph_DLL_LIB "${skia_LIB_DIR}/@skparagraph_DLL_LIB_FILE_NAME@")
    set_target_properties(Skia::skparagraph PROPERTIES
      IMPORTED_IMPLIB "${skparagraph_DLL_LIB}"
    )
  endif()

  set_property(TARGET Skia::skparagraph APPEND PROPERTY
    INTERFACE_LINK_LIBRARIES
      Skia::skia
      Skia::skshaper
      Skia::skunicode
  )
endif()


#if(skia_enable_svg AND skia_use_expat)
if(@skia_enable_svg@ AND @skia_use_expat@)
  add_library(Skia::svg ${lib_type} IMPORTED)

  set_property(TARGET Skia::svg APPEND PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "${skia_MODULES_DIR}/svg/include"
  )

  set_and_check(svg_LIB "${skia_LIB_DIR}/@svg_FILE_NAME@")
  set_target_properties(Skia::svg PROPERTIES
    IMPORTED_LOCATION "${svg_LIB}"
  )

  #if(is_win AND is_component_build)
  if(@is_win@ AND @is_component_build@)
    set_and_check(svg_DLL_LIB "${skia_LIB_DIR}/@svg_DLL_LIB_FILE_NAME@")
    set_target_properties(Skia::svg PROPERTIES
      IMPORTED_IMPLIB "${svg_DLL_LIB}"
    )
  endif()

  set_property(TARGET Skia::svg APPEND PROPERTY
    INTERFACE_LINK_LIBRARIES
      Skia::skia
      Skia::skshaper
      Skia::skunicode
  )
endif()


#if(skia_use_icu AND NOT skia_use_system_icu)
if(@skia_use_icu@ AND NOT @skia_use_system_icu@)
  add_library(Skia::icudata UNKNOWN IMPORTED)

  set_and_check(icudata_LIB "${skia_DLL_DIR}/@icudata_FILE_NAME@")
  set_target_properties(Skia::icudata PROPERTIES
    IMPORTED_LOCATION "${icudata_LIB}"
    IMPORTED_NO_SONAME ON
  )

  #if(cmake_gen_config)
  if(@cmake_gen_config@)
    add_dependencies(Skia::icudata build_skia)
  endif()
endif()


# NOTE: We can not link to dawn::webgpu_dawn due to <build>/gen/include
# because CMake checks it during config phase. We can link it only via
# target_link_libraries in the main project.
# We do not link to ICU for the sake of consistency.
#set_property(TARGET Skia::skia APPEND PROPERTY
#  INTERFACE_LINK_LIBRARIES
#    dawn::webgpu_dawn
#)
#set_property(TARGET Skia::skunicode_icu APPEND PROPERTY
#  INTERFACE_LINK_LIBRARIES
#    ICU::io ICU::i18n ICU::uc ICU::data
#)


# -------------------------------------
# CMakePackageConfigHelpers
#

check_required_components("Skia")
