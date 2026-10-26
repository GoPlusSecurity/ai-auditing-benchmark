"""Offline acceptance checks for the fixed source-curation batch."""
import csv, hashlib, io, json, pathlib, re, subprocess, sys
from pathlib import Path
from decimal import Decimal
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[2]
sys.path.insert(0,str(ROOT/'docs/cases/sources'))
import validate_20261002_batch as shared
from archive_maintenance import validate_csv_records
def load(p):return json.loads(p.read_text('utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def validate():
 s=load(BASE/'snapshot.json');r=load(BASE/'results.json');b=load(BASE/'baseline.json')
 rows=shared.read_csv(BASE/'sheet_gid0_raw.csv');assert sha(BASE/'sheet_gid0_raw.csv')==s['raw_export_sha256']
 processed,selected=shared.select_qualifying_rows(rows,s['parameters']['x'],s['parameters']['y'],r['rows'])
 assert processed==s['parameters']['processing_order']
 assert len(selected)==s['parameters']['y']
 assert len(r['rows'])==len(processed)==r['counts']['scanned_rows']
 assert {x['row'] for x in s['rows']}==set(processed)
 for item in s['rows']:
  assert item['cells']==rows[item['row']-1]
  assert item['fields']==dict(zip(rows[1],item['cells']))
 ids=list(dict.fromkeys(x['case_id'] for x in selected))
 for name in ['sandbox','term','fh','moonwell']:
  spec=load(BASE/name/'case_spec.json');cid=spec['case_id']
  assert (BASE/name/'draft.md').read_bytes()==(ROOT/'docs/cases'/f'{cid}.md').read_bytes(),('stale reviewed draft',cid)
  m=load(ROOT/'dataset_artifacts'/cid/'case_metadata.json')
  assert all(m[k]==v for k,v in spec['metadata'].items()),('stale reviewed metadata',cid)
 originals=slices=checksums=links=decomps=0
 for cid in ids:
  full=ROOT/'dataset'/cid
  art=ROOT/'dataset_artifacts'/cid
  assert full.is_dir() and art.is_dir()
  meta=load(art/'case_metadata.json')
  assert 'view' not in meta and meta['source_provenance']=='provenance.json'
  assert meta['event_date'].replace('-','')==cid[:8]
  p=load(art/'provenance.json')
  for bundle in p['bundles']:
   response=(art/bundle['response_path']).resolve()
   assert sha(response)==bundle['response_sha256']
   raw=load(response)
   for item in bundle['source_files']:
    fp=(art/item['path']).resolve()
    assert sha(fp)==item['sha256']
    assert fp.read_bytes()==raw['sources'][item['original_source_path']]['content'].encode('utf-8')
    originals+=1
  for item in p.get('decompilations',[]):
   fp=(art/item['path']).resolve();assert sha(fp)==item['sha256'];decomps+=1
   original=(art/item['source_path']).resolve();assert fp.read_bytes()==original.read_bytes()
   assert item.get('not_original_source',True)
  for a in [art]:
   listed=set()
   for line in (a/'SHA256SUMS').read_text('utf-8').splitlines():
    digest,name=line.split('  ',1);fp=(a/name).resolve();assert sha(fp)==digest,(cid,name);checksums+=1;listed.add(fp)
   code=full
   actual={p.resolve() for tree in [a,code] for p in tree.rglob('*') if p.is_file() and p.name!='SHA256SUMS'}
   assert listed==actual,(cid,'checksum coverage')
   links+=shared.validate_local_links(a/'SOURCE.md')
  doc=ROOT/'docs/cases'/f'{cid}.md';links+=shared.validate_local_links(doc)
  text=doc.read_text('utf-8')
  blocks=re.findall(r'\x60\x60\x60mermaid\s*\n(.*?)\x60\x60\x60',text,re.S)
  assert blocks,(cid,'no mermaid')
  for diagram in blocks:
   assert diagram.strip().startswith(('flowchart','graph'))
   assert diagram.count('[')==diagram.count(']'),(cid,'unbalanced Mermaid nodes')
   assert '-->' in diagram,(cid,'no Mermaid edge')
  assert text.count('\x60\x60\x60')%2==0
 recordcounts=validate_csv_records(ROOT,ids)
 # Every file in dataset must be source text, including labelled high-level decompilation.
 noncode=[p.relative_to(ROOT).as_posix() for p in (ROOT/'dataset').rglob('*') if p.is_file() and p.suffix.lower() not in {'.sol','.vy','.vyi','.yul','.huff','.rs','.cairo','.move','.fc','.tact','.pan','.ts','.cpp','.h'}]
 assert not noncode,noncode[:30]
 links+=shared.validate_local_links(ROOT/'docs/cases/README.md')
 links+=shared.validate_local_links(BASE/'README.md')
 report={'status':'passed','parameters':s['parameters'],'counts':r['counts'],'case_ids':ids,'original_source_files_verified':originals,'decompiled_source_files_verified':decomps,'checksum_entries_verified':checksums,'local_links_and_line_anchors_verified':links,'dataset_non_source_files':noncode,'csv_event_counts':recordcounts,'scope_check':'See 20261027_amos_tz_merge/test_migration.py: amos blobs and premerge byte backup','selection_tests':'See selection_tests.txt: 12 pure selector boundary tests','mermaid_validation':'fenced blocks, flowchart header, bracket balance and edges; not rendered','not_performed':['upstream script or PoC execution','Solidity/Vyper compilation','deployment','fork replay','transactions'],'semantic_review_files':['sandbox/validation.json','term/validation.json','fh/verification.json','moonwell/independent_review.json'],'evidence_boundaries':'Source checks and selected historical evidence do not establish all historical state, full attack replay, or final net economic losses.'}
 return report

if __name__=='__main__':
 import argparse
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path);args=parser.parse_args()
 report=validate();text=json.dumps(report,ensure_ascii=False,indent=2)+'\n'
 if args.output:
  assert args.output.resolve()!=(BASE/'validation.json').resolve(), 'Historical validation.json is immutable; choose a new output path'
  args.output.write_bytes(text.encode('utf-8'))
 print(text,end='')
