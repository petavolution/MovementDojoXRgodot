# Archived Scripts

These scripts are not currently used in the simplified architecture but are
preserved for potential future use or reference.

## Archived Files

| File | Reason | Notes |
|------|--------|-------|
| `application_manager.gd` | Complex orchestrator | Replaced by simpler main_vr.gd |
| `xr_session_manager.gd` | XR abstraction layer | Direct OpenXR handling in main_vr.gd |
| `settings_manager.gd` | Detailed settings system | SessionManager handles settings |
| `save_system.gd` | Separate persistence | SessionManager handles all persistence |
| `levels/level1_controller.gd` | Old hardcoded Level 1 | Replaced by data-driven TrainingSequenceController |
| `levels/level1_drone_spawner.gd` | Old drone spawner | Replaced by TrainingSpawner with WaveSpawnEntry |
| `levels/level1_scene.gd` | Old Level 1 scene builder | Replaced by TrainingSequenceScene |
| `environment/environment_manager.gd` | Complex env presets | Not used; new system uses EnvironmentLoader |
| `environment/scene_variant_system.gd` | USD-style variants/layers | Not used; sophisticated but unreferenced system |
| `training/training_mode_manager.gd` | Enum-based training modes | Replaced by data-driven TrainingSequence system |

## Current Architecture

The simplified architecture uses:
- **main_vr.gd** - Scene entry point and CLI routing
- **TrainingSequenceScene** - Data-driven training sequence executor
- **TrainingSequenceController** - Manages sequence/phase/wave state machine
- **TrainingSpawner** - Data-driven entity spawning from WaveSpawnEntry
- **EnvironmentLoader** - Loads procedural environments (dojo, ocean, hyperspace)
- **SessionManager** - Settings and data persistence
- **SystemsManager** - Lazy-loading of secondary systems

## Data-Driven Training System

The active training system uses:
```
TrainingSequence (e.g., "Level 1")
  └── TrainingPhase (e.g., "Saber Basics")
        └── TrainingWave (e.g., "Block 3 projectiles")
              └── WaveSpawnEntry (e.g., "2x Flying Drone")
```

Sequences are defined in `sequence_library.gd` and executed by `TrainingSequenceController`.

## Restoring

To restore any of these systems:
1. Move file back to appropriate directory
2. Update class references in dependent files
3. Add to autoloads if needed (see project.godot)
