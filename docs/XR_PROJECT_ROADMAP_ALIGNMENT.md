# Movement Dojo XR - Project Roadmap Alignment Analysis

## Executive Summary

This document analyzes how the Movement Dojo XR project can benefit from adopting the open-source XR development framework outlined in the 4-stage roadmap. The analysis reveals that **~75-80% of core systems are already implemented**, positioning the project well ahead of Stage 1-2 requirements, while key opportunities exist in Stage 3-4 areas: **USD asset pipeline integration, data-driven content systems, and developer tooling**.

### Project Maturity by Stage

| Stage | Target | Current Status | Completion |
|-------|--------|----------------|------------|
| Stage 1 | OpenXR Handshake & glTF/USD Skeleton | **Largely Complete** | 85% |
| Stage 2 | Lightsaber Loop & glTF Dojo | **Complete** | 95% |
| Stage 3 | Proprioception, USD-Driven Metadata & Fidelity | **Partial** | 60% |
| Stage 4 | Tooling, Modding & Extensible Framework | **Incomplete** | 25% |

---

## Stage 1 Analysis: OpenXR Handshake & glTF/USD Skeleton

### Stage 1 Motto
> "Prove the XR pipeline and external assets actually talk to each other."

### What's Already Implemented

#### OpenXR Integration (100% Complete)
The project has a comprehensive OpenXR implementation exceeding Stage 1 requirements:

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| OpenXR session lifecycle | ✅ | `XRSessionManager` handles READY → SYNCHRONIZED → VISIBLE → FOCUSED |
| Frame loop | ✅ | Godot's OpenXR plugin manages xrWaitFrame/xrBeginFrame/xrEndFrame |
| HMD pose & view transforms | ✅ | XRCamera3D with proper stereo rendering |
| Controller tracking | ✅ | XRController3D nodes with action bindings |
| Action sets & bindings | ✅ | `openxr_action_map.tres` resource configured |
| Controller visualization | ✅ | Lightsaber models attached to controllers |

**Key Files:**
- `godot_project/scripts/core/xr_session_manager.gd` - Full XR abstraction layer
- `godot_project/scripts/core/xr_input_manager.gd` - Input handling
- `godot_project/project.godot` - OpenXR configuration

#### glTF Support (70% Complete)
Godot 4.x has built-in glTF 2.0 support, but the project lacks explicit configuration:

| Requirement | Status | Notes |
|-------------|--------|-------|
| glTF import capability | ✅ | Godot built-in |
| PBR material mapping | ✅ | Automatic via Godot |
| Test mesh rendering | ⚠️ | No explicit test assets |
| Asset pipeline documentation | ❌ | Not documented |

#### USD Support (0% Complete - Major Gap)
This is the **primary opportunity for Stage 1 enhancement**:

| Requirement | Status | Notes |
|-------------|--------|-------|
| OpenUSD library integration | ❌ | Not implemented |
| UsdStage::Open capability | ❌ | No USD loading |
| Prim traversal | ❌ | N/A |
| USD → engine geometry mapping | ❌ | N/A |

### Stage 1 Benefit Opportunities

#### 1. Add USD Asset Pipeline (High Priority)
**Why**: USD provides canonical scene description with variants, layers, and metadata - ideal for training scenarios.

**Implementation Options:**

**Option A: GDExtension USD Importer**
```
Benefits:
- Native USD reading in Godot
- Access to USD variants, metadata, schemas
- Scene composition from multiple USD files

Complexity: High (requires building USD C++ libs as GDExtension)
```

**Option B: USD → glTF Conversion Pipeline**
```
Benefits:
- Simpler integration (use existing glTF pipeline)
- Leverage open-source converters (usd2gltf)
- Keep USD as authoring format, glTF as runtime

Complexity: Medium (external tooling + import scripts)
```

**Option C: USD Metadata-Only (Recommended Start)**
```
Benefits:
- Parse USD for metadata (training configs, spawn points)
- Use glTF for geometry
- Incremental adoption path

Complexity: Low-Medium (Python/GDScript USD parsing)
```

**Recommended Action:**
```gdscript
# Add USD metadata loader for training configuration
# Path: godot_project/scripts/core/usd_metadata_loader.gd

class_name USDMetadataLoader
extends RefCounted

# Parse USD for training-relevant metadata
# - Spawn point locations (/World/Dojo/SpawnPoints/*)
# - Path definitions (/World/Dojo/Paths/*)
# - Posture targets (/World/Dojo/Guides/*)
# - Variant selections

func load_training_metadata(usd_path: String) -> Dictionary:
    # Implementation using usda text parsing or Pixar USD via GDExtension
    pass
```

