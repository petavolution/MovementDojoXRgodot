/**
 * Movement Dojo XR Overlay - Overlay Renderer Implementation
 */

#include "overlay_renderer.h"
#include <cstring>
#include <algorithm>

namespace MovementDojo {

OverlayRenderer::OverlayRenderer() {
    m_leftTrail.reserve(MAX_TRAIL_POINTS);
    m_rightTrail.reserve(MAX_TRAIL_POINTS);
}

OverlayRenderer::~OverlayRenderer() {
    shutdown();
}

bool OverlayRenderer::initialize(XrInstance instance, XrSession session, XrSystemId systemId) {
    if (m_initialized) {
        return true;
    }

    m_instance = instance;
    m_session = session;
    m_systemId = systemId;

    // Create reference space for overlay positioning
    XrReferenceSpaceCreateInfo spaceCreateInfo{XR_TYPE_REFERENCE_SPACE_CREATE_INFO};
    spaceCreateInfo.referenceSpaceType = XR_REFERENCE_SPACE_TYPE_VIEW;  // Head-relative
    spaceCreateInfo.poseInReferenceSpace.orientation = {0, 0, 0, 1};
    spaceCreateInfo.poseInReferenceSpace.position = {0, 0, -1.0f};  // 1m in front

    XrResult result = xrCreateReferenceSpace(m_session, &spaceCreateInfo, &m_overlaySpace);
    if (XR_FAILED(result)) {
        LOG_ERROR("Failed to create overlay reference space");
        return false;
    }

    // Initialize Vulkan resources
    if (!initializeVulkan()) {
        LOG_ERROR("Failed to initialize Vulkan for overlay");
        return false;
    }

    // Create swapchain
    if (!createSwapchain()) {
        LOG_ERROR("Failed to create overlay swapchain");
        return false;
    }

    // Create render resources
    if (!createRenderResources()) {
        LOG_ERROR("Failed to create render resources");
        return false;
    }

    // Setup composition layer
    m_overlayLayer.type = XR_TYPE_COMPOSITION_LAYER_QUAD;
    m_overlayLayer.next = nullptr;
    m_overlayLayer.layerFlags = XR_COMPOSITION_LAYER_BLEND_TEXTURE_SOURCE_ALPHA_BIT;
    m_overlayLayer.space = m_overlaySpace;
    m_overlayLayer.eyeVisibility = XR_EYE_VISIBILITY_BOTH;
    m_overlayLayer.subImage.swapchain = m_swapchain;
    m_overlayLayer.subImage.imageRect.offset = {0, 0};
    m_overlayLayer.subImage.imageRect.extent = {
        static_cast<int32_t>(m_swapchainWidth),
        static_cast<int32_t>(m_swapchainHeight)
    };
    m_overlayLayer.subImage.imageArrayIndex = 0;
    m_overlayLayer.pose.orientation = {0, 0, 0, 1};
    m_overlayLayer.pose.position = {0, 0, 0};
    m_overlayLayer.size = {0.5f, 0.5f};  // 50cm x 50cm quad

    m_initialized = true;
    LOG_INFO("Overlay renderer initialized");
    return true;
}

void OverlayRenderer::shutdown() {
    if (!m_initialized) {
        return;
    }

    // Cleanup Vulkan resources
    if (m_vkDevice != VK_NULL_HANDLE) {
        vkDeviceWaitIdle(m_vkDevice);

        if (m_vkTrailPipeline != VK_NULL_HANDLE) {
            vkDestroyPipeline(m_vkDevice, m_vkTrailPipeline, nullptr);
        }
        if (m_vkPipelineLayout != VK_NULL_HANDLE) {
            vkDestroyPipelineLayout(m_vkDevice, m_vkPipelineLayout, nullptr);
        }
        if (m_vkRenderPass != VK_NULL_HANDLE) {
            vkDestroyRenderPass(m_vkDevice, m_vkRenderPass, nullptr);
        }

        for (auto& fb : m_framebuffers) {
            vkDestroyFramebuffer(m_vkDevice, fb, nullptr);
        }
        for (auto& iv : m_swapchainImageViews) {
            vkDestroyImageView(m_vkDevice, iv, nullptr);
        }

        if (m_vkCommandPool != VK_NULL_HANDLE) {
            vkDestroyCommandPool(m_vkDevice, m_vkCommandPool, nullptr);
        }
    }

    // Cleanup OpenXR
    if (m_swapchain != XR_NULL_HANDLE) {
        xrDestroySwapchain(m_swapchain);
    }
    if (m_overlaySpace != XR_NULL_HANDLE) {
        xrDestroySpace(m_overlaySpace);
    }

    m_initialized = false;
    LOG_INFO("Overlay renderer shutdown");
}

void OverlayRenderer::update(const MovementTracker& tracker, XrTime displayTime) {
    if (!m_initialized) {
        return;
    }

    updateTrails(tracker);

    if (m_heatMapEnabled) {
        updateHeatMap(tracker);
    }

    if (m_statsHudEnabled) {
        updateStatsHud(tracker);
    }

    renderFrame(displayTime);
}

XrCompositionLayerQuad* OverlayRenderer::getOverlayLayer() {
    if (!m_initialized) {
        return nullptr;
    }
    return &m_overlayLayer;
}

void OverlayRenderer::setTrailColor(const XrVector3f& leftColor, const XrVector3f& rightColor) {
    m_leftTrailColor = leftColor;
    m_rightTrailColor = rightColor;
}

void OverlayRenderer::updateTrails(const MovementTracker& tracker) {
    const MovementFrame* frame = tracker.getCurrentFrame();
    if (frame == nullptr) {
        return;
    }

    float currentTime = static_cast<float>(frame->timestamp) / 1e9f;

    // Add new trail points
    TrailPoint leftPoint;
    leftPoint.position = frame->left_hand.position;
    leftPoint.timestamp = currentTime;
    leftPoint.intensity = 1.0f;

    TrailPoint rightPoint;
    rightPoint.position = frame->right_hand.position;
    rightPoint.timestamp = currentTime;
    rightPoint.intensity = 1.0f;

    m_leftTrail.push_back(leftPoint);
    m_rightTrail.push_back(rightPoint);

    // Limit trail length
    while (m_leftTrail.size() > MAX_TRAIL_POINTS) {
        m_leftTrail.erase(m_leftTrail.begin());
    }
    while (m_rightTrail.size() > MAX_TRAIL_POINTS) {
        m_rightTrail.erase(m_rightTrail.begin());
    }

    // Update intensities (fade over time)
    float fadeTime = 1.0f;  // Fade over 1 second
    for (auto& point : m_leftTrail) {
        float age = currentTime - point.timestamp;
        point.intensity = std::max(0.0f, 1.0f - age / fadeTime);
    }
    for (auto& point : m_rightTrail) {
        float age = currentTime - point.timestamp;
        point.intensity = std::max(0.0f, 1.0f - age / fadeTime);
    }

    // Remove fully faded points
    m_leftTrail.erase(
        std::remove_if(m_leftTrail.begin(), m_leftTrail.end(),
            [](const TrailPoint& p) { return p.intensity <= 0.0f; }),
        m_leftTrail.end()
    );
    m_rightTrail.erase(
        std::remove_if(m_rightTrail.begin(), m_rightTrail.end(),
            [](const TrailPoint& p) { return p.intensity <= 0.0f; }),
        m_rightTrail.end()
    );
}

void OverlayRenderer::updateHeatMap(const MovementTracker& tracker) {
    // Heat map data is retrieved from tracker.getSpaceMap()
    // Would update vertex buffer with colored points
}

void OverlayRenderer::updateStatsHud(const MovementTracker& tracker) {
    // Would render stats text to texture
    SessionStats stats = tracker.getSessionStats();
    // Format: Coverage, Symmetry, Duration, etc.
}

void OverlayRenderer::renderFrame(XrTime displayTime) {
    // Acquire swapchain image
    uint32_t imageIndex;
    XrSwapchainImageAcquireInfo acquireInfo{XR_TYPE_SWAPCHAIN_IMAGE_ACQUIRE_INFO};
    xrAcquireSwapchainImage(m_swapchain, &acquireInfo, &imageIndex);

    XrSwapchainImageWaitInfo waitInfo{XR_TYPE_SWAPCHAIN_IMAGE_WAIT_INFO};
    waitInfo.timeout = XR_INFINITE_DURATION;
    xrWaitSwapchainImage(m_swapchain, &waitInfo);

    // Render to the swapchain image
    // (Actual Vulkan rendering code would go here)

    if (m_trailsEnabled) {
        renderTrails();
    }

    if (m_heatMapEnabled) {
        renderHeatMap();
    }

    if (m_statsHudEnabled) {
        renderStatsHud();
    }

    // Release swapchain image
    XrSwapchainImageReleaseInfo releaseInfo{XR_TYPE_SWAPCHAIN_IMAGE_RELEASE_INFO};
    xrReleaseSwapchainImage(m_swapchain, &releaseInfo);
}

void OverlayRenderer::renderTrails() {
    // Would render m_leftTrail and m_rightTrail as line strips
    // Using Vulkan commands
}

void OverlayRenderer::renderHeatMap() {
    // Would render heat map points as instanced spheres/points
}

void OverlayRenderer::renderStatsHud() {
    // Would render text overlay with stats
}

bool OverlayRenderer::initializeVulkan() {
    // In a full implementation, would:
    // 1. Get Vulkan instance/device from OpenXR via XR_KHR_vulkan_enable2
    // 2. Create command pool, queues, etc.

    // For now, this is a placeholder that assumes Vulkan is available
    LOG_INFO("Vulkan initialization placeholder");
    return true;
}

bool OverlayRenderer::createSwapchain() {
    // Query swapchain formats
    uint32_t formatCount;
    xrEnumerateSwapchainFormats(m_session, 0, &formatCount, nullptr);

    std::vector<int64_t> formats(formatCount);
    xrEnumerateSwapchainFormats(m_session, formatCount, &formatCount, formats.data());

    // Find suitable format (prefer RGBA8)
    int64_t selectedFormat = formats[0];
    for (int64_t format : formats) {
        if (format == VK_FORMAT_R8G8B8A8_SRGB || format == VK_FORMAT_R8G8B8A8_UNORM) {
            selectedFormat = format;
            break;
        }
    }

    // Create swapchain
    XrSwapchainCreateInfo swapchainCreateInfo{XR_TYPE_SWAPCHAIN_CREATE_INFO};
    swapchainCreateInfo.usageFlags = XR_SWAPCHAIN_USAGE_COLOR_ATTACHMENT_BIT | XR_SWAPCHAIN_USAGE_SAMPLED_BIT;
    swapchainCreateInfo.format = selectedFormat;
    swapchainCreateInfo.sampleCount = 1;
    swapchainCreateInfo.width = m_swapchainWidth;
    swapchainCreateInfo.height = m_swapchainHeight;
    swapchainCreateInfo.faceCount = 1;
    swapchainCreateInfo.arraySize = 1;
    swapchainCreateInfo.mipCount = 1;

    XrResult result = xrCreateSwapchain(m_session, &swapchainCreateInfo, &m_swapchain);
    if (XR_FAILED(result)) {
        LOG_ERROR("Failed to create swapchain");
        return false;
    }

    // Get swapchain images
    uint32_t imageCount;
    xrEnumerateSwapchainImages(m_swapchain, 0, &imageCount, nullptr);

    std::vector<XrSwapchainImageVulkanKHR> images(imageCount, {XR_TYPE_SWAPCHAIN_IMAGE_VULKAN_KHR});
    xrEnumerateSwapchainImages(
        m_swapchain,
        imageCount,
        &imageCount,
        reinterpret_cast<XrSwapchainImageBaseHeader*>(images.data())
    );

    m_swapchainImages.resize(imageCount);
    for (uint32_t i = 0; i < imageCount; i++) {
        m_swapchainImages[i] = images[i].image;
    }

    LOG_INFO("Created swapchain with " + std::to_string(imageCount) + " images");
    return true;
}

bool OverlayRenderer::createRenderResources() {
    // In full implementation would create:
    // - Render pass
    // - Framebuffers
    // - Graphics pipeline for trail/point rendering
    // - Vertex/index buffers
    // - Descriptor sets

    LOG_INFO("Render resources placeholder");
    return true;
}

}  // namespace MovementDojo
