# Movement Dojo XR

**Serious Game for Movement Wellness, Meditation & Full-Body Activation**

A VR application combining lightsaber combat gameplay with movement wellness principles from yoga, qi gong, and meditation. Features comprehensive movement analytics and can work as a universal OpenXR overlay for any VR application.

## Features

### Core Gameplay
- Physics-based lightsaber combat with velocity-sensitive damage
- Training targets and droid enemies
- Dojo environment with atmospheric lighting

### Movement Analytics
- **Real-time tracking** of all controller and headset movements
- **3D space mapping** with 10cm resolution grid
- **Movement pattern classification** (sweeps, thrusts, circular, overhead reach, etc.)
- **Pose detection** for yoga and qi gong movements
- **Symmetry analysis** for left/right balance

### Visualization
- **Movement trails** showing hand paths
- **3D heat maps** visualizing movement frequency
- **Gap indicators** highlighting unexplored movement zones
- **Real-time HUD** with coverage, symmetry, and pose detection

### OpenXR Overlay (C++)
- Works as API layer with **any VR game**
- Background tracking always active
- Toggle-able overlay visualization
- Session data export

## Project Structure

```
movement-dojo-xr/
├── godot_project/           # Godot 4.x VR Application
│   ├── scripts/
│   │   ├── core/            # Movement tracking, session management
│   │   ├── analytics/       # Pattern analysis, pose detection
│   │   ├── visualization/   # Trails, heat maps, HUD
│   │   ├── combat/          # Lightsaber, targets
│   │   └── ui/              # World-space UI
│   ├── scenes/              # Godot scenes
│   ├── shaders/             # Blade glow, trail effects
│   └── resources/           # Assets and configurations
│
├── openxr_overlay/          # C++ OpenXR API Layer
│   ├── src/
│   │   ├── api_layer.*      # OpenXR function interception
│   │   ├── movement_tracker.*  # Tracking system
│   │   ├── data_recorder.*  # Session persistence
│   │   └── config.*         # Configuration
│   └── CMakeLists.txt
│
└── LIGHTSABER_VR_GAME_DESIGN.md  # Full design document
```

## Requirements

### Godot Project
- Godot Engine 4.2+
- OpenXR-compatible VR headset
- SteamVR or native OpenXR runtime

### OpenXR Overlay
- CMake 3.16+
- OpenXR SDK
- Vulkan SDK
- C++17 compiler

## Building

### Godot Project
1. Open Godot 4.2+
2. Import the `godot_project` folder
3. Configure XR settings in Project Settings
4. Run or export

### OpenXR Overlay
```bash
cd openxr_overlay
mkdir build && cd build
cmake ..
cmake --build .
```

To install the API layer:
```bash
sudo cmake --install .
# Or manually copy the .so/.dll and .json manifest
```

Enable the layer:
```bash
export MOVEMENT_DOJO_ENABLE=1
```

## Usage

### Standalone Mode
1. Launch the Godot project
2. Press trigger to activate lightsabers
3. Menu button to toggle between training and menu
4. B/Y button to toggle heat map visualization

### Overlay Mode
1. Install and enable the OpenXR API layer
2. Launch any VR game
3. Movement data is tracked automatically
4. View analytics in companion desktop app (TODO)

## Core Systems

### MovementFrame
Single frame of tracking data including:
- Head/left/right positions and rotations
- Linear and angular velocities
- Controller inputs (grip, trigger)
- Derived metrics (reach distance, movement intensity)

### MovementSpaceMap
3D grid (31x31x31 cells, 10cm each) tracking:
- Visit counts per cell per hand
- Coverage percentage
- Symmetry score
- Unexplored zone detection

### MovementAnalyzer
Classifies movements into types:
- Horizontal/Vertical sweeps
- Thrusts and pulls
- Circular motions
- Overhead/behind/low reaches
- Cross-body movements

Detects poses:
- T-Pose
- Arms Raised
- Warrior Stance
- Gathering Qi
- Meditation

### SessionManager
Handles data persistence:
- Session start/end lifecycle
- JSON session export
- Lifetime statistics
- Achievement tracking
- Settings management

## Data Format

Sessions are saved as JSON:
```json
{
  "session_id": "20250122_143000_abc123",
  "duration": 1800,
  "frames": [...],
  "stats": {
    "coverage": 45.2,
    "symmetry": 87.5,
    "poses_detected": ["T-Pose", "Meditation"]
  }
}
```

## Roadmap

- [ ] Guided wellness routines (yoga, qi gong sequences)
- [ ] Achievement system with notifications
- [ ] Multiplayer dojo sessions
- [ ] Desktop analytics dashboard
- [ ] Quest standalone build
- [ ] Overlay visualization rendering

## License

MIT License - See LICENSE file

## Contributing

Contributions welcome! Please read the design document for architecture details.

## Acknowledgments

- Inspired by Vader Immortal: Lightsaber Dojo
- Movement principles from yoga, qi gong, tai chi
- Built with Godot Engine and OpenXR