#### 2. Formalize Asset Pipeline Documentation
Create `docs/ASSET_PIPELINE.md` defining:
- Blender → glTF export settings
- Naming conventions
- Material requirements
- LOD specifications
- USD authoring guidelines

#### 3. Add glTF Test Suite
Create validation assets to verify pipeline:
- `assets/test/cube_pbr.glb` - Basic PBR material test
- `assets/test/skeleton_test.glb` - Animation test
- `assets/test/morph_test.glb` - Blend shape test

### Stage 1 Gap Summary

| Gap | Priority | Effort | Impact |
|-----|----------|--------|--------|
| USD integration | HIGH | Medium | Enables Stage 3-4 features |
| Asset pipeline docs | MEDIUM | Low | Developer onboarding |
| glTF test suite | LOW | Low | Quality assurance |

---

## Stage 2 Analysis: Lightsaber Loop & glTF Dojo

### Stage 2 Motto
> "Swing the saber, hit something, and feel it."

### What's Already Implemented (95% Complete)

The project **exceeds Stage 2 requirements** with a sophisticated combat and training system:

#### Environment & Assets

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Dojo environment | ✅ | `DojoEnvironment` node in main scene |
| Scene management | ✅ | `SceneVariantManager` for environment variants |
| Environment loading | ✅ | `EnvironmentManager` handles transitions |

**Key Files:**
- `godot_project/scripts/dojo_environment.gd`
- `godot_project/scripts/environment/scene_variant_manager.gd`
- `godot_project/scripts/environment/environment_manager.gd`

#### Lightsaber Mechanics (100% Complete)

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Handle attached to controller | ✅ | XRController3D child node |
| Blade visual mesh | ✅ | Emissive material + glow shader |
| Physics collider | ✅ | Swept collision detection |
| Activation/deactivation | ✅ | State machine with audio/haptics |
| Velocity-based damage | ✅ | 1-8 m/s linear interpolation |

**Key Files:**
- `godot_project/scripts/combat/lightsaber.gd` - Full implementation
- `godot_project/scripts/combat/blade_collision_system.gd` - Physics
- `godot_project/shaders/blade_glow.gdshader` - Visual effects

#### Physics System (100% Complete)

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Open-source physics | ✅ | Godot 4.x integrated physics |
| Static environment bodies | ✅ | `PhysicsManager` layer setup |
| Kinematic weapon body | ✅ | Controller-driven saber |
| Dynamic rigidbody targets | ✅ | Training targets with physics |
| Collision callbacks | ✅ | Signal-based hit detection |

**Key Files:**
- `godot_project/scripts/core/physics_manager.gd`

#### Haptics System (100% Complete - Exceeds Requirements)

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Haptic actions | ✅ | OpenXR haptic action bindings |
| Saber ignition feedback | ✅ | SABER_ON pattern |
| Target hit feedback | ✅ | BLADE_HIT pattern |
| Environment collision | ✅ | BLADE_CLASH pattern |
| Advanced patterns | ✅ | 18+ predefined patterns |

**Key Files:**
- `godot_project/scripts/core/haptic_patterns.gd` - Comprehensive pattern library

#### Training Module System (100% Complete - Exceeds Requirements)

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| "Hit N Targets" module | ✅ | Multiple training modes |
| Target spawning | ✅ | Wave-based with difficulty |
| Collision detection | ✅ | Per-target tracking |
| Sound effects | ✅ | Full audio system |
| Performance metrics | ✅ | Accuracy, timing, combos |

**Beyond Stage 2:**
- 11 distinct training modes (vs. 1 required)
- Adaptive difficulty system
- Combo detection and scoring
- Movement coverage tracking
- Calorie estimation

**Key Files:**
- `godot_project/scripts/training/training_mode_manager.gd`
- `godot_project/scripts/combat/target_spawner.gd`
- `godot_project/scripts/combat/training_target.gd`

### Stage 2 Architecture (100% Complete)

