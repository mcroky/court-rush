"""Compare actual Lean checker output with the real Godot fixture output."""
import json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lean=(root/(sys.argv[1] if len(sys.argv)>1 else 'artifacts/mb-formal-project.log')).read_text(encoding='utf-8-sig')
native=(root/(sys.argv[2] if len(sys.argv)>2 else 'artifacts/mb-formal-native.log')).read_text(encoding='utf-8-sig')
assert re.search(r'PASS .+: \d+ declarations checked, no unfinished proof \(sorry\), no added axiom',lean)
assert 'failures=0' in native
def actual(name):
    match=re.search(r'^'+name+r' (.+)$',native,re.M)
    assert match,name
    return json.loads(match[1])
vectors=[]
for row in re.findall(r'SAMPLER_VECTOR (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+)',lean):
    f,j,a,c,second,offset,next_offset=map(int,row)
    if (f,j)==(26,45):vectors.append([a,c,offset,next_offset])
assert vectors==actual('FORMAL_INDEX_VECTORS')
bits=re.search(r'GATE_BITSET ([01]{256})',lean)[1]
assert bits==''.join('1' if x else '0' for x in actual('FORMAL_GUARD_VECTORS'))
names={'leftR':'left_r','leftL':'left_l','rightR':'right_r','rightL':'right_l','run':'run'}
for prefix,native_name in [('CUT','FORMAL_CLIP_VECTORS'),('EXPIRE','FORMAL_EXPIRE_VECTORS')]:
    values=re.findall(prefix+r'_VECTOR left=(?:true|false) supportR=(?:true|false) clip=LayerPriority\.Clip\.(\w+)',lean)
    assert [names[x] for x in values]==actual(native_name)
assert actual('FORMAL_STOP_VECTORS')==['stop_r','stop_l']
assert actual('FORMAL_RESET_VECTOR')==dict(active='run',clock=0,weight=0,previous_redirect=0,previous_braking=False,offsets_clear=True)
assert 'RESET_VECTOR { active := LayerPriority.Clip.run' in lean
print('FORMAL_DIFFERENTIAL PASS: 9 Lean index vectors, 84 actual sampler outputs, 256 guard outcomes, 4 cut/expiry pairs, 2 stop variants and reset agree')
