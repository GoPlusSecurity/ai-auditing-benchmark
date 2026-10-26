"""Aggregate acquisition records/hashes offline. No downloaded code is executed."""
import datetime,hashlib,json
from pathlib import Path
BASE=Path(__file__).resolve().parent
BATCH=BASE.parent
extra=[]
for name,url in [('ethervm-form.html','https://ethervm.io/decompile'),('helper-implementation-ethervm-address-response.html','https://ethervm.io/decompile?address=0x3e30DDF30172F54C50cB490fF56E10f1a4737cF1'),('sources/weth-source.json','https://sourcify.dev/server/v2/contract/1/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2?fields=all')]:
 if (BASE/name).exists():extra.append({'path':'term/'+name,'url':url,'method':'GET','collection_note':'Successful saved response; exact HTTP receipt timestamp was not separately captured.'})
(BASE/'self10-fetch-results.json').write_text(json.dumps(extra,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
records=[]
for log in sorted(BATCH.glob('*fetch-results.json'))+sorted(BASE.glob('self*-fetch-results.json')):
 try:items=json.loads(log.read_text('utf-8-sig'))
 except (ValueError,OSError):continue
 for item in items:
  if not item.get('path','').startswith('term/'):continue
  rec=dict(item,collection_log=str(log.relative_to(BATCH)).replace('\\','/'))
  target=BATCH/item['path']
  if target.is_file():
   raw=target.read_bytes();rec.update(sha256=hashlib.sha256(raw).hexdigest(),bytes=len(raw),file_present=True)
   if 'retrieved_at' not in rec:
    rec['retrieved_at']=datetime.datetime.fromtimestamp(target.stat().st_mtime,datetime.timezone.utc).isoformat()
    rec['retrieved_at_basis']='local downloaded file last-write time; exact response timestamp not recorded'
   if target.suffix=='.json':
    try:
     content=json.loads(raw)
     if isinstance(content,dict) and content.get('jsonrpc'):rec['rpc_result_status']='error' if 'error'in content else ('null' if content.get('result') is None else 'non_null')
     if isinstance(content,dict) and 'sources'in content:rec['authoritative_source_response']=bool(content['sources'])
     if isinstance(content,dict) and 'error'in content:rec['provider_error']=content['error']
    except (ValueError,UnicodeDecodeError):pass
  else:rec['file_present']=False
  records.append(rec)
(BASE/'retrievals.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('acquisition records',len(records),'files present',sum(r['file_present'] for r in records))
