# Movement Dojo XR - Developer Quickstart

## Prerequisites

- **Godot 4.2+** with OpenXR support
- **SteamVR** or native OpenXR runtime (for VR mode)
- VR headset with controllers (optional - desktop mode available)

## Quick Setup

```bash
# Clone and open
git clone <repo-url>
cd MovementDojoXRgodot/godot_project

# Validate project structure
godot --headless --script tools/validate_project.gd

# Run tests
godot --headless --script tests/test_runner.gd
```

## Running the Application

### VR Mode (Default)
1. Start SteamVR (or your OpenXR runtime)
2. Open project in Godot 4.2+
3. Press F5 or click Play

### Desktop Mode (No VR Required)
The application auto-detects missing VR and falls back to desktop mode:

- **WASD** - Movement
- **Mouse** - Look around
- **ESC** - Release/capture mouse
- **Space** - Toggle menu

Desktop mode simulates controller positions for testing.

## Project Validation

Verify project health before development:

```bash
# From godot_project/ directory
./tools/validate.sh

# Or directly:
godot --headless --script tools/validate_project.gd
```

This checks:
- All 5 autoloads present and ordered correctly
- Core scripts exist
- Scene structure valid
- Resources available

## Key Files

| File | Purpose |
|------|---------|
| `scripts/main_vr.gd` | Entry point, XR initialization |
| `scripts/core/debug_logger.gd` | Logging (first autoload) |
| `scripts/core/game_events.gd` | Signal bus |
| `scripts/core/movement_tracker.gd` | XR data capture |
| `scripts/core/session_manager.gd` | Data persistence |
| `scenes/main_vr.tscn` | Main scene |

## Autoload Order (Critical)

The 5 autoloads must load in this exact order:

1. **DebugLogger** - File logging, startup validation
2. **GameEvents** - Signal bus (no dependencies)
3. **XRInputManager** - Controller input
4. **MovementTracker** - XR tracking (depends on GameEvents)
5. **SessionManager** - Persistence (depends on above)

## Debug Log Location

All debug output goes to file:
```
~/.local/share/godot/app_userdata/Movement Dojo XR/debug-log.txt
```

Or on Windows:
```
%APPDATA%/Godot/app_userdata/Movement Dojo XR/debug-log.txt
```

View logs:
```bash
tail -f ~/.local/share/godot/app_userdata/Movement\ Dojo\ XR/debug-log.txt
```

## Common Tasks

### Add a New System
1. Create script in `scripts/core/` or appropriate subfolder
2. If needed at startup, add to `project.godot` autoloads (maintain order)
3. Otherwise, lazy-load via `SystemsManager`

### Connect to Events
```gdscript
func _ready():
    GameEvents.session_started.connect(_on_session_started)
    GameEvents.movement_frame_recorded.connect(_on_frame)

func _on_session_started(session_id: String):
    pass  # Handle event
```

### Log Messages
```gdscript
DebugLogger.debug("MySystem", "Debug info")
DebugLogger.info("MySystem", "Important info")
DebugLogger.warn("MySystem", "Warning")
DebugLogger.error("MySystem", "Error occurred")
```

### Start a Training Session
```gdscript
# From any script
SessionManager.start_session()
# ... user trains ...
SessionManager.end_session()  # Saves data
```

## Troubleshooting

### "Nonexistent function 'info' in base 'Nil'"
Autoload name mismatch. Check `project.godot` uses `DebugLogger` (not `Logger`).

### XR not initializing
- Ensure SteamVR is running
- Check OpenXR runtime is default
- Desktop mode will auto-activate as fallback

### Missing autoloads at startup
Check debug log for "Startup validation FAILED" message listing missing autoloads.

## Architecture Reference

See `docs/ARCHITECTURE.md` for:
- System tiers and dependencies
- Initialization sequence diagram
- Data flow patterns
- Extension points
