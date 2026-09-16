"""Fail-closed tests for the new paper64 cohort and power contracts."""
import csv
from pathlib import Path
import pytest
from run_core64_power import read_spec,pt_window,parse_power_report

def write(path,fields,rows):
 with path.open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)

def test_exact_non_sync_eight_power_points():
 spec=read_spec()
 assert len(spec['points'])==8
 assert {p['id'] for p in spec['points']}=={
  'prop_m100','pfat_m100','flatmesh_m100','dynamic_common_high',
  'static_m100','static_common_high','f16_native_m5','f16_repeated_m5'}
 assert not any(p['design'].startswith('SYNC') for p in spec['points'])

def test_f16_rejects_399_of_400(tmp_path:Path):
 rows=[{'original_event_id':i,'head_offer_ps':100+i,'tail_capture_ps':200+i}
       for i in range(64,463) for _ in range(16)]
 write(tmp_path/'latency.csv',list(rows[0]),rows)
 with pytest.raises(RuntimeError,match='400/400'):
  pt_window({'id':'f16_native_m5','suite':'multicast'},{'local_log':str(tmp_path)})

def test_f16_accepts_400_origins_and_6400_destinations(tmp_path:Path):
 rows=[{'original_event_id':i,'head_offer_ps':100+i,'tail_capture_ps':200+i}
       for i in range(64,464) for _ in range(16)]
 write(tmp_path/'latency.csv',list(rows[0]),rows)
 start,end,denom=pt_window({'id':'f16_native_m5','suite':'multicast'},{'local_log':str(tmp_path)})
 assert (start,end)==(164,663)
 assert denom=={'original_transactions':400,'useful_destination_deliveries':6400}

def test_zero_power_or_missing_unit_rejected(tmp_path:Path):
 report=tmp_path/'power.rpt'
 report.write_text('Total Power = 0 W\nCell Leakage Power = 0 W\n',encoding='utf-8')
 with pytest.raises(RuntimeError,match='unit parse'):
  parse_power_report(report)
 # PrimeTime time-based summaries may omit the suffix; the report unit is W.
 report.write_text('Total Power = 1\nCell Leakage Power = 0.2\n',encoding='utf-8')
 assert parse_power_report(report)==(0.8,0.2,1.0)
 report.write_text('Total Power = 1 W\n',encoding='utf-8')
 with pytest.raises(RuntimeError,match='unit parse'):parse_power_report(report)
