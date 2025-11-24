#!/usr/bin/env python3
"""
Movement Dojo XR - CLI Tools

Command-line interface for testing, validation, and debugging.
"""

import argparse
import json
import math
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional


# =============================================================================
# CONFIGURATION
# =============================================================================

PROJECT_ROOT = Path(__file__).parent.parent
GODOT_PROJECT = PROJECT_ROOT / "godot_project"
SCRIPTS_DIR = GODOT_PROJECT / "scripts"
TESTS_DIR = GODOT_PROJECT / "tests"
DATA_DIR = Path.home() / ".local" / "share" / "godot" / "app_userdata" / "MovementDojoXR"


# =============================================================================
# DATA CLASSES (Mirror GDScript classes for validation)
# =============================================================================

@dataclass
class Vector3:
    x: float = 0.0
    y: float = 0.0
    z: float = 0.0

    def length(self) -> float:
        return math.sqrt(self.x**2 + self.y**2 + self.z**2)

    def distance_to(self, other: 'Vector3') -> float:
        dx = self.x - other.x
        dy = self.y - other.y
        dz = self.z - other.z
        return math.sqrt(dx**2 + dy**2 + dz**2)

    @classmethod
    def from_list(cls, lst: list) -> 'Vector3':
        return cls(lst[0], lst[1], lst[2]) if len(lst) >= 3 else cls()


@dataclass
class MovementFrame:
    """Mirror of GDScript MovementFrame for validation."""
    timestamp: float = 0.0
    frame_delta: float = 0.0
    head_position: Vector3 = None
    left_position: Vector3 = None
    right_position: Vector3 = None
    left_velocity: Vector3 = None
    right_velocity: Vector3 = None
    left_grip: float = 0.0
    right_grip: float = 0.0
    left_trigger: float = 0.0
    right_trigger: float = 0.0

    def __post_init__(self):
        self.head_position = self.head_position or Vector3()
        self.left_position = self.left_position or Vector3()
        self.right_position = self.right_position or Vector3()
        self.left_velocity = self.left_velocity or Vector3()
        self.right_velocity = self.right_velocity or Vector3()

    @classmethod
    def from_dict(cls, data: dict) -> 'MovementFrame':
        frame = cls()
        frame.timestamp = data.get('t', 0.0)
        frame.frame_delta = data.get('dt', 0.0)

        if 'head' in data:
            frame.head_position = Vector3.from_list(data['head'].get('p', [0,0,0]))
        if 'left' in data:
            frame.left_position = Vector3.from_list(data['left'].get('p', [0,0,0]))
            frame.left_velocity = Vector3.from_list(data['left'].get('v', [0,0,0]))
            frame.left_grip = data['left'].get('grip', 0.0)
            frame.left_trigger = data['left'].get('trigger', 0.0)
        if 'right' in data:
            frame.right_position = Vector3.from_list(data['right'].get('p', [0,0,0]))
            frame.right_velocity = Vector3.from_list(data['right'].get('v', [0,0,0]))
            frame.right_grip = data['right'].get('grip', 0.0)
            frame.right_trigger = data['right'].get('trigger', 0.0)

        return frame


# =============================================================================
# VALIDATORS
# =============================================================================

class ValidationError:
    def __init__(self, path: str, message: str, severity: str = "error"):
        self.path = path
        self.message = message
        self.severity = severity

    def __str__(self):
        return f"[{self.severity.upper()}] {self.path}: {self.message}"


