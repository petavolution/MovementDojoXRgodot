# Movement Dojo XR - Simplified Architecture

## Design Principles

1. **Minimal Core** - Only essential systems as autoloads
2. **Lazy Loading** - Secondary systems initialized on-demand
3. **Clear Flow** - Predictable initialization sequence
4. **Loose Coupling** - Signal-based communication via GameEvents
5. **Testable** - Core logic separable from XR runtime
6. **Debug First** - Centralized logging to file for troubleshooting

## System Tiers

### Tier 1: Essential (Autoloads)
These systems are required for basic application function:

| System | Purpose | Dependencies |
|--------|---------|--------------|
| `DebugLogger` | Debug output to file | None (loads first) |
| `GameEvents` | Signal bus | DebugLogger |
| `XRInputManager` | Controller input | DebugLogger |
| `MovementTracker` | XR data capture | DebugLogger, GameEvents |
| `SessionManager` | Data persistence | DebugLogger, MovementTracker, GameEvents |

### Tier 2: Core Gameplay (Lazy-loaded via SystemsManager)
Instantiated by main scene when needed:

| System | Purpose | Loaded When |
|--------|---------|-------------|
| `MovementAnalytics` | Statistics | Session starts |
| `ScoreManager` | Scoring/combos | Training mode |
| `AudioManager` | Sound effects | Scene ready |

### Tier 3: Optional Features (Lazy-loaded)
Loaded only when needed:

| System | Purpose | Loaded When |
|--------|---------|-------------|
| `ReplaySystem` | Recording/playback | User requests |
| `AdaptiveDifficulty` | Game balance | Training mode |
| `CalibrationSystem` | Player setup | First run or menu |
| `AchievementSystem` | Rewards | Session end |

## Initialization Sequence

```
Application Start
    │
    ▼
┌─────────────────────────────────────┐
│  1. Godot Autoloads (in order)      │
│     • DebugLogger (first - logs all)│
│     • GameEvents                    │
│     • XRInputManager                │
│     • MovementTracker               │
│     • SessionManager                │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│  2. Main Scene (_ready)             │
│     • _validate_scene_structure()   │
│       - CRITICAL: Verify XR nodes   │
│       - Abort if missing            │
│     • _initialize_xr()              │
│       - Set viewport.use_xr FIRST   │
│       - Find & init OpenXR          │
│       - Sync physics to 90Hz        │
│       - Or fallback to desktop mode │
│     • Create SystemsManager         │
│     • _setup_optional_nodes()       │
│       - Get visualization refs      │
│       - Get saber refs              │
│     • _setup_controllers()          │
│       - Link XR nodes to tracker    │
│       - Configure HUD references    │
│     • _connect_signals()            │
│     • _change_state(MENU)           │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│  3. User Action: Start Training     │
│     • SessionManager.start_session()│
│     • MovementTracker.start()       │
│     • Load Tier 2 systems           │
└─────────────────────────────────────┘
```

**Desktop Mode Fallback:**
When VR is unavailable, the app auto-detects and enables desktop mode:
- Camera positioned at 1.6m eye height
- WASD movement, mouse look controls
- Simulated controller positions for testing
- 60Hz physics (instead of 90Hz VR)

## Data Flow

```
XR Hardware → MovementTracker → MovementFrame
                    │
                    ▼
              MovementSpaceMap
                    │
                    ▼
           GameEvents.movement_frame_recorded
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
   Analytics    Visualization  Training
```

## Directory Structure (Simplified)

```
godot_project/
├── project.godot              # 4 essential autoloads only
├── scenes/
│   └── main_vr.tscn           # Single main scene
├── scripts/
│   ├── main_vr.gd             # Entry point
│   ├── core/                  # Essential systems
│   │   ├── game_events.gd     # Signal bus
│   │   ├── movement_tracker.gd
│   │   ├── movement_frame.gd
│   │   ├── movement_space_map.gd
│   │   ├── session_manager.gd
│   │   └── xr_input_manager.gd
│   ├── combat/                # Gameplay
│   ├── training/              # Training modes
│   ├── proprioception/        # Body awareness
│   └── ui/                    # User interface
├── tests/                     # Test suite
└── resources/                 # Assets
```

## project.godot Autoloads

