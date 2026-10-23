"""Retry a DC run with private, hash-verified scripts and read-all Tcl driver."""
import hashlib
import json
import re
import shlex
import sys
import os
from pathlib import Path
from run_remote_cmr_flow import atomic_put_bytes, fetch_tree, job_id, remote_run, wait_job
from run_remote_cmr_noc16_sdf import connect

HERE=Path(__file__).resolve().parent
ROOT='/home/ghy19/Asynchronous_Router_CMR'
name=sys.argv[1]
old=os.environ.get('CMR_RETRY_SOURCE_RUN','20261022_router_ppa_r5_'+name)
run=os.environ.get('CMR_RETRY_RUN_ID','20261022_router_ppa_'+os.environ.get('CMR_RETRY_REV','r5b')+'_'+name)
local=HERE/'results'/run
local.mkdir(parents=True,exist_ok=True)
client=connect();sftp=client.open_sftp()
try:
    stage=ROOT+'/rtl/runs/'+run+'/dc_scripts'
    remote_run(client,'mkdir -p '+stage+' '+ROOT+'/logs/dc')
    hashes={}
    transformed_hashes={}
    for file in ('run_dc_cmr_router.tcl','apply_cmr_ipm_timing_recipe.tcl','apply_cmr_router_cell_recipe.tcl'):
        data=(HERE/file).read_text().replace('\r\n','\n')
        hashes[file]=hashlib.sha256(data.encode()).hexdigest()
        if file=='apply_cmr_router_cell_recipe.tcl' and (name=='async_c4p8' or os.environ.get('CMR_RETRY_MAPPED_XNR')=='1'):
            old_line='  cmr_ipm_resize_exact $xnr [expr {2*$n}] XNR4D2BWP12T30P140 opm_click_xnr'
            assert old_line in data
            data=data.replace(old_line,'''  # High-fanin OPM parity trees have more XNR4 cells than c1p4.
  # Apply the same size-only target to every mapped gate and verify post refs.
  if {[sizeof_collection $xnr] < [expr {2*$n}]} {error "high-fanin XNR4 binding incomplete"}
  cmr_ipm_resize_mapped $xnr XNR4D2BWP12T30P140 opm_click_xnr''')
            expected=os.environ.get('CMR_RETRY_EXPECT_XNR')
            if expected:
                assert expected.isdigit() and int(expected)>0
                data=data.replace('if {[sizeof_collection $xnr] < [expr {2*$n}]} {error "high-fanin XNR4 binding incomplete"}',
                    'if {[sizeof_collection $xnr] != '+expected+'} {error "geometry-specific XNR4 binding incomplete"}')
                data=data.replace('# High-fanin OPM parity trees have more XNR4 cells than c1p4.',
                    '# Geometry-specific mapped XNR4 count checked before sizing.')
        if file=='run_dc_cmr_router.tcl':
            for recipe in ('apply_cmr_ipm_timing_recipe.tcl','apply_cmr_router_cell_recipe.tcl'):
                data=data.replace('$PROJECT_DIR/scripts/dc/'+recipe,stage+'/'+recipe)
        dest=stage+'/'+file
        transformed_hashes[file]=hashlib.sha256(data.encode()).hexdigest()
        digest=atomic_put_bytes(client,sftp,data.encode(),dest)
        if digest not in remote_run(client,'sha256sum '+dest):raise RuntimeError('private script hash mismatch')
        (local/file).write_text(data)
    driver='''set fh [open "MAIN" r]
set body [read $fh]
close $fh
puts "FROZEN_TCL_COMPLETE [info complete $body]"
if {[catch {uplevel #0 $body} message]} {
  puts "CMR_DC_FAIL frozen_driver=$message"
  puts $::errorInfo
  exit 2
}
'''.replace('MAIN',stage+'/run_dc_cmr_router.tcl')
    atomic_put_bytes(client,sftp,driver.encode(),stage+'/driver.tcl')
    with sftp.file(ROOT+'/logs/dc/'+old+'.sh','rb') as f:body=f.read().decode()
    body=body.replace(old,run).replace('/rtl/runs/'+run+'/', '/rtl/runs/'+old+'/')
    body=body.replace(ROOT+'/scripts/dc/run_dc_cmr_router.tcl',stage+'/driver.tcl')
    wrapper=ROOT+'/logs/dc/'+run+'.sh'
    atomic_put_bytes(client,sftp,body.encode(),wrapper)
    (local/'retry_wrapper.sh').write_text(body)
    log=ROOT+'/logs/dc/'+run+'.log'
    reply=remote_run(client,f'bsub -n 1 -m "node21 node26 node24 node18" -o {log} -e {log}.err -J retry_{name} bash {wrapper}')
    jid=job_id(reply)
    (local/'retry_job.json').write_text(json.dumps({'run_id':run,'job_id':jid,'source_run':old,'original_script_sha256':hashes,'private_script_sha256':transformed_hashes,'script_path':stage},indent=2)+'\n')
    print('FROZEN_DC_RETRY_SUBMIT',run,jid,flush=True)
finally:sftp.close();client.close()
client=connect()
try:
    try:client=wait_job(client,jid,run)
    except RuntimeError as exc:print('RETRY_JOB_FAILURE',exc,flush=True)
finally:client.close()
client=connect();sftp=client.open_sftp()
try:
    text=remote_run(client,f'cat {log} {log}.err 2>/dev/null')
    (local/'dc.log').write_text(text,encoding='utf-8')
    if not re.search(r'^CMR_DC_PASS output=',text,re.M):raise RuntimeError(text[-12000:])
    for remote,name in ((ROOT+'/outputs/'+run,'outputs'),(ROOT+'/reports/dc/'+run,'reports_dc')):
        fetch_tree(sftp,remote,local/name)
    for file in ('CMRRouter.ddc','CMRRouter_post.v','CMRRouter.sdf','CMRRouter.sdc'):
        if not (local/'outputs'/file).is_file() or not (local/'outputs'/file).stat().st_size:raise RuntimeError('missing '+file)
    summary=json.loads((HERE/'results'/old/'summary.json').read_text())
    summary['run_id']=run;summary['dc']={'pass':True,'job_id':jid,'retry_of':old}
    summary['manifest']['run_id']=run
    summary['manifest']['retry_private_script_hashes']=hashes
    summary['manifest']['private_script_sha256']=transformed_hashes
    summary['manifest']['opm_xnr_count_rule']=('geometry_exact_'+os.environ['CMR_RETRY_EXPECT_XNR']) if os.environ.get('CMR_RETRY_EXPECT_XNR') else ('mapped_high_fanin' if (name=='async_c4p8' or os.environ.get('CMR_RETRY_MAPPED_XNR')=='1') else 'baseline_exact')
    summary['manifest']['rtl_source_run']=old
    (local/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('FROZEN_DC_RETRY_PASS',run,flush=True)
finally:sftp.close();client.close()