def validate_session_file(filepath: Path) -> list[ValidationError]:
    """Validate a session JSON file."""
    errors = []

    if not filepath.exists():
        errors.append(ValidationError(str(filepath), "File does not exist"))
        return errors

    try:
        with open(filepath) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        errors.append(ValidationError(str(filepath), f"Invalid JSON: {e}"))
        return errors

    # Check required fields
    required_fields = ['session_id', 'timestamp']
    for field in required_fields:
        if field not in data:
            errors.append(ValidationError(str(filepath), f"Missing required field: {field}"))

    # Validate frames if present
    if 'frames' in data:
        frames = data['frames']
        if not isinstance(frames, list):
            errors.append(ValidationError(str(filepath), "frames must be an array"))
        else:
            prev_timestamp = -1
            for i, frame_data in enumerate(frames):
                # Check timestamp ordering
                t = frame_data.get('t', 0)
                if t < prev_timestamp:
                    errors.append(ValidationError(
                        f"{filepath}:frames[{i}]",
                        f"Timestamp out of order: {t} < {prev_timestamp}",
                        "warning"
                    ))
                prev_timestamp = t

                # Validate frame structure
                frame_errors = validate_frame_data(frame_data, f"{filepath}:frames[{i}]")
                errors.extend(frame_errors)

    # Validate stats if present
    if 'stats' in data:
        stats = data['stats']
        if 'coverage' in stats:
            coverage = stats['coverage']
            if not (0 <= coverage <= 100):
                errors.append(ValidationError(
                    f"{filepath}:stats.coverage",
                    f"Coverage out of range [0, 100]: {coverage}"
                ))

    return errors


def validate_frame_data(frame: dict, path: str) -> list[ValidationError]:
    """Validate a single frame's data."""
    errors = []

    # Check for required keys
    for key in ['head', 'left', 'right']:
        if key not in frame:
            errors.append(ValidationError(path, f"Missing key: {key}"))
            continue

        limb = frame[key]
        if 'p' not in limb:
            errors.append(ValidationError(f"{path}.{key}", "Missing position 'p'"))
        elif len(limb['p']) != 3:
            errors.append(ValidationError(f"{path}.{key}.p", "Position must have 3 components"))

    # Validate position values are reasonable
    for key in ['head', 'left', 'right']:
        if key in frame and 'p' in frame[key]:
            pos = frame[key]['p']
            for i, component in enumerate(pos):
                if abs(component) > 100:  # Sanity check
                    errors.append(ValidationError(
                        f"{path}.{key}.p[{i}]",
                        f"Position component suspiciously large: {component}",
                        "warning"
                    ))

    # Validate velocities if present
    for key in ['left', 'right']:
        if key in frame and 'v' in frame[key]:
            vel = frame[key]['v']
            speed = math.sqrt(sum(v**2 for v in vel))
            if speed > 50:  # 50 m/s is extremely fast for hand movement
                errors.append(ValidationError(
                    f"{path}.{key}.v",
                    f"Velocity suspiciously high: {speed:.2f} m/s",
                    "warning"
                ))

    return errors


def validate_gdscript(filepath: Path) -> list[ValidationError]:
    """Basic GDScript validation."""
    errors = []

    if not filepath.exists():
        errors.append(ValidationError(str(filepath), "File does not exist"))
        return errors

    with open(filepath) as f:
        content = f.read()
        lines = content.split('\n')

    # Check for class_name if it's a RefCounted or Resource
    if 'extends RefCounted' in content or 'extends Resource' in content:
        if 'class_name' not in content:
            errors.append(ValidationError(
                str(filepath),
                "RefCounted/Resource class should have class_name",
                "warning"
            ))

    # Check for missing type hints on function params (warning)
    import re
    func_pattern = re.compile(r'func\s+\w+\s*\(([^)]+)\)')
    for i, line in enumerate(lines, 1):
        match = func_pattern.search(line)
        if match:
            params = match.group(1)
            if params.strip() and ':' not in params and '=' not in params:
                errors.append(ValidationError(
                    f"{filepath}:{i}",
                    "Function parameters missing type hints",
                    "info"
                ))

    # Check for TODO/FIXME comments
    for i, line in enumerate(lines, 1):
        if 'TODO' in line or 'FIXME' in line:
            errors.append(ValidationError(
                f"{filepath}:{i}",
                f"Found TODO/FIXME: {line.strip()[:60]}...",
                "info"
            ))

    return errors


# =============================================================================
# ANALYSIS COMMANDS
# =============================================================================

