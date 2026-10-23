"""Extract selected router's named scalar/control histories without copying VCD."""
import json
import re
import sys

path, router, begin, end = sys.argv[1:5]
begin, end = int(begin), int(end)
scope_filter = re.compile(sys.argv[6]) if len(sys.argv) > 6 else None
stack, signals, history, inventory = [], {}, {}, []
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
        elif p[0] == '$var' and router in stack:
            local = '.'.join(stack[stack.index(router)+1:])
            name = local + '.' + p[4] + ''.join(p[5:-1])
            if (scope_filter.search(name) if scope_filter else len(stack)-stack.index(router) <= 3):
                inventory.append(name)
                if int(p[2]) <= 16 and not re.search(r'flit\[|Datain|Dataout', name):
                    signals.setdefault(p[3], []).append(name)
                    history[p[3]] = []
        elif p[0] == '$enddefinitions':
            break
    with open(sys.argv[5] + '.inventory', 'w') as out:
        out.write('\n'.join(inventory))
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
            if now < begin:
                history[code][:] = [(now, value)]
            else:
                history[code].append((now, value))
with open(sys.argv[5], 'w') as out:
    for code, names in signals.items():
        for name in names:
            out.write(json.dumps([name, history[code]]) + '\n')
print('INTERNAL_WINDOW_SAVED', sys.argv[5], 'signals', len(signals))
