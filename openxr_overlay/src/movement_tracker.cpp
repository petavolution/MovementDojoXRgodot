/**
 * Movement Dojo XR Overlay - Movement Tracker Implementation
 */

#include "movement_tracker.h"
#include <algorithm>
#include <cmath>

namespace MovementDojo {

// ============================================================================
// MovementSpaceMap Implementation
// ============================================================================

MovementSpaceMap::MovementSpaceMap()
    : m_uniqueCellsVisited(0)
    , m_totalLeftVisits(0)
    , m_totalRightVisits(0) {

    reset();
    m_reachableCellsCount = calculateReachableCells();
}

void MovementSpaceMap::reset() {
    for (auto& cell : m_cells) {
        cell.left_visits = 0;
        cell.right_visits = 0;
        cell.first_visit_time = -1.0f;
    }
    m_uniqueCellsVisited = 0;
    m_totalLeftVisits = 0;
    m_totalRightVisits = 0;
}

bool MovementSpaceMap::recordPosition(const std::string& hand,
                                       const XrVector3f& worldPos,
                                       const XrVector3f& headPos) {
    XrVector3f relativePos = worldPos - headPos;
    int index = worldToIndex(relativePos);

    if (!isValidIndex(index)) {
        return false;
    }

    auto& cell = m_cells[index];
    bool isNew = (cell.left_visits == 0 && cell.right_visits == 0);

    if (hand == "left") {
        cell.left_visits++;
        m_totalLeftVisits++;
    } else {
        cell.right_visits++;
        m_totalRightVisits++;
    }

    if (isNew) {
        m_uniqueCellsVisited++;
        return true;
    }

    return false;
}

float MovementSpaceMap::getCoveragePercentage() const {
    if (m_reachableCellsCount <= 0) return 0.0f;
    return (static_cast<float>(m_uniqueCellsVisited) / m_reachableCellsCount) * 100.0f;
}

float MovementSpaceMap::getSymmetryScore() const {
    uint32_t total = m_totalLeftVisits + m_totalRightVisits;
    if (total == 0) return 100.0f;

    uint32_t minVisits = std::min(m_totalLeftVisits, m_totalRightVisits);
    uint32_t maxVisits = std::max(m_totalLeftVisits, m_totalRightVisits);

    return (static_cast<float>(minVisits) / maxVisits) * 100.0f;
}

std::vector<MovementSpaceMap::HeatMapPoint> MovementSpaceMap::getHeatMapData() const {
    std::vector<HeatMapPoint> data;

    // Find max visits for normalization
    uint32_t maxVisits = 1;
    for (const auto& cell : m_cells) {
        uint32_t total = cell.left_visits + cell.right_visits;
        if (total > maxVisits) maxVisits = total;
    }

    // Build data
    for (int i = 0; i < static_cast<int>(m_cells.size()); i++) {
        const auto& cell = m_cells[i];
        uint32_t total = cell.left_visits + cell.right_visits;

        if (total > 0) {
            HeatMapPoint point;
            point.position = indexToWorld(i);
            point.intensity = static_cast<float>(total) / maxVisits;
            point.left_visits = cell.left_visits;
            point.right_visits = cell.right_visits;
            data.push_back(point);
        }
    }

    return data;
}

std::vector<XrVector3f> MovementSpaceMap::getUnexploredZones(size_t maxCount) const {
    std::vector<XrVector3f> unexplored;
    float maxDistance = GRID_RADIUS * CELL_SIZE;

    for (int i = 0; i < static_cast<int>(m_cells.size()); i++) {
        const auto& cell = m_cells[i];

        if (cell.left_visits == 0 && cell.right_visits == 0) {
            XrVector3f worldPos = indexToWorld(i);

            if (length(worldPos) <= maxDistance) {
                unexplored.push_back(worldPos);

                if (unexplored.size() >= maxCount) {
                    break;
                }
            }
        }
    }

    return unexplored;
}

int MovementSpaceMap::worldToIndex(const XrVector3f& relativePos) const {
    int x = static_cast<int>(std::round(relativePos.x / CELL_SIZE)) + GRID_RADIUS;
    int y = static_cast<int>(std::round((relativePos.y + 1.0f) / CELL_SIZE));  // Offset for below-head
    int z = static_cast<int>(std::round(relativePos.z / CELL_SIZE)) + GRID_RADIUS;

    if (x < 0 || x >= GRID_SIZE || y < 0 || y >= GRID_SIZE || z < 0 || z >= GRID_SIZE) {
        return -1;
    }

    return x + y * GRID_SIZE + z * GRID_SIZE * GRID_SIZE;
}

XrVector3f MovementSpaceMap::indexToWorld(int index) const {
    int x = index % GRID_SIZE;
    int y = (index / GRID_SIZE) % GRID_SIZE;
    int z = index / (GRID_SIZE * GRID_SIZE);

    return {
        (x - GRID_RADIUS) * CELL_SIZE,
        y * CELL_SIZE - 1.0f,
        (z - GRID_RADIUS) * CELL_SIZE
    };
}

bool MovementSpaceMap::isValidIndex(int index) const {
    return index >= 0 && index < static_cast<int>(m_cells.size());
}

int MovementSpaceMap::calculateReachableCells() const {
    int count = 0;
    float maxDist = GRID_RADIUS * CELL_SIZE;

    for (int i = 0; i < static_cast<int>(m_cells.size()); i++) {
        XrVector3f pos = indexToWorld(i);
        if (length(pos) <= maxDist) {
            count++;
        }
    }

    return count;
}

// ============================================================================
// MovementTracker Implementation
// ============================================================================

MovementTracker::MovementTracker()
    : m_isTracking(false)
    , m_sessionStartTime(0)
    , m_lastFrameTime(0)
    , m_currentFrameValid(false)
    , m_leftGrip(0), m_leftTrigger(0)
    , m_rightGrip(0), m_rightTrigger(0) {

    m_pendingHead.valid = false;
    m_pendingLeft.valid = false;
    m_pendingRight.valid = false;
}

MovementTracker::~MovementTracker() {
    stopTracking();
}

void MovementTracker::startTracking() {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (m_isTracking) return;

    m_isTracking = true;
    m_sessionStartTime = 0;  // Will be set on first frame
    m_frameBuffer.clear();
    m_spaceMap.reset();

    // Reset statistics
    m_stats = SessionStats{};

    LOG_INFO("Movement tracking started");
}

void MovementTracker::stopTracking() {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (!m_isTracking) return;

    m_isTracking = false;
    LOG_INFO("Movement tracking stopped. Frames: " + std::to_string(m_frameBuffer.size()));
}

void MovementTracker::recordHeadPose(XrTime time, const XrPosef& pose) {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (!m_isTracking) return;

    m_pendingHead.pose = pose;
    m_pendingHead.valid = true;
}

void MovementTracker::recordControllerPose(XrTime time, const std::string& hand, const XrPosef& pose) {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (!m_isTracking) return;

    if (hand == "left") {
        m_pendingLeft.pose = pose;
        m_pendingLeft.valid = true;
    } else {
        m_pendingRight.pose = pose;
        m_pendingRight.valid = true;
    }
}

void MovementTracker::recordControllerInput(const std::string& hand, float grip, float trigger) {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (hand == "left") {
        m_leftGrip = grip;
        m_leftTrigger = trigger;
    } else {
        m_rightGrip = grip;
        m_rightTrigger = trigger;
    }
}

void MovementTracker::completeFrame(XrTime frameTime) {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (!m_isTracking) return;

    // Need at least head pose
    if (!m_pendingHead.valid) return;

    // Initialize session start time
    if (m_sessionStartTime == 0) {
        m_sessionStartTime = frameTime;
        m_lastFrameTime = frameTime;
    }

    // Build frame
    MovementFrame frame{};
    frame.timestamp = frameTime;
    frame.delta_time = static_cast<float>(frameTime - m_lastFrameTime) / 1e9f;  // Convert ns to s

    // Copy poses
    frame.head.position = m_pendingHead.pose.position;
    frame.head.orientation = m_pendingHead.pose.orientation;

    if (m_pendingLeft.valid) {
        frame.left_hand.position = m_pendingLeft.pose.position;
        frame.left_hand.orientation = m_pendingLeft.pose.orientation;
    }

    if (m_pendingRight.valid) {
        frame.right_hand.position = m_pendingRight.pose.position;
        frame.right_hand.orientation = m_pendingRight.pose.orientation;
    }

    // Copy input state
    frame.left_grip = m_leftGrip;
    frame.left_trigger = m_leftTrigger;
    frame.right_grip = m_rightGrip;
    frame.right_trigger = m_rightTrigger;

    // Compute velocities from previous frame
    const MovementFrame* previous = m_frameBuffer.empty() ? nullptr : &m_frameBuffer.back();
    computeVelocities(frame, previous);

    // Compute derived metrics
    computeDerivedMetrics(frame);

    // Update space map
    updateSpaceMap(frame);

    // Update statistics
    updateStatistics(frame);

    // Store frame
    m_frameBuffer.push_back(frame);
    if (m_frameBuffer.size() > MAX_FRAME_HISTORY) {
        m_frameBuffer.pop_front();
    }

    m_currentFrame = frame;
    m_currentFrameValid = true;

    // Reset pending state
    m_pendingHead.valid = false;
    m_pendingLeft.valid = false;
    m_pendingRight.valid = false;
    m_lastFrameTime = frameTime;

    // Callback
    if (m_frameCallback) {
        m_frameCallback(frame);
    }
}

const MovementFrame* MovementTracker::getCurrentFrame() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_currentFrameValid ? &m_currentFrame : nullptr;
}

