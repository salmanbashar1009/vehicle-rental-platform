"""Export FastAPI OpenAPI schema to shared-contracts/openapi.json."""

import json
import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.main import app  # noqa: E402


def main() -> None:
    """Write deterministic OpenAPI 3.1 JSON schema."""
    target = BACKEND_ROOT.parent / "shared-contracts" / "openapi.json"
    schema = app.openapi()
    target.write_text(json.dumps(schema, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Exported OpenAPI schema to {target}")


if __name__ == "__main__":
    main()
