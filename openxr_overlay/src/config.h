/**
 * Movement Dojo XR Overlay - Configuration
 */

#pragma once

#include "common.h"
#include <string>

namespace MovementDojo {

class Config {
public:
    static Config& getInstance();

    void load();
    void save();

    // Settings
    bool overlayEnabled = true;
    bool trackingEnabled = true;
    bool heatMapVisible = false;
    bool trailsVisible = true;
    bool statsHudVisible = true;

    float hapticIntensity = 0.5f;

    std::string dataDirectory;
    std::string sessionPrefix = "session_";

private:
    Config() = default;

    std::string getConfigPath() const;
};

}  // namespace MovementDojo
