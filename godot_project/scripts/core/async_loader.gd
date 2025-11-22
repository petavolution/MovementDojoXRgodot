## AsyncLoader - Background resource loading and scene preparation
## Keeps main thread lean for smooth VR frame timing
class_name AsyncLoader
extends Node

signal resource_loaded(path: String, resource: Resource)
signal resource_failed(path: String, error: String)
signal scene_prepared(path: String, instance: Node)
signal loading_progress(path: String, progress: float)
signal batch_completed(batch_id: String, results: Dictionary)
signal queue_empty

## Load request structure
class LoadRequest:
	var path: String = ""
	var type_hint: String = ""
	var use_sub_threads: bool = true
	var cache_mode: ResourceLoader.CacheMode = ResourceLoader.CACHE_MODE_REUSE
	var priority: int = 0
	var callback: Callable
	var batch_id: String = ""
	var started: bool = false
	var progress: float = 0.0

## Configuration
@export var max_concurrent_loads: int = 4
@export var poll_interval: float = 0.016  # ~60Hz
@export var enable_caching: bool = true
@export var preload_on_startup: bool = false

## Queue state
var load_queue: Array[LoadRequest] = []
var active_loads: Dictionary = {}  # path -> LoadRequest
var resource_cache: Dictionary = {}  # path -> Resource
var batch_progress: Dictionary = {}  # batch_id -> {total, completed, results}

## Thread pool for heavy operations
var thread_pool: Array[Thread] = []
var pending_callbacks: Array[Callable] = []

## Stats
var total_loaded: int = 0
var total_failed: int = 0
var total_cached_hits: int = 0


func _ready() -> void:
	set_process(true)

	if preload_on_startup:
		_preload_common_resources()


func _process(_delta: float) -> void:
	_poll_active_loads()
	_start_queued_loads()
	_execute_pending_callbacks()


## Queue a resource for loading
func load_resource(path: String, type_hint: String = "", callback: Callable = Callable(), priority: int = 0) -> void:
	# Check cache first
	if enable_caching and resource_cache.has(path):
		total_cached_hits += 1
		var resource: Resource = resource_cache[path]
		resource_loaded.emit(path, resource)
		if callback.is_valid():
			callback.call(resource)
		return

	# Check if already loading
	if active_loads.has(path):
		return

	# Check if already queued
	for request in load_queue:
		if request.path == path:
			return

	# Create load request
	var request := LoadRequest.new()
	request.path = path
	request.type_hint = type_hint
	request.callback = callback
	request.priority = priority

	# Insert sorted by priority
	var inserted := false
	for i in range(load_queue.size()):
		if load_queue[i].priority < priority:
			load_queue.insert(i, request)
			inserted = true
			break

	if not inserted:
		load_queue.append(request)


## Queue multiple resources as a batch
func load_batch(paths: Array[String], batch_id: String, callback: Callable = Callable()) -> void:
	if paths.is_empty():
		if callback.is_valid():
			callback.call({})
		batch_completed.emit(batch_id, {})
		return

	# Initialize batch tracking
	batch_progress[batch_id] = {
		"total": paths.size(),
		"completed": 0,
		"results": {},
		"callback": callback
	}

	# Queue all resources
	for path in paths:
		var request := LoadRequest.new()
		request.path = path
		request.batch_id = batch_id
		load_queue.append(request)


## Load and instantiate a scene
func load_scene(path: String, callback: Callable = Callable()) -> void:
	load_resource(path, "PackedScene", func(resource: Resource) -> void:
		if resource is PackedScene:
			var instance := (resource as PackedScene).instantiate()
			scene_prepared.emit(path, instance)
			if callback.is_valid():
				callback.call(instance)
		else:
			resource_failed.emit(path, "Resource is not a PackedScene")
	)


## Load scene in background and add to parent
func load_and_add_scene(path: String, parent: Node, callback: Callable = Callable()) -> void:
	load_scene(path, func(instance: Node) -> void:
		if parent and is_instance_valid(parent):
			parent.add_child(instance)
		if callback.is_valid():
			callback.call(instance)
	)


func _start_queued_loads() -> void:
	while load_queue.size() > 0 and active_loads.size() < max_concurrent_loads:
		var request := load_queue.pop_front() as LoadRequest

		# Start background loading
		var error := ResourceLoader.load_threaded_request(
			request.path,
			request.type_hint,
			request.use_sub_threads,
			request.cache_mode
		)

		if error == OK:
			request.started = true
			active_loads[request.path] = request
		else:
			total_failed += 1
			resource_failed.emit(request.path, "Failed to start loading: %d" % error)
			_update_batch_progress(request.batch_id, request.path, null, false)


