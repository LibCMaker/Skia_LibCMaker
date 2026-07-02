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


#-----------------------------------------------------------------------
# Library version
#

set(upd_SKIA_SRC_URL "https://skia.googlesource.com/skia.git")
set(upd_SKIA_BRANCH  "chrome/m${Skia_lib_VERSION}")

set(upd_DEPOT_TOOLS_URL "https://chromium.googlesource.com/chromium/tools/depot_tools.git")
# Commit date is Fri Jan 07 23:44:16 2022.
set(upd_DEPOT_TOOLS_COMMIT "d3cc7ad85ed680907978c3d125b51db0f6ca5ea8")


#-----------------------------------------------------------------------
# Paths
#

set(upd_SRC_DIR_NAME "skia-m${Skia_lib_VERSION}")

set(upd_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/source")
set(upd_SRC_DIR    "${upd_SOURCE_DIR}/${upd_SRC_DIR_NAME}")
set(upd_PATCH_DIR  "${upd_SOURCE_DIR}/patch/${upd_SRC_DIR_NAME}")

set(upd_SKIA_SRC_DIR        "${upd_SRC_DIR}/skia")
set(upd_DEPOT_TOOLS_SRC_DIR "${upd_SRC_DIR}/depot_tools")

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
  "PATH=$<SHELL_PATH:${upd_DEPOT_TOOLS_SRC_DIR}>${_PATH_SEP}${_PATH}"
)


#-----------------------------------------------------------------------
# TODO
#

macro(upd_skia_option _option _value)
  if(${_value})
    set(_opt_value "true")
  else()
    set(_opt_value "false")
  endif()
  set(${_option} "${_opt_value}" CACHE STRING "${_option}")
  unset(_opt_value)
endmacro()


#-----------------------------------------------------------------------
# LibCMaker options
#

upd_skia_option(not_fvisibility_hidden_patch true)
upd_skia_option(export_icu_from_skia true)


#-----------------------------------------------------------------------
# TODO
#

find_package(Git 2.17.1 REQUIRED)
find_package(Python REQUIRED COMPONENTS Interpreter)

if(Python_VERSION VERSION_LESS 2.7
    OR Python_VERSION VERSION_GREATER 3.0 AND Python_VERSION VERSION_LESS 3.8)
  cmr_print_error("depot_tools requires python 2.7 or 3.8.")
endif()

find_program(tar_EXECUTABLE "tar" REQUIRED)
message(STATUS "Found tar: ${tar_EXECUTABLE}")

find_program(xz_EXECUTABLE "xz" REQUIRED)
message(STATUS "Found xz: ${xz_EXECUTABLE}")


#-----------------------------------------------------------------------
# TODO
#

if(NOT EXISTS ${upd_DEPOT_TOOLS_SRC_DIR})
  cmr_print_status(
    "Download depot_tools sources from\n  '${upd_DEPOT_TOOLS_URL}'\nto\n  '${upd_DEPOT_TOOLS_SRC_DIR}'"
  )
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E make_directory ${upd_DEPOT_TOOLS_SRC_DIR}
    RESULT_VARIABLE error_RESULT
  )
  if(error_RESULT)
    cmr_print_error("Failed make_directory: ${error_RESULT}")
  endif()
  execute_process(
    COMMAND ${GIT_EXECUTABLE} init --quiet
    WORKING_DIRECTORY ${upd_DEPOT_TOOLS_SRC_DIR}
    RESULT_VARIABLE error_RESULT
  )
  if(error_RESULT)
    cmr_print_error("Failed git init: ${error_RESULT}")
  endif()
  execute_process(
    COMMAND ${GIT_EXECUTABLE} remote add origin ${upd_DEPOT_TOOLS_URL}
    WORKING_DIRECTORY ${upd_DEPOT_TOOLS_SRC_DIR}
    RESULT_VARIABLE error_RESULT
  )
  if(error_RESULT)
    cmr_print_error("Failed git remote: ${error_RESULT}")
  endif()
  execute_process(
    COMMAND ${GIT_EXECUTABLE} fetch --depth 1 origin ${upd_DEPOT_TOOLS_COMMIT}
    WORKING_DIRECTORY ${upd_DEPOT_TOOLS_SRC_DIR}
    RESULT_VARIABLE error_RESULT
  )
  if(error_RESULT)
    cmr_print_error("Failed git fetch: ${error_RESULT}")
  endif()
  execute_process(
    COMMAND ${GIT_EXECUTABLE} checkout --quiet FETCH_HEAD
    WORKING_DIRECTORY ${upd_DEPOT_TOOLS_SRC_DIR}
    RESULT_VARIABLE error_RESULT
  )
  if(error_RESULT)
    cmr_print_error("Failed git checkout: ${error_RESULT}")
  endif()
endif()


#-----------------------------------------------------------------------
# TODO
#

