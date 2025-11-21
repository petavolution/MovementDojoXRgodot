/**
 * Movement Dojo XR Overlay - Overlay Renderer
 * Renders movement visualization as OpenXR composition layer
 */

#pragma once

#include "common.h"
#include "movement_tracker.h"
#include <vulkan/vulkan.h>
#include <vector>

namespace MovementDojo {

/**
 * TrailPoint - Single point in a movement trail
 */
struct TrailPoint {
    XrVector3f position;
    float timestamp;
    float intensity;  // 0-1, fades over time
};

/**
 * OverlayRenderer - Renders visualization overlay
 */
class OverlayRenderer {
public:
    OverlayRenderer();
    ~OverlayRenderer();

    // Initialization
    bool initialize(XrInstance instance, XrSession session, XrSystemId systemId);
    void shutdown();

    // Configuration
    void setTrailsEnabled(bool enabled) { m_trailsEnabled = enabled; }
    void setHeatMapEnabled(bool enabled) { m_heatMapEnabled = enabled; }
    void setStatsHudEnabled(bool enabled) { m_statsHudEnabled = enabled; }

    // Update/Render
    void update(const MovementTracker& tracker, XrTime displayTime);
    XrCompositionLayerQuad* getOverlayLayer();

    // Colors
    void setTrailColor(const XrVector3f& leftColor, const XrVector3f& rightColor);
    void setHeatMapGradient(const std::vector<XrVector3f>& colors);

private:
    bool initializeVulkan();
    bool createSwapchain();
    bool createRenderResources();

    void updateTrails(const MovementTracker& tracker);
    void updateHeatMap(const MovementTracker& tracker);
    void updateStatsHud(const MovementTracker& tracker);

    void renderFrame(XrTime displayTime);
    void renderTrails();
    void renderHeatMap();
    void renderStatsHud();

    // OpenXR handles
    XrInstance m_instance = XR_NULL_HANDLE;
    XrSession m_session = XR_NULL_HANDLE;
    XrSystemId m_systemId = XR_NULL_SYSTEM_ID;
    XrSpace m_overlaySpace = XR_NULL_HANDLE;
    XrSwapchain m_swapchain = XR_NULL_HANDLE;

    // Vulkan handles
    VkInstance m_vkInstance = VK_NULL_HANDLE;
    VkDevice m_vkDevice = VK_NULL_HANDLE;
    VkPhysicalDevice m_vkPhysicalDevice = VK_NULL_HANDLE;
    VkQueue m_vkQueue = VK_NULL_HANDLE;
    VkCommandPool m_vkCommandPool = VK_NULL_HANDLE;
    VkRenderPass m_vkRenderPass = VK_NULL_HANDLE;
    VkPipeline m_vkTrailPipeline = VK_NULL_HANDLE;
    VkPipelineLayout m_vkPipelineLayout = VK_NULL_HANDLE;

    // Swapchain images
    std::vector<VkImage> m_swapchainImages;
    std::vector<VkImageView> m_swapchainImageViews;
    std::vector<VkFramebuffer> m_framebuffers;
    uint32_t m_swapchainWidth = 1024;
    uint32_t m_swapchainHeight = 1024;

    // Composition layer
    XrCompositionLayerQuad m_overlayLayer{};

    // Visualization data
    std::vector<TrailPoint> m_leftTrail;
    std::vector<TrailPoint> m_rightTrail;
    static constexpr size_t MAX_TRAIL_POINTS = 100;

    // Feature toggles
    bool m_trailsEnabled = true;
    bool m_heatMapEnabled = false;
    bool m_statsHudEnabled = true;

    // Colors
    XrVector3f m_leftTrailColor = {0.2f, 0.6f, 1.0f};
    XrVector3f m_rightTrailColor = {1.0f, 0.4f, 0.2f};

    bool m_initialized = false;
};

}  // namespace MovementDojo
