/**
 * Movement Dojo XR Overlay - API Layer Implementation
 */

#include "api_layer.h"
#include <cstring>

namespace MovementDojo {

// Logging implementation
void Log(LogLevel level, const std::string& message) {
    const char* prefix = "";
    switch (level) {
        case LogLevel::Debug:   prefix = "[DEBUG]"; break;
        case LogLevel::Info:    prefix = "[INFO]"; break;
        case LogLevel::Warning: prefix = "[WARN]"; break;
        case LogLevel::Error:   prefix = "[ERROR]"; break;
    }
    // In production, write to file or use platform logging
    fprintf(stderr, "MovementDojo %s %s\n", prefix, message.c_str());
}

ApiLayer& ApiLayer::getInstance() {
    static ApiLayer instance;
    return instance;
}

XrResult ApiLayer::initialize(XrInstance instance, PFN_xrGetInstanceProcAddr getInstanceProcAddr) {
    if (m_initialized) {
        return XR_SUCCESS;
    }

    m_instance = instance;
    pfnGetInstanceProcAddr = getInstanceProcAddr;

    // Get original function pointers
    #define GET_PROC(name) \
        pfnGetInstanceProcAddr(instance, #name, reinterpret_cast<PFN_xrVoidFunction*>(&pfn##name))

    GET_PROC(CreateSession);
    GET_PROC(DestroySession);
    GET_PROC(BeginFrame);
    GET_PROC(EndFrame);
    GET_PROC(LocateSpace);
    GET_PROC(LocateViews);
    GET_PROC(SyncActions);
    GET_PROC(GetActionStateFloat);

    #undef GET_PROC

    m_initialized = true;
    LOG_INFO("API Layer initialized");

    return XR_SUCCESS;
}

void ApiLayer::shutdown() {
    if (!m_initialized) return;

    m_tracker.stopTracking();
    m_initialized = false;

    LOG_INFO("API Layer shutdown");
}

PFN_xrVoidFunction ApiLayer::getInterceptedFunction(const char* name) {
    // Return our intercepted function if we handle it
    #define INTERCEPT(func) \
        if (strcmp(name, #func) == 0) return reinterpret_cast<PFN_xrVoidFunction>(MovementDojo_##func)

    INTERCEPT(xrGetInstanceProcAddr);
    INTERCEPT(xrCreateSession);
    INTERCEPT(xrDestroySession);
    INTERCEPT(xrBeginFrame);
    INTERCEPT(xrEndFrame);
    INTERCEPT(xrLocateSpace);
    INTERCEPT(xrLocateViews);

    #undef INTERCEPT

    return nullptr;
}

// ============================================================================
// Intercepted Functions
// ============================================================================

extern "C" {

XrResult XRAPI_CALL MovementDojo_xrGetInstanceProcAddr(
    XrInstance instance,
    const char* name,
    PFN_xrVoidFunction* function)
{
    auto& layer = ApiLayer::getInstance();

    // Check if we intercept this function
    PFN_xrVoidFunction intercepted = layer.getInterceptedFunction(name);
    if (intercepted) {
        *function = intercepted;
        return XR_SUCCESS;
    }

    // Pass through to runtime
    if (layer.pfnGetInstanceProcAddr) {
        return layer.pfnGetInstanceProcAddr(instance, name, function);
    }

    return XR_ERROR_FUNCTION_UNSUPPORTED;
}

XrResult XRAPI_CALL MovementDojo_xrCreateSession(
    XrInstance instance,
    const XrSessionCreateInfo* createInfo,
    XrSession* session)
{
    auto& layer = ApiLayer::getInstance();

    // Call original
    XrResult result = layer.pfnCreateSession(instance, createInfo, session);

    if (XR_SUCCEEDED(result)) {
        LOG_INFO("Session created, starting movement tracking");
        layer.getTracker().startTracking();
    }

    return result;
}

XrResult XRAPI_CALL MovementDojo_xrDestroySession(XrSession session) {
    auto& layer = ApiLayer::getInstance();

    LOG_INFO("Session destroyed, stopping movement tracking");
    layer.getTracker().stopTracking();

    return layer.pfnDestroySession(session);
}

XrResult XRAPI_CALL MovementDojo_xrBeginFrame(
    XrSession session,
    const XrFrameBeginInfo* frameBeginInfo)
{
    auto& layer = ApiLayer::getInstance();
    return layer.pfnBeginFrame(session, frameBeginInfo);
}

XrResult XRAPI_CALL MovementDojo_xrEndFrame(
    XrSession session,
    const XrFrameEndInfo* frameEndInfo)
{
    auto& layer = ApiLayer::getInstance();

    // Complete current tracking frame
    if (layer.isOverlayEnabled() && frameEndInfo) {
        layer.getTracker().completeFrame(frameEndInfo->displayTime);
    }

    // TODO: Inject overlay layer into composition if enabled
    // This would require creating our own composition layer and appending it

    return layer.pfnEndFrame(session, frameEndInfo);
}

XrResult XRAPI_CALL MovementDojo_xrLocateSpace(
    XrSpace space,
    XrSpace baseSpace,
    XrTime time,
    XrSpaceLocation* location)
{
    auto& layer = ApiLayer::getInstance();

    // Call original
    XrResult result = layer.pfnLocateSpace(space, baseSpace, time, location);

    // Record tracking data if successful
    if (XR_SUCCEEDED(result) && layer.isOverlayEnabled()) {
        if (location->locationFlags & XR_SPACE_LOCATION_POSITION_VALID_BIT) {
            // Note: In a real implementation, we'd need to track which space
            // corresponds to head/left_hand/right_hand by intercepting
            // xrCreateActionSpace and xrCreateReferenceSpace

            // For now, this is a simplified placeholder
            // The actual hand/head determination would come from action space creation
        }
    }

    return result;
}

XrResult XRAPI_CALL MovementDojo_xrLocateViews(
    XrSession session,
    const XrViewLocateInfo* viewLocateInfo,
    XrViewState* viewState,
    uint32_t viewCapacityInput,
    uint32_t* viewCountOutput,
    XrView* views)
{
    auto& layer = ApiLayer::getInstance();

    XrResult result = layer.pfnLocateViews(
        session, viewLocateInfo, viewState,
        viewCapacityInput, viewCountOutput, views);

    // Record head pose from view data
    if (XR_SUCCEEDED(result) && layer.isOverlayEnabled() && views && viewCountOutput && *viewCountOutput > 0) {
        // Use first view's pose as approximate head position
        layer.getTracker().recordHeadPose(viewLocateInfo->displayTime, views[0].pose);
    }

    return result;
}

}  // extern "C"

}  // namespace MovementDojo
