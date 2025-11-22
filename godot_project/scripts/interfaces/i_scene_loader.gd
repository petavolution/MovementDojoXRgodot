## ISceneLoader - Interface for scene/environment loaders
## Supports USD-like composition and variant systems
class_name ISceneLoader
extends RefCounted

## Scene load status
enum LoadStatus {
	NOT_LOADED,
	LOADING,
	LOADED,
	FAILED
}

## Scene metadata
class SceneMetadata:
	var scene_id: String = ""
	var display_name: String = ""
	var description: String = ""
	var preview_image: String = ""
	var variant_sets: Dictionary = {}  # name -> Array[String] of variants
	var layers: Array[String] = []
	var required_assets: Array[String] = []
	var estimated_load_time: float = 0.0

## Layer visibility data
class LayerState:
	var layer_name: String = ""
	var is_visible: bool = true
	var opacity: float = 1.0

## Interface methods

## Get list of available scenes
func get_available_scenes() -> Array[SceneMetadata]:
	push_error("ISceneLoader.get_available_scenes() not implemented")
	return []

## Load a scene by ID
func load_scene(scene_id: String) -> bool:
	push_error("ISceneLoader.load_scene() not implemented")
	return false

## Load scene asynchronously
func load_scene_async(scene_id: String, callback: Callable) -> void:
	push_error("ISceneLoader.load_scene_async() not implemented")

## Get current load status
func get_load_status() -> LoadStatus:
	push_error("ISceneLoader.get_load_status() not implemented")
	return LoadStatus.NOT_LOADED

## Get load progress (0.0 to 1.0)
func get_load_progress() -> float:
	push_error("ISceneLoader.get_load_progress() not implemented")
	return 0.0

## Unload current scene
func unload_scene() -> void:
	push_error("ISceneLoader.unload_scene() not implemented")

## Get currently loaded scene root
func get_scene_root() -> Node3D:
	push_error("ISceneLoader.get_scene_root() not implemented")
	return null

## Set variant for a variant set
func set_variant(variant_set: String, variant: String) -> bool:
	push_error("ISceneLoader.set_variant() not implemented")
	return false

## Get current variant for a variant set
func get_variant(variant_set: String) -> String:
	push_error("ISceneLoader.get_variant() not implemented")
	return ""

## Get all variant sets and their options
func get_variant_sets() -> Dictionary:
	push_error("ISceneLoader.get_variant_sets() not implemented")
	return {}

## Set layer visibility
func set_layer_visible(layer_name: String, visible: bool) -> void:
	push_error("ISceneLoader.set_layer_visible() not implemented")

## Get layer visibility state
func get_layer_state(layer_name: String) -> LayerState:
	push_error("ISceneLoader.get_layer_state() not implemented")
	return LayerState.new()

## Get all layers
func get_layers() -> Array[String]:
	push_error("ISceneLoader.get_layers() not implemented")
	return []

## Apply overlay layer
func apply_overlay(overlay_path: String) -> bool:
	push_error("ISceneLoader.apply_overlay() not implemented")
	return false

## Remove overlay layer
func remove_overlay(overlay_path: String) -> void:
	push_error("ISceneLoader.remove_overlay() not implemented")

## Validate scene (check for missing references, etc.)
func validate_scene(scene_id: String) -> Dictionary:
	# Returns {valid: bool, errors: Array[String], warnings: Array[String]}
	push_error("ISceneLoader.validate_scene() not implemented")
	return {"valid": false, "errors": [], "warnings": []}