| Component | Status | Implementation |
|-----------|--------|----------------|
| SceneManager | ✅ | Main VR script + Environment Manager |
| PhysicsSystem | ✅ | PhysicsManager singleton |
| InteractionSystem | ✅ | XR Input Manager |
| HapticsManager | ✅ | HapticPatterns class |
| TrainingModuleBase | ✅ | ITrainingModule interface |
| TrainingModule_HitTargets | ✅ | Multiple implementations |

### Stage 2 Benefit Opportunities

#### 1. Formalize glTF Dojo Asset Workflow
While the dojo exists, there's opportunity to:
- Document the Blender → Godot workflow
- Create modular dojo components as glTF assets
- Enable community-created environments

#### 2. Add Combat Replay Recording
Leverage existing `ReplaySystem` for:
- Recording impressive combat sequences
- Sharing via exported files
- Learning from recorded sessions

#### 3. Enhance Target Variety
Current targets are basic spheres/cubes. Opportunity for:
- glTF-based target models
- Animated targets
- Destructible target parts

### Stage 2 Gap Summary

| Gap | Priority | Effort | Impact |
|-----|----------|--------|--------|
| glTF dojo workflow docs | LOW | Low | Community content |
| Combat replay polish | LOW | Medium | User engagement |
| Target variety | LOW | Medium | Visual polish |

---

## Stage 3 Analysis: Proprioception, USD-Driven Metadata & Fidelity

### Stage 3 Motto
> "Turn a toy into a proprioception trainer."

### What's Already Implemented

#### Visual Fidelity (70% Complete)

| Requirement | Status | Notes |
|-------------|--------|-------|
| PBR materials | ✅ | Standard Godot PBR pipeline |
| Saber bloom/glow | ✅ | Custom shader implementation |
| Trail effects | ✅ | MovementTrail visualization |
| Mixed lighting | ⚠️ | Basic setup, room for enhancement |
| LOD system | ❌ | Not implemented |
| Reflection probes | ⚠️ | Minimal setup |

**Key Files:**
- `godot_project/shaders/blade_glow.gdshader`
- `godot_project/scripts/visualization/movement_trail.gd`

#### Proprioception Training (95% Complete - Major Strength)

This is where the project **shines**:

| Module | Status | Implementation |
|--------|--------|----------------|
| Posture/Angle Holding | ✅ | `ProprioceptionSystem` with pose detection |
| Ghost saber visualization | ✅ | Target posture display |
| Tolerance checking | ✅ | Position ±0.1m, Rotation ±15° |
| Hold duration | ✅ | 2-5 second configurable |
| Visual feedback | ✅ | Alignment indicators |
| Haptic guidance | ✅ | Deviation pulses |
| Scoring | ✅ | 0-100% accuracy |

| Module | Status | Implementation |
|--------|--------|----------------|
| Path Following | ✅ | `PathFollowing` system |
| 3D path visualization | ✅ | Curve-based paths |
| Deviation tracking | ✅ | Real-time feedback |
| Speed constraints | ✅ | Timing validation |
| Color feedback | ✅ | Path segment coloring |

| Module | Status | Implementation |
|--------|--------|----------------|
| Blocking/Deflection | ✅ | `TrainingModeManager.DEFLECTION_TRAINING` |
| Projectile spawning | ✅ | `ProjectileLauncher` system |
| Deflection detection | ✅ | Collision-based |
| Haptic impact | ✅ | DEFLECTION pattern |
| Scoring | ✅ | Timing and angle tracking |

**Additional Proprioception Features (Beyond Requirements):**
- **Kata System**: Choreographed sequences with step types
- **Pose Detection**: Yoga, Qi Gong, Meditation poses
- **Movement Classification**: 10+ movement types detected
- **Symmetry Scoring**: Left/right balance analysis
- **Space Mapping**: 3D grid tracking of explored zones

**Key Files:**
- `godot_project/scripts/proprioception/proprioception_system.gd`
- `godot_project/scripts/proprioception/kata_system.gd`
- `godot_project/scripts/proprioception/path_following.gd`

#### USD as Canonical Scene (0% Complete - Major Gap)

This is the **key Stage 3 opportunity**:

| Requirement | Status | Notes |
|-------------|--------|-------|
| USD environment definition | ❌ | Not implemented |
| Semantic prim roles | ❌ | No USD schema |
| Training zone markup | ❌ | Hardcoded in scripts |
| Spawn point definitions | ❌ | Code-based |
| Path definitions | ❌ | Script-defined |
| Custom USD schemas | ❌ | N/A |

