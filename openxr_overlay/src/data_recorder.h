/**
 * Movement Dojo XR Overlay - Data Recorder
 * Saves session data to disk
 */

#pragma once

#include "common.h"
#include "movement_tracker.h"
#include <string>
#include <fstream>

namespace MovementDojo {

class DataRecorder {
public:
    DataRecorder();
    ~DataRecorder();

    // Session management
    bool startSession(const std::string& sessionId);
    void endSession();
    bool isRecording() const { return m_isRecording; }

    // Data recording
    void recordFrame(const MovementFrame& frame);
    void recordStats(const SessionStats& stats);

    // File access
    std::string getSessionFilePath() const { return m_currentFilePath; }

    // Static utilities
    static std::string generateSessionId();
    static std::string getSessionsDirectory();

private:
    bool m_isRecording;
    std::string m_sessionId;
    std::string m_currentFilePath;
    std::ofstream m_file;

    uint64_t m_framesSaved;
    int m_frameSampleRate;  // Save every N frames

    void writeHeader();
    void writeFooter(const SessionStats& stats);
    std::string frameToJson(const MovementFrame& frame);
};

}  // namespace MovementDojo
