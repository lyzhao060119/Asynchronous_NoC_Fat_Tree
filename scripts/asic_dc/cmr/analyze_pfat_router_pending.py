"""Read VCD remotely: retain router boundary values and last transitions only."""
import json
import re
import sys

stack = []
signals = {}
values = {}
times = {}
now = 0
with open(sys.argv[1]) as stream:
    for line in stream:
        p = line.split()
        if not p:
            continue
        if p[0] == '$scope':
            stack.append(p[2])
        elif p[0] == '$upscope':
            stack.pop()
        elif p[0] == '$var' and re.fullmatch(r'routers?L[123](?:_\d+)*', stack[-1] if stack else ''):
            if p[4].startswith('io_'):
                bit = int(p[5][1:-1]) if p[5].startswith('[') and ':' not in p[5] else None
                signals.setdefault(p[3], []).append(('.'.join(stack), p[4], bit))
        elif p[0] == '$enddefinitions':
            break
    for line in stream:
        line = line.strip()
        if not line:
            continue
        if line[0] == '#':
            now = int(line[1:])
        elif line[0] in 'bBrR':
            p = line.split()
            if len(p) == 2 and p[1] in signals:
                values[p[1]] = p[0][1:]; times[p[1]] = now
        elif line[0] in '01xXzZ' and line[1:] in signals:
            values[line[1:]] = line[0]; times[line[1:]] = now
ports = {}
bits = {}
for code, names in signals.items():
    for router, name, bit in names:
        if bit is None:
            ports[(router, name)] = (values.get(code), times.get(code))
        else:
            bits.setdefault((router, name), {})[bit] = (values.get(code, 'x'), times.get(code, 0))
for key, vector in bits.items():
    ports[key] = (''.join(vector.get(i, ('x', 0))[0] for i in range(max(vector), -1, -1)), max(v[1] for v in vector.values()))
print('ROUTER_BOUNDARY_SIGNALS', len(ports), 'FINAL_TIME', now)
for (router, name), (req, rt) in sorted(ports.items()):
    if name.endswith('_HS_Req'):
        base = name[:-7]
        ack, at = ports.get((router, base + '_HS_Ack'), (None, None))
        data, dt = ports.get((router, base + '_Data_flit'), (None, None))
        if req != ack:
            print(json.dumps(dict(router=router, port=base, req=req, ack=ack,
                                  data=hex(int(data,2)) if data and set(data)<=set('01') else data,
                                  req_time=rt, ack_time=at, data_time=dt)))