#### Haptics & Feedback (100% Complete)

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Multiple haptic profiles | ✅ | 18+ patterns defined |
| Guidance pulses | ✅ | Low-intensity feedback |
| Strong impacts | ✅ | Collision feedback |
| Continuous rumble | ✅ | Saber hum effect |
| Audio layering | ✅ | AudioManager system |
| Alignment sounds | ✅ | Achievement audio cues |

#### Performance & Profiling (40% Complete)

| Requirement | Status | Notes |
|-------------|--------|-------|
| 90 Hz frame rate | ✅ | Physics configured for 90 Hz |
| Graphics quality settings | ⚠️ | Basic options exist |
| LOD implementation | ❌ | Not implemented |
| Collision shape optimization | ✅ | Simplified proxies used |
| Profiling tools | ❌ | No built-in profiler |

### Stage 3 Benefit Opportunities

#### 1. USD Training Definition Schema (High Priority)

Create a standardized USD schema for training content:

```python
# Proposed USD Schema: TrainingExercise.usda

def "World" {
    def Xform "Dojo" {
        def Xform "TrainingZones" {
            def "PostureZone_01" (
                customData = {
                    string exerciseType = "posture"
                    string difficulty = "beginner"
                    float holdDuration = 3.0
                    float positionTolerance = 0.1
                    float rotationTolerance = 15.0
                }
            ) {
                # Target pose definition
                double3 xformOp:translate = (0, 1.4, -1)
                float3 xformOp:rotateXYZ = (0, 0, 0)
            }
        }

        def Xform "Paths" {
            def BasisCurves "DeflectionArc" (
                customData = {
                    string exerciseType = "path"
                    float targetSpeed = 0.5
                    float corridorWidth = 0.1
                }
            ) {
                int[] curveVertexCounts = [10]
                point3f[] points = [...]
            }
        }

        def Xform "SpawnPoints" {
            def Xform "TargetSpawn_01" (
                customData = {
                    string spawnType = "target"
                    float spawnRate = 2.0
                    int waveSize = 5
                }
            ) {
                double3 xformOp:translate = (0, 1.2, -3)
            }
        }
    }
}
```

**Benefits:**
- Training content becomes data-driven
- Non-programmers can create exercises
- Consistent structure across modules
- Version control for training definitions

#### 2. USD Variant Sets for Content Management

```python
# Environment variants via USD VariantSets

def "World" {
    def Xform "Dojo" (
        variants = {
            string layout = "beginner"
        }
        prepend variantSets = "layout"
    ) {
        variantSet "layout" = {
            "beginner" {
                # Simple layout with few spawn points
            }
            "intermediate" {
                # More complex with multiple zones
            }
            "advanced" {
                # Full complexity
            }
        }
    }
}
```

#### 3. Performance Optimization System

```gdscript
# Proposed: godot_project/scripts/core/performance_manager.gd

class_name PerformanceManager
extends Node

enum QualityLevel { LOW, MEDIUM, HIGH, ULTRA }

var current_quality: QualityLevel = QualityLevel.HIGH
var target_frametime_ms: float = 11.1  # 90 FPS

func _process(_delta):
    var frametime = Performance.get_monitor(Performance.TIME_PROCESS)
    if frametime > target_frametime_ms * 1.2:
        _decrease_quality()
    elif frametime < target_frametime_ms * 0.8:
        _increase_quality()

func _decrease_quality():
    # Reduce shadow quality
    # Lower particle counts
    # Reduce trail points
    # Enable more aggressive LOD
    pass
```

#### 4. LOD System Integration

```gdscript
# Add LOD support for dojo environments

class_name LODManager
extends Node

@export var lod_distances: Array[float] = [5.0, 10.0, 20.0]

func setup_mesh_lod(mesh_instance: MeshInstance3D, lods: Array[Mesh]):
    # Configure Godot's built-in LOD system
    mesh_instance.lod_bias = 1.0
    for i in range(lods.size()):
        mesh_instance.set_lod_bias_distance(i, lod_distances[i])
```

### Stage 3 Gap Summary

| Gap | Priority | Effort | Impact |
|-----|----------|--------|--------|
| USD training schema | HIGH | Medium | Enables data-driven content |
| USD variant support | HIGH | Medium | Difficulty management |
| LOD system | MEDIUM | Medium | Performance on lower-end HW |
| Performance manager | MEDIUM | Low | Automatic quality adjustment |
| Visual fidelity polish | LOW | Medium | Aesthetic improvement |

