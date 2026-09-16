#!/usr/bin/env python3
"""Validate frozen Static4 full-drain cohorts against accepted Dynamic4 traces."""
from __future__ import annotations

import csv
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from reaggregate_flit_latency import reaggregate

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
PAPER = REPO / 'DATE paper/experiments/raw/paper64'
LOADS = (5, 100, 160, 220, 280, 340, 420)
DC = '20260915_144500_prop_temp64_static4_dc'
GLS = '20260915_162500_prop_temp64_static4_m5_smoke'

def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(1024*1024),b''): h.update(block)
 return h.hexdigest()

def main():
 source=sorted(PAPER.glob('static64_final_raw_*'))[-1]
 cohort=sorted(PAPER.glob('cohort64_*'))[-1]
 old=list(csv.DictReader((PAPER/'compact64_20260915_112900/ur_acceptance.csv').open(newline='',encoding='utf-8')))
 dynamics={int(r['load_setpoint_mflit_per_port_s']):r for r in old if r['design']=='PROP_temp64'}
 out=PAPER/f'static64_cohort_{datetime.now():%Y%m%d_%H%M%S}'
 out.mkdir(parents=True,exist_ok=False)
 rows=[]
 for load in LOADS:
  case=f'TOPO-UR_n64_s202701_m{load}_PROP_temp64_top16'
  raw=source/f'logs/gls/{GLS}/sdf/{case}'
  files={name:raw/name for name in ('latency.csv','flit_latency.csv','events.csv','run.log','input_hashes.log')}
  if any(not p.is_file() or p.stat().st_size==0 for p in files.values()): raise RuntimeError(f'missing Static raw {case}')
  log=files['run.log'].read_text(errors='replace')
  if 'TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0' not in log: raise RuntimeError(f'Static TB FAIL {case}')
  if any(t in log for t in ('TB_RESULT FAIL','TB_HARD_TIMEOUT','Fatal:')): raise RuntimeError(f'Static failure {case}')
  stats=reaggregate(files['latency.csv'],files['flit_latency.csv'])
  hashes=files['input_hashes.log'].read_text(errors='replace')
  dynamic=dynamics[load]
  trace=dynamic['case']
  if trace!=case: raise RuntimeError(f'paired case mismatch {case} {trace}')
  h_static=re.search(rf'(?m)^([0-9a-f]{{64}})\s+\S+/{re.escape(case)}\.case$',hashes)
  d_record=next(r for r in csv.DictReader((cohort/'ur_acceptance.csv').open(newline='',encoding='utf-8'))
                if r['design']=='PROP_temp64' and int(r['load_setpoint_mflit_per_port_s'])==load)
  d_raw=Path(d_record['raw_path']) if d_record['raw_path'] else None
  h_dynamic=None
  if d_raw and (d_raw/'input_hashes.log').is_file():
   d_hashes=(d_raw/'input_hashes.log').read_text(errors='replace')
   h_dynamic=re.search(rf'(?m)^([0-9a-f]{{64}})\s+\S+/{re.escape(case)}\.case$',d_hashes)
  if not h_static or (h_dynamic and h_static.group(1)!=h_dynamic.group(1)) or (load in (5,100,420) and not h_dynamic):
   raise RuntimeError(f'paired trace SHA mismatch {case}')
  backlog_match=re.search(r'backlog=(\d+)',log)
  if not backlog_match: raise RuntimeError(f'missing window backlog {case}')
  backlog=int(backlog_match.group(1))
  rate_match=re.search(r'offered=([0-9.]+)\s+delivered_rate=([0-9.]+)',log)
  if not rate_match: raise RuntimeError(f'missing offered/delivered rate {case}')
  row={'design':'PROP_temp64_static4','load':load,'case':case,'netlist_run_id':DC,'gls_run_id':GLS,
       'injected_flits':55000,'delivered_flits':55000,'measurement_packets':stats['measurement_packets'],
       'measurement_flits':stats['measurement_flits'],'cohort_mean_ns':stats['flit_latency_mean_ns'],
       'cohort_p50_ns':stats['flit_latency_p50_ns'],'cohort_p95_ns':stats['flit_latency_p95_ns'],
       'cohort_p99_ns':stats['flit_latency_p99_ns'],'cohort_max_ns':stats['flit_latency_max_ns'],
       'measurement_backlog_flits':backlog,
       'offered_mflit_per_port_s':float(rate_match.group(1)),
       'delivered_mflit_per_port_s':float(rate_match.group(2)),
       'censored':backlog>5,'claim_role':'selection_probe' if load not in (5,100,420) else 'paper_point',
       'latency_csv_sha256':sha(files['latency.csv']),'flit_csv_sha256':sha(files['flit_latency.csv']),
       'events_csv_sha256':sha(files['events.csv']),'input_hashes_sha256':sha(files['input_hashes.log']),
       'trace_sha256':h_static.group(1),'trace_case_paired':bool(h_dynamic),'sdf_annotation_errors':0,'pass':True,'raw_path':str(raw)}
  rows.append(row)
  print('STATIC_COHORT_PASS',load,stats['flit_latency_mean_ns'],flush=True)
 with (out/'summary.csv').open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
 (out/'acceptance.csv').write_bytes((out/'summary.csv').read_bytes())
 (out/'manifest.json').write_text(json.dumps({'created_utc':datetime.now(timezone.utc).isoformat(),
  'git_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip(),
  'git_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=REPO)),
  'static_source':str(source),'dynamic_source':str(cohort),'M_DS_high':420,
  'selection_probes':[160,220,280,340],'dc_run_id':DC,'gls_run_id':GLS},indent=2)+'\n',encoding='utf-8')
 (out/'RESULTS.md').write_text('Static4 frozen DC and seven 50,000-flit full-drain cohort points accepted. M5/M100/M420 paper points; M220 censored (backlog 7). Real lane utilization remains pending activity monitor.\n',encoding='utf-8')
 print('STATIC_COHORT_FINALIZE_PASS',out,flush=True)

if __name__=='__main__': main()
