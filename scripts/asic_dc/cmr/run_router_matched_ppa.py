#!/usr/bin/env python3
"""Matched aggregate/isolated throughput and PT-PX campaign.

This is deliberately a new entry point.  It never mutates the historical
multi-lane aggregate or hop-PPA result directories and it refuses to publish
rows unless the matched GLS and PT-PX gates pass.
"""
from __future__ import annotations
import argparse, csv, hashlib, json, os, re, shlex, shutil, stat, time
from pathlib import Path

from run_remote_cmr_flow import atomic_put_retry, job_id, remote_run, wait_job
from run_remote_cmr_noc16_sdf import connect

REPO=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
REMOTE_ROOT="/home/ghy19/Asynchronous_Router_CMR"
BATCH=os.environ.get("CMR_MATCHED_BATCH", "router_matched_ppa_20260920_"+time.strftime("%H%M%S"))
HOSTS=os.environ.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')

CONFIGS=[
 {"name":"async_c1p1","kind":"async_thin_1x1","netlist":os.environ.get("CMR_MATCHED_C1P1_NETLIST", "20260912_205700_cmr_thin_l1_hop_rpsdel050"),"sync":False,"lanes":1},
 {"name":"async_c1p4","kind":"async_fat_1x4","netlist":"20260914_cmr_prop_temp_c1p4_rpsdel050_r1","sync":False,"lanes":4},
 {"name":"sync_c1p4","kind":"sync_fat_1x4","netlist":os.environ.get("CMR_MATCHED_SYNC_C1P4_NETLIST", "20260914_cmr_sync_prop_temp_c1p4_1p0ns"),"sync":True,"lanes":4},
]
TB_FILES={False:HERE/"tb_router_matched_ppa_async.sv",True:HERE/"tb_router_matched_ppa_sync.sv"}
WRAPPER=HERE/"run_gls_router_matched_ppa.sh"
BIND_DIR=HERE/"hop_binds"

def digest(p:Path)->str: return hashlib.sha256(p.read_bytes().replace(b"\r\n",b"\n")).hexdigest()
def out_dir()->Path: return HERE/"results"/BATCH
def archive_dir()->Path: return REPO/"DATE_paper"/"experiments"/"raw"/BATCH
def cfg(name):
    for c in CONFIGS:
        if c["name"]==name:return c
    raise SystemExit("unknown config "+name)
def remote_sha(client,path): return remote_run(client,f"sha256sum {shlex.quote(path)} 2>/dev/null || true").strip()
def put(client,sftp,local:Path,remote:str):
    if digest(local) in remote_sha(client,remote): return "skip"
    client,sftp,d=atomic_put_retry(client,sftp,local,remote)
    if d not in remote_sha(client,remote): raise RuntimeError("hash mismatch "+remote)
    return "uploaded"

def preflight(names=None):
    selected=[c for c in CONFIGS if not names or c["name"] in names]
    client=connect(); rows=[]; blocked=[]
    try:
        for c in selected:
            root=f"{REMOTE_ROOT}/outputs/{c['netlist']}"; dut="SyncCmrRouter" if c["sync"] else "CMRRouter"
            for a in (f"{dut}.ddc",f"{dut}_post.v",f"{dut}.sdf",f"{dut}.sdc"):
                r=remote_run(client,f"test -s {shlex.quote(root+'/'+a)} && sha256sum {shlex.quote(root+'/'+a)} || echo MISSING")
                if "MISSING" in r:
                    blocked.append({"config":c["name"],"artifact":a,"remote":r.strip()})
                else:
                    rows.append({"config":c["name"],"artifact":a,"remote":r.strip()})
    finally: client.close()
    d=out_dir();d.mkdir(parents=True,exist_ok=True)
    spec={"batch":BATCH,"workload":{"flit_width":28,"flits_per_packet":5,"warmup_packets_per_source":200,"measurement_packets_per_source":2000,"cooldown_packets_per_source":200,"measurement_flits":40000,"async_tx_setup_ns":0.05,"async_rx_capture_ns":0.09,"sync_clock_ns":1.0,"modes":["isolated","aggregate"]},"configs":CONFIGS,"source_hashes":{p.name:digest(p) for p in [WRAPPER,*TB_FILES.values()]}}
    (d/"experiment_spec.json").write_text(json.dumps(spec,indent=2)+"\n",encoding="utf-8")
    (d/"preflight.json").write_text(json.dumps({"batch":BATCH,"configs":rows,"blocked":blocked},indent=2)+"\n",encoding="utf-8")
    if blocked:
        print("PREFLIGHT_BLOCKED",json.dumps(blocked));raise RuntimeError("frozen artifact gate failed")
    print("PREFLIGHT_PASS",len(rows))