---

## Stage 4 Analysis: Tooling, Modding & Extensible Framework

### Stage 4 Motto
> "Make it robust, moddable, and future-proof."

### What's Already Implemented

#### Data Persistence (100% Complete)

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Session saving | ✅ | JSON export with frame data |
| Settings persistence | ✅ | User preferences saved |
| Achievement tracking | ✅ | AchievementSystem |
| Lifetime statistics | ✅ | SessionManager aggregation |

**Key Files:**
- `godot_project/scripts/core/session_manager.gd`
- `godot_project/scripts/core/save_system.gd`
- `godot_project/scripts/analytics/data_exporter.gd`

#### Error Handling (60% Complete)

| Requirement | Status | Notes |
|-------------|--------|-------|
| Missing controller handling | ⚠️ | Basic checks exist |
| Invalid file fallback | ⚠️ | Partial implementation |
| Lost tracking handling | ⚠️ | Basic pause support |
| Graceful degradation | ⚠️ | Limited |

#### UX/UI (70% Complete)

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| VR main menu | ✅ | MenuPanel in VR space |
| Training selection | ✅ | Mode selection UI |
| Settings menu | ⚠️ | Basic options |
| Results view | ✅ | MovementDashboard |
| Calibration | ✅ | CalibrationSystem |
| Onboarding tutorial | ✅ | TutorialSystem |

**Key Files:**
- `godot_project/scripts/ui/menu_panel.gd`
- `godot_project/scripts/ui/movement_dashboard.gd`
- `godot_project/scripts/tutorial/tutorial_system.gd`

#### Data-Driven Training (20% Complete - Major Gap)

| Requirement | Status | Notes |
|-------------|--------|-------|
| Training definition schema | ❌ | Hardcoded in scripts |
| External config files | ❌ | No config system |
| Dynamic module instantiation | ⚠️ | Limited |
| VR menu auto-population | ❌ | Manual setup |

#### Toolchain & Automation (10% Complete - Major Gap)

| Requirement | Status | Notes |
|-------------|--------|-------|
| CLI asset tools | ❌ | No tools |
| USD → glTF baking | ❌ | N/A |
| Content validation | ❌ | No validators |
| Content packing | ❌ | No bundling |
| CI/CD pipeline | ❌ | Not configured |
| Automated testing | ❌ | No tests |

#### USD Variants & Layers (0% Complete)

| Requirement | Status | Notes |
|-------------|--------|-------|
| VariantSets | ❌ | Not implemented |
| Layer composition | ❌ | Not implemented |
| Session layers | ❌ | Not implemented |
| Runtime variant switching | ❌ | Not implemented |

### Stage 4 Benefit Opportunities

#### 1. Training Definition System (High Priority)

Create a YAML/JSON schema for training exercises:

```yaml
# training_definitions/beginner_posture_01.yaml
id: beginner_posture_01
name: "Ready Stance"
type: posture
difficulty: 1
description: "Hold the basic ready stance with saber at chest level"

target_pose:
  position: [0, 1.4, 0]
  rotation: [0, 0, 0]

parameters:
  hold_duration: 3.0
  position_tolerance: 0.15
  rotation_tolerance: 20.0

feedback:
  visual_guide: true
  haptic_guidance: true
  audio_cues: ["alignment_lock", "drift_warning"]

scoring:
  accuracy_weight: 0.6
  stability_weight: 0.4

rewards:
  completion_xp: 50
  perfect_bonus: 25
```

**Implementation:**

```gdscript
# godot_project/scripts/core/training_definition_loader.gd

class_name TrainingDefinitionLoader
extends RefCounted

const DEFINITIONS_PATH = "res://training_definitions/"

var definitions: Dictionary = {}

func load_all_definitions() -> void:
    var dir = DirAccess.open(DEFINITIONS_PATH)
    if dir:
        dir.list_dir_begin()
        var filename = dir.get_next()
        while filename != "":
            if filename.ends_with(".yaml") or filename.ends_with(".json"):
                _load_definition(DEFINITIONS_PATH + filename)
            filename = dir.get_next()

func _load_definition(path: String) -> void:
    var file = FileAccess.open(path, FileAccess.READ)
    var content = file.get_as_text()
    var data = _parse_yaml_or_json(content)
    definitions[data.id] = data

func get_definition(id: String) -> Dictionary:
    return definitions.get(id, {})

func get_definitions_by_type(type: String) -> Array:
    return definitions.values().filter(func(d): return d.type == type)
```

