"""Verify all source, config, and doc files obey the 200-line ceiling."""

from pathlib import Path

EXTENSIONS = {".py", ".dart", ".css", ".html", ".md", ".yml", ".yaml", ".toml", ".ini"}
SKIP_DIRS = {".venv", ".dart_tool", "build", "__pycache__", ".git", ".pytest_cache", ".mypy_cache"}
MAX_LINES = 200


def main() -> int:
    """Return 0 if compliant, 1 if any file exceeds MAX_LINES."""
    root = Path(__file__).resolve().parents[2]
    violations: list[tuple[Path, int]] = []
    for path in root.rglob("*"):
        if not path.is_file() or any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.suffix.lower() not in EXTENSIONS:
            continue
        count = len(path.read_text(encoding="utf-8", errors="ignore").splitlines())
        if count > MAX_LINES:
            violations.append((path.relative_to(root), count))

    if violations:
        for rel, count in sorted(violations):
            print(f"VIOLATION ({count} > {MAX_LINES}): {rel}")
        return 1
    print(f"OK: all checked files <= {MAX_LINES} lines.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
