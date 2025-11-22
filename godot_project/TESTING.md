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
```

Level 1 uses the same hardened OpenXR startup as diagnostics/smoke test, with additional
preflight checks for assets and input bindings.

**Expected in HMD:**
- Octagonal dojo environment with dark walls and blue accent lighting
- Right hand: Debug saber with cyan glowing blade (always active in Level 1)
- Left hand: Debug blaster
- Floating 3D text prompts guiding through training phases
- Visual feedback: "BLOCKED!", "HIT!", "DESTROYED!", etc.

**Training Flow (State Machine):**
1. **INTRO** (~10s): Welcome message, controls overview, "Relax and enjoy the chilled training"
2. **SABER_DRILL**: Block slow-moving projectiles with saber (3 required)
   - Slow projectiles (2 m/s) from stationary drone
   - Visual feedback on successful blocks
3. **BLASTER_DRILL**: Destroy stationary targets with blaster (4 required)
   - Targets spawn at comfortable range
   - Track hits and accuracy
4. **MIXED_DRILL**: Combined combat with drones and one dive attack
   - Destroy drones while blocking projectiles
   - One clearly telegraphed dive attack (⚠️ DIVE ATTACK! warning)
   - Evade or block the dive
5. **SUMMARY**: Display session stats in floating panel
   - Total duration, blocks, hits, drones destroyed
   - Dive attack result (evaded/hit)

**Expected in Log (preflight + phases):**
```
[Level1] === DOJO LEVEL 1 ===
[Level1] Starting Level 1 dojo experience (chilled training mode)
[Level1] Running preflight checks...
[Level1]   [1/4] OpenXR initialization...
[Level1]   PASS: OpenXR initialized
[Level1]   [2/4] XR session validation...
[Level1]   PASS: XR session valid
[Level1]   [3/4] Input binding verification...
[Level1]   PASS: Input bindings configured
[Level1]   [4/4] Optional asset check...
[Level1] Preflight checks: ALL PASSED
[Level1] State: IDLE → INTRO
[Level1] State: INTRO → SABER_DRILL
[Level1] State: SABER_DRILL → BLASTER_DRILL
[Level1] State: BLASTER_DRILL → MIXED_DRILL
[Level1] State: MIXED_DRILL → SUMMARY
[Level1] === LEVEL 1 SUMMARY ===
[Level1] Level 1 completed successfully
```

**Test Actions:**
1. Put on headset and verify you're in the octagonal dojo
2. Read the floating intro text
3. **SABER_DRILL**: Block 3 slow projectiles with your saber
4. **BLASTER_DRILL**: Shoot 4 targets with your blaster (left trigger)
5. **MIXED_DRILL**: Destroy drones and watch for "DIVE ATTACK!" warning
6. **SUMMARY**: Review your stats in the floating panel
7. Press menu button or ESC to exit cleanly

**Key Characteristics (Chilled Mode):**
- Slow projectiles (2 m/s) - easy to track and block
- Few drones (1-2 at a time)
- Clearly telegraphed dive attack with 1.2s warning
- Generous hit detection
- No time pressure on drills

**If Issues:**
- "Preflight checks failed" → Check log for specific FAIL message
- State not advancing → Check for timer or spawner issues in log
- No visual feedback → Verify Level1Feedback is created
- Immediate exit → Look for "Level 1 aborted" in log with reason
- Dive attack not appearing → Check Level1DroneSpawner logs

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
| `godot --dojo-level1` | Level 1 training flow | Preflight PASS, completes all 5 states, shows summary |
| `godot --training-sequence=level1` | Data-driven Level 1 | Sequence loads, phases execute, summary shown |
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
[TrnSeqCtrl] Wave completed: saber_w1 (success=true)
[TrnSeqCtrl] ═══ SEQUENCE COMPLETE! ═══
```

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
