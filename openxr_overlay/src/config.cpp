/**
 * Movement Dojo XR Overlay - Configuration Implementation
 */

#include "config.h"
#include <fstream>
#include <cstdlib>
#include <filesystem>

#ifdef _WIN32
#include <shlobj.h>
#else
#include <pwd.h>
#include <unistd.h>
#endif

namespace fs = std::filesystem;

namespace MovementDojo {

Config& Config::getInstance() {
    static Config instance;
    return instance;
}

std::string Config::getConfigPath() const {
    std::string basePath;

#ifdef _WIN32
    char path[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathA(NULL, CSIDL_APPDATA, NULL, 0, path))) {
        basePath = path;
    }
#else
    const char* home = getenv("HOME");
    if (!home) {
        struct passwd* pw = getpwuid(getuid());
        if (pw) {
            home = pw->pw_dir;
        }
    }
    if (home) {
        basePath = home;
        basePath += "/.config";
    }
#endif

    if (basePath.empty()) {
        basePath = ".";
    }

    return basePath + "/movement_dojo";
}

void Config::load() {
    dataDirectory = getConfigPath();

    // Create directory if it doesn't exist
    try {
        fs::create_directories(dataDirectory);
        fs::create_directories(dataDirectory + "/sessions");
    } catch (const std::exception& e) {
        LOG_ERROR(std::string("Failed to create data directory: ") + e.what());
    }

    std::string configFile = dataDirectory + "/config.json";

    std::ifstream file(configFile);
    if (!file.is_open()) {
        LOG_INFO("No config file found, using defaults");
        return;
    }

    // Simple JSON parsing (in production, use a proper JSON library)
    std::string content((std::istreambuf_iterator<char>(file)),
                         std::istreambuf_iterator<char>());

    // Parse simple key-value pairs
    auto findBool = [&content](const char* key, bool defaultVal) -> bool {
        std::string search = std::string("\"") + key + "\":";
        size_t pos = content.find(search);
        if (pos != std::string::npos) {
            pos += search.length();
            while (pos < content.length() && (content[pos] == ' ' || content[pos] == '\t')) pos++;
            return content.substr(pos, 4) == "true";
        }
        return defaultVal;
    };

    auto findFloat = [&content](const char* key, float defaultVal) -> float {
        std::string search = std::string("\"") + key + "\":";
        size_t pos = content.find(search);
        if (pos != std::string::npos) {
            pos += search.length();
            while (pos < content.length() && (content[pos] == ' ' || content[pos] == '\t')) pos++;
            try {
                return std::stof(content.substr(pos));
            } catch (...) {}
        }
        return defaultVal;
    };

    overlayEnabled = findBool("overlay_enabled", overlayEnabled);
    trackingEnabled = findBool("tracking_enabled", trackingEnabled);
    heatMapVisible = findBool("heat_map_visible", heatMapVisible);
    trailsVisible = findBool("trails_visible", trailsVisible);
    statsHudVisible = findBool("stats_hud_visible", statsHudVisible);
    hapticIntensity = findFloat("haptic_intensity", hapticIntensity);

    LOG_INFO("Configuration loaded from " + configFile);
}

void Config::save() {
    std::string configFile = dataDirectory + "/config.json";

    std::ofstream file(configFile);
    if (!file.is_open()) {
        LOG_ERROR("Failed to save config to " + configFile);
        return;
    }

    file << "{\n";
    file << "  \"overlay_enabled\": " << (overlayEnabled ? "true" : "false") << ",\n";
    file << "  \"tracking_enabled\": " << (trackingEnabled ? "true" : "false") << ",\n";
    file << "  \"heat_map_visible\": " << (heatMapVisible ? "true" : "false") << ",\n";
    file << "  \"trails_visible\": " << (trailsVisible ? "true" : "false") << ",\n";
    file << "  \"stats_hud_visible\": " << (statsHudVisible ? "true" : "false") << ",\n";
    file << "  \"haptic_intensity\": " << hapticIntensity << "\n";
    file << "}\n";

    LOG_INFO("Configuration saved to " + configFile);
}

}  // namespace MovementDojo