def analyze_session(filepath: Path) -> dict:
    """Analyze a session file and return statistics."""
    with open(filepath) as f:
        data = json.load(f)

    frames = data.get('frames', [])
    if not frames:
        return {"error": "No frames in session"}

    # Parse frames
    parsed_frames = [MovementFrame.from_dict(f) for f in frames]

    # Calculate statistics
    duration = parsed_frames[-1].timestamp - parsed_frames[0].timestamp if len(parsed_frames) > 1 else 0

    left_speeds = [f.left_velocity.length() for f in parsed_frames]
    right_speeds = [f.right_velocity.length() for f in parsed_frames]

    stats = {
        "frame_count": len(frames),
        "duration_seconds": duration,
        "avg_frame_delta": sum(f.frame_delta for f in parsed_frames) / len(parsed_frames),
        "effective_fps": len(frames) / duration if duration > 0 else 0,
        "left_hand": {
            "avg_speed": sum(left_speeds) / len(left_speeds),
            "max_speed": max(left_speeds),
            "avg_height": sum(f.left_position.y for f in parsed_frames) / len(parsed_frames),
        },
        "right_hand": {
            "avg_speed": sum(right_speeds) / len(right_speeds),
            "max_speed": max(right_speeds),
            "avg_height": sum(f.right_position.y for f in parsed_frames) / len(parsed_frames),
        },
        "head": {
            "avg_height": sum(f.head_position.y for f in parsed_frames) / len(parsed_frames),
        }
    }

    # Add existing stats from file
    if 'stats' in data:
        stats['recorded_stats'] = data['stats']

    return stats


def find_session_files() -> list[Path]:
    """Find all session files in the data directory."""
    sessions_dir = DATA_DIR / "sessions"
    if not sessions_dir.exists():
        return []
    return sorted(sessions_dir.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)


# =============================================================================
# CLI COMMANDS
# =============================================================================

def cmd_test(args):
    """Run the test suite."""
    godot = args.godot or os.environ.get('GODOT_PATH', 'godot')

    # Check Godot exists
    try:
        result = subprocess.run([godot, '--version'], capture_output=True, text=True)
        print(f"Using Godot: {result.stdout.strip()}")
    except FileNotFoundError:
        print(f"Error: Godot not found at '{godot}'")
        print("Install Godot 4.x or specify path with --godot")
        return 1

    # Run tests
    test_script = "res://tests/test_runner.gd"
    cmd = [godot, '--headless', '--path', str(GODOT_PROJECT), '--script', test_script]

    print(f"\nRunning: {' '.join(cmd)}\n")
    result = subprocess.run(cmd)
    return result.returncode


def cmd_validate(args):
    """Validate project files."""
    errors = []
    warnings = []
    info = []

    # Validate GDScript files
    if args.scripts or args.all:
        print("Validating GDScript files...")
        for script in SCRIPTS_DIR.rglob("*.gd"):
            script_errors = validate_gdscript(script)
            for e in script_errors:
                if e.severity == "error":
                    errors.append(e)
                elif e.severity == "warning":
                    warnings.append(e)
                else:
                    info.append(e)

    # Validate session files
    if args.sessions or args.all:
        print("Validating session files...")
        for session_file in find_session_files()[:args.limit]:
            session_errors = validate_session_file(session_file)
            for e in session_errors:
                if e.severity == "error":
                    errors.append(e)
                elif e.severity == "warning":
                    warnings.append(e)
                else:
                    info.append(e)

    # Print results
    print("\n" + "="*60)

    if args.verbose:
        for i in info:
            print(f"  [INFO] {i}")

    for w in warnings:
        print(f"  [WARN] {w}")

    for e in errors:
        print(f"  [ERROR] {e}")

    print(f"\nResults: {len(errors)} errors, {len(warnings)} warnings, {len(info)} info")
    print("="*60)

    return 1 if errors else 0


def cmd_analyze(args):
    """Analyze session data."""
    if args.file:
        filepath = Path(args.file)
        if not filepath.exists():
            print(f"Error: File not found: {filepath}")
            return 1

        print(f"Analyzing: {filepath}")
        stats = analyze_session(filepath)
        print(json.dumps(stats, indent=2))

    elif args.list:
        sessions = find_session_files()
        if not sessions:
            print("No session files found")
            return 0

        print(f"Found {len(sessions)} sessions:\n")
        for i, session in enumerate(sessions[:args.limit], 1):
            mtime = session.stat().st_mtime
            size = session.stat().st_size
            print(f"  {i}. {session.name} ({size/1024:.1f} KB)")

    elif args.latest:
        sessions = find_session_files()
        if not sessions:
            print("No session files found")
            return 0

        print(f"Analyzing latest: {sessions[0]}")
        stats = analyze_session(sessions[0])
        print(json.dumps(stats, indent=2))

    else:
        print("Specify --file, --list, or --latest")
        return 1

    return 0