def upload_inputs(client,sftp,selected):
    base=f"/prjtemp/ghy19/{BATCH}/sim/tb"
    remote_run(client,f"mkdir -p {base}/hop_binds")
    put(client,sftp,WRAPPER,f"{base}/{WRAPPER.name}")
    for sync in {c["sync"] for c in selected}: put(client,sftp,TB_FILES[sync],f"{base}/{TB_FILES[sync].name}")
    for p in BIND_DIR.glob("*.vi"): put(client,sftp,p,f"{base}/hop_binds/{p.name}")
    return base

def stage_root(): return f"/prjtemp/ghy19/{BATCH}"

def submit(names=None):
    selected=[c for c in CONFIGS if not names or c["name"] in names]
    preflight(names);client=connect();sftp=client.open_sftp();jobs=[]
    try:
        remote_tb_base=upload_inputs(client,sftp,selected)
        for c in selected:
            rid=f"{BATCH}_{c['name']}";log=f"{stage_root()}/logs/{rid}"
            sync="1" if c["sync"] else "0"
            remote_run(client,f"mkdir -p {log}/isolated {log}/aggregate")
            cmd=(f"bsub -n 8 {HOSTS} -oo {shlex.quote(log+'/lsf.log')} -J matched_{c['name']} env "
                 f"CMR_REMOTE_ROOT={shlex.quote(REMOTE_ROOT)} CMR_RUN_ID={shlex.quote(rid)} "
                 f"CMR_NETLIST_RUN_ID={shlex.quote(c['netlist'])} CMR_HOP_KIND={shlex.quote(c['kind'])} "
                 f"CMR_MATCHED_SYNC={sync} CMR_MATCHED_TB_ROOT={remote_tb_base} CMR_MATCHED_LOG_ROOT={log} CMR_HOP_WORK_BASE=/tmp/cmr_hop_ppa_ghy19 "
                 f"bash {remote_tb_base}/{WRAPPER.name}")
            response=remote_run(client,cmd);jid=job_id(response);jobs.append({"name":c["name"],"run_id":rid,"job_id":jid})
            print("JOB_SUBMIT",c["name"],jid)
    finally: sftp.close();client.close()
    d=out_dir();d.mkdir(parents=True,exist_ok=True);(d/"jobs.json").write_text(json.dumps({"batch":BATCH,"jobs":jobs},indent=2)+"\n",encoding="utf-8")

def fetch_tree(sftp,remote,local):
    local.mkdir(parents=True,exist_ok=True)
    try: entries=sftp.listdir_attr(remote)
    except OSError:return
    for e in entries:
        rp=f"{remote}/{e.filename}";lp=local/e.filename
        if stat.S_ISDIR(e.st_mode): fetch_tree(sftp,rp,lp)
        else:
            # VCDs stay on the remote staging filesystem for PT-PX; pulling a
            # multi-gigabyte sync waveform is neither needed for acceptance nor
            # safe for the local archive.  The manifest retains its remote path.
            if e.filename.endswith(".vcd"): continue
            try:sftp.get(rp,str(lp))
            except OSError: pass

