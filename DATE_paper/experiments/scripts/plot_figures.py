"""Plot DATE figures from curated tables only.  Phase 13 fills in the artists."""
from __future__ import annotations

from pathlib import Path

from date_v3.paths import CURATED, FIGURES


def main() -> int:
    if not any(CURATED.glob("*.csv")) and not (CURATED / "table_i_implementation.csv").is_file():
        print("PLOT_SKIP no curated CSV yet; refusing to invent figures")
        FIGURES.mkdir(parents=True, exist_ok=True)
        (FIGURES / "plot_metadata.json").write_text(
            '{"source": "curated", "status": "empty"}\n', encoding="utf-8"
        )
        return 0
    print("PLOT_TODO implement artists after Table I / Fig A/B/C CSV exist")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
