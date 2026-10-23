"""Extend the accepted single-packet experiment to async L2 c2p4 / L3 c4p8."""
import csv
import json
import re
import shutil
import statistics
import time
from pathlib import Path
import run_router_single_packet_power_20261022 as packet
m=packet.m
m.BATCH='single_router_c2p4_c4p8_20261022_r5'
HERE=Path(__file__).resolve().parent
SOURCE=HERE/'results/single_router_packet_power_20261022_r4/inputs'
m.CONFIGS=[
    {'name':'async_c2p4','kind':'async_pfat_2x4','netlist':'20261022_router_ppa_r5c_async_c2p4','sync':False,'lanes':4,'child':2,'level':2},
    {'name':'async_c4p8','kind':'async_pfat_4x8','netlist':'20261022_router_ppa_r5b_async_c4p8','sync':False,'lanes':8,'child':4,'level':3},
]

def prepare():
    d=m.out_dir()/'inputs';d.mkdir(parents=True,exist_ok=True)
    t=(SOURCE/'tb_router_matched_ppa_async.sv').read_text()
    first='''`ifdef GEOM_C4_P8
  localparam integer CHILD_LANES=4, PARENT_LANES=8;
`elsif GEOM_C2_P4
  localparam integer CHILD_LANES=2, PARENT_LANES=4;
`else
  localparam integer CHILD_LANES=1, PARENT_LANES=1;
`endif'''
    t=re.sub(r'`ifdef GEOM_C1_P4.*?`endif',lambda _:first,t,count=1,flags=re.S)
    bind='''`ifdef GEOM_C4_P8
  CMRRouter dut (`include "async_ports_c4_p8.vi");
`elsif GEOM_C2_P4
  CMRRouter dut (`include "async_ports_c2_p4.vi");
`else
  CMRRouter dut (`include "async_ports_c1_p1.vi");
`endif'''
    t=re.sub(r'`ifdef GEOM_C1_P4.*?`endif',lambda _:bind,t,count=1,flags=re.S)
    t=t.replace('lane_count[0:3]','lane_count[0:PARENT_LANES-1]')
    t=t.replace('for(i=0;i<4;i=i+1) lane_count[i]=0;', 'for(i=0;i<PARENT_LANES;i=i+1) lane_count[i]=0;')
    marker='    if(PARENT_LANES>3) fork receive_lane(PARENT_BASE+3); join_none'
    assert marker in t
    t=t.replace(marker,marker+'\n'+'\n'.join(f'    if(PARENT_LANES>{i}) fork receive_lane(PARENT_BASE+{i}); join_none' for i in range(4,8)))
    dest=d/'tb_router_matched_ppa_async.sv';dest.write_text(t);m.TB_FILES={False:dest}
    t=(SOURCE/'run_gls_router_matched_ppa.sh').read_text()
    t=t.replace('case "$KIND" in','case "$KIND" in\n  async_pfat_2x4) DEF=\'+define+GEOM_C2_P4\'; PREFIX=async_ports_c2_p4.vi ;;\n  async_pfat_4x8) DEF=\'+define+GEOM_C4_P8\'; PREFIX=async_ports_c4_p8.vi ;;')
    dest=d/'run_gls_router_matched_ppa.sh';dest.write_text(t);m.WRAPPER=dest
    binds=d/'hop_binds';binds.mkdir(exist_ok=True)
    for name in ('async_ports_c2_p4.vi','async_ports_c4_p8.vi'):
        shutil.copy2(HERE/'hop_binds'/name,binds/name)
    m.BIND_DIR=binds
    shutil.copy2(SOURCE/'packet_power.tcl',d/'packet_power.tcl')
    spec={'batch':m.BATCH,'configs':m.CONFIGS,'corner':'tt0p8v25c','flit_bits':28,'packet_flits':5,
        'seeds':[1,2,3],'injection':'one source, one packet per reset, input-Ack paced; child0 to parent, destination (8,8)',
        'latency':'output_tail_req-input_head_req; amortized flit latency=packet_completion/5; also retain per-flit input/output timestamps',
        'power':'entire DUT; random 24-bit Body/Tail payload; 50ps input slew; 5fF output load; internal+switching+leakage; no idle subtraction',
        'power_windows':['head input to tail capture','tail capture +2ns','tail capture +5ns','idle tail capture+10..20ns'],
        'scope':'post-synthesis, no extracted P&R/SPEF/CTS'}
    (m.out_dir()/'packet_spec.json').write_text(json.dumps(spec,indent=2)+'\n')

