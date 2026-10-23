import csv,json,hashlib
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect

out=Path('results/metric_scope_audit_20261022')
selected=json.loads((out/'selected_provenance.json').read_text())
roots=[(out/f'root{i}_listing.txt').read_text().splitlines()[0] for i in range(3)]
c=connect();s=c.open_sftp();manifest=[]
try:
 for i,root in enumerate(roots):
  paths=['src/tb_noc64_async_boundary.sv'] if i<2 else ['src/tb_formal256_fast.sv']
  for d in (['PROP_M16','FM64'] if i<2 else ['Mesh256','M16_256']):
   paths += [f'work/{d}/input_hashes.log',f'work/{d}/filelist.f']
  if i==0:paths+=['experiments/scripts/date_v3/materialize_case.py','generate_formal64_multicast.py']
  for relative in paths:
   remote=root+'/'+relative
   try:
    with s.open(remote) as f:data=f.read()
    if len(data)>2000000:continue
    p=out/f'root{i}'/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    manifest.append(dict(remote=remote,local=str(p),sha256=hashlib.sha256(data).hexdigest()))
   except OSError as e:manifest.append(dict(remote=remote,error=str(e)))
 for row in selected:
  root=row['source_csv'].split('/results/')[0]
  stem=Path(row['source_csv']).stem
  for rel in [f'logs/{row["design"]}/{stem}/run.log',f'cases/{row["case_name"]}.case']:
   remote=root+'/'+rel
   try:
    with s.open(remote) as f:data=f.read()
    if len(data)>6000000:continue
    p=out/'samples'/row['design']/row['benchmark']/Path(rel).name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    manifest.append(dict(remote=remote,local=str(p),sha256=hashlib.sha256(data).hexdigest()))
   except OSError as e:manifest.append(dict(remote=remote,error=str(e)))
 (out/'evidence_hashes.json').write_text(json.dumps(manifest,indent=2));print(json.dumps(manifest,indent=2))
finally:s.close();c.close()
