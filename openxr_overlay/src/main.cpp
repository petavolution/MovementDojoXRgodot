/**
 * Movement Dojo XR Overlay - Entry Point
 * OpenXR API Layer for universal VR movement tracking
 */

#include "api_layer.h"
#include "config.h"

// Platform-specific exports
#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

extern "C" {

/**
 * xrNegotiateLoaderApiLayerInterface - Required entry point for OpenXR API layers
 * Called by the OpenXR loader to initialize the layer
 */
EXPORT XrResult xrNegotiateLoaderApiLayerInterface(
    const XrNegotiateLoaderInfo* loaderInfo,
    const char* layerName,
    XrNegotiateApiLayerRequest* apiLayerRequest)
{
    if (loaderInfo == nullptr || apiLayerRequest == nullptr) {
        return XR_ERROR_INITIALIZATION_FAILED;
    }

    // Verify loader API version compatibility
    if (loaderInfo->structType != XR_LOADER_INTERFACE_STRUCT_LOADER_INFO ||
        loaderInfo->structVersion != XR_LOADER_INFO_STRUCT_VERSION ||
        loaderInfo->structSize != sizeof(XrNegotiateLoaderInfo)) {
        return XR_ERROR_INITIALIZATION_FAILED;
    }

    // Check API version (we support OpenXR 1.0+)
    if (XR_VERSION_MAJOR(loaderInfo->minApiVersion) > 1 ||
        (XR_VERSION_MAJOR(loaderInfo->minApiVersion) == 1 &&
         XR_VERSION_MINOR(loaderInfo->minApiVersion) > 0)) {
        MovementDojo::LOG_ERROR("Unsupported OpenXR API version");
        return XR_ERROR_INITIALIZATION_FAILED;
    }

    // Fill in our response
    apiLayerRequest->structType = XR_LOADER_INTERFACE_STRUCT_API_LAYER_REQUEST;
    apiLayerRequest->structVersion = XR_API_LAYER_INFO_STRUCT_VERSION;
    apiLayerRequest->structSize = sizeof(XrNegotiateApiLayerRequest);
    apiLayerRequest->layerInterfaceVersion = XR_CURRENT_LOADER_API_LAYER_VERSION;
    apiLayerRequest->layerApiVersion = XR_MAKE_VERSION(1, 0, 0);
    apiLayerRequest->getInstanceProcAddr = MovementDojo::MovementDojo_xrGetInstanceProcAddr;
    apiLayerRequest->createApiLayerInstance = nullptr;  // Use default

    MovementDojo::LOG_INFO("Movement Dojo XR Layer negotiated successfully");

    return XR_SUCCESS;
}

/**
 * Alternative entry point for some loaders
 */
EXPORT PFN_xrGetInstanceProcAddr MovementDojo_xrGetInstanceProcAddr_Export() {
    return MovementDojo::MovementDojo_xrGetInstanceProcAddr;
}

}  // extern "C"

// ============================================================================
// Layer lifecycle hooks (called by loader)
// ============================================================================

namespace MovementDojo {

/**
 * Called when an XR instance is created through this layer
 */
XrResult onInstanceCreate(XrInstance instance, PFN_xrGetInstanceProcAddr nextGetInstanceProcAddr) {
    LOG_INFO("Initializing Movement Dojo for instance");

    // Load configuration
    Config::getInstance().load();

    // Initialize API layer
    XrResult result = ApiLayer::getInstance().initialize(instance, nextGetInstanceProcAddr);

    if (XR_FAILED(result)) {
        LOG_ERROR("Failed to initialize API layer");
        return result;
    }

    return XR_SUCCESS;
}

/**
 * Called when an XR instance is destroyed
 */
void onInstanceDestroy(XrInstance instance) {
    LOG_INFO("Shutting down Movement Dojo");

    // Save any pending data
    Config::getInstance().save();

    // Shutdown layer
    ApiLayer::getInstance().shutdown();
}

}  // namespace MovementDojo
