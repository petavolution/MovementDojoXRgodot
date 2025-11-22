## SceneVariantSystem - Dynamic scene configuration using variant sets
## Implements USD-style variants and layers for flexible dojo layouts
class_name SceneVariantSystem
extends Node

signal variant_changed(variant_set: String, variant_name: String)
signal layer_activated(layer_name: String)
signal layer_deactivated(layer_name: String)
signal scene_rebuilt

## Variant set definition (like USD VariantSets)
class VariantSet:
	var name: String = ""
	var current_variant: String = ""
	var variants: Dictionary = {}  # variant_name -> VariantData
	var default_variant: String = ""


## Variant data - what changes when variant is selected
class VariantData:
	var name: String = ""
	var description: String = ""
	var nodes_to_show: Array[String] = []  # Node paths
	var nodes_to_hide: Array[String] = []
	var property_overrides: Dictionary = {}  # node_path -> {property: value}
	var spawn_prefabs: Array[Dictionary] = []  # {prefab, transform}
	var environment_preset: String = ""
	var audio_ambience: String = ""


## Layer definition (like USD Layers)
class SceneLayer:
	var name: String = ""
	var description: String = ""
	var priority: int = 0  # Higher = applied later
	var is_active: bool = false
	var nodes: Array[Node] = []
	var property_overrides: Dictionary = {}
	var is_additive: bool = true  # Add to scene vs replace


## Active state
var variant_sets: Dictionary = {}  # name -> VariantSet
var layers: Dictionary = {}  # name -> SceneLayer
var active_layers: Array[String] = []

## Scene root reference
var scene_root: Node3D

## Prefab cache
var prefab_cache: Dictionary = {}

## Spawned variant nodes (to clean up)
var spawned_nodes: Array[Node] = []


func _ready() -> void:
	_setup_default_variants()
	_setup_default_layers()


func setup(root: Node3D) -> void:
	scene_root = root


func _setup_default_variants() -> void:
	# Dojo Layout variant set
	var layout_set := VariantSet.new()
	layout_set.name = "DojoLayout"
	layout_set.default_variant = "standard"

	var standard := VariantData.new()
	standard.name = "standard"
	standard.description = "Standard training dojo"
	standard.environment_preset = "TRAINING_DOJO"
	layout_set.variants["standard"] = standard

	var advanced := VariantData.new()
	advanced.name = "advanced"
	advanced.description = "Advanced dojo with more obstacles"
	advanced.environment_preset = "NIGHT_TEMPLE"
	advanced.spawn_prefabs = [
		{"prefab": "res://prefabs/pillar.tscn", "position": Vector3(-2, 0, -3)},
		{"prefab": "res://prefabs/pillar.tscn", "position": Vector3(2, 0, -3)},
		{"prefab": "res://prefabs/pillar.tscn", "position": Vector3(0, 0, -5)}
	]
	layout_set.variants["advanced"] = advanced

	var meditation := VariantData.new()
	meditation.name = "meditation"
	meditation.description = "Peaceful meditation space"
	meditation.environment_preset = "SUNRISE_GARDEN"
	meditation.audio_ambience = "ambient_nature"
	layout_set.variants["meditation"] = meditation

	var combat := VariantData.new()
	combat.name = "combat"
	combat.description = "Combat arena configuration"
	combat.environment_preset = "VOID_SPACE"
	combat.spawn_prefabs = [
		{"prefab": "res://prefabs/arena_barrier.tscn", "position": Vector3(0, 0, 0)}
	]
	layout_set.variants["combat"] = combat

	layout_set.current_variant = "standard"
	variant_sets["DojoLayout"] = layout_set

	# Difficulty variant set
	var difficulty_set := VariantSet.new()
	difficulty_set.name = "Difficulty"
	difficulty_set.default_variant = "normal"

	var easy := VariantData.new()
	easy.name = "easy"
	easy.description = "Larger targets, slower spawns"
	easy.property_overrides = {
		"/root/Main/TargetSpawner": {"target_scale": 1.3, "spawn_interval": 2.0}
	}
	difficulty_set.variants["easy"] = easy

	var normal := VariantData.new()
	normal.name = "normal"
	normal.description = "Standard difficulty"
	difficulty_set.variants["normal"] = normal

	var hard := VariantData.new()
	hard.name = "hard"
	hard.description = "Smaller targets, faster spawns"
	hard.property_overrides = {
		"/root/Main/TargetSpawner": {"target_scale": 0.8, "spawn_interval": 0.8}
	}
	difficulty_set.variants["hard"] = hard

	difficulty_set.current_variant = "normal"
	variant_sets["Difficulty"] = difficulty_set

	# Time of Day variant set
	var time_set := VariantSet.new()
	time_set.name = "TimeOfDay"
	time_set.default_variant = "day"

	var day := VariantData.new()
	day.name = "day"
	day.environment_preset = "FOREST_CLEARING"
	time_set.variants["day"] = day

	var sunset := VariantData.new()
	sunset.name = "sunset"
	sunset.environment_preset = "SUNSET_BEACH"
	time_set.variants["sunset"] = sunset

	var night := VariantData.new()
	night.name = "night"
	night.environment_preset = "STARFIELD"
	time_set.variants["night"] = night

	time_set.current_variant = "day"
	variant_sets["TimeOfDay"] = time_set


