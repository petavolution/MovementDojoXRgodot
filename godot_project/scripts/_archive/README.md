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

## Current Architecture

The simplified architecture uses:
- **main_vr.gd** - Scene entry point and state management
- **SessionManager** - Settings and data persistence
- **SystemsManager** - Lazy-loading of secondary systems

## Restoring

To restore any of these systems:
1. Move file back to `scripts/core/`
2. Update class references in dependent files
3. Add to autoloads if needed (see project.godot)
