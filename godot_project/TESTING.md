# Dojo Test Ritual

Manual test procedure for verifying VR dojo engine stability before development.
Run this ritual after any significant changes to XR, rendering, or input systems.

## Prerequisites

- Meta Quest 3 headset
- Virtual Desktop installed and configured
- SteamVR installed and set as active OpenXR runtime
- PC and Quest on same network (preferably 5GHz WiFi or wired)

## Pre-Test Checklist

1. **Start SteamVR**
   - Launch SteamVR on PC
   - Wait for "Ready" status in system tray

2. **Connect Quest 3 via Virtual Desktop**
   - Put on headset
   - Launch Virtual Desktop
   - Connect to PC
   - Verify "SteamVR" appears in Games tab

3. **Verify Tracking**
   - In SteamVR Home, confirm:
     - HMD shows green in SteamVR status window
     - Both controllers show green and tracked
   - Move around to verify play space is configured

## Step 1: VR Diagnostics

Run the automated diagnostics to verify OpenXR setup:

```bash
cd godot_project
godot --vr-diagnostics
```

**Expected Result:**
```
VR Diagnostics: PASS – Ready for dojo prototype.
Log file: ~/.local/share/godot/app_userdata/Movement Dojo XR/logs/engine.log
```

**If FAIL:**
1. Check the log file for detailed error information
2. Common issues:
   - "OpenXR interface not found" → SteamVR not set as active runtime
   - "HMD not detected" → Virtual Desktop not streaming, or SteamVR not detecting Quest
   - "Tracking unstable" → Poor lighting, move to better lit area
3. See `xr_helpers.gd` for common fix suggestions

**What It Tests:**
- OpenXR runtime detection (SteamVR)
- HMD detection and initialization
- Display configuration (resolution, refresh rate)
- 5-second frame loop with pose tracking
- 80%+ HMD pose validity requirement

## Step 2: VR Smoke Test

Run the visual smoke test to verify rendering and tracking:

```bash
cd godot_project
godot --vr-smoke-test
```

**Expected in HMD:**
- Dark gray floor (10m × 10m)
- Four corner pillars
- Back wall for depth reference
- Right hand: Silver saber hilt (trigger to activate cyan blade)
- Left hand: Dark blaster body with barrel
- Red hovering sphere (dummy drone) at head height

**Expected in Log (1Hz updates):**
```
[SmokeTest] Tracking: HMD=OK Left=OK Right=OK
```

**Test Actions:**
1. Look around - verify stereo rendering and head tracking
2. Move controllers - verify they follow your hands
3. Pull right trigger - saber blade should appear (cyan glow)
4. Pull left trigger - blaster should flash orange
5. Press menu button or ESC to exit cleanly

**If Issues:**
- No controllers visible → Check XRInputManager logs for binding issues
- Jittery tracking → Check Virtual Desktop streaming quality
- Black screen → Check SteamVR compositor, restart VR

## Step 3: Dojo Level 1 Training

Run the Level 1 training sequence to test the full gameplay loop:

```bash
cd godot_project
godot --dojo-level1
# Or equivalently:
godot --training-sequence=level1
```

Level 1 uses the data-driven training sequence system with preflight checks for OpenXR.

**Expected in HMD:**
- Dojo environment (or selected environment via --env flag)
- Right hand: Debug saber with cyan glowing blade
- Left hand: Debug blaster
- Floating 3D text prompts with phase hints
- Visual feedback: "BLOCKED!", "HIT!", "DESTROYED!", wave ratings (★★★)

**Training Flow (Data-Driven Phases):**
1. **Welcome** (~8s): Introduction with hint text
2. **Saber Basics**: Block 3 projectiles from 2 stationary shooters
3. **Blaster Basics**: Destroy 3 orbiting target dummies
4. **Mixed Combat**: Handle 2 shooters + 1 dive attacker
5. **Summary**: Display session stats with score/rating

**Expected in Log:**
```
[TrnSeqScene] ═══ TRAINING SEQUENCE MODE (Data-Driven) ═══
[TrnSeqScene] Selected sequence: level1_fundamentals
[TrnSeqScene] Running preflight checks...
[TrnSeqScene]   [1/3] OpenXR initialization... PASS
[TrnSeqScene]   [2/3] Sequence validation... PASS
[TrnSeqScene]   [3/3] Sequence structure check... PASS
[TrnSeqCtrl] === PHASE 1/5: Welcome ===
[TrnSeqCtrl] === PHASE 2/5: Saber Basics ===
[TrnSeqCtrl] Wave 'saber_w1' COMPLETED - Rating: ★★★
[TrnSeqCtrl] ═══ SEQUENCE COMPLETE! ═══
[TrnSeqCtrl] TrainingSequenceSummary: sequence='level1_fundamentals', totalWaves=3, totalScore=9
```

