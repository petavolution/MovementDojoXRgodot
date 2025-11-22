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

## Step 3: Normal Launch (Optional)

If Steps 1 and 2 pass, the full engine should work:

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
| `godot` | Full game launch | No errors, enters menu state |

## Troubleshooting Common Issues

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
