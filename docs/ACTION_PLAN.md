# Movement Dojo XR - Action Plan

## Quick Assessment

| Area | Status | Priority Actions |
|------|--------|------------------|
| OpenXR Integration | 100% | None needed |
| Lightsaber/Combat | 95% | Minor polish |
| Proprioception Training | 95% | Externalize definitions |
| glTF Pipeline | 70% | Document workflow |
| **Data-Driven Content** | **60%** | **Phase 1 complete, add YAML/JSON** |
| **USD Integration** | **0%** | **High priority** |
| **CI/CD & Tooling** | **10%** | **High priority** |

---

## Immediate Actions (Next Sprint)

### 1. Training Definition System
**Status: Phase 1 Complete ✓**

**Completed (Phase 1 - .tres Resources):**
- ✅ Created `resources/training_sequences/` directory
- ✅ Updated `SequenceLibrary` to load from .tres files
- ✅ Added validation on load with fallback to factory methods
- ✅ Created `export_training_sequences.gd` tool
- ✅ Comprehensive README.md documentation

**Next Steps (Phase 2 - YAML/JSON):**
Create `training_definitions/` directory structure:
```
training_definitions/
├── schema.json          # JSON Schema for validation
├── sequences/
│   ├── level1_fundamentals.yaml
│   └── level2_intermediate.yaml
└── README.md
```

Implement YAML converter:
```
godot_project/scripts/core/training_definition_loader.gd
```

**Current Usage:**
```bash
# Export sequences to .tres files
godot --headless --script res://tools/export_training_sequences.gd

# Sequences auto-load from:
# res://resources/training_sequences/{sequence_id}.tres
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

| File | Purpose | Priority | Status |
|------|---------|----------|--------|
| `training_definitions/schema.json` | Training def validation | HIGH | PENDING |
| `godot_project/scripts/core/training_definition_loader.gd` | Load external defs | HIGH | PENDING |
| `godot_project/resources/training_sequences/*.tres` | Sequence resources | HIGH | ✅ DONE |
| `godot_project/tools/export_training_sequences.gd` | Export tool | HIGH | ✅ DONE |
| `.github/workflows/ci.yml` | Automated testing | HIGH | PENDING |
| `docs/ASSET_PIPELINE.md` | Artist documentation | MEDIUM | PENDING |
| `tools/movement_dojo_cli.py` | Developer tools | MEDIUM | PENDING |
| `godot_project/scripts/core/mod_loader.gd` | Community content | MEDIUM | PENDING |
| `godot_project/scripts/core/usd_metadata_loader.gd` | USD integration | MEDIUM | PENDING |
| `godot_project/scripts/core/performance_manager.gd` | Auto quality | MEDIUM | PENDING |

---

## Success Criteria

**Phase 1 Complete:**
- [x] Training sequences externalized to .tres files ✓
- [x] Resource loading system with validation ✓
- [x] Export tool and documentation ✓
- [ ] 3+ training exercises defined (1/3 complete: level1_fundamentals)
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