def read_events(path:Path,sync:bool,mode:str):
    if not path.is_file():return []
    with path.open(newline="",encoding="utf-8",errors="replace") as f:return list(csv.DictReader(f))
def event_window(events,sync,mode):
    vals=[]
    for r in events:
        if mode=="aggregate" and r.get("measurement")!="1":continue
        try: vals.append(float(r["cycle"] if sync else r["time_ps"])/(1.0 if sync else 1000.0))
        except (KeyError,ValueError): pass
    if len(vals)<(40000 if mode=="aggregate" else 5): raise ValueError("incomplete event window")
    return min(vals),max(vals)
def collect(wait=False):
    jobs=json.loads((out_dir()/"jobs.json").read_text(encoding="utf-8"))["jobs"]
    client=connect();sftp=client.open_sftp();rows=[]
    try:
        for j in jobs:
            c=cfg(j["name"]);rid=j["run_id"];remote=f"{stage_root()}/logs/{rid}";local=out_dir()/rid
            if wait and j.get("job_id"):wait_job(client,j["job_id"],rid,polls=240)
            fetch_tree(sftp,remote,local)
            for mode in ("isolated","aggregate"):
                run=(local/mode/"run.log").read_text(encoding="utf-8",errors="replace") if (local/mode/"run.log").is_file() else ""
                sdf=(local/mode/"sdf_annotate.log").read_text(encoding="utf-8",errors="replace") if (local/mode/"sdf_annotate.log").is_file() else ""
                events=read_events(local/mode/"hop_events.csv",c["sync"],mode)
                try:start,end=event_window(events,c["sync"],mode); window_ok=True
                except ValueError:start=end=None;window_ok=False
                meas=[e for e in events if e.get("measurement")=="1"]
                lane_counts={str(i):sum(1 for e in meas if e.get("lane")==str(i)) for i in range(c["lanes"])}
                expected_events=5 if mode=="isolated" else 4*2400*5
                expected_meas=5 if mode=="isolated" else 40000
                count_ok=len(events)==expected_events and len(meas)==expected_meas and len({(e.get("src"),e.get("packet"),e.get("flit")) for e in meas})==expected_meas
                lane_ok=mode!="aggregate" or c["lanes"]==1 or all(v>0 for v in lane_counts.values())
                functional_pass="MATCHED_RESULT PASS" in run and "PPA_RESULT PASS" in run and bool(re.search(r"Total errors:\s*0\b",sdf)) and window_ok and count_ok and not re.search(r"MATCHED_FAIL|Timing violation|PPA_RESULT FAIL",run)
                # A zero-traffic physical lane is a mechanism diagnostic, not
                # a functional failure. Sync c1p4 delivered every flit with
                # three active lanes; keep throughput eligible but exclude
                # that aggregate window from PT-PX until all lanes are active.
                marker=functional_pass
                active_parent_lanes=sum(1 for value in lane_counts.values() if value > 0)
                duration=None if start is None else end-start
                rows.append({"config":c["name"],"run_id":rid,"mode":mode,"status":"PASS" if marker else "FAIL","functional_pass":functional_pass,"throughput_eligible":functional_pass,"power_eligible":functional_pass and lane_ok,"all_lanes_active":lane_ok,"active_parent_lanes":active_parent_lanes,"lane_limitation":None if lane_ok else f"{active_parent_lanes}/{c['lanes']} parent lanes active","start_ns":start,"end_ns":end,"duration_ns":duration,"throughput_gflit_s":None if duration is None else (expected_meas/duration),"throughput_gb_s":None if duration is None else (expected_meas/duration*28),"event_count":len(events),"measurement_count":len(meas),"lane_counts":lane_counts,"count_ok":count_ok,"lane_ok":lane_ok,"sdf_errors_zero":bool(re.search(r"Total errors:\s*0\b",sdf))})
    finally:sftp.close();client.close()
    d=out_dir();(d/"gls_summary.json").write_text(json.dumps(rows,indent=2)+"\n",encoding="utf-8");print("COLLECTED",len(rows));return rows

