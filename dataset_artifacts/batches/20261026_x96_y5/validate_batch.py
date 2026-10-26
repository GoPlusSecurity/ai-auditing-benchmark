"""Offline acceptance checks for the fixed source-curation batch."""
import csv, hashlib, io, json, pathlib, re, subprocess, sys
from pathlib import Path
from decimal import Decimal
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[2]
sys.path.insert(0,str(ROOT/'docs/cases/sources'))
import validate_20261002_batch as shared
def load(p):return json.loads(p.read_text('utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 (BASE/'validation.json').write_text(json.dumps({'status':'in_progress','note':'Not an acceptance result until all checks finish.'}),encoding='utf-8')
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
  m=load(ROOT/'dataset_artifacts/benchmark_complete'/cid/'case_metadata.json')
  assert all(m[k]==v for k,v in spec['metadata'].items()),('stale reviewed metadata',cid)
 originals=slices=checksums=links=decomps=0
 for cid in ids:
  full=ROOT/'dataset/benchmark_complete'/cid;small=ROOT/'dataset/benchmark_simplified'/cid
  art=ROOT/'dataset_artifacts/benchmark_complete'/cid;sa=ROOT/'dataset_artifacts/benchmark_simplified'/cid
  assert full.is_dir() and small.is_dir() and art.is_dir() and sa.is_dir()
  meta=load(art/'case_metadata.json');sm=load(sa/'case_metadata.json')
  for k in ['case_id','event_date','tx_urls','vulnerable_contract_urls','loss_usd']:
   assert meta[k]==sm[k],(cid,k)
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
  for item in load(sa/'slice_manifest.json')['slices']:
   fp=(sa/item['path']).resolve();cp=(sa/item['complete_path']).resolve()
   assert fp.is_relative_to(small.resolve()) and cp.is_relative_to(full.resolve())
   assert sha(fp)==item['sha256'];assert sha(cp)==item['complete_source_sha256']
   lines=cp.read_bytes().splitlines(keepends=True);start=item['original_start_line'];end=item['original_end_line']
   assert 1<=start<=end<=len(lines)
   assert fp.read_bytes()==b''.join(lines[start-1:end]),(cid,fp)
   slices+=1
  for a in [art,sa]:
   listed=set()
   for line in (a/'SHA256SUMS').read_text('utf-8').splitlines():
    digest,name=line.split('  ',1);fp=(a/name).resolve();assert sha(fp)==digest,(cid,name);checksums+=1;listed.add(fp)
   code=full if a==art else small
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
 # CSV prefix equality protects all pre-existing rows, order, encoding and line endings.
 manifest=load(BASE/'csv_append_manifest.json');recordcounts={}
 for language,scale in [('cn',10000),('en',1000)]:
  f=ROOT/f'ai-auditing-benchmark_{language}.csv';data=f.read_bytes();m=manifest[language];n=m['baseline_bytes']
  assert hashlib.sha256(data[:n]).hexdigest()==m['baseline_sha256']==b['files'][f.name]
  tail=data[n:];new=list(csv.reader(io.StringIO(tail.decode('utf-8'),newline='')))
  assert new==m['appended_records'];assert len(new)==r['counts']['new_cases']
  parsed=list(csv.reader(io.StringIO(data.decode('utf-8-sig'),newline='')));assert all(len(x)==7 for x in parsed)
  assert tail.endswith(b'\r\n')
  for event,entry in zip(sorted([x for x in selected if x['status']=='new'],key=lambda x:x['case_id']),new):
   meta=load(ROOT/'dataset_artifacts/benchmark_complete'/event['case_id']/'case_metadata.json')
   assert entry[0]==meta['event_date'].replace('-','.')
   assert entry[4]=='\n'.join(meta['tx_urls']) and entry[5]=='\n'.join(meta['vulnerable_contract_urls'])
   expected='' if meta['loss_usd'] is None else format(Decimal(meta['loss_usd'])/scale,'f')
   assert entry[6]==expected
   for tx in meta['tx_urls']:assert sum(tx in row[4] for row in parsed[1:])==1,(language,tx,'duplicate/missing')
  recordcounts[language]=len(parsed)-1
 # Every file in dataset must be source text, including labelled high-level decompilation.
 noncode=[p.relative_to(ROOT).as_posix() for p in (ROOT/'dataset').rglob('*') if p.is_file() and p.suffix.lower() not in {'.sol','.vy','.vyi','.yul','.huff','.rs','.cairo','.move','.fc','.tact','.pan','.ts','.cpp','.h'}]
 assert not noncode,noncode[:30]
 allowed={'ai-auditing-benchmark_cn.csv','ai-auditing-benchmark_en.csv','docs/cases/README.md','docs/cases/20260820_Allbridge_CCTP.md'}
 for view in ['benchmark_complete','benchmark_simplified']:
  allowed.update({f'dataset_artifacts/{view}/20260820_Allbridge_CCTP/case_metadata.json',f'dataset_artifacts/{view}/20260820_Allbridge_CCTP/SHA256SUMS'})
 changed=[]
 for name,digest in b['files'].items():
  fp=ROOT/name
  assert fp.exists(),('baseline file disappeared',name)
  if sha(fp)!=digest:changed.append(name);assert name in allowed,('out of scope modification',name)
 new_paths=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=ROOT,text=True,encoding='utf-8').splitlines()
 newids={x['case_id'] for x in selected if x['status']=='new'}
 for name in new_paths:
  okay=name.startswith('dataset_artifacts/batches/'+BASE.name+'/')
  okay|=any(name.startswith(f'{tree}/{view}/{cid}/') for tree in ['dataset','dataset_artifacts'] for view in ['benchmark_complete','benchmark_simplified'] for cid in newids)
  okay|=any(name==f'docs/cases/{cid}.md' for cid in newids)
  assert okay,('unexpected untracked path',name)
 links+=shared.validate_local_links(ROOT/'docs/cases/README.md')
 links+=shared.validate_local_links(BASE/'README.md')
 report={'status':'passed','parameters':s['parameters'],'counts':r['counts'],'case_ids':ids,'original_source_files_verified':originals,'verbatim_slices_verified':slices,'decompiled_source_files_verified':decomps,'checksum_entries_verified':checksums,'local_links_and_line_anchors_verified':links,'dataset_non_source_files':noncode,'csv_event_counts':recordcounts,'csv_baseline_bytes_preserved':True,'scope_baseline_file_count':len(b['files']),'scope_changed_existing_files':changed,'scope_new_paths_count':len(new_paths),'selection_tests':'See selection_tests.txt: 12 pure selector boundary tests','mermaid_validation':'fenced blocks, flowchart header, bracket balance and edges; not rendered','not_performed':['upstream script or PoC execution','Solidity/Vyper compilation','deployment','fork replay','transactions'],'semantic_review_files':['sandbox/validation.json','term/validation.json','fh/verification.json','moonwell/independent_review.json'],'evidence_boundaries':'Source checks and selected historical evidence do not establish all historical state, full attack replay, or final net economic losses.'}
 (BASE/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__=='__main__':
 try:main()
 except Exception as error:
  (BASE/'validation.json').write_text(json.dumps({'status':'failed','error':str(error)},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
  raise
