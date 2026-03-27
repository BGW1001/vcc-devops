"""Placeholder tests — full test suite coming in Day 3+."""


def test_package_importable():
    """Smoke test: the package directory is importable."""
    import importlib
    import os

    pkg = [
        d
        for d in os.listdir(".")
        if os.path.isdir(d) and not d.startswith(".") and d not in {"tests", "scripts"}
    ]
    for p in pkg:
        if os.path.exists(os.path.join(p, "__init__.py")):
            importlib.import_module(p)
