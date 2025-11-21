/**
 * Movement Dojo XR Overlay - Movement Tracker
 * Records and analyzes VR tracking data
 */

#pragma once

#include "common.h"
#include <deque>
#include <unordered_map>
#include <functional>

namespace MovementDojo {

/**
 * MovementSpaceMap - 3D grid tracking movement coverage
 */
class MovementSpaceMap {
public:
    MovementSpaceMap();

    void reset();

    // Record position, returns true if newly explored
    bool recordPosition(const std::string& hand, const XrVector3f& worldPos, const XrVector3f& headPos);

    float getCoveragePercentage() const;
    float getSymmetryScore() const;

    struct HeatMapPoint {
        XrVector3f position;
        float intensity;
        uint32_t left_visits;
        uint32_t right_visits;
    };

    std::vector<HeatMapPoint> getHeatMapData() const;
    std::vector<XrVector3f> getUnexploredZones(size_t maxCount = 50) const;

private:
    std::array<GridCell, GRID_SIZE * GRID_SIZE * GRID_SIZE> m_cells;
    uint32_t m_uniqueCellsVisited;
    uint32_t m_totalLeftVisits;
    uint32_t m_totalRightVisits;
    int m_reachableCellsCount;

    int worldToIndex(const XrVector3f& relativePos) const;
    XrVector3f indexToWorld(int index) const;
    bool isValidIndex(int index) const;
    int calculateReachableCells() const;
};

/**
 * MovementTracker - Core tracking system
 */
class MovementTracker {
public:
    using FrameCallback = std::function<void(const MovementFrame&)>;
    using ZoneExploredCallback = std::function<void(const XrVector3f&, const std::string&)>;

    MovementTracker();
    ~MovementTracker();

    // Lifecycle
    void startTracking();
    void stopTracking();
    bool isTracking() const { return m_isTracking; }

    // Data recording (called from API hooks)
    void recordHeadPose(XrTime time, const XrPosef& pose);
    void recordControllerPose(XrTime time, const std::string& hand, const XrPosef& pose);
    void recordControllerInput(const std::string& hand, float grip, float trigger);

    // Frame completion (called at end of each frame)
    void completeFrame(XrTime frameTime);

    // Data access
    const MovementFrame* getCurrentFrame() const;
    std::vector<MovementFrame> getRecentFrames(size_t count) const;
    const MovementSpaceMap& getSpaceMap() const { return m_spaceMap; }
    SessionStats getSessionStats() const;
    float getSessionDuration() const;

    // Callbacks
    void setFrameCallback(FrameCallback callback) { m_frameCallback = callback; }
    void setZoneExploredCallback(ZoneExploredCallback callback) { m_zoneExploredCallback = callback; }

private:
    void computeVelocities(MovementFrame& frame, const MovementFrame* previous);
    void computeDerivedMetrics(MovementFrame& frame);
    void updateSpaceMap(const MovementFrame& frame);
    void updateStatistics(const MovementFrame& frame);

    bool m_isTracking;
    XrTime m_sessionStartTime;
    XrTime m_lastFrameTime;

    // Frame buffer (ring buffer)
    std::deque<MovementFrame> m_frameBuffer;
    MovementFrame m_currentFrame;
    bool m_currentFrameValid;

    // Pending pose data for current frame
    struct PendingPose {
        XrPosef pose;
        bool valid;
    };
    PendingPose m_pendingHead;
    PendingPose m_pendingLeft;
    PendingPose m_pendingRight;

    // Input state
    float m_leftGrip, m_leftTrigger;
    float m_rightGrip, m_rightTrigger;

    // Space map
    MovementSpaceMap m_spaceMap;

    // Statistics
    SessionStats m_stats;

    // Callbacks
    FrameCallback m_frameCallback;
    ZoneExploredCallback m_zoneExploredCallback;

    mutable std::mutex m_mutex;
};

}  // namespace MovementDojo