#### 2. CLI Toolchain (Medium Priority)

```bash
# tools/movement_dojo_cli.py

# Asset validation
python tools/movement_dojo_cli.py validate-training training_definitions/

# USD to glTF conversion
python tools/movement_dojo_cli.py convert-usd environments/dojo.usda --output assets/dojo.glb

# Content pack creation
python tools/movement_dojo_cli.py pack-content my_content/ --output my_content_pack.zip

# Training definition linting
python tools/movement_dojo_cli.py lint-training training_definitions/beginner_posture_01.yaml
```

**Python CLI Implementation:**

```python
# tools/movement_dojo_cli.py

import click
import json
import yaml
from pathlib import Path

@click.group()
def cli():
    """Movement Dojo content tools"""
    pass

@cli.command()
@click.argument('path', type=click.Path(exists=True))
def validate_training(path):
    """Validate training definition files"""
    path = Path(path)
    files = list(path.glob('**/*.yaml')) + list(path.glob('**/*.json'))

    for f in files:
        try:
            content = yaml.safe_load(f.read_text())
            _validate_training_schema(content)
            click.echo(f"✓ {f.name}")
        except Exception as e:
            click.echo(f"✗ {f.name}: {e}", err=True)

@cli.command()
@click.argument('usd_path', type=click.Path(exists=True))
@click.option('--output', '-o', required=True)
def convert_usd(usd_path, output):
    """Convert USD to glTF for runtime"""
    from pxr import Usd, UsdGeom
    # Implementation using Pixar USD + usd2gltf
    pass

@cli.command()
@click.argument('content_dir', type=click.Path(exists=True))
@click.option('--output', '-o', required=True)
def pack_content(content_dir, output):
    """Package content into distributable pack"""
    import zipfile
    with zipfile.ZipFile(output, 'w') as zf:
        for f in Path(content_dir).rglob('*'):
            if f.is_file():
                zf.write(f, f.relative_to(content_dir))

if __name__ == '__main__':
    cli()
```

#### 3. CI/CD Pipeline (High Priority)

```yaml
# .github/workflows/ci.yml

name: Movement Dojo CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install pyyaml click jsonschema

      - name: Validate training definitions
        run: |
          python tools/movement_dojo_cli.py validate-training training_definitions/

      - name: Lint GDScript
        uses: Scony/godot-gdscript-toolkit@master
        with:
          path: godot_project/scripts/

  build-godot:
    runs-on: ubuntu-latest
    needs: validate
    steps:
      - uses: actions/checkout@v4

      - name: Download Godot
        run: |
          wget -q https://downloads.tuxfamily.org/godotengine/4.2.2/Godot_v4.2.2-stable_linux.x86_64.zip
          unzip -q Godot_v4.2.2-stable_linux.x86_64.zip

      - name: Export project
        run: |
          ./Godot_v4.2.2-stable_linux.x86_64 --headless --export-release "Linux/X11" build/movement_dojo

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: movement-dojo-linux
          path: build/

  build-overlay:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y cmake build-essential libvulkan-dev

      - name: Build OpenXR overlay
        run: |
          cd openxr_overlay
          mkdir build && cd build
          cmake ..
          make -j$(nproc)

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: openxr-overlay
          path: openxr_overlay/build/*.so
```

#### 4. Content Modding System

