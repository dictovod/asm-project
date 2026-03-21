cmake_minimum_required(VERSION 3.22.1)
project(AssemblyNativeActivity C ASM)
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

set_target_properties(AssemblyNativeActivity PROPERTIES
    LINKER_LANGUAGE C
)

target_link_libraries(
    AssemblyNativeActivity
    -nostdlib
    -Wl,--no-undefined
    ${log-lib}
    ${android-lib}
)