func _poll_active_loads() -> void:
	var completed_paths: Array[String] = []

	for path in active_loads:
		var request: LoadRequest = active_loads[path]

		var progress_array: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progress_array)

		if progress_array.size() > 0:
			request.progress = progress_array[0]
			loading_progress.emit(path, request.progress)

		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				var resource := ResourceLoader.load_threaded_get(path)
				completed_paths.append(path)
				total_loaded += 1

				# Cache the resource
				if enable_caching:
					resource_cache[path] = resource

				# Queue callback for main thread execution
				if request.callback.is_valid():
					pending_callbacks.append(func() -> void: request.callback.call(resource))

				resource_loaded.emit(path, resource)
				_update_batch_progress(request.batch_id, path, resource, true)

			ResourceLoader.THREAD_LOAD_FAILED:
				completed_paths.append(path)
				total_failed += 1
				resource_failed.emit(path, "Loading failed")
				_update_batch_progress(request.batch_id, path, null, false)

			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				completed_paths.append(path)
				total_failed += 1
				resource_failed.emit(path, "Invalid resource")
				_update_batch_progress(request.batch_id, path, null, false)

	# Remove completed loads
	for path in completed_paths:
		active_loads.erase(path)

	# Check if queue is empty
	if load_queue.is_empty() and active_loads.is_empty():
		queue_empty.emit()


func _update_batch_progress(batch_id: String, path: String, resource: Resource, success: bool) -> void:
	if batch_id.is_empty() or not batch_progress.has(batch_id):
		return

	var batch: Dictionary = batch_progress[batch_id]
	batch.completed += 1

	if success and resource:
		batch.results[path] = resource

	# Check if batch is complete
	if batch.completed >= batch.total:
		var callback: Callable = batch.callback
		var results: Dictionary = batch.results

		batch_completed.emit(batch_id, results)

		if callback.is_valid():
			pending_callbacks.append(func() -> void: callback.call(results))

		batch_progress.erase(batch_id)


func _execute_pending_callbacks() -> void:
	# Execute limited number of callbacks per frame to avoid blocking
	var max_callbacks := 5
	var executed := 0

	while pending_callbacks.size() > 0 and executed < max_callbacks:
		var callback := pending_callbacks.pop_front() as Callable
		if callback.is_valid():
			callback.call()
		executed += 1


func _preload_common_resources() -> void:
	# Preload commonly used resources
	var common_paths: Array[String] = [
		"res://scenes/effects/hit_particles.tscn",
		"res://scenes/effects/slash_trail.tscn",
		"res://audio/sfx/saber_hum.wav",
		"res://audio/sfx/hit_impact.wav"
	]

	load_batch(common_paths, "preload", func(_results: Dictionary) -> void:
		print("[AsyncLoader] Preload complete")
	)


## Get resource from cache (synchronous)
func get_cached(path: String) -> Resource:
	return resource_cache.get(path)


## Check if resource is cached
func is_cached(path: String) -> bool:
	return resource_cache.has(path)


## Check if resource is currently loading
func is_loading(path: String) -> bool:
	return active_loads.has(path) or load_queue.any(func(r: LoadRequest) -> bool: return r.path == path)


## Clear resource cache
func clear_cache() -> void:
	resource_cache.clear()


## Remove specific resource from cache
func uncache(path: String) -> void:
	resource_cache.erase(path)


## Cancel loading for a path
func cancel_load(path: String) -> void:
	# Remove from queue
	for i in range(load_queue.size() - 1, -1, -1):
		if load_queue[i].path == path:
			load_queue.remove_at(i)
			break

	# Note: Cannot cancel active ResourceLoader.load_threaded_request


## Get loading progress for a path
func get_progress(path: String) -> float:
	if active_loads.has(path):
		return active_loads[path].progress
	if is_cached(path):
		return 1.0
	return 0.0


## Get overall queue progress
func get_queue_progress() -> float:
	var total := load_queue.size() + active_loads.size()
	if total == 0:
		return 1.0

	var progress := 0.0
	for request in active_loads.values():
		progress += request.progress

	return progress / total


## Get loader statistics
func get_stats() -> Dictionary:
	return {
		"queue_size": load_queue.size(),
		"active_loads": active_loads.size(),
		"cached_resources": resource_cache.size(),
		"total_loaded": total_loaded,
		"total_failed": total_failed,
		"cache_hits": total_cached_hits,
		"pending_batches": batch_progress.size()
	}


## Warmup cache with paths
func warmup_cache(paths: Array[String]) -> void:
	for path in paths:
		if not is_cached(path) and not is_loading(path):
			load_resource(path)
