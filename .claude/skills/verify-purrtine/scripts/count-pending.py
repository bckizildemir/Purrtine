import plistlib, sys
UID = plistlib.UID
d = plistlib.load(open(sys.argv[1], 'rb')); o = d['$objects']
root = o[d['$top']['root'].data] if 'root' in d['$top'] else o[1]
def strings(v, seen=0):
    if seen > 12: return
    if isinstance(v, UID): yield from strings(o[v.data], seen + 1)
    elif isinstance(v, str): yield v
    elif isinstance(v, dict):
        for x in v.values(): yield from strings(x, seen + 1)
    elif isinstance(v, list):
        for x in v: yield from strings(x, seen + 1)
reqs = root.get('NS.objects', [])
texts = [" ".join(strings(r)) for r in reqs]
print(len(reqs), "requests")
for t in sys.argv[2:]:
    print(sum(1 for x in texts if t in x), t)
