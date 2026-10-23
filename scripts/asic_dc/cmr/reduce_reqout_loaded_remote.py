"""Small remote-side reduction: full event CSV stays remote."""
import collections
import csv
import json
from pathlib import Path
import sys

folder = Path(sys.argv[1])
log = (folder / "run.log").read_text()
count = measured = 0
total_latency = 0.0
first = None
last = None
lanes = collections.Counter()
sources = collections.Counter()
with (folder / "events.csv").open() as f:
    for event in csv.DictReader(f):
        count += 1
        if event["measurement"] != "1":
            continue
        measured += 1
        total_latency += float(event["latency_ns"]) - .09
        t = float(event["input_ns"]) + float(event["latency_ns"])
        first = t if first is None else min(first, t)
        last = t if last is None else max(last, t)
        lanes[event["lane"]] += 1
        sources[event["src"]] += 1
valid = count == 48000 and measured == 40000 and "MATCHED_RESULT PASS" in log and not any(
    bad in log for bad in ("MATCHED_FAIL", "Fatal", "Error"))
valid = valid and dict(sources) == {str(i): 10000 for i in range(4)}
summary = dict(valid=valid, event_count=count, measurement_count=measured,
               mean_flit_latency_ns=total_latency/measured if measured else None,
               throughput_gflit_s=measured/(last-first) if last and first and last>first else None,
               start_ns=first, end_ns=last, lane_counts=dict(lanes), source_counts=dict(sources),
               parameters=dict(mode="aggregate", DATA_RANDOM=1, setup_ns=.05, capture_ns=.09),
               log_tail=log[-1500:] if not valid else "MATCHED_RESULT PASS")
(folder / "summary.json").write_text(json.dumps(summary, indent=2))
print(json.dumps(summary))
if not valid:
    sys.exit(2)