def reduce():
    packet.reduce();packet.release_audit()
    target=m.REPO/'results'/m.BATCH
    powers=json.loads((target/'packet_power_summary.json').read_text())
    gls=json.loads((m.out_dir()/'gls_packets.json').read_text())
    release=json.loads((target/'packet_release_audit.json').read_text())
    rows=[];flits=[]
    for c in m.CONFIGS:
        dc=HERE/'results'/c['netlist']
        summary=json.loads((dc/'summary.json').read_text())
        if not summary.get('dc',{}).get('pass'):raise RuntimeError('DC failed '+c['name'])
        qor=(dc/'reports_dc/qor.rpt').read_text()
        area=float(re.search(r'Cell Area:\s*([0-9.eE+-]+)',qor,re.I)[1])
        selected=[r for r in gls if r['config']==c['name']]
        completion=[];individual=[]
        for r in selected:
            events=r['events']
            completion.append(max(float(e['input_ns'])+float(e['latency_ns'])-.09 for e in events)-min(float(e['input_ns']) for e in events))
            individual.append(statistics.mean(float(e['latency_ns'])-.09 for e in events))
            for e in events:flits.append({'config':c['name'],'seed':r['seed'],'flit':int(e['flit']),
                'input_ns':float(e['input_ns']),'output_req_ns':float(e['input_ns'])+float(e['latency_ns'])-.09,'latency_ns':float(e['latency_ns'])-.09,'parent_lane':int(e['lane'])})
        active=next(r for r in powers if r['config']==c['name'] and r['window']=='active')
        guard=next(r for r in powers if r['config']==c['name'] and r['window']=='guard5')
        rows.append({'config':c['name'],'level':c['level'],'area_um2':area,'packet_completion_ns':statistics.mean(completion),
            'packet_completion_div5_ns':statistics.mean(completion)/5,'mean_individual_flit_latency_ns':statistics.mean(individual),
            'packet_power_mw':active['total_power_mw'],'packet_energy_pj':active['energy_pj'],
            'packet_energy_pj_sample_std':active['energy_pj_sample_std'],'packet_pj_per_bit':active['pj_per_transferred_bit'],
            'guard5_energy_pj':guard['energy_pj'],'guard5_pj_per_bit':guard['pj_per_transferred_bit'],
            'last_nonclock_release_ns':max(r['last_nonclock_transition_after_tail_capture_ns'] or 0 for r in release if r['config']==c['name'])})
    for name,data in [('summary',rows),('flit_events',flits)]:
        (target/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n')
        with (target/(name+'.csv')).open('w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
    lines=['# Async c2p4 / c4p8 single Router PPA','',
        'TT 0.8V 25C; same current async DC recipe as 20261022 c1p4. c2p4 is L2; c4p8 is L3.',
        'Both final DC runs use private frozen scripts with the same size-only cell targets. The c1p4-specific XNR4 count assumption was replaced by mapped-count verification (32 for c2p4, 144 for c4p8); RTL, handshake equations and DEL settings were not changed.',
        '28 bits/flit, five-flit unicast packet; one child0 source to parent, destination (8,8); input-handshake paced; three independent data seeds/reset runs.',
        'Packet completion is first input Req to final output Req. Packet completion/5 is amortized time, not mean individual flit traversal latency.',
        'Power uses whole DUT, 50ps input slew / 5fF output load, internal+switching+leakage, no idle subtraction. Active window ends at Tail capture, 90ps after Tail Req.',
        'Post-synthesis zero-wire estimate: no extracted routing or physical CTS. Library extrapolation warnings remain.','',
        'Acceptance: 2 final DC PASS with nonempty DDC/netlist/SDF/SDC; 6/6 GLS runs each delivered 5/5 flits and passed post-drain settling, with zero SDF errors and no timing violation; 24/24 PT-PX windows pass with 100% net activity annotation.','',
        '|Router|Area um2|Packet ns|Packet/5 ns|Mean power mW|Packet pJ|pJ/transferred bit|',
        '|---|---:|---:|---:|---:|---:|---:|']
    for r in rows:lines.append(f"|{r['config']}|{r['area_um2']:.3f}|{r['packet_completion_ns']:.6f}|{r['packet_completion_div5_ns']:.6f}|{r['packet_power_mw']:.6f}|{r['packet_energy_pj']:.6f}|{r['packet_pj_per_bit']:.6f}|")
    lines.extend(['','Tail+5ns window includes control release and idle; its packet energies are:'])
    for r in rows:lines.append(f"- {r['config']}: {r['guard5_energy_pj']:.6f} pJ, {r['guard5_pj_per_bit']:.6f} pJ/bit; last observed nonclock release {r['last_nonclock_release_ns']:.6f} ns after Tail capture.")
    (target/'RESULTS.md').write_text('\n'.join(lines)+'\n')
    archive=m.archive_dir()/'analysis'
    for p in target.iterdir():
        if p.is_file():shutil.copy2(p,archive/p.name)
    shutil.copy2(Path(__file__),archive/Path(__file__).name)
    print('C2P4_C4P8_FINAL_PASS',json.dumps(rows),flush=True)

if __name__=='__main__':
    import sys
    command=sys.argv[1]
    if command=='run':
        prepare()
        for attempt in range(360):
            if all((HERE/'results'/c['netlist']/'summary.json').is_file() for c in m.CONFIGS):break
            print('WAIT_DC',attempt,flush=True);time.sleep(20)
        else:raise RuntimeError('DC timeout')
        m.submit()
        spec=json.loads((m.out_dir()/'experiment_spec.json').read_text());spec['workload']=json.loads((m.out_dir()/'packet_spec.json').read_text())
        (m.out_dir()/'experiment_spec.json').write_text(json.dumps(spec,indent=2)+'\n')
        packet.collect_gls();packet.submit_power();packet.collect_power();reduce()
    elif command=='reduce':reduce()
    elif command=='prepare':prepare();print('PREPARED',m.out_dir())
