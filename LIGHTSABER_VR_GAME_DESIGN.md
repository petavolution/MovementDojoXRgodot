# Lightsaber VR Game Design Document
## Technology Evaluation for SteamVR Development

---

## Overview

This document evaluates two technology stacks for building a 3D lightsaber VR game (similar to Vader Immortal / Vader Dojo) targeting SteamVR:

1. **Godot Engine** (with OpenXR + Vulkan backend + C++ / GDExtension)
2. **Open-source idTech forks** (ioquake3, Dhewm3 + VR patches)

---

## Part 1: Godot Engine Advantages

### 1.1 Native OpenXR Support

| Feature | Benefit |
|---------|---------|
| Built-in OpenXR plugin | Direct SteamVR, Quest, and WMR support |
| Controller pose access | Full 6DoF tracking for saber positioning |
| Haptics API | Tactile feedback on blade contact/parry |
| Hand tracking support | Optional gesture-based Force powers |
| Action-based input system | Remappable controls across devices |

**VR Combat Implications:**
- Dual-wielding lightsaber support
- Swing velocity detection for damage calculation
- Precise parry/counter mechanics via blade angle detection

### 1.2 Vulkan Rendering Pipeline

| Capability | Application |
|------------|-------------|
| Real-time HDR bloom | Glowing lightsaber blades |
| Emissive materials | Blade core illumination |
| Decal system | Scorch marks, blade trails |
| Particle effects | Sparks on clash, Force effects |
| Volumetric fog | Atmospheric dojo environments |
| Forward+ rendering | VR-optimized performance |

**Visual Design Benefits:**
- Cinematic saber glow in dark environments
- Dynamic lighting from blade movement
- Real-time shadows for immersive combat

### 1.3 Physics System for Melee Combat

```
RigidBody3D (blade physics)
    |
    +-- Area3D (hit detection)
    |       +-- CollisionShape3D (blade volume)
    |
    +-- ContactMonitor (collision callbacks)
```

**Combat Mechanics Support:**
- Physics-based saber collisions
- Blade deflection on parry
- Force push/pull environmental interaction
- Velocity-based damage scaling

### 1.4 Scene Architecture for VR

Godot's node-based scene system enables modular VR object composition:

```
Lightsaber (Node3D)
    |
    +-- Hilt (MeshInstance3D)
    +-- Blade (MeshInstance3D + emissive material)
    +-- BladeHitbox (Area3D)
    +-- BladeLight (OmniLight3D)
    +-- SwingAudio (AudioStreamPlayer3D)
    +-- HapticController (custom node)
```

**Design Benefits:**
- Each component has independent logic and signals
- No monolithic "God classes"
- Easy to create variant sabers (dual-blade, crossguard, etc.)
- World-space UI for holocrons, menus, Force selection

### 1.5 Extensibility via GDExtension

| Layer | Use Case |
|-------|----------|
| GDScript | Rapid prototyping, game logic |
| C++ (GDExtension) | High-performance saber physics |
| Rust (godot-rust) | Type-safe low-level systems |
| C# (optional) | Unity-style workflow |

**Performance Strategy:**
- Prototype in GDScript
- Profile bottlenecks
- Optimize critical paths in C++/Rust

### 1.6 VR-Specific Features

**Locomotion Options:**
- Snap turning
- Teleport movement
- Smooth locomotion
- Room-scale support

**Comfort Features:**
- Vignette during motion
- Configurable turn speed
- Seated/standing modes

**Interaction Design:**
- Belt holsters for saber storage
- Grab/throw mechanics
- Diegetic (in-world) UI panels

### 1.7 Development Workflow Advantages

| Advantage | Description |
|-----------|-------------|
| MIT License | No royalties, full ownership |
| Rapid iteration | Live scene editing |
| Blender integration | Direct asset pipeline |
| Active XR community | Godot XR Tools, templates |
| Excellent documentation | Clear API and tutorials |

---

## Part 2: Dhewm3 / idTech Fork Advantages

### 2.1 Engine Architecture (idTech 4)

| Feature | Benefit |
|---------|---------|
| Client-server architecture | Even in single-player (deterministic) |
| Modular subsystems | Separable render/audio/logic |
| Logic/render decoupling | Clean system boundaries |
| Tick-based simulation | Precise timing for combat |

**Combat Design Implications:**
- Deterministic hit detection
- Precise parry timing windows
- Consistent physics replay

### 2.2 Real-Time Unified Lighting

