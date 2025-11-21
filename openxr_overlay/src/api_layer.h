/**
 * Movement Dojo XR Overlay - OpenXR API Layer
 * Intercepts OpenXR calls to track movement data
 */

#pragma once

#include "common.h"
#include "movement_tracker.h"
#include <unordered_map>

namespace MovementDojo {

/**
 * API Layer - Hooks into OpenXR runtime
 */
class ApiLayer {
public:
    static ApiLayer& getInstance();

    // Initialization
    XrResult initialize(XrInstance instance, PFN_xrGetInstanceProcAddr getInstanceProcAddr);
    void shutdown();

    // Hook management
    PFN_xrVoidFunction getInterceptedFunction(const char* name);

    // Accessors
    MovementTracker& getTracker() { return m_tracker; }
    XrInstance getInstance() const { return m_instance; }
    bool isInitialized() const { return m_initialized; }

    // Configuration
    void setOverlayEnabled(bool enabled) { m_overlayEnabled = enabled; }
    bool isOverlayEnabled() const { return m_overlayEnabled; }

    // Original function pointers
    PFN_xrGetInstanceProcAddr pfnGetInstanceProcAddr = nullptr;
    PFN_xrCreateSession pfnCreateSession = nullptr;
    PFN_xrDestroySession pfnDestroySession = nullptr;
    PFN_xrBeginFrame pfnBeginFrame = nullptr;
    PFN_xrEndFrame pfnEndFrame = nullptr;
    PFN_xrLocateSpace pfnLocateSpace = nullptr;
    PFN_xrLocateViews pfnLocateViews = nullptr;
    PFN_xrSyncActions pfnSyncActions = nullptr;
    PFN_xrGetActionStateFloat pfnGetActionStateFloat = nullptr;

private:
    ApiLayer() = default;
    ~ApiLayer() = default;
    ApiLayer(const ApiLayer&) = delete;
    ApiLayer& operator=(const ApiLayer&) = delete;

    bool m_initialized = false;
    bool m_overlayEnabled = true;
    XrInstance m_instance = XR_NULL_HANDLE;
    XrSession m_activeSession = XR_NULL_HANDLE;

    MovementTracker m_tracker;

    // Space handles for tracking
    std::unordered_map<XrSpace, std::string> m_spaceTypes;  // Maps space to "head", "left", "right"
};

// Intercepted functions (exposed for export)
extern "C" {

XrResult XRAPI_CALL MovementDojo_xrGetInstanceProcAddr(
    XrInstance instance,
    const char* name,
    PFN_xrVoidFunction* function);

XrResult XRAPI_CALL MovementDojo_xrCreateSession(
    XrInstance instance,
    const XrSessionCreateInfo* createInfo,
    XrSession* session);

XrResult XRAPI_CALL MovementDojo_xrDestroySession(
    XrSession session);

XrResult XRAPI_CALL MovementDojo_xrBeginFrame(
    XrSession session,
    const XrFrameBeginInfo* frameBeginInfo);

XrResult XRAPI_CALL MovementDojo_xrEndFrame(
    XrSession session,
    const XrFrameEndInfo* frameEndInfo);

XrResult XRAPI_CALL MovementDojo_xrLocateSpace(
    XrSpace space,
    XrSpace baseSpace,
    XrTime time,
    XrSpaceLocation* location);

XrResult XRAPI_CALL MovementDojo_xrLocateViews(
    XrSession session,
    const XrViewLocateInfo* viewLocateInfo,
    XrViewState* viewState,
    uint32_t viewCapacityInput,
    uint32_t* viewCountOutput,
    XrView* views);

}  // extern "C"

}  // namespace MovementDojo