def submit_ptpx():
    rows=json.loads((out_dir()/"gls_summary.json").read_text(encoding="utf-8"));client=connect();jobs=[]
    sftp=client.open_sftp()
    try:
        remote_tcl=f"{stage_root()}/run_ptpx_cmr_router_hop_ppa.tcl"
        remote_run(client,f"mkdir -p {stage_root()}")
        put(client,sftp,REPO/"scripts"/"asic_dc"/"power"/"run_ptpx_cmr_router_hop_ppa.tcl",remote_tcl)
        allow_partial = os.environ.get("CMR_ALLOW_PARTIAL_LANES_POWER", "0") == "1"
        for r in rows:
            partial_sync = allow_partial and r["config"] == "sync_c1p4" and r["mode"] == "aggregate" and r.get("functional_pass", True)
            if r["status"]!="PASS" or (not r.get("power_eligible", False) and not partial_sync):
                print("PTPX_SKIP",r["config"],r["mode"],"power_eligible="+str(r.get("power_eligible")));continue
            c=cfg(r["config"]);tag=f"{BATCH}_{r['config']}_{r['mode']}";rid=f"{BATCH}_{r['config']}";dut="SyncCmrRouter" if c["sync"] else "CMRRouter";strip="tb_router_matched_ppa_sync/dut" if c["sync"] else "tb_router_matched_ppa_async/dut"
            vcd=f"{stage_root()}/logs/{rid}/{r['mode']}/hop_ppa.vcd";log=f"{stage_root()}/logs/{tag}/ptpx";report=f"{stage_root()}/reports/{tag}/power"
            work=f"{stage_root()}/ptpx_work/{tag}"
            cmd=(f"mkdir -p {shlex.quote(log)} {shlex.quote(work)} {shlex.quote(stage_root()+'/tmp')}; bsub -n 4 {HOSTS} -oo {shlex.quote(log+'/lsf.log')} -J ppx_{r['config']}_{r['mode']} "
                 f"bash -lc 'cd {shlex.quote(work)} && env "
                 f"SYNOPSYS_LC_ROOT=/soft/synopsys/lc/V-2023.12 CMR_REMOTE_ROOT={shlex.quote(REMOTE_ROOT)} CMR_RUN_ID={shlex.quote(tag)} "
                 f"CMR_NETLIST_RUN_ID={shlex.quote(c['netlist'])} CMR_DUT_NAME={dut} CMR_TB_STRIP={strip} CMR_POWER_VCD_FILE={shlex.quote(vcd)} CMR_POWER_REPORT_DIR={shlex.quote(report)} "
                 f"CMR_POWER_START_NS={r['start_ns']:.3f} CMR_POWER_END_NS={r['end_ns']:.3f} "
                 f"TMPDIR={shlex.quote(stage_root()+'/tmp')} PT_TMPDIR={shlex.quote(stage_root()+'/tmp')} /soft/synopsys/prime/V-2023.12/bin/pt_shell -f {remote_tcl}'")
            response=remote_run(client,cmd);jobs.append({"tag":tag,"config":r["config"],"mode":r["mode"],"job_id":job_id(response),"report":report,"log":log});print("PTPX_SUBMIT",tag,job_id(response))
    finally:sftp.close();client.close()
    (out_dir()/"ptpx_jobs.json").write_text(json.dumps(jobs,indent=2)+"\n",encoding="utf-8")

