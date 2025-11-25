# Training Sequences

This directory contains training sequence definitions as Godot `.tres` resource files.

## Overview

Training sequences are the core content structure for Movement Dojo XR. Each sequence represents a complete training program with multiple phases, waves, and enemies.

**Data Structure:**
```
TrainingSequence (level1_fundamentals.tres)
├── Metadata (display name, description, difficulty)
├── TrainingPhase 1 (intro)
│   └── (no waves - timed phase)
├── TrainingPhase 2 (saber_basics)
│   └── TrainingWave 1
│       └── WaveSpawnEntry (2x Flying Drones)
├── TrainingPhase 3 (blaster_basics)
│   └── TrainingWave 1
│       └── WaveSpawnEntry (3x Target Dummies)
└── TrainingPhase 4 (mixed_combat)
    └── TrainingWave 1
        ├── WaveSpawnEntry (2x Shooters)
        └── WaveSpawnEntry (1x Dive Attacker)
```

## File Format

Files are saved in Godot's text-based `.tres` format, which is:
- **Human-readable** text format
- **Version-control friendly** (easy to diff)
- **Godot native** (loads directly as Resources)
- **Type-safe** with built-in validation

## Exporting Sequences

### First-time Export

To migrate hardcoded sequences to resource files:

1. Open Godot Editor
2. Open `res://tools/export_training_sequences.gd`
3. Click **File → Run** (or press `Ctrl/Cmd+Shift+X`)
4. Check console output for results

The tool will create `.tres` files for all built-in sequences.

### Manual Export (from code)

```gdscript
# Export all sequences
var results = SequenceLibrary.export_all_sequences(false)

# Export single sequence
var sequence = SequenceLibrary.create_level1_fundamentals()
SequenceLibrary.export_sequence(sequence, false)
```

## Loading Sequences

The system automatically uses the following priority:

1. **Load from .tres file** (if exists in this directory)
2. **Validate** the loaded resource
3. **Fall back to factory method** (if file missing or invalid)

```gdscript
# Automatically loads from file or creates programmatically
var sequence = SequenceLibrary.get_sequence("level1_fundamentals")
```

## Editing Sequences

### In Godot Editor (Recommended)

1. Double-click a `.tres` file in FileSystem dock
2. Edit properties in Inspector panel
3. Save (Ctrl/Cmd+S)

### In Text Editor (Advanced)

`.tres` files can be edited directly in any text editor:

```
[gd_resource type="TrainingSequence" format=3 ...]

[resource]
sequence_id = "level1_fundamentals"
display_name = "Level 1: Fundamentals"
description = "Learn the basics..."
difficulty = 1
estimated_duration_minutes = 5
...
```

**Warning:** Manual text editing can break references. Use Godot Editor when possible.

## Creating New Sequences

### Method 1: Duplicate Existing

1. Right-click existing `.tres` file → Duplicate
2. Rename file
3. Edit properties in Inspector
4. Update `sequence_id` to match filename

### Method 2: Create New Resource

1. Right-click in FileSystem → New Resource
2. Search for "TrainingSequence"
3. Save as `.tres` file
4. Add phases using Inspector

### Method 3: Programmatic Creation

1. Add factory method to `SequenceLibrary`
2. Use `export_sequence()` to save
3. Edit `.tres` file going forward

## Validation

All sequences are validated on load. Validation checks:

- ✓ Required fields (sequence_id, display_name, phases)
- ✓ No duplicate phase IDs
- ✓ Each phase has valid waves
- ✓ Grade thresholds are descending

To manually validate:
```gdscript
var sequence = load("res://resources/training_sequences/level1_fundamentals.tres")
var errors = sequence.validate()
if errors.is_empty():
    print("Valid!")
else:
    for error in errors:
        print("ERROR: ", error)
```

## Built-in Sequences

| File | Sequence ID | Description | Status |
|------|-------------|-------------|--------|
| `level1_fundamentals.tres` | level1_fundamentals | Beginner tutorial with blocking, shooting, mixed combat | Complete |
| `level2_intermediate.tres` | level2_intermediate | Intermediate training with faster enemies | Placeholder |
| `endless_survival.tres` | endless_survival | Endless adaptive difficulty mode | Placeholder |

