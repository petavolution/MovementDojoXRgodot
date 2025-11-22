# Movement Dojo XR - Testing Guide

This document describes the testing infrastructure and workflows for ensuring core engine stability.

## Quick Start

```bash
# Run all tests (requires Godot 4.x installed)
./tools/run_tests.sh

# Or with custom Godot path
./tools/run_tests.sh -g /path/to/godot

# Using Python CLI
python tools/dojo_cli.py test

# Validate project files
python tools/dojo_cli.py validate --all

# Lint GDScript
python tools/dojo_cli.py lint
```

## Test Architecture

```
godot_project/tests/
├── test_runner.gd          # Main headless test runner
├── unit/                   # Unit tests for individual components
│   ├── test_movement_frame.gd
│   ├── test_score_system.gd
│   └── ...
└── integration/            # Integration tests for data flow
    ├── test_data_pipeline.gd
    └── ...

tools/
├── run_tests.sh            # Shell script test runner
└── dojo_cli.py             # Python CLI for testing & validation
```

## Running Tests

### Method 1: Shell Script (Recommended)

```bash
# Basic usage
./tools/run_tests.sh

# Specify Godot path
./tools/run_tests.sh -g /usr/local/bin/godot4

# Via environment variable
GODOT_PATH=/path/to/godot ./tools/run_tests.sh

# Verbose output
./tools/run_tests.sh -v
```

### Method 2: Python CLI

```bash
# Run tests
python tools/dojo_cli.py test

# With custom Godot path
python tools/dojo_cli.py test --godot /path/to/godot
```

### Method 3: Direct Godot

```bash
cd godot_project
godot --headless --script res://tests/test_runner.gd
```

## Test Output

Tests produce output in this format:

```
============================================================
Movement Dojo XR - Test Suite
============================================================

[SUITE] MovementFrame
  [PASS] create_timestamp
  [PASS] create_delta
  [PASS] velocity_computation_x
  [FAIL] some_failing_test
         Expected: 100
         Got:      99

[SUITE] ScoreSystem
  [PASS] combo_mult_0
  ...

============================================================
RESULTS: 45 passed, 1 failed, 46 total
============================================================
```

Exit codes:
- `0` = All tests passed
- `1` = One or more tests failed

## Test Categories

### Unit Tests

Test individual components in isolation.

| Test Class | System Under Test | Key Tests |
|------------|-------------------|-----------|
| `TestMovementFrame` | `MovementFrame` | Velocity computation, derived metrics, serialization |
| `TestScoreSystem` | `ScoreManager` | Combo multipliers, point calculation, accuracy |
| `TestMovementSpaceMap` | `MovementSpaceMap` | Grid math, coverage, symmetry |
| `TestProprioceptionMath` | Math utilities | Position deviation, rotation deviation |
| `TestHapticPatterns` | `HapticPatterns` | Pattern structure, amplitude bounds |
| `TestSerialization` | JSON round-trips | Frame and map serialization |

### Integration Tests

Test data flow between components.

| Test Class | Flow Under Test | Key Tests |
|------------|-----------------|-----------|
| `TestDataPipeline` | Frame → SpaceMap → Analytics | Session simulation, coverage tracking |
| `TestDataFlow` | End-to-end data flow | Multi-frame processing |

## Writing New Tests

### 1. Create Test Class

```gdscript
## Unit Tests for MySystem
extends RefCounted
class_name TestMySystem


static func run_all() -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    results.append_array(_test_basic_functionality())
    results.append_array(_test_edge_cases())
    return results


static func _test_basic_functionality() -> Array[Dictionary]:
    var results: Array[Dictionary] = []

    # Test case
    var actual := MySystem.compute_something(10)
    results.append(_eq(actual, 100, "compute_basic"))

    return results


# Test helpers
static func _eq(actual, expected, name: String) -> Dictionary:
    return {
        "name": name,
        "suite": "MySystem",
        "passed": actual == expected,
        "expected": expected,
        "actual": actual
    }

static func _near(actual: float, expected: float, epsilon: float, name: String) -> Dictionary:
    return {
        "name": name,
        "suite": "MySystem",
        "passed": abs(actual - expected) <= epsilon,
        "expected": expected,
        "actual": actual,
        "message": "epsilon=" + str(epsilon)
    }

static func _true(condition: bool, name: String) -> Dictionary:
    return {
        "name": name,
        "suite": "MySystem",
        "passed": condition,
        "expected": true,
        "actual": condition
    }
```

### 2. Register in Test Runner

Edit `tests/test_runner.gd`:

```gdscript
func _run_all_tests() -> void:
    # ... existing tests ...
    _run_suite("MySystem", TestMySystem.run_all())
```

### 3. Test Naming Conventions

- Test classes: `TestSystemName` (e.g., `TestMovementFrame`)
- Test methods: `_test_category()` (e.g., `_test_velocity_computation`)
- Test names: `snake_case` descriptive name (e.g., `"velocity_left_x"`)

