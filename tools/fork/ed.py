"""Tiny exact-edit helper: every edit asserts it matched."""
import re
class F:
    def __init__(s,p): s.p=p; s.s=open(p).read()
    def sub(s,a,b='',n=1):
        c=s.s.count(a); assert c>=1, f"{s.p}: not found: {a[:70]!r}"
        if n: assert c==n, f"{s.p}: {c} matches (want {n}): {a[:70]!r}"
        s.s=s.s.replace(a,b); return s
    def cut(s,a,b,keep=''):
        i=s.s.index(a); j=s.s.index(b,i); s.s=s.s[:i]+keep+s.s[j:]; return s
    def rx(s,pat,rep='',n=1,flags=re.M):
        s.s,c=re.subn(pat,rep,s.s,flags=flags); assert (c==n if n else c>=1), f"{s.p}: {c} rx matches: {pat[:60]}"; return s
    def lines(s,pat):
        "drop whole lines matching regex"
        out=[l for l in s.s.split('\n') if not re.search(pat,l)]; assert len(out)<len(s.s.split('\n')), f"{s.p}: no line {pat}"
        s.s='\n'.join(out); return s
    def save(s): open(s.p,'w').write(s.s)

def cut_block(f, start):
    "remove the brace-balanced block whose header line contains `start`, plus one trailing blank line"
    i=f.s.index(start); assert f.s.count(start)==1, f"{f.p}: ambiguous {start!r}"
    ls=f.s.rfind('\n',0,i)+1
    j=f.s.index('{',i); d=0
    while True:
        c=f.s[j]
        if c=='{': d+=1
        elif c=='}':
            d-=1
            if d==0: break
        j+=1
    e=f.s.index('\n',j)+1
    if f.s[e:e+1]=='\n' and f.s[ls-2:ls]=='\n\n': e+=1
    f.s=f.s[:ls]+f.s[e:]; return f
F.block=cut_block
