#!/usr/bin/env python3
"""Static dangling-reference checker for the iNiR QML tree. Usage: check.py <root>
Prints one finding per line as KIND\tfile\tdetail (no line numbers, so two trees diff cleanly)."""
import os,re,sys,json
root=os.path.abspath(sys.argv[1]); os.chdir(root)
SKIP={'.git','node_modules','docs','.remember'}
qml=[];allf=[]
for d,ds,fs in os.walk('.'):
    ds[:]=[x for x in ds if x not in SKIP]
    for f in fs:
        p=os.path.join(d,f)[2:]; allf.append(p)
        if f.endswith('.qml'): qml.append(p)
src={p:open(p,errors='replace').read() for p in qml}
def strip(s):
    s=re.sub(r'/\*.*?\*/','',s,flags=re.S)
    return re.sub(r'(?m)^\s*//.*$','',s)
code={p:strip(s) for p,s in src.items()}
out=set()
# 1 imports
for p,s in code.items():
    for m in re.finditer(r'(?m)^import\s+qs\.([\w.]+)',s):
        d=m.group(1).replace('.','/')
        if not os.path.isdir(d) or not any(f.endswith(('.qml','.js')) or f=='qmldir' for f in os.listdir(d)):
            out.add(f"IMPORT\t{p}\tqs.{m.group(1)}")
    for m in re.finditer(r'(?m)^import\s+"([^"]+)"',s):
        t=m.group(1)[5:] or '.' if m.group(1).startswith('root:') else os.path.normpath(os.path.join(os.path.dirname(p),m.group(1)))
        if not os.path.exists(t): out.add(f"IMPORT\t{p}\t{m.group(1)}")
# 2 qmldir
for p in allf:
    if os.path.basename(p)=='qmldir':
        for l in open(p):
            t=l.split()
            if t and t[-1].endswith(('.qml','.js')):
                if not os.path.exists(os.path.join(os.path.dirname(p),t[-1])): out.add(f"QMLDIR\t{p}\t{t[-1]}")
# 3 path literals
for p,s in code.items():
    for m in re.finditer(r'"((?:\.\.?/)?[\w./-]+\.(?:qml|js|sh|py|fish|json|svg|png|frag\.qsb))"',s):
        lit=m.group(1)
        if '/' not in lit and not re.search(r'source\s*:\s*$|resolvedUrl\(\s*$|shellPath\(\s*$',s[max(0,m.start()-40):m.start()]): continue
        cands=[os.path.normpath(os.path.join(os.path.dirname(p),lit)),os.path.normpath(lit)]
        pre=s[max(0,m.start()-60):m.start()]
        if not any(os.path.exists(c) for c in cands):
            if re.search(r'shellPath\(\s*$|source\s*:\s*$|resolvedUrl\(\s*$|component:\s*$',pre) or lit.startswith(('modules/','services/','scripts/','assets/','defaults/','../','./')):
                out.add(f"PATH\t{p}\t{lit}")
# 4 type names: capitalised identifiers used as `Name {` or `Name.` that resolve nowhere
names=set(os.path.basename(p)[:-4] for p in qml)
for p in allf:
    if os.path.basename(p)=='qmldir':
        for l in open(p):
            t=l.split()
            if len(t)>=3 and t[-1].endswith('.qml') and os.path.exists(os.path.join(os.path.dirname(p),t[-1])): names.add(t[-3] if t[0]!='singleton' else t[1])
known=set(json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'qtnames.json')))) if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)),'qtnames.json')) else None
used={}
for p,s in code.items():
    s2=re.sub(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'|`(?:[^`\\]|\\.)*`','""',s)
    loc=set(re.findall(r'\bcomponent\s+([A-Z]\w*)\s*:',s2))|set(re.findall(r'(?m)^import\s+.*\s+as\s+([A-Z]\w*)',s2))|set(re.findall(r'\benum\s+([A-Z]\w*)',s2))|set(re.findall(r'\bclass\s+([A-Z]\w*)',s2))
    for m in re.finditer(r'(?<![\w.])([A-Z][A-Za-z0-9_]*)\s*(\{|\.[a-zA-Z_])',s2):
        n=m.group(1)
        if n in loc or n in names: continue
        used.setdefault(n,set()).add(p)
