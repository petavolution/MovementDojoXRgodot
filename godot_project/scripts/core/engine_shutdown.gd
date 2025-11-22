## EngineShutdown - Centralized cleanup and shutdown for VR dojo engine
## Ensures all resources are released and logs are flushed on any exit path
## Call request_shutdown() for clean exits, or emergency_shutdown() for failures
extends RefCounted
class_name EngineShutdown

const SOURCE := "Shutdown"

# Shutdown state
static var _shutdown_in_progress := false
static var _shutdown_reason := ""

# =============================================================================
# PUBLIC API
# =============================================================================

## Request a clean shutdown with optional reason
static func request_shutdown(reason: String = "Normal exit", exit_code: int = 0) -> void:
	if _shutdown_in_progress:
		DebugLogger.warn(SOURCE, "Shutdown already in progress, ignoring duplicate request")
		return

	_shutdown_in_progress = true
	_shutdown_reason = reason

	DebugLogger.info(SOURCE, "=== SHUTDOWN INITIATED ===")
	DebugLogger.info(SOURCE, "Reason: %s" % reason)

	# Shutdown subsystems in reverse initialization order
	_shutdown_subsystems()

	# Final log flush
	_final_flush()

	DebugLogger.info(SOURCE, "=== SHUTDOWN COMPLETE (logs flushed) ===")

	# Request engine quit
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.quit(exit_code)


## Emergency shutdown for critical failures - minimal cleanup, maximum logging
static func emergency_shutdown(reason: String, error_details: String = "") -> void:
	_shutdown_in_progress = true
	_shutdown_reason = reason

	DebugLogger.error(SOURCE, "=== EMERGENCY SHUTDOWN ===")
	DebugLogger.error(SOURCE, "Reason: %s" % reason)
	if error_details:
		DebugLogger.error(SOURCE, "Details: %s" % error_details)

	# Log stack trace if available
	var stack := get_stack()
	if stack.size() > 1:
		DebugLogger.error(SOURCE, "Stack trace:")
		for i in range(1, mini(stack.size(), 8)):
			var frame: Dictionary = stack[i]
			DebugLogger.error(SOURCE, "  %s:%d in %s()" % [
				frame.get("source", "unknown"),
				frame.get("line", 0),
				frame.get("function", "unknown")
			])

	# Minimal cleanup - just OpenXR and logs
	_cleanup_openxr()
	_final_flush()

	DebugLogger.error(SOURCE, "=== EMERGENCY SHUTDOWN COMPLETE ===")

	# Force quit
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.quit(1)


## Shutdown triggered by early failure during startup
static func startup_failure(subsystem: String, reason: String) -> void:
	DebugLogger.error(SOURCE, "STARTUP FAILURE in %s: %s" % [subsystem, reason])
	emergency_shutdown("Startup failure: %s" % subsystem, reason)


## Check if shutdown is in progress
static func is_shutting_down() -> bool:
	return _shutdown_in_progress


# =============================================================================
# SUBSYSTEM SHUTDOWN
# =============================================================================

static func _shutdown_subsystems() -> void:
	DebugLogger.debug(SOURCE, "Shutting down subsystems...")

	# Shutdown order (reverse of initialization):
	# 1. Game systems (SessionManager, etc.)
	# 2. Input systems (XRInputManager)
	# 3. Tracking (MovementTracker)
	# 4. Events (GameEvents)
	# 5. OpenXR
	# 6. Logger (last)

	_shutdown_game_systems()
	_shutdown_input_systems()
	_shutdown_tracking()
	_cleanup_openxr()


static func _shutdown_game_systems() -> void:
	DebugLogger.debug(SOURCE, "Shutting down game systems...")

	# SessionManager cleanup
	var session_manager := Engine.get_main_loop().get_node_or_null("/root/SessionManager") if Engine.get_main_loop() else null
	if session_manager and session_manager.has_method("end_session"):
		if session_manager.get("session_active"):
			DebugLogger.debug(SOURCE, "  Ending active session")
			session_manager.end_session()

	DebugLogger.debug(SOURCE, "  Game systems: OK")


static func _shutdown_input_systems() -> void:
	DebugLogger.debug(SOURCE, "Shutting down input systems...")

	# XRInputManager doesn't need explicit cleanup - signals auto-disconnect
	# But log for completeness
	DebugLogger.debug(SOURCE, "  Input systems: OK")


static func _shutdown_tracking() -> void:
	DebugLogger.debug(SOURCE, "Shutting down tracking...")

	# MovementTracker cleanup
	var tracker := Engine.get_main_loop().get_node_or_null("/root/MovementTracker") if Engine.get_main_loop() else null
	if tracker and tracker.has_method("stop_tracking"):
		DebugLogger.debug(SOURCE, "  Stopping movement tracker")
		tracker.stop_tracking()

	DebugLogger.debug(SOURCE, "  Tracking: OK")


static func _cleanup_openxr() -> void:
	DebugLogger.debug(SOURCE, "Shutting down OpenXR...")

	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		DebugLogger.debug(SOURCE, "  Uninitializing OpenXR interface")
		# Note: Godot handles most OpenXR cleanup automatically
		# The interface will be uninitialized when the viewport is destroyed
		# We just need to ensure the viewport isn't using XR anymore

		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			tree.root.use_xr = false

		DebugLogger.debug(SOURCE, "  OpenXR: OK")
	else:
		DebugLogger.debug(SOURCE, "  OpenXR: not initialized (skipped)")


static func _final_flush() -> void:
	DebugLogger.debug(SOURCE, "Flushing logs to disk...")
	DebugLogger.flush()
	DebugLogger.debug(SOURCE, "  Logs flushed: OK")


# =============================================================================
# UTILITY: Shutdown with XR diagnostic info
# =============================================================================

## Log XR state before shutdown (useful for debugging crashes)
static func log_xr_state_before_shutdown() -> void:
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface == null:
		DebugLogger.debug(SOURCE, "XR state: interface not found")
		return

	DebugLogger.debug(SOURCE, "XR state at shutdown:")
	DebugLogger.debug(SOURCE, "  Interface: %s" % xr_interface.get_name())
	DebugLogger.debug(SOURCE, "  Initialized: %s" % xr_interface.is_initialized())

	if xr_interface.is_initialized():
		var refresh := xr_interface.get_display_refresh_rate()
		var render_size := xr_interface.get_render_target_size()
		DebugLogger.debug(SOURCE, "  Refresh rate: %.0f Hz" % refresh)
		DebugLogger.debug(SOURCE, "  Render size: %dx%d" % [int(render_size.x), int(render_size.y)])