if(NOT EXISTS ${upd_SKIA_SRC_DIR})
  cmr_print_status(
    "Download Skia sources from\n  '${upd_SKIA_SRC_URL}'\nto\n  '${upd_SKIA_SRC_DIR}'"
  )
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E make_directory ${upd_SKIA_SRC_DIR}
    RESULT_VARIABLE error_RESULT
  )
  if(error_RESULT)
    cmr_print_error("Failed make_directory: ${error_RESULT}")
  endif()
  execute_process(
    COMMAND ${GIT_EXECUTABLE} init --quiet
    WORKING_DIRECTORY ${upd_SKIA_SRC_DIR}
    RESULT_VARIABLE error_RESULT
  )
  if(error_RESULT)
    cmr_print_error("Failed git init: ${error_RESULT}")
  endif()
  execute_process(
    COMMAND ${GIT_EXECUTABLE} remote add origin ${upd_SKIA_SRC_URL}
    WORKING_DIRECTORY ${upd_SKIA_SRC_DIR}
    RESULT_VARIABLE error_RESULT
  )
  if(error_RESULT)
    cmr_print_error("Failed git remote: ${error_RESULT}")
  endif()
  execute_process(
    COMMAND ${GIT_EXECUTABLE} fetch --depth 1 origin ${upd_SKIA_BRANCH}
    WORKING_DIRECTORY ${upd_SKIA_SRC_DIR}
    RESULT_VARIABLE error_RESULT
  )
  if(error_RESULT)
    cmr_print_error("Failed git fetch: ${error_RESULT}")
  endif()
  execute_process(
    COMMAND ${GIT_EXECUTABLE} checkout --quiet FETCH_HEAD
    WORKING_DIRECTORY ${upd_SKIA_SRC_DIR}
    RESULT_VARIABLE error_RESULT
  )
  if(error_RESULT)
    cmr_print_error("Failed git checkout: ${error_RESULT}")
  endif()
endif()


#-----------------------------------------------------------------------
# TODO
#

function(upd_apply_skia_source_patch _name)
  set(${_name}_STAMP
    "${upd_SRC_DIR}/patch__${_name}__.stamp"
  )
  if(NOT EXISTS ${${_name}_STAMP})
    cmr_print_status("Apply Skia source patch: '${_name}'")
    set(${_name}_FILE
      "${upd_PATCH_DIR}/${_name}"
    )
    execute_process(
      COMMAND ${GIT_EXECUTABLE} apply ${${_name}_FILE}
      #COMMAND ${GIT_EXECUTABLE} apply --reverse ${${_name}_FILE}
      WORKING_DIRECTORY ${upd_SKIA_SRC_DIR}
      RESULT_VARIABLE error_RESULT
    )
    if(error_RESULT)
      cmr_print_error("Failed git apply: ${error_RESULT}")
    endif()
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E touch ${${_name}_STAMP}
    )
  endif()
endfunction()

# upd_apply_skia_source_patch("GN__Android_iOS__Do_not_build__skia_c_api_example.patch")
# upd_apply_skia_source_patch("GN__Windows__Fix_MSVC_x86_build.patch")
# upd_apply_skia_source_patch("GN__Windows__Fix_link_deps.patch")
# upd_apply_skia_source_patch("GN__iOS__Fix_link_deps.patch")
# upd_apply_skia_source_patch("Src__Fix_for__skia_enable_sksl.patch")
# upd_apply_skia_source_patch("Src__Fix_for__skia_use_sfntly.patch")
# upd_apply_skia_source_patch("Src__Windows__Fix_MSVC_shared_build.patch")
upd_apply_skia_source_patch("Tools__Add_depth-1_to_git-clone_for_deps.patch")

if(not_fvisibility_hidden_patch)
  # upd_apply_skia_source_patch("GN__Not_-fvisibility_hidden.patch")
endif()
if(export_icu_from_skia)
  # upd_apply_skia_source_patch("GN__export_icu_from_skia.patch")
endif()


#-----------------------------------------------------------------------
# TODO
#

set(git_sync_deps_STAMP
  "${upd_SRC_DIR}/tools__git-sync-deps.stamp"
)
if(NOT EXISTS ${git_sync_deps_STAMP})
  cmr_print_status("Run 'tools/git-sync-deps'")
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env ${skia_ENV}
      ${Python_EXECUTABLE} tools/git-sync-deps
    WORKING_DIRECTORY ${upd_SKIA_SRC_DIR}
    RESULT_VARIABLE error_RESULT
  )
  if(error_RESULT)
    cmr_print_error("Failed run 'tools/git-sync-deps': ${error_RESULT}")
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E touch ${git_sync_deps_STAMP}
  )
endif()


#-----------------------------------------------------------------------
# TODO
#

set(tar_create_STAMP
  "${upd_SOURCE_DIR}/tools__tar-create.stamp"
)
if(NOT EXISTS ${tar_create_STAMP})
  cmr_print_status("Run tar --create")
  execute_process(
    COMMAND ${tar_EXECUTABLE}
      # --verbose
      --create
      --file "${upd_SRC_DIR_NAME}__NEW.tar.xz"
      --use-compress-program "${xz_EXECUTABLE} --threads=${cmr_BUILD_MULTIPROC_CNT}"
      "${upd_SRC_DIR_NAME}"
    WORKING_DIRECTORY ${upd_SOURCE_DIR}
    RESULT_VARIABLE error_RESULT
  )
  if(error_RESULT)
    cmr_print_error("Failed create tar: ${error_RESULT}")
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E touch ${tar_create_STAMP}
  )
endif()
