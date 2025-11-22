# Movement Dojo XR - Action Plan

## Quick Assessment

| Area | Status | Priority Actions |
|------|--------|------------------|
| OpenXR Integration | 100% | None needed |
| Lightsaber/Combat | 95% | Minor polish |
| Proprioception Training | 95% | Externalize definitions |
| glTF Pipeline | 70% | Document workflow |
| **USD Integration** | **0%** | **High priority** |
| **Data-Driven Content** | **20%** | **High priority** |
| **CI/CD & Tooling** | **10%** | **High priority** |

---

## Immediate Actions (Next Sprint)

### 1. Training Definition System
**Estimated effort: 3-4 days**

Create `training_definitions/` directory structure:
```
training_definitions/
├── schema.json          # JSON Schema for validation
├── posture/
│   └── ready_stance.yaml
├── paths/
│   └── basic_arc.yaml
└── katas/
    └── beginner_form_1.yaml
```

Implement loader:
```
godot_project/scripts/core/training_definition_loader.gd
```

### 2. CI/CD Pipeline Setup
**Estimated effort: 1 day**

Create `.github/workflows/ci.yml`:
- GDScript linting
- Training definition validation
- Automated Linux build
- OpenXR overlay build

### 3. Asset Pipeline Documentation
**Estimated effort: 1 day**

Create `docs/ASSET_PIPELINE.md`:
- Blender export settings
- Material conventions
- Naming standards

---

## Short-term Actions (Next 2 Weeks)

### 4. USD Metadata Integration
**Estimated effort: 3-5 days**

Options (choose one):
- **Option A**: Python USDA text parser (simplest)
- **Option B**: GDExtension with Pixar USD (most powerful)
- **Option C**: External USD → JSON converter (balanced)

Target: Parse USD for spawn points, paths, and training zones.

### 5. CLI Toolchain
**Estimated effort: 2-3 days**

Create `tools/movement_dojo_cli.py`:
```bash
python tools/cli.py validate-training training_definitions/
python tools/cli.py pack-content my_mod/ -o my_mod.zip
```

### 6. Performance Manager
**Estimated effort: 2 days**

Create adaptive quality system:
- Monitor frame time
- Auto-adjust quality level
- Implement graphics presets

---

## Medium-term Actions (Next Month)

### 7. Mod Loading System
- Content pack discovery
- Manifest validation
- Hot-loading support

### 8. USD Training Schema
- Custom USD schemas for exercises
- Variant sets for difficulty
- Layer composition for sessions

### 9. Comprehensive Testing
- Unit tests for scoring math
- Integration tests for training modules
- VR sanity check automation

---

## Key Files to Create

| File | Purpose | Priority |
|------|---------|----------|
| `training_definitions/schema.json` | Training def validation | HIGH |
| `godot_project/scripts/core/training_definition_loader.gd` | Load external defs | HIGH |
| `.github/workflows/ci.yml` | Automated testing | HIGH |
| `docs/ASSET_PIPELINE.md` | Artist documentation | MEDIUM |
| `tools/movement_dojo_cli.py` | Developer tools | MEDIUM |
| `godot_project/scripts/core/mod_loader.gd` | Community content | MEDIUM |
| `godot_project/scripts/core/usd_metadata_loader.gd` | USD integration | MEDIUM |
| `godot_project/scripts/core/performance_manager.gd` | Auto quality | MEDIUM |

---

## Success Criteria

**Phase 1 Complete:**
- [ ] 3+ training exercises defined in YAML
- [ ] CI pipeline runs on every PR
- [ ] Asset pipeline documented

**Phase 2 Complete:**
- [ ] USD metadata parsed for 1 training zone
- [ ] CLI validates training definitions
- [ ] Performance manager active

**Phase 3 Complete:**
- [ ] Mod system loads community content
- [ ] Full USD authoring workflow documented
- [ ] Platform ready for community contributions

---

## Architecture Decisions

### Training Definition Format: YAML
**Rationale**: Human-readable, easy to edit, well-supported

### USD Role: Metadata + Scene Authoring
**Rationale**: Leverage USD for complex scene composition while keeping glTF for runtime efficiency

### CI Platform: GitHub Actions
**Rationale**: Native integration, free for open source, extensive action marketplace

---

## Risk Mitigations

| Risk | Mitigation |
|------|------------|
| USD complexity | Start with metadata-only parsing |
| Performance regression | Add benchmarks to CI |
| Breaking content changes | Version manifest format |
| Scope creep | Focus on tooling before features |

---

## Next Steps

1. **Today**: Review this plan and prioritize
2. **This week**: Implement training definition system
3. **Next week**: Set up CI/CD pipeline
4. **Following weeks**: USD integration + CLI tools

The project is already strong on gameplay and XR mechanics. Focus investment on **infrastructure and content tools** to unlock community contribution and rapid iteration.
