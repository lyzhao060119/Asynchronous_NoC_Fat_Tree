"""Read-only input/evidence audit. Writes only the isolated audit JSON.

Functional success and source preservation do not imply performance fidelity.
No external jobs are started, resumed or cancelled by this command.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RESULTS = ROOT / "results"
OUT = RESULTS / "rtl_reqout_model_status_20261022"


def read(path):
    return json.loads(path.read_text())


def original_emission_audit(family, name):
    bundle = ROOT / "generated_cmr/split1024_20261020" / family
    manifest = read(bundle / "audit.json")
    checked, failures = 0, []
    prefix = f"children/{name}/"
    for relative, expected in manifest["hashes"].items():
        relative = relative.replace("\\", "/")
        if not relative.startswith(prefix):
            continue
        checked += 1
        path = bundle / relative
        actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
        if actual != expected:
            failures.append(dict(path=relative, expected=expected, actual=actual))
    return dict(source=str(bundle / prefix), scope="original emitted input directory used in this experiment",
                checked=checked, valid=checked>0 and not failures, failures=failures)


def main():
    emissions = [original_emission_audit("mesh", "CMRRouter_split_l1_c1_p1_x0_y0_m1_g32_s0_a0"),
                 original_emission_audit("m16", "CMRRouter_split_l1_c1_p4_x0_y0_m0_g8_s0_a0")]
    unit = read(RESULTS / "rtl_reqout_calibration_20261022_r9_multicast_ordering/summary.json")
    multicast = read(RESULTS / "rtl_reqout_calibration_20261022_r12_unique_multicast/summary.json")
    loaded = read(RESULTS / "rtl_reqout_calibration_20261022_r11_loaded_validation/comparison.json")
    unit_keys = {(row["kind"], row["test"]) for row in unit}
    expected_unit = {(kind,test) for kind in ("thin","c1p4") for test in
                     ("isolated","packet","continuous","backpressure","contention")}
    mc_keys = {(row["kind"],row["branch_ack_ns"]) for row in multicast}
    expected_mc = {(kind,delay) for kind in ("thin","c1p4") for delay in (0.,.5,2.)}
    unit_valid = len(unit)==10 and unit_keys==expected_unit and all(
        row["valid"] and row["count"]==row["expected"] for row in unit)
    mc_valid = len(multicast)==6 and mc_keys==expected_mc and all(
        row["valid"] and row["delivered"]==row["expected"] and row["input_flits"]==100
        and row["log_sha256"] for row in multicast)
    payload_evidence = []
    for kind in ("thin", "c1p4"):
        code = (RESULTS / "rtl_reqout_calibration_20261022_r12_unique_multicast" / kind / "tb_model_multicast.sv").read_text()
        payload_evidence.append(dict(kind=kind, distinct_body_generator="if(flit!=0) v[25:2]=" in code,
                                     generator_sha256=hashlib.sha256(code.encode()).hexdigest()))
    loaded_coverage = len(loaded)==2 and {x["kind"] for x in loaded}=={"thin","c1p4"}
    report = dict(
        source_inputs=emissions,
        unicast_functional_audit=dict(valid=unit_valid, checked=len(unit)),
        multicast_functional_audit=dict(valid=mc_valid, checked=len(multicast), payload_evidence=payload_evidence),
        loaded_comparison=dict(coverage_complete=loaded_coverage, rows=loaded,
                               accuracy_accepted=False, reason="material c1p4 latency/throughput and lane-utilization mismatch"),
        original_emission_inputs_preserved=all(row["valid"] for row in emissions),
        functional_evidence_complete=unit_valid and mc_valid and all(x["distinct_body_generator"] for x in payload_evidence),
        goal_complete=False, full_network_deployment_approved=False,
        next_decision="confirm isolated stage-level timing modelling beyond ReqOut-only delay; no production RTL modification",
        limitations=["calibration inputs are not independent validation", "Mesh uses Thin timing approximation",
                     "no in-flight reset support", "not STA/SDF/power signoff", "no full-network adoption"],
    )
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / "delivery_audit.json"
    target.write_text(json.dumps(report, indent=2))
    print(json.dumps(dict(original_emission_inputs_preserved=report["original_emission_inputs_preserved"],
                          original_input_files_checked=sum(x["checked"] for x in emissions),
                          unicast_valid=unit_valid,multicast_valid=mc_valid,
                          loaded_accuracy_accepted=False, goal_complete=False, audit=str(target))))
    if not report["original_emission_inputs_preserved"] or not report["functional_evidence_complete"] or not loaded_coverage:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
