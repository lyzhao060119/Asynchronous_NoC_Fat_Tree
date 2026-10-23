"""Fetch only compact 64-node CSV/manifest/report evidence; verify every file."""
import hashlib,json,tarfile,io
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect

ROOT=Path(__file__).resolve().parents[3]/'results/formal64_all_20261021_r1'
REMOTE='/prjtemp/ghy19/formal64_export_20261021_r1'

def main():
 c=connect();c.get_transport().channel_timeout=600
 cmd="/soft/GNU/python3.12/bin/python3 - <<'PY'\nimport tarfile,hashlib,json\nfrom pathlib import Path\np=Path('"+REMOTE+"')\nfiles=[x for x in p.rglob('*') if x.is_file() and x.name!='download_hashes.json']\nassert all(x.suffix in ['.csv','.json','.rpt','.sha256'] for x in files)\nmanifest={str(x.relative_to(p)):dict(bytes=x.stat().st_size,sha256=hashlib.sha256(x.read_bytes()).hexdigest()) for x in files}\n(p/'download_hashes.json').write_text(json.dumps(manifest,indent=2))\nwith tarfile.open(str(p)+'.tar.gz','w:gz') as t:\n for x in p.rglob('*'):\n  if x.is_file():t.add(x,arcname=str(x.relative_to(p)))\nprint('BUNDLE_READY',len(files))\nPY"
 i,o,e=c.exec_command(cmd,timeout=600)
 print(o.read().decode(),flush=True)
 if o.channel.recv_exit_status():raise RuntimeError(e.read().decode())
 s=c.open_sftp();s.get_channel().settimeout(600)
 with s.file(REMOTE+'.tar.gz','rb') as f:data=f.read()
 s.close();c.close()
 ROOT.mkdir(parents=True,exist_ok=True)
 with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as t:
  for member in t.getmembers():
   target=(ROOT/member.name).resolve()
   if not target.is_relative_to(ROOT.resolve()) or not member.isfile():raise ValueError('unsafe archive member')
   target.parent.mkdir(parents=True,exist_ok=True)
   target.write_bytes(t.extractfile(member).read())
 manifest=json.loads((ROOT/'download_hashes.json').read_text())
 for name,meta in manifest.items():
  p=ROOT/name;assert p.stat().st_size==meta['bytes'];assert hashlib.sha256(p.read_bytes()).hexdigest()==meta['sha256']
 print('DOWNLOAD_VERIFIED files=%d compressed_bytes=%d out=%s'%(len(manifest),len(data),ROOT))

if __name__=='__main__':main()