std::vector<MovementFrame> MovementTracker::getRecentFrames(size_t count) const {
    std::lock_guard<std::mutex> lock(m_mutex);

    std::vector<MovementFrame> result;
    size_t available = std::min(count, m_frameBuffer.size());

    for (size_t i = m_frameBuffer.size() - available; i < m_frameBuffer.size(); i++) {
        result.push_back(m_frameBuffer[i]);
    }

    return result;
}

SessionStats MovementTracker::getSessionStats() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_stats;
}

float MovementTracker::getSessionDuration() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_sessionStartTime == 0 || m_lastFrameTime == 0) return 0.0f;
    return static_cast<float>(m_lastFrameTime - m_sessionStartTime) / 1e9f;
}

void MovementTracker::computeVelocities(MovementFrame& frame, const MovementFrame* previous) {
    if (!previous || frame.delta_time <= 0) return;

    float invDelta = 1.0f / frame.delta_time;

    // Linear velocities
    frame.head_velocity.linear = (frame.head.position - previous->head.position) * invDelta;
    frame.left_velocity.linear = (frame.left_hand.position - previous->left_hand.position) * invDelta;
    frame.right_velocity.linear = (frame.right_hand.position - previous->right_hand.position) * invDelta;

    // TODO: Angular velocities from quaternion difference
}