```gdscript
# godot_project/scripts/core/mod_loader.gd

class_name ModLoader
extends Node

const MODS_PATH = "user://mods/"
const MOD_MANIFEST = "manifest.json"

signal mod_loaded(mod_id: String)
signal mod_error(mod_id: String, error: String)

var loaded_mods: Dictionary = {}

func _ready():
    _ensure_mods_directory()
    scan_and_load_mods()

func _ensure_mods_directory():
    DirAccess.make_dir_recursive_absolute(MODS_PATH)

func scan_and_load_mods():
    var dir = DirAccess.open(MODS_PATH)
    if not dir:
        return

    dir.list_dir_begin()
    var mod_name = dir.get_next()
    while mod_name != "":
        if dir.current_is_dir() and mod_name != "." and mod_name != "..":
            _try_load_mod(mod_name)
        mod_name = dir.get_next()

func _try_load_mod(mod_name: String):
    var manifest_path = MODS_PATH + mod_name + "/" + MOD_MANIFEST
    if not FileAccess.file_exists(manifest_path):
        mod_error.emit(mod_name, "Missing manifest.json")
        return

    var manifest = _parse_manifest(manifest_path)
    if not manifest:
        mod_error.emit(mod_name, "Invalid manifest.json")
        return

    # Load training definitions
    if manifest.has("training_definitions"):
        for def_file in manifest.training_definitions:
            var path = MODS_PATH + mod_name + "/" + def_file
            TrainingDefinitionLoader.load_definition(path)

    # Load environments
    if manifest.has("environments"):
        for env in manifest.environments:
            var path = MODS_PATH + mod_name + "/" + env.path
            EnvironmentManager.register_custom_environment(env.id, path)

    loaded_mods[mod_name] = manifest
    mod_loaded.emit(mod_name)
```

#### 5. Robust Error Handling

```gdscript
# godot_project/scripts/core/error_handler.gd

class_name ErrorHandler
extends Node

signal critical_error(message: String)
signal warning(message: String)
signal tracking_lost(device: String)

enum ErrorSeverity { INFO, WARNING, ERROR, CRITICAL }

func _ready():
    # Connect to XR signals
    XRServer.tracker_added.connect(_on_tracker_added)
    XRServer.tracker_removed.connect(_on_tracker_removed)

func _on_tracker_removed(tracker_name: StringName, _type: int):
    tracking_lost.emit(str(tracker_name))
    _show_vr_notification("Tracking lost: " + str(tracker_name), ErrorSeverity.WARNING)

func handle_error(error: String, severity: ErrorSeverity = ErrorSeverity.ERROR):
    match severity:
        ErrorSeverity.INFO:
            print("[INFO] " + error)
        ErrorSeverity.WARNING:
            push_warning(error)
            warning.emit(error)
        ErrorSeverity.ERROR:
            push_error(error)
            _show_vr_notification(error, severity)
        ErrorSeverity.CRITICAL:
            push_error("[CRITICAL] " + error)
            critical_error.emit(error)
            _show_vr_notification(error, severity)

func _show_vr_notification(message: String, severity: ErrorSeverity):
    # Display in VR space
    var notification = preload("res://scenes/ui/vr_notification.tscn").instantiate()
    notification.set_message(message, severity)
    get_tree().current_scene.add_child(notification)
```

### Stage 4 Gap Summary

| Gap | Priority | Effort | Impact |
|-----|----------|--------|--------|
| Training definition system | HIGH | Medium | Data-driven content |
| CI/CD pipeline | HIGH | Low | Quality assurance |
| CLI toolchain | MEDIUM | Medium | Developer productivity |
| Mod loading system | MEDIUM | Medium | Community content |
| Error handling | MEDIUM | Low | Robustness |
| Content validation | LOW | Low | Content quality |

---

## Prioritized Implementation Roadmap

Based on the analysis, here's the recommended implementation order:

### Phase 1: Foundation (Weeks 1-2)
**Focus: Enable data-driven content and establish quality infrastructure**

1. **Training Definition System** [HIGH]
   - Create YAML schema for training definitions
   - Implement `TrainingDefinitionLoader`
   - Migrate 2-3 existing exercises to new format
   - Document schema for content creators

2. **CI/CD Pipeline** [HIGH]
   - Set up GitHub Actions workflow
   - Add GDScript linting
   - Add training definition validation
   - Configure automated builds

3. **Asset Pipeline Documentation** [MEDIUM]
   - Document Blender → glTF workflow
   - Create naming conventions guide
   - Add example assets

### Phase 2: USD Integration (Weeks 3-4)
**Focus: Introduce USD as canonical scene/metadata format**

1. **USD Metadata Loader** [HIGH]
   - Implement USDA text parser or GDExtension
   - Parse training metadata from USD
   - Map spawn points, paths, zones

2. **USD Training Schema** [HIGH]
   - Define custom USD schemas for training
   - Create example training environment
   - Document USD authoring workflow

3. **USD → glTF Pipeline** [MEDIUM]
   - Integrate usd2gltf converter
   - Create CLI tool for conversion
   - Set up asset build pipeline

