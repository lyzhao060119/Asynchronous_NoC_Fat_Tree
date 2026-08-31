#!/usr/bin/env python3
"""DATE V3 experiment orchestrator: plan / run / resume / status / archive."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from date_v3 import gitmeta  # noqa: E402
from date_v3.adapters import run_adapter  # noqa: E402
from date_v3.hashutil import load_json, sha256_json  # noqa: E402
from date_v3.manifest import config_hash_of, hashes_match, new_manifest, save_manifest  # noqa: E402
from date_v3.paths import BENCHMARKS, DESIGNS, PLANS, REGISTRY  # noqa: E402
from date_v3.registry import curated_gate, get_run, iter_manifests, upsert_run  # noqa: E402
from date_v3.schema import assert_locked_delay, validate_file  # noqa: E402


def load_design(design_id: str) -> dict:
    path = DESIGNS / ("%s.json" % design_id.lower())
    if not path.is_file():
        raise SystemExit("missing design config %s" % path)
    design = validate_file(path)
    if design.get("kind") != "fpga":
        assert_locked_delay(design["delay_recipe"], label=design_id)
    return design


def load_plan(plan_id: str) -> dict:
    path = Path(plan_id)
    if not path.is_file():
        path = PLANS / plan_id
    if not path.is_file() and not str(plan_id).endswith(".json"):
        path = PLANS / ("%s.json" % plan_id)
    if not path.is_file():
        raise SystemExit("missing plan %s" % plan_id)
    return validate_file(path)


def cmd_plan(args: argparse.Namespace) -> int:
    plan = load_plan(args.plan)
    created = 0
    skipped = 0
    for item in plan["runs"]:
        existing = get_run(item["run_id"])
        design = load_design(item["design_id"]) if item.get("design_id") else None
        config_hash = config_hash_of(design) if design else None
        incoming = new_manifest(
            run_id=item["run_id"],
            status="planned" if item["adapter"] != "import_readonly" else "imported_readonly",
            design_id=item.get("design_id"),
            benchmark_id=item.get("benchmark_id"),
            seed=item.get("seed"),
            adapter=item["adapter"],
            config_hash=config_hash,
            paper_eligible=bool(item.get("paper_eligible", False)),
            physical_class=item.get("physical_class", "unknown"),
            archive_only_reason=item.get("archive_only_reason"),
            env=item.get("env") or {},
            command=[item["adapter"]],
            notes=item.get("notes", ""),
            git=gitmeta.snapshot(),
        )
        if existing and existing.get("status") in ("pass", "imported_readonly", "archived"):
            if hashes_match(existing, incoming):
                skipped += 1
                print("SKIP", item["run_id"], existing["status"], flush=True)
                continue
        save_manifest(incoming)
        upsert_run(incoming)
        created += 1
        print("PLAN", incoming["run_id"], incoming["status"], flush=True)
    print("PLAN_DONE created=%d skipped=%d" % (created, skipped), flush=True)
    return 0


def _should_skip(existing: dict, incoming: dict) -> bool:
    if existing.get("status") != "pass":
        return False
    return hashes_match(existing, incoming)


def cmd_run(args: argparse.Namespace) -> int:
    plan = load_plan(args.plan)
    failures = 0
    for item in plan["runs"]:
        if args.only and item["run_id"] not in args.only:
            continue
        existing = get_run(item["run_id"])
        design = load_design(item["design_id"]) if item.get("design_id") else None
        incoming = new_manifest(
            run_id=item["run_id"],
            status="running",
            design_id=item.get("design_id"),
            benchmark_id=item.get("benchmark_id"),
            adapter=item["adapter"],
            config_hash=config_hash_of(design) if design else None,
            paper_eligible=bool(item.get("paper_eligible", False)),
            physical_class=item.get("physical_class", "unknown"),
            archive_only_reason=item.get("archive_only_reason"),
            env=item.get("env") or {},
            notes=item.get("notes", ""),
        )
        if existing and _should_skip(existing, incoming) and not args.force:
            print("SKIP_HASH_MATCH", item["run_id"], flush=True)
            continue
        if item["adapter"] == "import_readonly":
            incoming["status"] = "imported_readonly"
            if existing:
                incoming = existing
                incoming["status"] = "imported_readonly"
            save_manifest(incoming)
            upsert_run(incoming)
            print("IMPORT", incoming["run_id"], flush=True)
            continue
        if args.resume and existing and existing.get("status") == "pass":
            print("RESUME_SKIP_PASS", item["run_id"], flush=True)
            continue
        save_manifest(incoming)
        upsert_run(incoming)
        code = run_adapter(item, dry_run=args.dry_run)
        incoming["status"] = "pass" if code == 0 else "fail"
        if args.dry_run:
            incoming["status"] = "planned"
            incoming["notes"] = (incoming.get("notes") or "") + " dry-run"
        save_manifest(incoming)
        upsert_run(incoming)
        print("RUN", incoming["run_id"], incoming["status"], "code", code, flush=True)
        if code != 0:
            failures += 1
            if not args.keep_going:
                return code
    return 1 if failures else 0


def cmd_status(_args: argparse.Namespace) -> int:
    rows = iter_manifests()
    print("REGISTRY", REGISTRY, "runs", len(rows), flush=True)
    for manifest in rows:
        gate = curated_gate(
            manifest,
            has_traffic=bool(manifest.get("benchmark_id")),
        )
        print(
            "%s  %-18s  %-16s  paper=%s  class=%s  gate=%s"
            % (
                manifest["run_id"],
                manifest.get("status"),
                manifest.get("design_id") or "-",
                manifest.get("paper_eligible"),
                manifest.get("physical_class"),
                "OK" if not gate else ",".join(gate),
            ),
            flush=True,
        )
    return 0


def cmd_archive(args: argparse.Namespace) -> int:
    manifest = get_run(args.run_id)
    if not manifest:
        raise SystemExit("unknown run %s" % args.run_id)
    manifest["status"] = "archived"
    manifest["paper_eligible"] = False
    manifest["physical_class"] = "archive-only"
    manifest["archive_only_reason"] = args.reason
    save_manifest(manifest)
    upsert_run(manifest)
    print("ARCHIVED", args.run_id, args.reason, flush=True)
    return 0


def cmd_validate_curated(_args: argparse.Namespace) -> int:
    blocked = 0
    for manifest in iter_manifests():
        if not manifest.get("paper_eligible"):
            continue
        errors = curated_gate(manifest, has_traffic=bool(manifest.get("benchmark_id")))
        if errors:
            blocked += 1
            print("CURATED_BLOCK", manifest["run_id"], "; ".join(errors), flush=True)
    print("CURATED_GATE blocked=%d" % blocked, flush=True)
    return 1 if blocked else 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="DATE V3 experiment orchestrator")
    sub = parser.add_subparsers(dest="cmd", required=True)
    plan = sub.add_parser("plan", help="materialize manifests without submitting jobs")
    plan.add_argument("--plan", required=True)
    plan.set_defaults(func=cmd_plan)
    run = sub.add_parser("run", help="execute planned runs; skip matching hashes")
    run.add_argument("--plan", required=True)
    run.add_argument("--dry-run", action="store_true")
    run.add_argument("--force", action="store_true")
    run.add_argument("--keep-going", action="store_true")
    run.add_argument("--resume", action="store_true")
    run.add_argument("--only", nargs="*")
    run.set_defaults(func=cmd_run)
    resume = sub.add_parser("resume", help="rerun fail/running; keep passing cases")
    resume.add_argument("--plan", required=True)
    resume.add_argument("--dry-run", action="store_true")
    resume.add_argument("--keep-going", action="store_true")
    resume.set_defaults(func=cmd_run, resume=True, force=False, only=None)
    status = sub.add_parser("status", help="print registry")
    status.set_defaults(func=cmd_status)
    archive = sub.add_parser("archive", help="mark a run archive-only")
    archive.add_argument("run_id")
    archive.add_argument("--reason", required=True)
    archive.set_defaults(func=cmd_archive)
    gate = sub.add_parser("validate-curated", help="refuse curated entry without hashes")
    gate.set_defaults(func=cmd_validate_curated)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
