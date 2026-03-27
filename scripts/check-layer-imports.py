#!/usr/bin/env python3
"""Layer lint check: ensure repos don't violate dependency layering.

Usage:
    python check-layer-imports.py [repo_path]

Exit codes:
    0 — all import checks passed
    1 — violations found or configuration error
"""

import os
import re
import sys

LAYER_DEFS = {
    'vcc-config': 0,
    'vcc-market-data': 1,
    'vcc-financial-models': 1,
    'vcc-nocode-quantlib': 1.5,
    'vcc-strategy-research': 2,
    'vcc-mcp-servers': 2,
    'vcc-devops': 2,
    'vcc-platform': 3,
    'vcc-ui-dashboard': 3,
}


def get_repo_layer(repo_path: str) -> float | None:
    """Extract layer number from pyproject.toml [tool.vcc-layer] section.

    Args:
        repo_path: Path to the repository root.

    Returns:
        Layer number as float, or ``None`` if not found.
    """
    pyproject = os.path.join(repo_path, 'pyproject.toml')
    if not os.path.exists(pyproject):
        print(f"❌ No pyproject.toml in {repo_path}")
        return None
    with open(pyproject) as f:
        for line in f:
            if 'layer = ' in line or 'layer=' in line:
                try:
                    return float(line.split('=')[1].strip())
                except (IndexError, ValueError):
                    pass
    return None


def check_imports(repo_path: str, current_layer: float) -> list[str]:
    """Check Python source files for illegal same-or-higher-layer imports.

    Args:
        repo_path: Path to the repository root.
        current_layer: Layer number of the repo being checked.

    Returns:
        List of violation description strings (empty if none).
    """
    violations: list[str] = []
    skip_dirs = {'tests', '.venv', '__pycache__', '.git', 'node_modules', '.tox'}

    for root, dirs, files in os.walk(repo_path):
        dirs[:] = [d for d in dirs if d not in skip_dirs]
        for file in files:
            if not file.endswith('.py'):
                continue
            filepath = os.path.join(root, file)
            try:
                with open(filepath, encoding='utf-8', errors='ignore') as f:
                    for lineno, line in enumerate(f, start=1):
                        match = re.search(r'from vcc_(\w+)|import vcc_(\w+)', line)
                        if match:
                            raw = match.group(1) or match.group(2)
                            imported_repo = 'vcc-' + raw.replace('_', '-')
                            imported_layer = LAYER_DEFS.get(imported_repo)
                            if imported_layer is not None and imported_layer >= current_layer:
                                violations.append(
                                    f"{filepath}:{lineno}: imports {imported_repo} "
                                    f"(layer {imported_layer} >= current layer {current_layer})"
                                )
            except OSError as exc:
                print(f"⚠️  Could not read {filepath}: {exc}")

    return violations


def main() -> int:
    """Entry point."""
    repo_path = sys.argv[1] if len(sys.argv) > 1 else '.'
    repo_path = os.path.abspath(repo_path)

    layer = get_repo_layer(repo_path)
    if layer is None:
        print(f"❌ Could not determine layer for {repo_path}")
        return 1

    print(f"🔍 Checking layer {layer} imports in: {repo_path}")
    violations = check_imports(repo_path, layer)

    if violations:
        print(f"\n❌ {len(violations)} layer violation(s) found:")
        for v in violations:
            print(f"   {v}")
        return 1

    print(f"✅ Layer {layer} import check passed — no violations")
    return 0


if __name__ == '__main__':
    sys.exit(main())
