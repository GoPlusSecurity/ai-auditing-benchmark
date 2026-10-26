"""Final static validation of artifact links, evidence decoding and source selectors."""
from pathlib import Path
import json,re,hashlib
B=Path(__file__).resolve().parent
R=B.parents[3]
spec=json.loads((B/'case_spec.json').read_text());provenance=json.loads((B/'provenance.json').read_text());draft=(B/'draft.md').read_text()
source_by_id={s['id']:json.loads((R/s['response_path']).read_text())for s in spec['sources']}
links=re.findall(r'\]\(([^)]+)\)',draft);source_links=0;local_artifact_links=0
for link in links:
 if link.startswith('../../dataset/benchmark_complete/'+spec['case_id']+'/source-bundles/'):
  part=link.split('/source-bundles/',1)[1];base,anchor=part.split('#',1);bid,name=base.split('/',1)
  text=source_by_id[bid]['sources'][name]['content'];m=re.fullmatch(r'L(\d+)-L(\d+)',anchor);assert m,link
  start,end=map(int,m.groups());assert 1<=start<=end<=len(text.splitlines()),link
  ranges=spec['slices'][bid][name]
  if ranges!='all':assert any(a<=start<=end<=z for a,z in ranges),('reference outside simplified slices',link)
  source_links+=1
 elif link.startswith('../../dataset/benchmark_complete/'+spec['case_id']+'/decompiled/'):
  tail=link.split('/decompiled/',1)[1];name,anchor=tail.split('#');path=B/name;m=re.fullmatch(r'L(\d+)-L(\d+)',anchor);a,z=map(int,m.groups());assert1=1<=a<=z<=len(path.read_text().splitlines());assert assert1
 elif link.startswith('../../dataset_artifacts/'):
  path=R/link.removeprefix('../../').split('#')[0];assert path.is_file(),link;local_artifact_links+=1
# Verify every named selector against authoritative provider signatures and decoded arguments.
checks={
 'term-roles':{'callTargetFunctionWithRole(address,bytes,uint16)':'0x9518aaac'},
 'term-delay':{'setTxCooldown(uint256)':'0xebb2b4a2','setTxExpiration(uint256)':'0x9b56d5be','enableModule(address)':'0x610b5925','execTransactionFromModule(address,uint256,bytes,uint8)':'0x468721a7','executeNextTx(address,uint256,bytes,uint8)':'0xee072baf'},
 'term-vault':{'update_debt(address,uint256,uint256)':'0xba54971f','add_strategy(address,bool)':'0xc2e73cca','update_max_debt_for_strategy(address,uint256)':'0xb9ddcd68'}}
for bid,expected in checks.items():
 got={x['signature']:x['signatureHash4']for x in source_by_id[bid]['signatures']['function']}
 for sig,value in expected.items():assert got[sig]==value,(bid,sig)
a=json.loads((B/'decoded-proposal.json').read_text())['actions'];assert len(a)==17
assert [x['inner_selector']for x in a[:3]]==['0xebb2b4a2','0x9b56d5be','0x610b5925']
assert all(x['role']==1 for x in a[:3])
assert int(a[0]['inner_argument_word'],16)==0 and int(a[1]['inner_argument_word'],16)==0
assert a[2]['inner_argument_word'][-40:]=='0ae12af3878a2d896f5c4dce3be7250fb187c0a6'
for n in range(3,17,2):
 assert a[n]['selector']=='0x468721a7'and a[n+1]['selector']=='0xee072baf'
 assert a[n]['inner_data']==a[n+1]['inner_data']
 assert a[n]['operation']==a[n+1]['operation']==0
for n in [3,5,7,9]:
 assert a[n]['inner_selector']=='0xba54971f'
 assert int(a[n]['inner_argument_words'][1],16)==0 and int(a[n]['inner_argument_words'][2],16)==10000
assert a[11]['inner_selector']=='0xc2e73cca'and int(a[11]['inner_argument_words'][1],16)==0
assert a[13]['inner_selector']=='0xb9ddcd68'and int(a[13]['inner_argument_words'][1],16)==2**256-1
assert a[15]['inner_selector']=='0xba54971f'and int(a[15]['inner_argument_words'][1],16)==2**256-1
assert int(a[15]['inner_argument_words'][2],16)==10000
assert spec['metadata']['loss_usd']is None
assert json.loads((B/'sheet-row.json').read_text())['fields']['target (社媒 or Addr)']=='@term_labs'
assert len(spec['sources'])==9
q=json.loads((B/'qualification.json').read_text());assert q['qualified'] is True
v=json.loads((B/'validation.json').read_text());v.update(draft_source_links_checked=source_links,draft_existing_artifact_links_checked=local_artifact_links,all_17_action_selectors_and_arguments_checked=True,authoritative_selector_signatures_checked=9,draft_sha256=hashlib.sha256((B/'draft.md').read_bytes()).hexdigest(),case_spec_sha256=hashlib.sha256((B/'case_spec.json').read_bytes()).hexdigest())
(B/'validation.json').write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(v,ensure_ascii=False,indent=2))
