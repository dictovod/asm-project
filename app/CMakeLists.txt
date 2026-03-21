cmake_minimum_required(VERSION 3.22.1)
project(AssemblyNativeActivity ASM)
enable_language(ASM)

if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -march=armv8-a+simd")
endif()

find_library(log-lib log)
find_library(android-lib android)

add_library(
    AssemblyNativeActivity
    SHARED
    src/main/cpp/asm/main_asm.S
)

target_link_libraries(
    AssemblyNativeActivity
    ${log-lib}
    ${android-lib}
)