json.dump({n:sorted(v) for n,v in used.items()},open('/dev/stdout','w') if False else open(os.devnull,'w'))
_nf=os.path.join(os.path.dirname(os.path.abspath(__file__)),'basenames.txt')
if '--dump-names' in sys.argv: open(_nf,'w').write('\n'.join(sorted(names)))
basenames=set(open(_nf).read().split()) if os.path.exists(_nf) else set()
for n,ps in used.items():
    if n in basenames:
        for p in ps: out.add(f"TYPE\t{p}\t{n}")
# 5 singleton members
def members(s):
    m=set(re.findall(r'(?m)^\s*(?:readonly\s+|required\s+|default\s+)*property\s+(?:[\w.<>]+)\s+(\w+)',s))
    m|=set(re.findall(r'(?m)^\s*function\s+(\w+)',s)); m|=set(re.findall(r'(?m)^\s*signal\s+(\w+)',s))
    m|=set(re.findall(r'(?m)^\s*(?:readonly\s+)?property\s+alias\s+(\w+)',s)); m|=set(re.findall(r'\bid\s*:\s*(\w+)',s))
    m|=set(re.findall(r'(?m)^\s*enum\s+(\w+)',s))
    for e in re.findall(r'enum\s+\w+\s*\{([^}]*)\}',s): m|=set(re.findall(r'(\w+)',e))
    return m
sing={}
for p,s in src.items():
    if re.search(r'(?m)^pragma Singleton',s): sing[os.path.basename(p)[:-4]]=(p,members(code[p]))
BUILTIN={'connect','disconnect','objectName','destroy','toString','hasOwnProperty','valueOf'}
for p,s in code.items():
    s2=re.sub(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'','""',s)
    for m in re.finditer(r'(?<![\w.])([A-Z]\w*)\??\.(\w+)',s2):
        n,mem=m.groups()
        if n in sing and os.path.basename(p)[:-4]!=n:
            ms=sing[n][1]
            if mem in ms or mem in BUILTIN: continue
            if mem.endswith('Changed') and mem[:-7] in ms: continue
            if mem.startswith('on') and (mem[2:3].lower()+mem[3:]) in ms: continue
            out.add(f"MEMBER\t{p}\t{n}.{mem}")
# 6 config paths
cfg=code.get('modules/common/Config.qml','')
cfg=cfg[cfg.index('id: configOptionsJsonAdapter'):] if 'id: configOptionsJsonAdapter' in cfg else cfg
tree={};stack=[(-1,tree)]
depth=0
for line in cfg.split('\n'):
    m=re.match(r'\s*(?:readonly\s+)?property\s+([\w.<>]+)\s+(\w+)\s*:?\s*(.*)',line)
    ob=line.count('{')-line.count('}')
    if m:
        node={}
        while stack and stack[-1][0]>=depth: stack.pop()
        if stack: stack[-1][1][m.group(2)]=node
        if 'JsonObject {' in m.group(3) or m.group(3).rstrip().endswith('JsonObject {'):
            stack.append((depth,node))
        else: node['_leaf']=True
    depth+=ob
opt=None
def find(t,k):
    if k in t: return t[k]
    for v in t.values():
        if isinstance(v,dict):
            r=find(v,k)
            if r is not None: return r
opt=tree
def chk(path):
    t=opt
    for i,k in enumerate(path):
        if not isinstance(t,dict) or t.get('_leaf'): return None
        if k not in t: return '.'.join(path[:i+1])
        t=t[k]
    return None
for p,s in code.items():
    if p=='modules/common/Config.qml': continue
    for m in re.finditer(r'Config\.options((?:\??\.\w+)+)',s):
        path=re.findall(r'\w+',m.group(1))
        bad=chk(path)
        if bad: out.add(f"CONFIG\t{p}\t{bad}")
    for m in re.finditer(r'setNestedValue\(\s*"([\w.]+)"',s):
        bad=chk(m.group(1).split('.'))
        if bad: out.add(f"CONFIG\t{p}\t{bad}")
if '--probe' in sys.argv: print('probe', chk(['waffles','x']), chk(['bar','weather','hideLocation']), chk(['bar','nope']), len(opt), file=sys.stderr)
print('\n'.join(sorted(out)))