```ini
[autoload]
; Essential systems only (loaded in dependency order)
; DebugLogger FIRST - captures all errors/debug output to file
DebugLogger="*res://scripts/core/debug_logger.gd"
; GameEvents - signal bus with no dependencies
GameEvents="*res://scripts/core/game_events.gd"
; XRInputManager - controller input handling
XRInputManager="*res://scripts/core/xr_input_manager.gd"
; MovementTracker - XR data capture (depends on GameEvents)
MovementTracker="*res://scripts/core/movement_tracker.gd"
; SessionManager - persistence (depends on MovementTracker, GameEvents)
SessionManager="*res://scripts/core/session_manager.gd"
```

**Debug Log Location:** `user://debug-log.txt`
(Typically `~/.local/share/godot/app_userdata/Movement Dojo XR/debug-log.txt`)

*Note: Secondary systems (MovementAnalytics, AudioManager, ScoreManager, etc.)
are lazy-loaded via SystemsManager when the main scene needs them.*

## Core Classes

### MovementFrame (Data Class)
```
Properties:
  - timestamp, frame_delta
  - head_position, head_rotation
  - left/right_position, rotation, velocity
  - left/right_grip, trigger

Methods:
  - create() - Factory method
  - compute_velocities() - Calculate from previous frame
  - compute_derived_metrics() - Reach, height relative
  - to_dict() / from_dict() - Serialization
```

### MovementSpaceMap (Data Class)
```
Properties:
  - left_visits, right_visits (PackedInt32Array)
  - unique_cells_visited
  - coverage stats

Methods:
  - record_position() - Track cell visit
  - get_coverage_percentage()
  - get_symmetry_score()
  - get_directional_coverage()
  - to_dict() / from_dict() - Serialization
```

### MovementTracker (Autoload)
```
Responsibilities:
  - Capture XR positions at physics rate
  - Manage frame buffer
  - Update space map
  - Emit movement events

Dependencies:
  - GameEvents (signals)
  - MovementFrame, MovementSpaceMap (data classes)
```

### SessionManager (Autoload)
```
Responsibilities:
  - Session lifecycle (start/pause/end)
  - Data persistence
  - Settings management
  - Achievement tracking

Dependencies:
  - MovementTracker (for frame data)
  - GameEvents (signals)
```

## Signal Flow (GameEvents)

```
Movement:
  movement_frame_recorded(frame) → Analytics, Visualization
  movement_zone_explored(pos, hand) → Achievements, UI

Session:
  session_started(id) → All systems
  session_ended(id, summary) → Save, Stats
  session_paused() / session_resumed() → Tracking

Combat:
  target_hit(target, damage, pos) → Score, VFX
  saber_activated(hand) / deactivated → Audio, VFX

Training:
  training_mode_started(mode) → UI, Audio
  training_mode_ended(mode, results) → Stats
```

## Testing Strategy

```
Unit Tests (headless):
  - MovementFrame math
  - MovementSpaceMap grid logic
  - Score calculations
  - Serialization round-trips

Integration Tests (headless):
  - Frame → SpaceMap flow
  - Session lifecycle
  - Data persistence

Manual Tests (VR):
  - XR tracking accuracy
  - Haptic feedback
  - Visual rendering
```

## Performance Guidelines

1. **90 FPS Target** - Physics at display refresh rate
2. **Ring Buffer** - Fixed memory for frame storage
3. **Lazy Updates** - Analytics computed on-demand, not per-frame
4. **Signal Throttling** - Batch UI updates
5. **Object Pooling** - Reuse projectiles, targets

## Extension Points

### Adding New Training Mode
1. Create `scripts/training/my_mode.gd` extending `TrainingModeBase`
2. Register in `TrainingModeManager`
3. Add UI entry in menu

### Adding New Haptic Pattern
1. Add pattern definition in `HapticPatterns`
2. Reference via `GameEvents.haptic_feedback`

### Adding New Achievement
1. Define in `AchievementSystem.ACHIEVEMENTS`
2. Add check in `SessionManager._check_achievements()`

## Migration Notes

To achieve simplified architecture:

1. Remove from project.godot autoloads:
   - MovementAnalytics
   - AudioManager
   - ScoreManager
   - AdaptiveDifficulty
   - ReplaySystem

2. Update main_vr.gd to instantiate these as children when needed

3. Update references to use lazy access pattern
