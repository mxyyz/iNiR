#!/usr/bin/env python3
"""Import-aware reachability over QML/JS. Usage: reach.py <root> [extra roots...]. Prints unreachable files."""
import os,re,sys
os.chdir(sys.argv[1]); why=[a[6:] for a in sys.argv[2:] if a.startswith('--why=')]; roots=['shell.qml']+[a for a in sys.argv[2:] if not a.startswith('--')]
files=[]
for top in ('.',):
    for d,ds,fs in os.walk(top):
        ds[:]=[x for x in ds if x not in('.git','docs','dots','defaults','.remember','node_modules','translations','sdata','assets','distro')]
        for f in fs:
            if f.endswith(('.qml','.js')): files.append(os.path.normpath(os.path.join(d,f)))
fset=set(files)
def strip(s):
    s=re.sub(r'/\*.*?\*/','',s,flags=re.S); return re.sub(r'(?m)^\s*//.*$','',s)
dirnames={}
def names_in(d):
    if d in dirnames: return dirnames[d]
    m={}
    if os.path.isdir(d):
        for f in os.listdir(d):
            if f.endswith('.qml'): m.setdefault(f[:-4],set()).add(os.path.normpath(os.path.join(d,f)))
        q=os.path.join(d,'qmldir')
        if os.path.exists(q):
            for l in open(q):
                t=l.split()
                if t and t[-1].endswith(('.qml','.js')) and len(t)>=2:
                    n=t[1] if t[0]=='singleton' else t[0]
                    p=os.path.normpath(os.path.join(d,t[-1]))
                    if os.path.exists(p): m.setdefault(n,set()).add(p)
    dirnames[d]=m; return m
edges={}
for f in files:
    s=strip(open(f,errors='replace').read()); d=os.path.dirname(f) or '.'
    dirs={d}; out=set()
    for m in re.finditer(r'(?m)^\s*(?:import|\.import)\s+(?:qs((?:\.\w+)*)|"([^"]+)")',s):
        if m.group(2) is not None:
            t=m.group(2); t=t[5:] if t.startswith('root:') else os.path.join(d,t)
            t=os.path.normpath(t or '.')
            if t.endswith('.js'): out.add(t)
            else: dirs.add(t)
        else: dirs.add(os.path.normpath(m.group(1).replace('.','/').lstrip('/') or '.'))
    al=set(re.findall(r'(?m)^\s*import\s+.*\s+as\s+(\w+)',s))
    toks=set(re.findall(r'(?<![\w.])[A-Z]\w*\b',s))
    for m2 in re.finditer(r'\b(\w+)\.([A-Z]\w*)\b',s):
        if m2.group(1) in al: toks.add(m2.group(2))
    for dd in dirs:
        for n,ps in names_in(dd).items():
            if n in toks: out|=ps
    for m in re.finditer(r'"([^"\n]*?\.(?:qml|js))"',s):
        lit=m.group(1)
        for c in (os.path.normpath(os.path.join(d,lit)),os.path.normpath(lit)):
            if c in fset: out.add(c)
    out.discard(f); edges[f]=out
from collections import deque
seen={}; q=deque((r,None) for r in roots if r in fset)
while q:
    x,par=q.popleft()
    if x in seen: continue
    seen[x]=par; q.extend((y,x) for y in sorted(edges.get(x,())) if y not in seen)
for w in why:
    c=[]; x=w
    while x: c.append(x); x=seen.get(x)
    print('WHY',' <- '.join(c) if w in seen else w+' unreachable')
if why: sys.exit()
for f in sorted(fset-set(seen)): print(f)
