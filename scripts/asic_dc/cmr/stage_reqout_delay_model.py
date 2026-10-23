"""Build isolated, simulation-only Router Req delay calibration inputs.

Never writes src/ or the emitted input directories. Delays are additive, not
substitutes for SDF. Mesh may use the Thin target only as a modelling assumption.
"""
import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stage(kind, destination):
    geometry = "c1_p1" if kind == "thin" else "c1_p4"
    family = "mesh" if kind == "thin" else "m16"
    suffix = "m1_g32" if kind == "thin" else "m0_g8"
    name = f"CMRRouter_split_l1_{geometry}_x0_y0_{suffix}_s0_a0"
    source = ROOT / "generated_cmr/split1024_20261020" / family / "children" / name
    if not source.is_dir():
        raise RuntimeError(f"Missing frozen emitted reference: {source}")
    out = destination / kind
    out.mkdir(parents=True, exist_ok=False)
    inputs = {}
    for file in source.glob("*.v"):
        inputs[str(file.relative_to(ROOT))] = sha(file)
        shutil.copy2(file, out / file.name)
    main = out / f"{name}.v"
    text = main.read_text()
    match = re.search(r"module " + re.escape(name) + r"\((.*?)\n\);", text, re.S)
    if not match:
        raise RuntimeError("Cannot bind emitted top header")
    header = match.group(1)
    ports = re.findall(r"\b(input|output)\s+(?:\[[^]]+\]\s*)?(\w+)", header)
    delayed = [p for direction, p in ports
               if direction == "output" and p.startswith("io_outputs_") and p.endswith("_HS_Req")]
    expected = 5 if kind == "thin" else 8
    if len(delayed) != expected:
        raise RuntimeError(f"Req binding mismatch: {delayed}")
    main.write_text(text[:match.start()] + text[match.start():].replace(
        f"module {name}(", "module CMRRouterRaw(", 1))
    lines = ["`timescale 1ns/1ps", "module CMRRouter(" + header + "\n);",
             "  realtime req_delay_ns = 0.0;",
             '  initial begin if ($value$plusargs("REQOUT_DELAY_NS=%f", req_delay_ns)) begin end',
             '    if (req_delay_ns < 0) $fatal(1, "Negative Req delay"); end']
    for p in delayed:
        lines += [f"  wire raw_{p};", f"  reg delayed_{p} = 0;",
                  f"  assign {p} = delayed_{p};",
                  # Nonblocking intra-assignment delay preserves both phases.
                  f"  always @(raw_{p}) delayed_{p} <= #(req_delay_ns) raw_{p};"]
    lines += ["  CMRRouterRaw raw ("]
    lines += ["    ." + p + "(" + ("raw_" + p if p in delayed else p) + ")" +
              ("," if i + 1 < len(ports) else "") for i, (_, p) in enumerate(ports)]
    lines += ["  );", "endmodule"]
    (out / "CMRRouter.v").write_text("\n".join(lines) + "\n")
    tb = ROOT / "scripts/asic_dc/cmr/results/single_router_latency_power_20261022_r3/inputs/tb_router_matched_ppa_async.sv"
    shutil.copy2(tb, out / tb.name)
    binds = ROOT / "scripts/asic_dc/cmr/hop_binds"
    shutil.copytree(binds, out / "hop_binds")
    manifest = {"kind": kind, "scope": "simulation model; not STA/SDF signoff",
                "isolated_target_ns": .6556 if kind == "thin" else .7922,
                "packet_target_ns": 3.710 if kind == "thin" else 4.907,
                "delayed_ports": delayed, "source_sha256": inputs,
                "tb_sha256": sha(tb), "reset_contract": "reset only before traffic; no in-flight reset",
                "mesh_assumption": "Mesh RTL fitted to Thin target, not measured Mesh timing"}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print(json.dumps({"staged": str(out), "req_ports": len(delayed)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    for kind in ("thin", "c1p4"):
        stage(kind, args.out.resolve())