def parse_power(path:Path):
    text=path.read_text(encoding="utf-8",errors="replace") if path.is_file() else ""
    def val(p):
        m=re.search(p,text,re.I);return float(m.group(1))*({"mW":1e-3,"uW":1e-6,"nW":1e-9,"W":1}.get(m.group(2) or "W",1)) if m else None
    total=val(r"Total\s+Power\s*=\s*([0-9.eE+-]+)\s*([mun]?W)?");leak=val(r"Cell\s+Leakage\s+Power\s*=\s*([0-9.eE+-]+)\s*([mun]?W)?")
    dynamic=val(r"Total\s+Dynamic\s+Power\s*=\s*([0-9.eE+-]+)\s*([mun]?W)?")
    internal=val(r"Cell\s+Internal\s+Power\s*=\s*([0-9.eE+-]+)\s*([mun]?W)?");switching=val(r"Net\s+Switching\s+Power\s*=\s*([0-9.eE+-]+)\s*([mun]?W)?")
    if dynamic is None and internal is not None and switching is not None: dynamic=internal+switching
    if dynamic is None and total is not None and leak is not None:dynamic=total-leak
    return {"total_power_w":total,"dynamic_power_w":dynamic,"leakage_power_w":leak,"internal_power_w":internal,"switching_power_w":switching,"power_sum_ok":bool(dynamic is not None and internal is not None and switching is not None and abs(dynamic-(internal+switching))<max(1e-12,0.05*abs(dynamic)) and total is not None and leak is not None and abs(total-(dynamic+leak))<max(1e-12,0.05*abs(total)))}

