from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent
EXPERIMENTS = SCRIPTS.parent
REPO = EXPERIMENTS.parent.parent

CONFIGS = EXPERIMENTS / "configs"
DESIGNS = CONFIGS / "designs"
BENCHMARKS = CONFIGS / "benchmarks"
SEEDS = CONFIGS / "seeds"
PLANS = CONFIGS / "plans"
SCHEMA = CONFIGS / "schema"
REGISTRY = EXPERIMENTS / "registry"
REGISTRY_RUNS = REGISTRY / "runs"
RAW = EXPERIMENTS / "raw"
INTERMEDIATE = EXPERIMENTS / "intermediate"
CURATED = EXPERIMENTS / "curated"
FIGURES = EXPERIMENTS / "figures"
MODEL = EXPERIMENTS / "model"

CMR_SCRIPTS = REPO / "scripts" / "asic_dc" / "cmr"
PNR_SCRIPTS = REPO / "scripts" / "asic_pnr" / "cmr"
