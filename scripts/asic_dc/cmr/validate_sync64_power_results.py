"""Compute-node acceptance audit; leaves all experiment inputs untouched."""
import csv, json, re, traceback
from pathlib import Path
from audit_power_vcd_coverage import audit

ROOT=Path('/prjtemp/ghy19/formal64_power_supplement/20261021_sync_and_broadcast_r1')
OUT=Path(__file__).resolve().parent

def read(p):return p.read_text(errors='replace') if p.is_file() else ''

def main():
    repair=json.loads((ROOT/'repair_submission_r2.json').read_text())
    original={j['tag']:j for j in json.loads((ROOT/'manifest.json').read_text())['jobs']}
    frozen=json.loads((ROOT/'frozen_inputs.json').read_text())['SYNC_M16']
    results=[]
    for j in repair['jobs']:
        if not j['tag'].startswith('SYNC_M16'):continue
        meta=original[j['tag']];a=Path(meta['activity_dir']);report=Path(j['report_dir'])
        run=read(a/'run.log');stdout=read(a/'stdout.log');px=read(Path(j['ptpx_log']))
        v=dict(tag=j['tag'],benchmark=meta['benchmark'],seed=meta['seed'],load=meta['load'])
        v['simulation_pass']=bool(re.search(r'TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0',run))
        # Multicast delivery count can exceed original injected flits.
        if meta['benchmark'].startswith(('MULTICAST','ALL-')):
            v['simulation_pass']=bool(re.search(r'TB_RESULT PASS injected=55000 delivered=[1-9][0-9]* missing=0 unexpected=0 timeout=0',run))
        v['timing_or_protocol_error']=bool(re.search(r'Timing violation|TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_STALL_FAIL|TB_HARD_TIMEOUT|TB_FATAL|Fatal:',run+'\n'+stdout))
        v['sdf_annotation_clean']=bool(re.search(r'Total errors:\s*0\b',read(a/'sdf_annotate.log')))
        v['ptpx_pass']='FORMAL64_PTPX_CASE_PASS' in px
        v['pt_errors']=[l for l in px.splitlines() if l.startswith('Error:')]
        v['unclassified_pt_errors']=[l for l in v['pt_errors'] if '(PT-063)' not in l]
        v['activity_full']=bool(re.search(r'Nets\s+\d+\(100\.00%\)',read(report/'activity.rpt')))
        v['reports_present']=all((report/n).is_file() and (report/n).stat().st_size>0 for n in ['power.rpt','power_hierarchy.rpt','power_cells.rpt','activity.rpt','check_power.rpt'])
        hashes={}
        for l in read(report/'input_hashes.sha256').splitlines():
            if len(l)>66:hashes[l[66:]]=l[:64]
        required={p:h for p,h in frozen.items() if p.endswith(('.ddc','_post.v','.sdf'))}
        v['frozen_design_hashes_match']=len(required)==3 and all(hashes.get(p)==h for p,h in required.items())
        v['archive_present']=(a/'measurement.vcd.archive.json').is_file()
        if v['ptpx_pass'] and v['archive_present']:
            try:v['waveform']=audit(dict(meta,variant='sync_m16_current'))
            except Exception as e:v['waveform']={'status':'AUDIT_ERROR','error':str(e),'traceback':traceback.format_exc()}
        else:v['waveform']={'status':'NOT_READY'}
        v['record_integrity_pass']=all(v[k] for k in ['simulation_pass','sdf_annotation_clean','ptpx_pass','activity_full','reports_present','frozen_design_hashes_match','archive_present']) and not v['timing_or_protocol_error'] and not v['unclassified_pt_errors'] and v['waveform']['status']=='BOUNDARY_COVERAGE_OK' and v['waveform'].get('archive_hash_matches') is True
        v['acceptance']='PROVISIONAL_LIBRARY_WARNING' if v['record_integrity_pass'] and v['pt_errors'] else 'RECORD_ACCEPTED' if v['record_integrity_pass'] else 'INCOMPLETE_OR_FAILED'
        power=read(report/'power.rpt');m=re.search(r'Total Power\s*=\s*([\d.eE+-]+)',power)
        if m:v['power_w_reported']=float(m[1])
        results.append(v)
        (OUT/'acceptance.json').write_text(json.dumps(results,indent=2))
        print(json.dumps(v),flush=True)
    summary={'total':len(results),'simulation_pass':sum(v['simulation_pass'] for v in results),'ptpx_pass':sum(v['ptpx_pass'] for v in results),'record_integrity_pass':sum(v['record_integrity_pass'] for v in results),'acceptance_counts':{k:sum(v['acceptance']==k for v in results) for k in sorted({v['acceptance'] for v in results})},'full_campaign_accepted':len(results)==24 and all(v['acceptance']=='RECORD_ACCEPTED' for v in results)}
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2));print('SYNC_POWER_ACCEPTANCE_AUDIT_DONE',json.dumps(summary),flush=True)

if __name__=='__main__':main()
