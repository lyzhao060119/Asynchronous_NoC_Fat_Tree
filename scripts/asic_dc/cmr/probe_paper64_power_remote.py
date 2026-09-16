#!/usr/bin/env python3
"""Read-only inventory of existing canonical inputs for the eight-point power run."""
import os
from pathlib import Path
from run_remote_cmr_fat_tree_noc16_sdf import connect

ROOT = '/home/ghy19/Asynchronous_Router_CMR'
NEED = {
 'PROP_temp64': '20260913_prop_temp64_asap_uc_m5_200',
 'PROP_temp64_static4': '20260915_144500_prop_temp64_static4_dc',
 'PFAT64': '20260915_080229_cmr_pfat64_rpsdel050_1248',
 'FM64': '20260913_104506_cmr_fm64_rpsdel150',
}
CASES = [
 'TOPO-UR_n64_s202701_m100_PROP_temp64_top16',
 'TOPO-UR_n64_s202701_m420_PROP_temp64_top16',
 'TOPO-UR_n64_s202701_m100_PFAT64_top8',
 'TOPO-UR_n64_s202701_m100_FM64_top0',
 'MC-REGION-F16_n64_s202701_m5_PROP_temp64_top16',
 'MC-REGION-F16_n64_s202701_m5_source_repeated_unicast_top16',
]

def main():
 os.environ.setdefault('C1_HOST', '192.168.2.8')
 client=connect(attempts=2); sftp=client.open_sftp()
 try:
  for design, run in NEED.items():
   out=f'{ROOT}/outputs/{run}'
   try: names=sftp.listdir(out)
   except IOError: names=[]
   print('NETLIST',design,run,names,flush=True)
   for report_root in (f'{ROOT}/reports/{run}',f'{ROOT}/reports/dc/{run}',f'{ROOT}/logs/dc/{run}'):
    try: print('DC_REPORT_ROOT',design,report_root,sftp.listdir(report_root)[:30],flush=True)
    except IOError: pass
   try:
    path=f'{ROOT}/reports/dc/{run}/qor.rpt';size=sftp.stat(path).st_size
    with sftp.file(path,'rb') as f:
     f.seek(max(0,size-3500))
     print('QOR_TAIL',design,f.read().decode(errors='replace')[-2500:],flush=True)
   except IOError: pass
  try:
   for d in sftp.listdir(f'{ROOT}/outputs'):
    if 'pfat64' in d.lower() or '1248' in d.lower():
     try: print('PFAT_OUTPUT_CANDIDATE',d,sftp.listdir(f'{ROOT}/outputs/{d}'),flush=True)
     except IOError: pass
  except IOError: pass
  roots=[f'{ROOT}/sim', f'{ROOT}/sim/tb', f'{ROOT}/sim/cases_noc64']
  try: roots += [f'{ROOT}/sim/{d}' for d in sftp.listdir(f'{ROOT}/sim') if d.startswith(('prop_temp64_', 'paper64_', 'pfat64_', 'fm64_'))]
  except IOError: pass
  for root in roots:
   for sub in ('', '/cases'):
    path=root+sub
    try: names=set(sftp.listdir(path))
    except IOError: continue
    matches=[c for c in CASES if c+'.case' in names]
    if matches: print('CASE_ROOT',path,matches,flush=True)
  for root in (f'{ROOT}/sim/tb', f'{ROOT}/scripts/asic_dc/cmr', f'{ROOT}/scripts/asic_dc/power'):
   try: print('INPUT_ROOT',root,sftp.listdir(root)[:80],flush=True)
   except IOError: pass
  required=['sim/tb/tb_noc64_async_boundary.sv','sim/tb/tb_cmr_noc64_async_boundary_failfast.sv',
    'sim/tb/tb_prop_temp64_lane_monitor.sv','sim/tb/async_prop_temp64_port_adapter.sv',
    'sim/tb/async_noc64_mesh_port_adapter.sv','sim/tb/async_noc64_port_adapter.sv',
    'scripts/run_ptpx_cmr_mesh_power.tcl']
  for r in required:
   try: print('INPUT',r,sftp.stat(f'{ROOT}/{r}').st_size,flush=True)
   except IOError: print('INPUT_MISSING',r,flush=True)
  f16=f'{ROOT}/logs/gls/20260914_prop_temp64_mc_f16_main/sdf/MC-REGION-F16_n64_s202701_m5_PROP_temp64_top16'
  for name in ('latency.csv','events.csv','result.csv','run.log'):
   try:
    with sftp.file(f'{f16}/{name}','rb') as f: print('F16_HEAD',name,f.read(1500).decode(errors='replace')[:600],flush=True)
   except IOError: print('F16_MISSING',name,flush=True)
  for scheme in ('PROP_temp64','source_repeated_unicast'):
   name=f'MC-REGION-F16_n64_s202701_m5_{scheme}_top16'
   path=f'{ROOT}/logs/gls/20260914_prop_temp64_mc_f16_main/sdf/{name}/latency.csv'
   _,stdout,_=client.exec_command('wc -l '+path)
   print('F16_LATENCY_ROWS',scheme,stdout.read().decode(errors='replace').strip(),flush=True)
 finally: sftp.close(); client.close()

if __name__=='__main__': main()
