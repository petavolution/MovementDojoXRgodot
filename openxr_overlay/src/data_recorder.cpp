/**
 * Movement Dojo XR Overlay - Data Recorder Implementation
 */

#include "data_recorder.h"
#include "config.h"
#include <chrono>
#include <iomanip>
#include <sstream>
#include <filesystem>
#include <random>

namespace fs = std::filesystem;

namespace MovementDojo {

DataRecorder::DataRecorder()
    : m_isRecording(false)
    , m_framesSaved(0)
    , m_frameSampleRate(9)  // Save every 9th frame (~10Hz from 90Hz)
{
}

DataRecorder::~DataRecorder() {
    if (m_isRecording) {
        endSession();
    }
}

std::string DataRecorder::generateSessionId() {
    auto now = std::chrono::system_clock::now();
    auto time = std::chrono::system_clock::to_time_t(now);
    std::tm tm = *std::localtime(&time);

    // Random suffix
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, 35);
    std::string chars = "abcdefghijklmnopqrstuvwxyz0123456789";
    std::string suffix;
    for (int i = 0; i < 6; i++) {
        suffix += chars[dis(gen)];
    }

    std::ostringstream ss;
    ss << std::put_time(&tm, "%Y%m%d_%H%M%S") << "_" << suffix;
    return ss.str();
}

std::string DataRecorder::getSessionsDirectory() {
    return Config::getInstance().dataDirectory + "/sessions";
}

bool DataRecorder::startSession(const std::string& sessionId) {
    if (m_isRecording) {
        endSession();
    }

    m_sessionId = sessionId;
    m_currentFilePath = getSessionsDirectory() + "/" + sessionId + ".json";

    // Ensure directory exists
    try {
        fs::create_directories(getSessionsDirectory());
    } catch (const std::exception& e) {
        LOG_ERROR(std::string("Failed to create sessions directory: ") + e.what());
        return false;
    }

    m_file.open(m_currentFilePath);
    if (!m_file.is_open()) {
        LOG_ERROR("Failed to open session file: " + m_currentFilePath);
        return false;
    }

    m_isRecording = true;
    m_framesSaved = 0;

    writeHeader();

    LOG_INFO("Session recording started: " + m_sessionId);
    return true;
}

void DataRecorder::endSession() {
    if (!m_isRecording) return;

    m_isRecording = false;

    // Close frames array and file
    m_file << "\n  ],\n";
    m_file << "  \"frame_count\": " << m_framesSaved << "\n";
    m_file << "}\n";

    m_file.close();

    LOG_INFO("Session recording ended: " + m_sessionId + " (" + std::to_string(m_framesSaved) + " frames)");
}

void DataRecorder::recordFrame(const MovementFrame& frame) {
    if (!m_isRecording) return;

    // Sample frames to reduce file size
    static uint64_t frameCounter = 0;
    frameCounter++;

    if (frameCounter % m_frameSampleRate != 0) {
        return;
    }

    std::string json = frameToJson(frame);

    if (m_framesSaved > 0) {
        m_file << ",\n";
    }
    m_file << "    " << json;

    m_framesSaved++;
}

void DataRecorder::recordStats(const SessionStats& stats) {
    // Stats are written in the footer when session ends
    // Could also write periodic snapshots here
}

void DataRecorder::writeHeader() {
    auto now = std::chrono::system_clock::now();
    auto time = std::chrono::system_clock::to_time_t(now);
    std::tm tm = *std::localtime(&time);

    std::ostringstream timestamp;
    timestamp << std::put_time(&tm, "%Y-%m-%dT%H:%M:%S");

    m_file << "{\n";
    m_file << "  \"version\": \"1.0\",\n";
    m_file << "  \"session_id\": \"" << m_sessionId << "\",\n";
    m_file << "  \"start_time\": \"" << timestamp.str() << "\",\n";
    m_file << "  \"sample_rate\": " << m_frameSampleRate << ",\n";
    m_file << "  \"frames\": [\n";
}

void DataRecorder::writeFooter(const SessionStats& stats) {
    // This is called separately if we want to include stats
    // For now, stats are computed when loading the file
}

std::string DataRecorder::frameToJson(const MovementFrame& frame) {
    std::ostringstream ss;
    ss << std::fixed << std::setprecision(4);

    ss << "{";
    ss << "\"t\":" << (frame.timestamp / 1e9) << ",";  // Convert to seconds
    ss << "\"head\":{\"p\":[" << frame.head.position.x << "," << frame.head.position.y << "," << frame.head.position.z << "],";
    ss << "\"r\":[" << frame.head.orientation.x << "," << frame.head.orientation.y << "," << frame.head.orientation.z << "," << frame.head.orientation.w << "]},";

    ss << "\"left\":{\"p\":[" << frame.left_hand.position.x << "," << frame.left_hand.position.y << "," << frame.left_hand.position.z << "],";
    ss << "\"r\":[" << frame.left_hand.orientation.x << "," << frame.left_hand.orientation.y << "," << frame.left_hand.orientation.z << "," << frame.left_hand.orientation.w << "],";
    ss << "\"v\":[" << frame.left_velocity.linear.x << "," << frame.left_velocity.linear.y << "," << frame.left_velocity.linear.z << "]},";

    ss << "\"right\":{\"p\":[" << frame.right_hand.position.x << "," << frame.right_hand.position.y << "," << frame.right_hand.position.z << "],";
    ss << "\"r\":[" << frame.right_hand.orientation.x << "," << frame.right_hand.orientation.y << "," << frame.right_hand.orientation.z << "," << frame.right_hand.orientation.w << "],";
    ss << "\"v\":[" << frame.right_velocity.linear.x << "," << frame.right_velocity.linear.y << "," << frame.right_velocity.linear.z << "]}";

    ss << "}";

    return ss.str();
}

}  // namespace MovementDojo