**Test Actions:**
1. Put on headset and verify environment loads
2. Read the floating intro text with hint
3. **Saber Basics**: Block 3 projectiles with your saber
4. **Blaster Basics**: Destroy 3 targets with your blaster (left trigger)
5. **Mixed Combat**: Destroy drones and watch for "DIVE ATTACK!" warning
6. **Summary**: Review your stats and star rating
7. Press ESC to exit cleanly

**Debug Mode:**
```bash
godot --dojo-level1 --training-debug
```
Enables keyboard shortcuts: R=restart, N=next phase, W=skip wave, 1-5=jump to phase

**If Issues:**
- "Preflight checks failed" → Check log for specific FAIL message
- Phase not advancing → Check for timer or spawner issues in log
- No visual feedback → Verify Level1Feedback is created

## Step 4: Normal Launch (Optional)

If Steps 1-3 pass, the full engine should work:

```bash
cd godot_project
godot
```

This loads the full game with all systems. Use this after validating basics.

## Log File Locations

All logs are written to:
- **Linux:** `~/.local/share/godot/app_userdata/Movement Dojo XR/logs/engine.log`
- **Windows:** `%APPDATA%/Godot/app_userdata/Movement Dojo XR/logs/engine.log`
- **macOS:** `~/Library/Application Support/Godot/app_userdata/Movement Dojo XR/logs/engine.log`

Log rotation keeps the last 3 sessions (engine.log.1, engine.log.2, engine.log.3).

## Quick Reference

| Command | Purpose | Pass Criteria |
|---------|---------|---------------|
| `godot --vr-diagnostics` | Automated XR validation | "PASS" message, exit code 0 |
| `godot --vr-smoke-test` | Visual/tracking verification | See floor, weapons, stable tracking |
| `godot --dojo-level1` | Level 1 training (data-driven) | Preflight PASS, completes all phases, shows summary |
| `godot --dojo-level1 --training-debug` | Debug mode | Debug keyboard shortcuts enabled |
| `godot --training-sequence=<id>` | Custom training sequence | Sequence loads, phases execute |
| `godot` | Full game launch | No errors, enters menu state |

### Alternative Launch Methods

Level 1 can also be started via:
- Short flag: `godot --level1`
- Config entry (future): `"mode": "dojo_level1"` in settings.json

All modes use the same hardened OpenXR startup sequence with graceful fallback.

### Training Environment Selection

Level 1 supports three procedurally-generated training environments. Use the `--env` flag:

| Command | Environment | Description |
|---------|-------------|-------------|
| `godot --dojo-level1 --env=dojo` | Kung-Fu Dojo (default) | 10m×8m wooden room, tatami floor, pillars, weapon rack, holoscreens |
| `godot --dojo-level1 --env=ocean` | Ocean Platform | 6m×6m stone platform with railings, infinite ocean, sky dome |
| `godot --dojo-level1 --env=hyperspace` | Hyperspace Cockpit | Hexagonal platform, sci-fi consoles, animated star streaks |

**Examples:**
```bash
# Default kung-fu dojo (no flag needed)
godot --dojo-level1

# Ocean platform with water and sky
godot --dojo-level1 --env=ocean

# Hyperspace with animated streaks
godot --dojo-level1 --env=hyperspace

# Short flag with environment
godot --level1 --env=hyperspace
```

**Environment Aliases:**
Each environment accepts multiple names:
- Dojo: `dojo`, `kungfu`, `kung-fu`
- Ocean: `ocean`, `platform`, `ocean-platform`
- Hyperspace: `hyperspace`, `space`, `cockpit`

**Fallback Behavior:**
- Unknown environment names default to dojo
- If environment fails to load, automatically falls back to dojo
- Log shows selected environment: `[EnvLoader] Selected environment from CLI: <name>`

### Data-Driven Training Sequences (New)

The new training sequence system uses data-driven definitions for flexible level design:

```bash
# Run Level 1 via the new data-driven system
godot --training-sequence=level1

# Alternative format
godot --training-sequence-level1

# Combine with environment selection
godot --training-sequence=level1 --env=ocean
```

**Available Sequences:**
- `level1` / `level1_fundamentals` - Beginner training (saber, blaster, mixed)
- `level2` / `level2_intermediate` - Coming soon
- `endless_survival` - Coming soon

