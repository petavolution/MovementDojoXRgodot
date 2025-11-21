/**
 * Movement Dojo XR Overlay - Common definitions
 * Universal VR movement tracking layer
 */

#pragma once

#include <openxr/openxr.h>
#include <cstdint>
#include <string>
#include <vector>
#include <array>
#include <chrono>
#include <mutex>
#include <memory>

namespace MovementDojo {

// Version info
constexpr uint32_t VERSION_MAJOR = 0;
constexpr uint32_t VERSION_MINOR = 1;
constexpr uint32_t VERSION_PATCH = 0;

// Configuration constants
constexpr size_t MAX_FRAME_HISTORY = 9000;  // ~100s at 90Hz
constexpr float CELL_SIZE = 0.1f;           // 10cm grid cells
constexpr int GRID_RADIUS = 15;             // 1.5m reach radius
constexpr int GRID_SIZE = GRID_RADIUS * 2 + 1;  // 31x31x31

// Pose data structure
struct Pose {
    XrVector3f position{0, 0, 0};
    XrQuaternionf orientation{0, 0, 0, 1};
};

// Velocity data
struct Velocity {
    XrVector3f linear{0, 0, 0};
    XrVector3f angular{0, 0, 0};
};

// Single frame of tracking data
struct MovementFrame {
    XrTime timestamp;
    float delta_time;

    Pose head;
    Pose left_hand;
    Pose right_hand;

    Velocity head_velocity;
    Velocity left_velocity;
    Velocity right_velocity;

    float left_grip;
    float left_trigger;
    float right_grip;
    float right_trigger;

    // Derived metrics
    float left_reach_distance;
    float right_reach_distance;
    float movement_intensity;
};

// Session statistics
struct SessionStats {
    double duration_seconds;
    uint64_t frame_count;

    float left_distance_traveled;
    float right_distance_traveled;
    float head_distance_traveled;

    float peak_left_velocity;
    float peak_right_velocity;

    float coverage_percentage;
    float symmetry_score;

    std::vector<std::string> detected_poses;
};

// Grid cell for space mapping
struct GridCell {
    uint32_t left_visits;
    uint32_t right_visits;
    float first_visit_time;
};

// Utility functions
inline XrVector3f operator-(const XrVector3f& a, const XrVector3f& b) {
    return {a.x - b.x, a.y - b.y, a.z - b.z};
}

inline XrVector3f operator+(const XrVector3f& a, const XrVector3f& b) {
    return {a.x + b.x, a.y + b.y, a.z + b.z};
}

inline XrVector3f operator*(const XrVector3f& v, float s) {
    return {v.x * s, v.y * s, v.z * s};
}

inline float length(const XrVector3f& v) {
    return std::sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

inline float distance(const XrVector3f& a, const XrVector3f& b) {
    return length(a - b);
}

// Logging
enum class LogLevel {
    Debug,
    Info,
    Warning,
    Error
};

void Log(LogLevel level, const std::string& message);

#define LOG_DEBUG(msg) MovementDojo::Log(MovementDojo::LogLevel::Debug, msg)
#define LOG_INFO(msg) MovementDojo::Log(MovementDojo::LogLevel::Info, msg)
#define LOG_WARN(msg) MovementDojo::Log(MovementDojo::LogLevel::Warning, msg)
#define LOG_ERROR(msg) MovementDojo::Log(MovementDojo::LogLevel::Error, msg)

}  // namespace MovementDojo
