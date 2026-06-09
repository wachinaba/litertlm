cmake_minimum_required(VERSION 3.14)

include("${CMAKE_CURRENT_LIST_DIR}/litertlm_binaries.cmake")

string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" LITERTLM_PROCESSOR)
if(LITERTLM_PROCESSOR MATCHES "^(x86_64|amd64|x64)$")
  set(LITERTLM_ARCH "x86_64")
elseif(LITERTLM_PROCESSOR MATCHES "^(aarch64|arm64)$")
  set(LITERTLM_ARCH "arm64")
else()
  message(FATAL_ERROR
          "Unsupported LiteRT-LM Linux target architecture. "
          "CMake target processor: ${CMAKE_SYSTEM_PROCESSOR}")
endif()
string(TOUPPER "${LITERTLM_ARCH}" LITERTLM_ARCH_KEY)

set(LITERTLM_URL_VARIABLE "LITERTLM_${LITERTLM_ARCH_KEY}_URL")
if(NOT DEFINED ${LITERTLM_URL_VARIABLE})
  message(FATAL_ERROR
          "LiteRT-LM Linux wheel is not configured for ${LITERTLM_ARCH} targets. "
          "Set ${LITERTLM_URL_VARIABLE}.")
endif()

set(LITERTLM_URL "${${LITERTLM_URL_VARIABLE}}")
get_filename_component(LITERTLM_ARCHIVE_NAME "${LITERTLM_URL}" NAME)
string(REGEX REPLACE "\\.whl$" "" LITERTLM_EXTRACT_NAME "${LITERTLM_ARCHIVE_NAME}")
set(LITERTLM_ARCHIVE
    "${CMAKE_CURRENT_BINARY_DIR}/${LITERTLM_ARCHIVE_NAME}")
set(LITERTLM_EXTRACT_DIR
    "${CMAKE_CURRENT_BINARY_DIR}/${LITERTLM_EXTRACT_NAME}")
set(LITERTLM_SHARED_LIBRARY "${LITERTLM_EXTRACT_DIR}/litert_lm/liblitert-lm.so")

if(NOT EXISTS "${LITERTLM_SHARED_LIBRARY}")
  file(REMOVE_RECURSE "${LITERTLM_EXTRACT_DIR}")

  message(STATUS "Downloading LiteRT-LM Linux wheel")
  file(DOWNLOAD
       "${LITERTLM_URL}"
       "${LITERTLM_ARCHIVE}"
       TLS_VERIFY ON
       SHOW_PROGRESS
       STATUS LITERTLM_DOWNLOAD_STATUS)
  list(GET LITERTLM_DOWNLOAD_STATUS 0 LITERTLM_DOWNLOAD_CODE)
  list(GET LITERTLM_DOWNLOAD_STATUS 1 LITERTLM_DOWNLOAD_MESSAGE)
  if(NOT LITERTLM_DOWNLOAD_CODE EQUAL 0)
    message(FATAL_ERROR
            "LiteRT-LM Linux wheel download failed: ${LITERTLM_DOWNLOAD_MESSAGE}")
  endif()

  file(MAKE_DIRECTORY "${LITERTLM_EXTRACT_DIR}")
  file(ARCHIVE_EXTRACT
       INPUT "${LITERTLM_ARCHIVE}"
       DESTINATION "${LITERTLM_EXTRACT_DIR}")
endif()

if(NOT EXISTS "${LITERTLM_SHARED_LIBRARY}")
  message(FATAL_ERROR
          "LiteRT-LM Linux wheel did not contain litert_lm/liblitert-lm.so.")
endif()

file(GLOB_RECURSE LITERTLM_WHEEL_FILES
     "${LITERTLM_EXTRACT_DIR}/*")
if(NOT LITERTLM_WHEEL_FILES)
  message(FATAL_ERROR
          "LiteRT-LM Linux wheel did not contain any files.")
endif()

set(litertlm_bundled_libraries
    ${LITERTLM_WHEEL_FILES}
    PARENT_SCOPE)