**Shadow Volumes (Carmack's Reverse):**
- All geometry lit dynamically
- Hard-edged, detailed shadows
- Atmospheric sci-fi/dojo aesthetics
- Low hardware requirements

**Visual Atmosphere:**
- High contrast environments
- Dramatic shadow interplay with saber glow
- Classic "dark corridor" tension

### 2.3 Built-in GUI Scripting System

Original Doom 3 GUI system enables:
- In-world 2D interfaces (terminals, keypads)
- Repurposable for VR diegetic UI:
  - Force power selection panels
  - Training feedback displays
  - Saber customization consoles

### 2.4 C++ Codebase Control

| Capability | Application |
|------------|-------------|
| Full engine access | Custom saber collision system |
| Game loop control | VR render timing integration |
| Physics modification | Blade momentum calculations |
| AI system access | Droid/enemy combat behavior |

**Integration Possibilities:**
- OpenXR layer implementation
- Bullet physics integration
- Modern audio system (FMOD)
- Custom VR renderer

### 2.5 Deterministic Simulation

**Precision Combat Benefits:**
- Frame-perfect parry detection
- Consistent saber clash physics
- Time-slow mechanics (Force focus)
- Replay system potential

### 2.6 Efficient Scene Management

| Technique | VR Benefit |
|-----------|------------|
| BSP-based rendering | Predictable performance |
| Portal culling | Reduced overdraw |
| Occlusion techniques | Lower latency |

### 2.7 VR Integration Path

**Reference Implementation: RBDOOM3-BFG-VR**
- Full SteamVR integration
- Head tracking
- Motion controller support
- Positional audio
- Stereoscopic rendering

**Portability Strategy:**
- Study RBDOOM3-BFG-VR techniques
- Backport OpenXR layer to Dhewm3
- Maintain custom fork

### 2.8 Legacy Saber Combat Resources

**Inspiration Sources:**
- Jedi Knight: Jedi Academy mechanics
- Jedi Outcast combat system
- OpenJK modding community
- Community saber physics mods

**Available Systems:**
- Parry mechanics
- Combo animations
- Blade trail effects
- Force power implementations

---

## Part 3: Comparative Analysis

### 3.1 Feature Comparison Matrix

| Feature | Godot 4.x | Dhewm3/idTech |
|---------|-----------|---------------|
| VR-First Design | Native | Requires patching |
| Saber Physics | RigidBody/Area3D | Manual implementation |
| High-Fidelity Rendering | Vulkan + HDR | Legacy OpenGL |
| Rapid Iteration | GDScript | C++ recompilation |
| Deterministic Combat | Possible | Native architecture |
| Multiplayer Arena | WIP | Proven (Quake-style) |
| Retro Combat Feel | Needs work | Readily moddable |
| Modding Ecosystem | Growing | Decades of content |
| Learning Curve | Moderate | Steep (C++ required) |

### 3.2 Development Effort Estimation

**Godot Engine:**
```
VR Setup:           1-2 weeks (OpenXR plugin)
Basic Combat:       2-3 weeks (physics + detection)
Visual Polish:      2-4 weeks (shaders + effects)
Full Prototype:     2-3 months
```

**Dhewm3 Fork:**
```
VR Integration:     4-8 weeks (OpenXR implementation)
Combat System:      3-4 weeks (custom physics)
Renderer Updates:   4-6 weeks (modern features)
Full Prototype:     4-6 months
```

### 3.3 Risk Assessment

**Godot Risks:**
- VR performance ceiling (mitigated by optimization)
- Smaller VR asset ecosystem
- GDScript performance for complex physics

**Dhewm3 Risks:**
- No native VR support (significant integration work)
- Legacy OpenGL limitations
- Maintenance burden of custom fork
- Steeper learning curve

---

## Part 4: Recommendations

### 4.1 Recommended Stack: Godot Engine

**Primary Reasons:**
1. Native OpenXR support minimizes VR integration effort
2. Vulkan renderer provides modern visual capabilities
3. Rapid prototyping enables faster iteration
4. MIT license ensures full project ownership
5. Active community support for VR development

### 4.2 When to Consider Dhewm3

Choose Dhewm3 if:
- You want deterministic, arena-style multiplayer combat
- You prefer deep C++ engine work
- You want to study/replicate Jedi Academy-style mechanics
- You have time for significant VR integration work
- You value legacy FPS engine architecture knowledge

### 4.3 Hybrid Approach

Consider combining strengths:
- **Godot for VR layer and interaction**
- **Study Dhewm3/OpenJK for combat logic patterns**
- **Port proven saber mechanics to Godot**

---

## Part 5: Godot Implementation Architecture

### 5.1 Proposed Node Structure

```
VRGame (Node3D)
    |
    +-- XROrigin3D
    |       +-- XRCamera3D (head)
    |       +-- XRController3D (left hand)
    |       |       +-- LeftSaber
    |       +-- XRController3D (right hand)
    |               +-- RightSaber
    |
    +-- Environment
    |       +-- DojoArena (MeshInstance3D)
    |       +-- Lighting (DirectionalLight3D, OmniLight3D)
    |       +-- TrainingDroids (enemy spawner)
    |
    +-- GameSystems
            +-- CombatManager
            +-- ScoreSystem
            +-- HapticController
```

### 5.2 Lightsaber Node Composition

```
Lightsaber (RigidBody3D)
    |
    +-- HiltMesh (MeshInstance3D)
    +-- BladeMesh (MeshInstance3D)
    |       +-- EmissiveMaterial (glow shader)
    |
    +-- BladeCollider (Area3D)
    |       +-- CollisionShape3D (capsule)
    |
    +-- BladeLight (OmniLight3D)
    |       +-- color: blade_color
    |       +-- energy: modulated by activation
    |
    +-- SwingAudio (AudioStreamPlayer3D)
    |       +-- hum loop
    |       +-- swing sounds (velocity-based)
    |
    +-- ClashParticles (GPUParticles3D)
    +-- TrailEffect (custom mesh or particles)
```

### 5.3 Combat Detection Logic

```gdscript
extends Area3D

signal blade_hit(target, velocity, contact_point)

@export var damage_multiplier: float = 1.0
@export var min_swing_velocity: float = 2.0

var previous_position: Vector3
var current_velocity: Vector3

func _physics_process(delta):
    current_velocity = (global_position - previous_position) / delta
    previous_position = global_position

func _on_body_entered(body):
    if current_velocity.length() < min_swing_velocity:
        return  # Too slow, no damage

    var damage = calculate_damage(current_velocity)
    var contact = get_contact_point(body)

    blade_hit.emit(body, current_velocity, contact)
    trigger_haptic_feedback()
    spawn_clash_effect(contact)

func calculate_damage(velocity: Vector3) -> float:
    return velocity.length() * damage_multiplier
```

### 5.4 Blade Glow Shader (GLSL)

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 blade_color : source_color = vec3(0.2, 0.4, 1.0);
uniform float core_intensity : hint_range(0, 10) = 5.0;
uniform float glow_falloff : hint_range(0.1, 5.0) = 2.0;

void fragment() {
    // Core is brightest at center
    float core = 1.0 - abs(UV.x - 0.5) * 2.0;
    core = pow(core, glow_falloff);

    // Blade color with intensity
    vec3 final_color = blade_color * (1.0 + core * core_intensity);

    ALBEDO = final_color;
    EMISSION = final_color * (core + 0.5);
    ALPHA = smoothstep(0.0, 0.1, core);
}
```

---

## Part 6: Development Roadmap

### Phase 1: Foundation (Weeks 1-4)
- [ ] Godot 4.x project setup with OpenXR
- [ ] Basic VR locomotion (teleport + snap turn)
- [ ] Controller tracking and input mapping
- [ ] Simple test environment

### Phase 2: Core Combat (Weeks 5-8)
- [ ] Lightsaber model and materials
- [ ] Blade activation/deactivation
- [ ] Swing detection and velocity tracking
- [ ] Basic collision and damage system
- [ ] Haptic feedback on contact

### Phase 3: Visual Polish (Weeks 9-12)
- [ ] Blade glow shader
- [ ] Clash particle effects
- [ ] Blade trail rendering
- [ ] Dynamic lighting from blade
- [ ] Sound design (hum, swing, clash)

### Phase 4: Gameplay (Weeks 13-16)
- [ ] Training droid enemies
- [ ] Projectile deflection
- [ ] Force power system (push/pull)
- [ ] Scoring and progression
- [ ] Dojo environment design

### Phase 5: Polish (Weeks 17-20)
- [ ] Performance optimization
- [ ] Comfort options
- [ ] Menu system
- [ ] Multiple saber styles
- [ ] Audio polish

---

## Appendix A: Resource Links

### Godot VR Resources
- Godot XR Tools: https://github.com/GodotVR/godot-xr-tools
- OpenXR Plugin: https://github.com/GodotVR/godot_openxr
- Godot XR Documentation: https://docs.godotengine.org/en/stable/tutorials/xr/

### idTech Resources
- Dhewm3: https://github.com/dhewm/dhewm3
- RBDOOM3-BFG: https://github.com/RobertBeckebans/RBDOOM-3-BFG
- OpenJK: https://github.com/JACoders/OpenJK

### VR Development References
- OpenXR Specification: https://www.khronos.org/openxr/
- SteamVR Documentation: https://developer.valvesoftware.com/wiki/SteamVR

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| OpenXR | Cross-platform VR/AR API standard |
| 6DoF | Six Degrees of Freedom (position + rotation) |
| Diegetic UI | User interface elements that exist within the game world |
| BSP | Binary Space Partitioning (level geometry format) |
| GDExtension | Godot's native code extension system |
| Shadow Volumes | Technique for rendering hard-edged shadows |
| Forward+ | Rendering technique optimized for many lights |

---

*Document Version: 1.0*
*Last Updated: 2025-11-21*
