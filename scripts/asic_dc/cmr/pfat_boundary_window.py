"""Extract a bounded PFAT router boundary history from a remote VCD."""
import bisect
import json
import re
import sys

path, pattern, begin, end = sys.argv[1:5]
anomalies_only = '--anomalies' in sys.argv[5:]
pattern = re.compile(pattern)
begin, end = int(begin), int(end)
stack, names, history = [], {}, {}
now = 0
with open(path) as stream:
    for line in stream:
        p = line.split()
        if not p:
            continue
        if p[0] == '$scope':
            stack.append(p[2])
        elif p[0] == '$upscope':
            stack.pop()
        elif p[0] == '$var':
            name = '.'.join(stack) + '.' + p[4] + ''.join(p[5:-1])
            if pattern.search(name):
                names.setdefault(p[3], []).append(name)
                history[p[3]] = []
        elif p[0] == '$enddefinitions':
            break
    for line in stream:
        p = line.split()
        if not p:
            continue
        if p[0][0] == '#':
            now = int(p[0][1:])
            if now > end:
                break
            continue
        if p[0][0] in 'bBrR' and len(p) == 2:
            code, value = p[1], p[0][1:]
        elif p[0][0] in '01xXzZ':
            code, value = p[0][1:], p[0][0]
        else:
            continue
        if code in history:
            h = history[code]
            if now < begin:
                h[:] = [(now, value)]
            else:
                h.append((now, value))
byname = {n: history[c] for c, ns in names.items() for n in ns}
def value_at(name, t):
    h = byname.get(name, [])
    i = bisect.bisect_right(h, (t, '\uffff')) - 1
    return h[i][1] if i >= 0 else 'x'
events = []
for name, h in byname.items():
    if not name.endswith(('_HS_Req', '_HS_Ack')):
        continue
    base = name[:-7]
    for t, value in h:
        if t < begin:
            continue
        bits = ''.join(value_at(base + '_Data_flit[' + str(i) + ']', t) for i in range(27, -1, -1))
        flit = hex(int(bits, 2)) if set(bits) <= set('01') else bits
        events.append((t, name, value, flit))
state = {}
for t, name, value, flit in sorted(events):
    base = name[:-7]
    kind = name[-3:]
    req, ack = state.setdefault(base, [value_at(base + '_HS_Req', begin - 1), value_at(base + '_HS_Ack', begin - 1)])
    if anomalies_only:
        if kind == 'Req' and req in '01' and ack in '01' and req != ack:
            print(json.dumps(dict(time=t, port=base, issue='Req_changed_while_pending', old_req=req, ack=ack, new_req=value, flit=flit)))
    else:
        print(json.dumps((t, name, value, flit)))
    state[base][0 if kind == 'Req' else 1] = value