void MovementTracker::computeDerivedMetrics(MovementFrame& frame) {
    // Body center estimate
    XrVector3f bodyCenter = frame.head.position;
    bodyCenter.y -= 0.4f;  // Approximate shoulder height

    // Reach distances
    frame.left_reach_distance = distance(frame.left_hand.position, bodyCenter);
    frame.right_reach_distance = distance(frame.right_hand.position, bodyCenter);

    // Movement intensity
    frame.movement_intensity = (
        length(frame.left_velocity.linear) +
        length(frame.right_velocity.linear) +
        length(frame.head_velocity.linear)
    ) / 3.0f;
}

void MovementTracker::updateSpaceMap(const MovementFrame& frame) {
    bool leftExplored = m_spaceMap.recordPosition("left", frame.left_hand.position, frame.head.position);
    bool rightExplored = m_spaceMap.recordPosition("right", frame.right_hand.position, frame.head.position);

    if (m_zoneExploredCallback) {
        if (leftExplored) {
            m_zoneExploredCallback(frame.left_hand.position, "left");
        }
        if (rightExplored) {
            m_zoneExploredCallback(frame.right_hand.position, "right");
        }
    }
}

void MovementTracker::updateStatistics(const MovementFrame& frame) {
    m_stats.frame_count++;
    m_stats.duration_seconds = getSessionDuration();

    // Distance traveled
    if (m_frameBuffer.size() > 1) {
        m_stats.left_distance_traveled += length(frame.left_velocity.linear) * frame.delta_time;
        m_stats.right_distance_traveled += length(frame.right_velocity.linear) * frame.delta_time;
        m_stats.head_distance_traveled += length(frame.head_velocity.linear) * frame.delta_time;
    }

    // Peak velocities
    float leftSpeed = length(frame.left_velocity.linear);
    float rightSpeed = length(frame.right_velocity.linear);

    if (leftSpeed > m_stats.peak_left_velocity) {
        m_stats.peak_left_velocity = leftSpeed;
    }
    if (rightSpeed > m_stats.peak_right_velocity) {
        m_stats.peak_right_velocity = rightSpeed;
    }

    // Coverage and symmetry
    m_stats.coverage_percentage = m_spaceMap.getCoveragePercentage();
    m_stats.symmetry_score = m_spaceMap.getSymmetryScore();
}

}  // namespace MovementDojo