## Python CLI Tools

### Validate Project

```bash
# Validate all (scripts + sessions)
python tools/dojo_cli.py validate --all

# Just scripts
python tools/dojo_cli.py validate --scripts

# Just session files
python tools/dojo_cli.py validate --sessions

# Verbose (show info messages)
python tools/dojo_cli.py validate --all --verbose
```

### Lint GDScript

```bash
python tools/dojo_cli.py lint
```

Checks for:
- Missing `class_name` on RefCounted classes
- Missing type hints on function parameters
- TODO/FIXME comments

### Analyze Session Data

```bash
# List saved sessions
python tools/dojo_cli.py analyze --list

# Analyze latest session
python tools/dojo_cli.py analyze --latest

# Analyze specific file
python tools/dojo_cli.py analyze --file /path/to/session.json
```

### Project Info

```bash
python tools/dojo_cli.py info
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download Godot
        run: |
          wget -q https://downloads.tuxfamily.org/godotengine/4.2.2/Godot_v4.2.2-stable_linux.x86_64.zip
          unzip -q Godot_v4.2.2-stable_linux.x86_64.zip
          chmod +x Godot_v4.2.2-stable_linux.x86_64

      - name: Run tests
        run: |
          ./Godot_v4.2.2-stable_linux.x86_64 --headless \
            --path godot_project \
            --script res://tests/test_runner.gd

      - name: Validate scripts
        run: python tools/dojo_cli.py validate --scripts
```

## Core Systems Tested

### MovementFrame

Tests for the frame capture data structure:

- **Creation**: Timestamp, delta, positions correctly stored
- **Velocity Computation**: Linear velocity from position delta
- **Angular Velocity**: Quaternion difference to angular velocity
- **Derived Metrics**: Reach distance, height relative to head
- **Serialization**: to_dict() / from_dict() round-trip

### MovementSpaceMap

Tests for the 3D movement coverage grid:

- **Grid Math**: Cell coordinate conversions, index calculations
- **Recording**: New cell detection, visit counting
- **Coverage**: Percentage calculation, hand-specific coverage
- **Symmetry**: Left/right balance scoring
- **Directional Coverage**: Zone categorization (overhead, front, etc.)

### ScoreManager

Tests for the scoring/combo system:

- **Combo Multiplier**: Threshold-based multiplier tiers
- **Combo Bonus**: End-of-combo bonus calculation
- **Point Calculation**: With combo and base multipliers
- **Accuracy**: Hit/miss percentage
- **Hit Registration**: Points for hits, destruction, perfect swings
- **Deflection Scoring**: Deflection and deflect-kill points

### ProprioceptionSystem

Tests for position tracking math:

- **Position Deviation**: Distance from target
- **Rotation Deviation**: Angular difference
- **Tolerance Checking**: Within/outside tolerance
- **Accuracy from Deviation**: Percentage calculation
- **Position Adjustment**: Scale for player height

### HapticPatterns

Tests for haptic feedback patterns:

- **Pattern Structure**: Required fields present
- **Amplitude Bounds**: 0.0 to 1.0 range
- **Duration**: Positive values
- **Frequency**: Reasonable Hz range
- **Velocity Intensity**: Speed-based intensity mapping

## Debugging Test Failures

### 1. Run Single Suite

Edit `test_runner.gd` temporarily:

```gdscript
func _run_all_tests() -> void:
    # Comment out other suites
    _run_suite("MovementFrame", TestMovementFrame.run_all())
    # _run_suite("ScoreSystem", TestScoreSystem.run_all())
```

### 2. Add Debug Output

In test class:

```gdscript
static func _test_something() -> Array[Dictionary]:
    var results: Array[Dictionary] = []

    var value := compute_something()
    print("DEBUG: value = ", value)  # Temporary debug

    results.append(_eq(value, expected, "test_name"))
    return results
```

### 3. Run Interactively

```bash
# Run with verbose Godot output
godot --headless --verbose --script res://tests/test_runner.gd
```

## Test Coverage Goals

| System | Coverage Goal | Current |
|--------|---------------|---------|
| MovementFrame | >90% | ~85% |
| MovementSpaceMap | >90% | ~80% |
| ScoreManager | >95% | ~90% |
| ProprioceptionSystem | >80% | ~70% |
| HapticPatterns | >80% | ~75% |
| Serialization | >95% | ~90% |
| Integration | >70% | ~60% |

## Best Practices

1. **Test Pure Functions First**: Start with math/calculation tests
2. **Avoid External Dependencies**: Tests should not require XR hardware
3. **Use Deterministic Data**: Avoid randomness in tests
4. **Test Edge Cases**: Zero values, negative values, max values
5. **Test Serialization**: Every data class should round-trip correctly
6. **Keep Tests Fast**: Target <5 seconds for full suite
7. **Name Tests Clearly**: Test name should describe expected behavior