**Architecture Overview:**
```
TrainingSequence (e.g., "Level 1")
  └── TrainingPhase (e.g., "Saber Basics")
        └── TrainingWave (e.g., "Block 3 projectiles")
              └── WaveSpawnEntry (e.g., "2x Flying Drone")
```

**Log Output:**
```
[TrnSeqCtrl] ═══ SEQUENCE: LEVEL 1: FUNDAMENTALS ═══
[TrnSeqCtrl] === PHASE 1/5: Welcome ===
[TrnSeqCtrl] === PHASE 2/5: Saber Basics ===
[TrnSeqCtrl] Wave 1/1: saber_w1 - 2x Flying Drone (stationary, shooting)
[TrnSeqCtrl] Wave completed: saber_w1 (success=true) - Rating: ★★★
[TrnSeqCtrl] ═══ SEQUENCE COMPLETE! ═══
[TrnSeqCtrl] TrainingSequenceSummary: sequence='level1_fundamentals', totalWaves=3, totalScore=9, totalHitsTaken=0, duration=45.2
```

### Debug Mode

Enable debug mode to access keyboard shortcuts for testing and QA:

```bash
# Enable debug mode with the --training-debug flag
godot --training-sequence=level1 --training-debug
```

**Debug Keyboard Controls:**
| Key | Action |
|-----|--------|
| `R` | Restart the current sequence from the beginning |
| `N` | Skip to the next phase |
| `W` | Skip the current wave |
| `1-5` | Jump directly to phase 1, 2, 3, 4, or 5 |

**Debug Log Output:**
```
[TrnSeqCtrl] DEBUG MODE ENABLED - Keyboard shortcuts:
[TrnSeqCtrl]   R = Restart sequence
[TrnSeqCtrl]   N = Skip to next phase
[TrnSeqCtrl]   W = Skip current wave
[TrnSeqCtrl]   1-5 = Jump to phase 1-5
[TrnSeqCtrl] DEBUG: Skipping to phase 3 (Mixed Combat)
```

### Wave Rating System

Each wave is rated based on hits taken:
- **★★★ (3 points)**: No hits taken - Perfect!
- **★★☆ (2 points)**: 1-2 hits taken - Good
- **★☆☆ (1 point)**: 3+ hits taken - Cleared

The sequence summary shows your total score and overall rating:
```
═══ SCORE ═══
  Total Score: 8/9 (89%)
  Overall Rating: ★★★★☆
```

### UX Feedback Display

The training system shows real-time feedback:
- **Phase start**: Shows phase name, objective, and hint text
- **Wave start**: Shows "Wave X/Y" indicator
- **Wave complete**: Shows summary with kills/blocks/hits and star rating
- **Sequence complete**: Shows full stats summary panel

## Troubleshooting Common Issues

### Level 1 Preflight Failures

If Level 1 aborts with "Preflight checks failed":

```
[Level1] Level 1 aborted: Preflight checks failed
[Level1] Check configuration/assets/XR runtime.
```

**Check the specific failure:**
1. **OpenXR initialization failed** → SteamVR not running or not set as active runtime
2. **XR session not valid** → HMD not detected, try restarting VR
3. **Input bindings missing** → Check openxr_action_map.tres exists
4. **Assets missing** → Non-critical warnings, level will continue

**Quick fix sequence:**
```bash
# 1. Verify XR is working
godot --vr-diagnostics

# 2. If that passes, try smoke test
godot --vr-smoke-test

# 3. Then retry Level 1
godot --dojo-level1
```

### "OpenXR interface not found"
```
Fix: Set SteamVR as active OpenXR runtime
1. Open SteamVR Settings
2. Go to Developer tab
3. Click "Set SteamVR as OpenXR Runtime"
4. Restart Virtual Desktop on Quest
```

### "HMD not detected"
```
Fix: Ensure Virtual Desktop is streaming
1. Put on Quest headset
2. Launch Virtual Desktop
3. Connect to PC
4. Launch SteamVR from VD Games tab
5. Retry test
```

### Controllers not tracked
```
Fix: Check controller bindings
1. In SteamVR, open Controller Settings
2. Verify Quest 3 controllers are listed
3. Check for binding conflicts
4. Look for "LeftHandPose/RightHandPose not tracked" warnings in log
```

### Poor performance / stuttering
```
Fix: Check Virtual Desktop settings
1. In VD Settings, try:
   - Lower streaming resolution
   - Enable HEVC encoding
   - Use 5GHz WiFi or wired connection
2. Close other GPU-intensive applications
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success / Clean exit |
| 1 | Failure / Error during operation |

Use exit codes for CI/automation:
```bash
godot --vr-diagnostics && echo "VR Ready" || echo "VR Failed"
```