func _setup_default_layers() -> void:
	# Training guides layer
	var guides := SceneLayer.new()
	guides.name = "TrainingGuides"
	guides.description = "Visual guides for training exercises"
	guides.priority = 10
	guides.is_additive = true
	layers["TrainingGuides"] = guides

	# Hazard zones layer
	var hazards := SceneLayer.new()
	hazards.name = "HazardZones"
	hazards.description = "Danger zones and obstacles"
	hazards.priority = 20
	hazards.is_additive = true
	layers["HazardZones"] = hazards

	# Decoration layer
	var decor := SceneLayer.new()
	decor.name = "Decorations"
	decor.description = "Visual decorations and props"
	decor.priority = 5
	decor.is_additive = true
	layers["Decorations"] = decor

	# Debug visualization layer
	var debug := SceneLayer.new()
	debug.name = "DebugVisualization"
	debug.description = "Debug helpers and visualizations"
	debug.priority = 100
	debug.is_additive = true
	layers["DebugVisualization"] = debug


## Variant selection
func select_variant(variant_set_name: String, variant_name: String) -> bool:
	if not variant_sets.has(variant_set_name):
		push_error("Unknown variant set: " + variant_set_name)
		return false

	var vs: VariantSet = variant_sets[variant_set_name]

	if not vs.variants.has(variant_name):
		push_error("Unknown variant: " + variant_name + " in set " + variant_set_name)
		return false

	var old_variant := vs.current_variant
	vs.current_variant = variant_name

	_apply_variant(vs, vs.variants[variant_name])
	variant_changed.emit(variant_set_name, variant_name)

	return true


func _apply_variant(vs: VariantSet, variant: VariantData) -> void:
	# Clear previously spawned nodes for this variant set
	_clear_spawned_nodes()

	# Apply node visibility
	for path in variant.nodes_to_show:
		var node := get_node_or_null(path)
		if node:
			node.visible = true

	for path in variant.nodes_to_hide:
		var node := get_node_or_null(path)
		if node:
			node.visible = false

	# Apply property overrides
	for node_path in variant.property_overrides:
		var node := get_node_or_null(node_path)
		if node:
			var overrides: Dictionary = variant.property_overrides[node_path]
			for property in overrides:
				if property in node:
					node.set(property, overrides[property])

	# Spawn prefabs
	for spawn_data in variant.spawn_prefabs:
		_spawn_prefab(spawn_data)

	# Apply environment preset
	if variant.environment_preset != "":
		_apply_environment(variant.environment_preset)

	# Set audio ambience
	if variant.audio_ambience != "":
		_set_ambience(variant.audio_ambience)


func _spawn_prefab(spawn_data: Dictionary) -> void:
	var prefab_path: String = spawn_data.get("prefab", "")
	if prefab_path == "":
		return

	var prefab: PackedScene = _load_prefab(prefab_path)
	if prefab == null:
		return

	var instance := prefab.instantiate()
	if instance is Node3D:
		instance.position = spawn_data.get("position", Vector3.ZERO)
		instance.rotation = spawn_data.get("rotation", Vector3.ZERO)
		instance.scale = spawn_data.get("scale", Vector3.ONE)

	if scene_root:
		scene_root.add_child(instance)
	else:
		add_child(instance)

	spawned_nodes.append(instance)


func _load_prefab(path: String) -> PackedScene:
	if prefab_cache.has(path):
		return prefab_cache[path]

	if ResourceLoader.exists(path):
		var prefab := load(path) as PackedScene
		prefab_cache[path] = prefab
		return prefab

	return null


func _clear_spawned_nodes() -> void:
	for node in spawned_nodes:
		if is_instance_valid(node):
			node.queue_free()
	spawned_nodes.clear()


