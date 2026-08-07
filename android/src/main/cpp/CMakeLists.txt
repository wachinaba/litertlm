cmake_minimum_required(VERSION 3.18.1)

project(litertlm_jni_guard LANGUAGES CXX)

add_library(
  litertlm_jni_guard
  SHARED
  litertlm_jni_guard.cc
)

target_compile_features(litertlm_jni_guard PRIVATE cxx_std_17)
target_compile_options(litertlm_jni_guard PRIVATE -fexceptions)
target_include_directories(
  litertlm_jni_guard
  PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/../../../../src
)

find_library(dl_library dl)
target_link_libraries(litertlm_jni_guard PRIVATE ${dl_library})