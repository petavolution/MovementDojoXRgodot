cmake_minimum_required(VERSION 3.16)
project(MovementDojoOverlay VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find OpenXR
find_package(OpenXR REQUIRED)

# Find Vulkan (for overlay rendering)
find_package(Vulkan REQUIRED)

# JSON library for data serialization
find_package(nlohmann_json 3.2.0 QUIET)
if(NOT nlohmann_json_FOUND)
    include(FetchContent)
    FetchContent_Declare(json
        GIT_REPOSITORY https://github.com/nlohmann/json.git
        GIT_TAG v3.11.2
    )
    FetchContent_MakeAvailable(json)
endif()

# Source files
set(SOURCES
    src/main.cpp
    src/api_layer.cpp
    src/movement_tracker.cpp
    src/data_recorder.cpp
    src/overlay_renderer.cpp
    src/config.cpp
)

set(HEADERS
    src/api_layer.h
    src/movement_tracker.h
    src/data_recorder.h
    src/overlay_renderer.h
    src/config.h
    src/common.h
)

# Build as shared library (OpenXR API layer)
add_library(${PROJECT_NAME} SHARED ${SOURCES} ${HEADERS})

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${OpenXR_INCLUDE_DIR}
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    OpenXR::openxr_loader
    Vulkan::Vulkan
    nlohmann_json::nlohmann_json
)

# Platform-specific settings
if(WIN32)
    target_compile_definitions(${PROJECT_NAME} PRIVATE
        WIN32_LEAN_AND_MEAN
        NOMINMAX
        XR_USE_PLATFORM_WIN32
        XR_USE_GRAPHICS_API_VULKAN
    )
    set_target_properties(${PROJECT_NAME} PROPERTIES
        OUTPUT_NAME "XR_APILAYER_MOVEMENT_DOJO"
        SUFFIX ".dll"
    )
elseif(UNIX)
    target_compile_definitions(${PROJECT_NAME} PRIVATE
        XR_USE_PLATFORM_XLIB
        XR_USE_GRAPHICS_API_VULKAN
    )
    set_target_properties(${PROJECT_NAME} PROPERTIES
        OUTPUT_NAME "XR_APILAYER_MOVEMENT_DOJO"
        PREFIX "lib"
        SUFFIX ".so"
    )
endif()

# Generate API layer manifest
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/XR_APILAYER_MOVEMENT_DOJO.json.in
    ${CMAKE_CURRENT_BINARY_DIR}/XR_APILAYER_MOVEMENT_DOJO.json
    @ONLY
)

# Install targets
install(TARGETS ${PROJECT_NAME}
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/XR_APILAYER_MOVEMENT_DOJO.json
    DESTINATION share/openxr/1/api_layers/implicit.d
)