func _apply_environment(preset_name: String) -> void:
	var env_manager := get_node_or_null("/root/EnvironmentManager")
	if env_manager and env_manager.has_method("apply_environment"):
		# Convert string to enum
		var preset := 0
		match preset_name:
			"TRAINING_DOJO": preset = 0
			"NIGHT_TEMPLE": preset = 1
			"FOREST_CLEARING": preset = 2
			"MOUNTAIN_PEAK": preset = 3
			"VOID_SPACE": preset = 4
			"SUNRISE_GARDEN": preset = 5
			"SUNSET_BEACH": preset = 6
			"STARFIELD": preset = 7

		env_manager.apply_environment(preset)


func _set_ambience(ambience_name: String) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_ambience"):
		audio_manager.play_ambience(ambience_name)


## Layer management
func activate_layer(layer_name: String) -> bool:
	if not layers.has(layer_name):
		push_error("Unknown layer: " + layer_name)
		return false

	var layer: SceneLayer = layers[layer_name]
	if layer.is_active:
		return true

	layer.is_active = true
	active_layers.append(layer_name)

	# Sort by priority
	active_layers.sort_custom(func(a, b): return layers[a].priority < layers[b].priority)

	_apply_layer(layer)
	layer_activated.emit(layer_name)

	return true


func deactivate_layer(layer_name: String) -> bool:
	if not layers.has(layer_name):
		return false

	var layer: SceneLayer = layers[layer_name]
	if not layer.is_active:
		return true

	layer.is_active = false
	active_layers.erase(layer_name)

	_remove_layer(layer)
	layer_deactivated.emit(layer_name)

	return true


func _apply_layer(layer: SceneLayer) -> void:
	# Show layer nodes
	for node in layer.nodes:
		if is_instance_valid(node):
			node.visible = true

	# Apply property overrides
	for node_path in layer.property_overrides:
		var node := get_node_or_null(node_path)
		if node:
			var overrides: Dictionary = layer.property_overrides[node_path]
			for property in overrides:
				if property in node:
					node.set(property, overrides[property])


func _remove_layer(layer: SceneLayer) -> void:
	# Hide layer nodes
	for node in layer.nodes:
		if is_instance_valid(node):
			node.visible = false


## Add nodes to a layer
func add_node_to_layer(layer_name: String, node: Node) -> void:
	if not layers.has(layer_name):
		return

	var layer: SceneLayer = layers[layer_name]
	if node not in layer.nodes:
		layer.nodes.append(node)

	if layer.is_active:
		node.visible = true


func remove_node_from_layer(layer_name: String, node: Node) -> void:
	if not layers.has(layer_name):
		return

	var layer: SceneLayer = layers[layer_name]
	layer.nodes.erase(node)


## Query functions
func get_current_variant(variant_set_name: String) -> String:
	if not variant_sets.has(variant_set_name):
		return ""
	return variant_sets[variant_set_name].current_variant


func get_variant_options(variant_set_name: String) -> Array[String]:
	var options: Array[String] = []
	if variant_sets.has(variant_set_name):
		for key in variant_sets[variant_set_name].variants:
			options.append(key)
	return options


func get_variant_sets() -> Array[String]:
	var sets: Array[String] = []
	for key in variant_sets:
		sets.append(key)
	return sets


func is_layer_active(layer_name: String) -> bool:
	if not layers.has(layer_name):
		return false
	return layers[layer_name].is_active


func get_active_layers() -> Array[String]:
	return active_layers.duplicate()


func get_all_layers() -> Array[String]:
	var all: Array[String] = []
	for key in layers:
		all.append(key)
	return all


## Save/Load current configuration
func get_configuration() -> Dictionary:
	var config := {
		"variants": {},
		"active_layers": active_layers.duplicate()
	}

	for vs_name in variant_sets:
		config.variants[vs_name] = variant_sets[vs_name].current_variant

	return config


func apply_configuration(config: Dictionary) -> void:
	# Deactivate all layers
	for layer_name in active_layers.duplicate():
		deactivate_layer(layer_name)

	# Apply variants
	var variants: Dictionary = config.get("variants", {})
	for vs_name in variants:
		select_variant(vs_name, variants[vs_name])

	# Activate layers
	var layer_list: Array = config.get("active_layers", [])
	for layer_name in layer_list:
		activate_layer(layer_name)

	scene_rebuilt.emit()


## Convenience methods for common configurations
func set_training_mode() -> void:
	select_variant("DojoLayout", "standard")
	select_variant("Difficulty", "normal")
	activate_layer("TrainingGuides")


func set_combat_mode() -> void:
	select_variant("DojoLayout", "combat")
	select_variant("Difficulty", "hard")
	deactivate_layer("TrainingGuides")


func set_meditation_mode() -> void:
	select_variant("DojoLayout", "meditation")
	select_variant("TimeOfDay", "sunset")
	deactivate_layer("TrainingGuides")
	deactivate_layer("HazardZones")