### Phase 3: Polish & Extensibility (Weeks 5-6)
**Focus: Make the platform content-creator friendly**

1. **CLI Toolchain** [MEDIUM]
   - Implement `validate-training` command
   - Implement `pack-content` command
   - Add `convert-usd` command

2. **Mod Loading System** [MEDIUM]
   - Implement `ModLoader`
   - Define mod manifest format
   - Create mod documentation

3. **Performance Manager** [MEDIUM]
   - Implement adaptive quality system
   - Add LOD support
   - Create graphics presets

### Phase 4: Hardening (Weeks 7-8)
**Focus: Production readiness**

1. **Error Handling** [MEDIUM]
   - Implement `ErrorHandler`
   - Add graceful degradation
   - Improve VR notifications

2. **Testing** [MEDIUM]
   - Add unit tests for core systems
   - Create integration test suite
   - Document testing procedures

3. **Documentation** [LOW]
   - Complete API documentation
   - Create content creator guide
   - Write deployment guide

---

## Technical Specifications

### USD Integration Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Authoring Layer                       │
│  Blender + USD Plugins → USD Files (.usda, .usd)        │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│                   Build Pipeline                         │
│  USD → glTF (geometry)  +  USD → JSON (metadata)        │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│                   Runtime Layer                          │
│  Godot loads glTF meshes + TrainingDefinitionLoader     │
│  parses JSON metadata for training configuration        │
└─────────────────────────────────────────────────────────┘
```

### Training Definition Architecture

```
┌─────────────────────────────────────────────────────────┐
│              training_definitions/                       │
│  ├── posture/                                           │
│  │   ├── ready_stance.yaml                              │
│  │   ├── high_guard.yaml                                │
│  │   └── low_guard.yaml                                 │
│  ├── paths/                                             │
│  │   ├── basic_arc.yaml                                 │
│  │   └── figure_eight.yaml                              │
│  ├── katas/                                             │
│  │   ├── beginner_form_1.yaml                           │
│  │   └── intermediate_defense.yaml                      │
│  └── blocking/                                          │
│      ├── basic_deflection.yaml                          │
│      └── multi_angle.yaml                               │
└─────────────────────────────────────────────────────────┘
```

### Mod Package Structure

```
my_custom_dojo/
├── manifest.json
├── training_definitions/
│   └── custom_exercise.yaml
├── environments/
│   └── custom_dojo.glb
├── textures/
│   └── custom_materials/
└── audio/
    └── custom_sounds/
```

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| USD library complexity | Medium | High | Start with metadata-only, defer full geometry import |
| Performance regression | Low | High | Implement performance manager early, establish benchmarks |
| Content compatibility | Medium | Medium | Version manifest format, provide migration tools |
| Platform fragmentation | Medium | Medium | Focus on SteamVR + Quest first, expand later |

---

## Success Metrics

### Stage Completion Criteria

**Stage 1 Complete When:**
- [ ] USD metadata can be parsed and used for training configuration
- [ ] glTF asset pipeline is documented
- [ ] Test assets validate full pipeline

**Stage 2 Complete When:**
- Already ✅ (existing implementation exceeds requirements)

**Stage 3 Complete When:**
- [ ] USD defines at least 3 training zones with metadata
- [ ] Proprioception modules load from external definitions
- [ ] Performance maintains 90 Hz on target hardware

**Stage 4 Complete When:**
- [ ] New training exercise can be added via config file only
- [ ] CI/CD runs on every commit
- [ ] Content packs can be installed via mod system
- [ ] Documentation enables community content creation

---

## Conclusion

The Movement Dojo XR project is exceptionally well-positioned to adopt the open-source XR framework. The existing implementation already exceeds Stage 1-2 requirements, with a sophisticated proprioception training system that matches Stage 3 goals.

**Key Strategic Benefits of Roadmap Adoption:**

1. **USD Integration** enables professional asset workflows and data-driven content
2. **Training Definition System** allows rapid content creation without code changes
3. **CI/CD Pipeline** ensures quality and enables community contributions
4. **Mod System** opens the platform to community content creators

The recommended approach is to focus on **infrastructure and tooling** (Stage 4 capabilities) while backfilling **USD integration** (Stage 1/3) to create a truly extensible, moddable XR proprioception training platform.

Total estimated implementation time: **6-8 weeks** for full roadmap alignment.