def finalize():
    rows=json.loads((out_dir()/"gls_summary.json").read_text(encoding="utf-8"));ptjobs=json.loads((out_dir()/"ptpx_jobs.json").read_text(encoding="utf-8")) if (out_dir()/"ptpx_jobs.json").is_file() else []
    client=connect();sftp=client.open_sftp();powers=[]
    try:
        for j in ptjobs:
            local=out_dir()/"ptpx"/j["tag"];fetch_tree(sftp,j["report"],local);fetch_tree(sftp,j["log"],local/"logs")
            rpt=local/"power.rpt";check=local/"check_power.rpt";activity=local/"activity.rpt";lsf=local/"logs"/"lsf.log"
            txt=lsf.read_text(encoding="utf-8",errors="replace") if lsf.is_file() else ""
            ok=all(p.is_file() and p.stat().st_size>0 for p in (rpt,check,activity)) and "PT-063" not in txt and "PT-063" not in (check.read_text(errors="replace") if check.is_file() else "") and "PPA_POWER_PASS" in txt
            p=parse_power(rpt); ok=ok and p.get("power_sum_ok",False) and all(p.get(k) is not None and p.get(k)>0 for k in ("total_power_w","dynamic_power_w","leakage_power_w"))
            gls=next(x for x in rows if x["config"]==j["config"] and x["mode"]==j["mode"])
            energy=p["total_power_w"]*gls["duration_ns"]*1e-9 if ok and p["total_power_w"] is not None else None
            denom=40000*28 if j["mode"]=="aggregate" else 5*28
            powers.append({**j,**p,"power_pass":ok,"energy_j":energy,"total_pj_per_bit":None if energy is None else energy/denom*1e12,"dynamic_pj_per_bit":None if energy is None or p["dynamic_power_w"] is None else p["dynamic_power_w"]*gls["duration_ns"]*1e-9/denom*1e12})
    finally:sftp.close();client.close()
    d=archive_dir();(d/"raw").mkdir(parents=True,exist_ok=True)
    local_raw=d/"raw"/"local_results"
    if local_raw.exists(): shutil.rmtree(local_raw)
    shutil.copytree(out_dir(),local_raw,ignore=shutil.ignore_patterns("*.pyc"))
    manifest={"batch":BATCH,"old_results":"superseded_tb_bias","gls":rows,"ptpx":powers,"source_hashes":json.loads((out_dir()/"experiment_spec.json").read_text(encoding="utf-8")).get("source_hashes",{})}
    (d/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    for name,data in (("throughput_summary.csv",rows),("steady_energy_summary.csv",[x for x in powers if x["mode"]=="aggregate"]),("isolated_energy_summary.csv",[x for x in powers if x["mode"]=="isolated"]),("acceptance.csv",powers)):
        if not data:continue
        with (d/name).open("w",newline="",encoding="utf-8") as f:csv.DictWriter(f,fieldnames=sorted({k for x in data for k in x})).writeheader();csv.DictWriter(f,fieldnames=sorted({k for x in data for k in x})).writerows(data)
    (d/"RESULTS.md").write_text("# Router matched PPA\n\nOld aggregate and isolated values remain superseded_tb_bias. This archive publishes only GLS/PT-PX rows passing the matched-window gates.\n",encoding="utf-8")
    print("FINALIZED",d)

def selftest():
    assert 4*2000*5==40000
    assert len(CONFIGS)==3 and {c["name"] for c in CONFIGS}=={"async_c1p1","async_c1p4","sync_c1p4"}
    print("SELFTEST PASS measurement_flits=40000 modes=6")

def closeout():
    """Merge the accepted partial batches without hiding blocked evidence."""
    batches=["router_matched_ppa_20260920_104000","router_matched_ppa_20260920_112000"]
    d=REPO/"DATE_paper"/"experiments"/"raw"/"router_matched_ppa_20260920_closeout"; (d/"raw").mkdir(parents=True,exist_ok=True)
    all_gls=[];all_px=[]
    for b in batches:
        src=REPO/"DATE_paper"/"experiments"/"raw"/b
        if (src/"manifest.json").is_file():
            m=json.loads((src/"manifest.json").read_text(encoding="utf-8"));all_gls.extend(m.get("gls",[]));all_px.extend(m.get("ptpx",[]))
        if (src/"raw"/"local_results").is_dir():
            target=d/"raw"/b
            if target.exists():shutil.rmtree(target)
            shutil.copytree(src/"raw"/"local_results",target,ignore=shutil.ignore_patterns("*.vcd"))
    with (d/"throughput_summary.csv").open("w",newline="",encoding="utf-8") as f:
        fields=sorted({k for x in all_gls for k in x});w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(all_gls)
    with (d/"acceptance.csv").open("w",newline="",encoding="utf-8") as f:
        fields=sorted({k for x in all_px for k in x});w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(all_px)
    blocked={"config":"async_c1p1","status":"needs evidence","reason":"frozen CMRRouter DDC/post-netlist/SDF/SDC absent from remote output 20260912_205700_cmr_thin_l1_hop_rpsdel050; no replacement DC authorized"}
    (d/"manifest.json").write_text(json.dumps({"batches":batches,"gls":all_gls,"ptpx":all_px,"blocked":[blocked],"old_results":"superseded_tb_bias"},indent=2)+"\n",encoding="utf-8")
    (d/"RESULTS.md").write_text("# Router matched PPA closeout\n\nAsync c1p4 passed both matched GLS windows and both PT-PX windows. Sync c1p4 isolated passed PT-PX; its aggregate delivered all flits but lane 3 had zero delivery and is `needs evidence`. Async c1p1 is blocked because its frozen netlist artifacts are absent remotely. Historical values remain `superseded_tb_bias`.\n",encoding="utf-8")
    print("CLOSEOUT",d)

def main():
    ap=argparse.ArgumentParser();sub=ap.add_subparsers(dest="cmd",required=True)
    for n in ("preflight","submit"): 
        p=sub.add_parser(n);p.add_argument("--names",nargs="*",choices=[c["name"] for c in CONFIGS])
    for n in ("collect","submit-ptpx","finalize"):sub.add_parser(n)
    sub.add_parser("self-test");sub.add_parser("closeout");args=ap.parse_args()
    if args.cmd=="preflight":preflight(args.names)
    elif args.cmd=="submit":submit(args.names)
    elif args.cmd=="collect":collect(wait=True)
    elif args.cmd=="submit-ptpx":submit_ptpx()
    elif args.cmd=="finalize":finalize()
    elif args.cmd=="self-test":selftest()
    else:closeout()
if __name__=="__main__":main()