## Resource Class Hierarchy

```gdscript
TrainingSequence extends Resource
  ├─ sequence_id: String
  ├─ display_name: String
  ├─ difficulty: int (1-5)
  ├─ phases: Array[TrainingPhase]
  └─ ... (30+ properties)

TrainingPhase extends Resource
  ├─ phase_id: String
  ├─ phase_type: PhaseType enum
  ├─ completion_type: CompletionType enum
  ├─ waves: Array[TrainingWave]
  └─ ... (20+ properties)

TrainingWave extends Resource
  ├─ wave_id: String
  ├─ completion_type: CompletionType enum
  ├─ spawn_entries: Array[WaveSpawnEntry]
  └─ ... (15+ properties)

WaveSpawnEntry extends Resource
  ├─ entry_id: String
  ├─ enemy_type: EnemyType enum
  ├─ count: int
  ├─ behavior: SpawnBehavior enum
  └─ ... (25+ properties)
```

Full class documentation: `res://scripts/training/training_sequence.gd`

## Version Control

### What to Commit

✅ **DO commit:**
- All `.tres` files (training content)
- This README.md
- Schema/validation changes

❌ **DON'T commit:**
- `.tres.remap` files (auto-generated)
- `.import` files (auto-generated)

### Git Diff Tips

`.tres` files show clear diffs:
```diff
 [resource]
 sequence_id = "level1_fundamentals"
-difficulty = 1
+difficulty = 2
-estimated_duration_minutes = 5
+estimated_duration_minutes = 8
```

## Migration Strategy

The codebase follows this migration path:

**Phase 1 (Current):**
- ✅ Load from `.tres` files with factory fallback
- ✅ Export tool to migrate hardcoded sequences
- ✅ Validation on load

**Phase 2 (Future):**
- JSON/YAML import/export for community content
- CLI validation tool for CI/CD
- Schema documentation for content creators

**Phase 3 (Future):**
- Content pack system with manifest files
- Hot-reload support for rapid iteration
- Visual sequence editor UI

## Troubleshooting

### "Sequence validation failed"
- Check console for specific error messages
- Verify all required fields are set
- Ensure phase IDs are unique
- Check that arrays (phases, waves) aren't empty

### "Failed to load sequence"
- Verify file exists in `res://resources/training_sequences/`
- Check file extension is `.tres`
- Try re-exporting with `export_all_sequences(true)`

### Changes not appearing in game
- Ensure you saved the `.tres` file
- Reload the scene or restart the game
- Check DebugLogger output for which file was loaded

### Factory methods still being called
- Check that `.tres` file exists
- Verify `sequence_id` in file matches filename
- Look for validation errors in console

## Best Practices

1. **Use descriptive IDs**: `level1_fundamentals` not `seq1`
2. **Validate before saving**: Check for errors before export
3. **Keep phases focused**: Each phase = one skill or concept
4. **Balance difficulty curves**: Start easy, ramp gradually
5. **Test in VR**: Always verify timing and spacing in headset
6. **Version control**: Commit sequences separately from code
7. **Document changes**: Use clear commit messages for content

## Future Enhancements

- [ ] JSON schema for external validation
- [ ] YAML format for easier editing
- [ ] Visual timeline editor
- [ ] Difficulty calculator
- [ ] Community content guidelines
- [ ] Sequence rating system
- [ ] Leaderboard integration

## Contributing

When creating new training sequences:

1. Follow naming convention: `{level}_{name}.tres`
2. Validate before committing
3. Test in VR for timing/difficulty
4. Update this README's Built-in Sequences table
5. Add `sequence_id` to `SequenceLibrary.get_available_sequences()`

## See Also

- `scripts/training/training_sequence.gd` - TrainingSequence class definition
- `scripts/training/training_phase.gd` - TrainingPhase class definition
- `scripts/training/training_wave.gd` - TrainingWave class definition
- `scripts/training/sequence_library.gd` - Loading and export system
- `tools/export_training_sequences.gd` - Export tool script
- `docs/ACTION_PLAN.md` - Development roadmap
