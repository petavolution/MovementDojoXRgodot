## IAnalyticsTracker - Interface for analytics and telemetry
## Defines contract for tracking user data and metrics
class_name IAnalyticsTracker
extends RefCounted

## Event types
enum EventType {
	SESSION_START,
	SESSION_END,
	TRAINING_START,
	TRAINING_COMPLETE,
	ACHIEVEMENT_UNLOCKED,
	CHALLENGE_COMPLETED,
	SETTINGS_CHANGED,
	ERROR_OCCURRED,
	CUSTOM
}

## Metric types
enum MetricType {
	COUNTER,        # Incremental count
	GAUGE,          # Current value
	HISTOGRAM,      # Distribution
	TIMER           # Duration
}

## Analytics event
class AnalyticsEvent:
	var event_type: EventType = EventType.CUSTOM
	var event_name: String = ""
	var timestamp: float = 0.0
	var session_id: String = ""
	var properties: Dictionary = {}

## Interface methods

## Start tracking session
func start_session() -> String:
	push_error("IAnalyticsTracker.start_session() not implemented")
	return ""

## End tracking session
func end_session() -> void:
	push_error("IAnalyticsTracker.end_session() not implemented")

## Track an event
func track_event(event: AnalyticsEvent) -> void:
	push_error("IAnalyticsTracker.track_event() not implemented")

## Track simple event by name
func track(event_name: String, properties: Dictionary = {}) -> void:
	var event := AnalyticsEvent.new()
	event.event_type = EventType.CUSTOM
	event.event_name = event_name
	event.timestamp = Time.get_unix_time_from_system()
	event.properties = properties
	track_event(event)

## Record a metric
func record_metric(name: String, value: float, metric_type: MetricType = MetricType.GAUGE) -> void:
	push_error("IAnalyticsTracker.record_metric() not implemented")

## Increment a counter
func increment_counter(name: String, amount: int = 1) -> void:
	push_error("IAnalyticsTracker.increment_counter() not implemented")

## Start a timer
func start_timer(name: String) -> void:
	push_error("IAnalyticsTracker.start_timer() not implemented")

## Stop a timer and record duration
func stop_timer(name: String) -> float:
	push_error("IAnalyticsTracker.stop_timer() not implemented")
	return 0.0

## Set user property
func set_user_property(name: String, value: Variant) -> void:
	push_error("IAnalyticsTracker.set_user_property() not implemented")

## Get user property
func get_user_property(name: String) -> Variant:
	push_error("IAnalyticsTracker.get_user_property() not implemented")
	return null

## Flush pending events (send to backend)
func flush() -> void:
	push_error("IAnalyticsTracker.flush() not implemented")

## Check if analytics is enabled
func is_enabled() -> bool:
	push_error("IAnalyticsTracker.is_enabled() not implemented")
	return false

## Enable/disable analytics
func set_enabled(enabled: bool) -> void:
	push_error("IAnalyticsTracker.set_enabled() not implemented")

## Get session ID
func get_session_id() -> String:
	push_error("IAnalyticsTracker.get_session_id() not implemented")
	return ""

## Export analytics data
func export_data(format: String = "json") -> String:
	push_error("IAnalyticsTracker.export_data() not implemented")
	return ""