def cmd_lint(args):
    """Lint GDScript files."""
    print("Linting GDScript files...\n")

    issues = 0
    for script in SCRIPTS_DIR.rglob("*.gd"):
        rel_path = script.relative_to(PROJECT_ROOT)
        errors = validate_gdscript(script)

        if errors:
            print(f"{rel_path}:")
            for e in errors:
                print(f"  {e.severity}: {e.message}")
                issues += 1
            print()

    if issues == 0:
        print("No issues found!")
    else:
        print(f"\nTotal issues: {issues}")

    return 1 if issues > 0 else 0


def cmd_info(args):
    """Show project information."""
    print("Movement Dojo XR - Project Info")
    print("="*60)

    # Count files
    gd_files = list(SCRIPTS_DIR.rglob("*.gd"))
    test_files = list(TESTS_DIR.rglob("*.gd")) if TESTS_DIR.exists() else []

    print(f"\nProject Root: {PROJECT_ROOT}")
    print(f"Godot Project: {GODOT_PROJECT}")
    print(f"Data Directory: {DATA_DIR}")

    print(f"\nGDScript Files: {len(gd_files)}")
    print(f"Test Files: {len(test_files)}")

    # Count lines
    total_lines = 0
    for gd in gd_files:
        with open(gd) as f:
            total_lines += sum(1 for _ in f)
    print(f"Total Lines of Code: {total_lines:,}")

    # Session stats
    sessions = find_session_files()
    print(f"\nSaved Sessions: {len(sessions)}")

    # Script categories
    categories = {}
    for gd in gd_files:
        category = gd.parent.name
        categories[category] = categories.get(category, 0) + 1

    print("\nScripts by Category:")
    for cat, count in sorted(categories.items(), key=lambda x: -x[1]):
        print(f"  {cat}: {count}")

    return 0


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Movement Dojo XR - CLI Tools",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s test                    Run the test suite
  %(prog)s validate --all          Validate all project files
  %(prog)s analyze --latest        Analyze the latest session
  %(prog)s lint                    Lint GDScript files
  %(prog)s info                    Show project information
        """
    )

    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # Test command
    test_parser = subparsers.add_parser('test', help='Run the test suite')
    test_parser.add_argument('--godot', '-g', help='Path to Godot executable')

    # Validate command
    validate_parser = subparsers.add_parser('validate', help='Validate project files')
    validate_parser.add_argument('--all', '-a', action='store_true', help='Validate everything')
    validate_parser.add_argument('--scripts', '-s', action='store_true', help='Validate scripts')
    validate_parser.add_argument('--sessions', action='store_true', help='Validate session files')
    validate_parser.add_argument('--limit', '-n', type=int, default=10, help='Max files to check')
    validate_parser.add_argument('--verbose', '-v', action='store_true', help='Show all messages')

    # Analyze command
    analyze_parser = subparsers.add_parser('analyze', help='Analyze session data')
    analyze_parser.add_argument('--file', '-f', help='Session file to analyze')
    analyze_parser.add_argument('--list', '-l', action='store_true', help='List available sessions')
    analyze_parser.add_argument('--latest', action='store_true', help='Analyze latest session')
    analyze_parser.add_argument('--limit', '-n', type=int, default=20, help='Max items to show')

    # Lint command
    lint_parser = subparsers.add_parser('lint', help='Lint GDScript files')

    # Info command
    info_parser = subparsers.add_parser('info', help='Show project information')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 0

    commands = {
        'test': cmd_test,
        'validate': cmd_validate,
        'analyze': cmd_analyze,
        'lint': cmd_lint,
        'info': cmd_info,
    }

    return commands[args.command](args)


if __name__ == '__main__':
    sys.exit(main())
