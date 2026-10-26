"""Build only the five source-qualified rows from the fixed X=96,Y=5 snapshot.
Own offline curation code; never executes downloaded contracts or PoCs.
"""
from __future__ import annotations
import csv, datetime as dt, hashlib, io, json, os, pathlib, shutil, subprocess, sys
from decimal import Decimal
from pathlib import Path
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
sys.path.insert(0,str(ROOT/'docs/cases/sources'))
import validate_20261002_batch as shared
from archive_maintenance import append_missing_rows
BATCH='20261026_x96_y5'
OLD='20260820_Allbridge_CCTP'
EXTS={'.sol','.vy','.yul','.huff','.vyi'}
def load(p):return json.loads(p.read_text('utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):
 p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
def rel(p,b):return Path(os.path.relpath(p,b)).as_posix()
def resolve_batch(p):
 v=Path(p)
 if v.is_absolute(): out=v.resolve()
 elif str(p).replace('\\','/').startswith('dataset_artifacts/'):out=(ROOT/v).resolve()
 else:out=(BASE/v).resolve()
 assert out.is_relative_to(BASE.resolve()),p
 return out
def safe_name(name):
 prefix='/Users/yos/chainlink2/evm-contracts/'
 name=name[len(prefix):] if name.startswith(prefix) else name
 p=Path(name)
 assert not p.is_absolute() and '..' not in p.parts and ':' not in name,name
 return p
def checksum(cid):
 art=ROOT/'dataset_artifacts'/cid;code=ROOT/'dataset'/cid
 fs=[p for tree in [art,code] for p in tree.rglob('*') if p.is_file() and p.name!='SHA256SUMS']
 newline='\n'
 (art/'SHA256SUMS').write_bytes(''.join(sha(p)+'  '+rel(p,art)+newline for p in sorted(fs,key=lambda p:rel(p,art))).encode())

SKIPS={
 96:('Maya Protocol','链协议 Trade Account / 盗窃补贴检查事件；当前资料定位节点协议逻辑，未确认属于本批合约代码漏洞。','source_sheet_classification; prior case-index context'),
 94:('BounceBit','源表及项目公告定位链节点/Cosmos 模块，未确认合约代码漏洞及相应原始源码，不因资产损失将其收为合约案例。','source_sheet_and_original_project_announcement_link'),
 93:('地址投毒','复制污染转账历史中的错误地址造成损失；没有确认的合约代码缺陷。','source_sheet_original_disclosure'),
 90:('Cosmos EVM / MANTRA / TAC / KiiChain','Cosmos 官方复盘定位 StateDB 与 SDK bank 余额、staking precompile 和 vesting 账户的节点实现问题，不属于本批智能合约代码。','official_cosmos_security_postmortem'),
 88:('Enjin CryptoItems','关键代理/适配器漏洞原始源码未取得；Etherscan未验证、Sourcify查询404，官方样例仓库不能证明目标槽位冲突版本。','see_enjin_qualification'),
 87:('Realio','源表原始项目披露定位网页应用与平台签名能力被接管；未确立合约权限绕过和对应漏洞原始源码。','source_sheet_project_disclosure; no_independent_contract_root_cause'),
 86:('ComeCome 恶意应用','现有资料是涉嫌恶意应用盗币，不是已确认合约代码漏洞；本批未执行应用或恶意链接。','source_sheet; allegation_not_independently_validated')
}
def main():
 snapshot=load(BASE/'input_snapshot.json');raw=BASE/'sheet_gid0_raw.csv'
 rows=shared.read_csv(raw);shared.validate_sheet_structure(rows)
 assert sha(raw)==snapshot['raw_export_sha256']
 baseline=load(BASE/'baseline.json')
 specs=[load(BASE/n/'case_spec.json') for n in ['sandbox','term','fh','moonwell']]
 for c in specs:
  assert c['qualified'] is True,c['case_id']
  c['row']=c.get('sheet_row',c['metadata'].get('sheet_row'))
  assert isinstance(c['row'],int)
  assert c['case_id'][:8]==rows[c['row']-1][5].replace('-','')
  assert c['sources']
  for s in c['sources']:
   response=load(resolve_batch(s['response_path']))
   assert response.get('runtimeMatch') in ('match','exact_match'),s
   assert response.get('sources'),s
   for name,v in response['sources'].items():
    assert safe_name(name).suffix in EXTS,name
  for d in c.get('decompilations',[]):
   assert resolve_batch(d.get('source_path',d.get('original_file_path'))).is_file(),d
 reuse=load(BASE/'allbridge_requalification.json');assert reuse['qualifies']
 byrow={c['row']:c for c in specs}
 decisions=[]
 for row in range(96,84,-1):
  fields=dict(zip(rows[1],rows[row-1]));case=byrow.get(row)
  item={'row':row,'sheet_event':fields['target (社媒 or Addr)'],'references':[fields['original_link'].strip()]}
  if row==95:
   item.update(event='Allbridge CCTP',case_id=OLD,qualifies=True,status='reused_existing',reason='本批重新下载并比较核心Messenger/Router原始源码30文件；既有原始源码哈希与文档复核通过，复用原记录。',source_qualification='public_original_vulnerable_source_refreshed',evidence='allbridge_requalification.json')
  elif case:
   item.update(event=case['metadata']['project_cn'],case_id=case['case_id'],qualifies=True,status='new',reason='取得与核心缺陷有关的权威公开原始源码，正常依赖、历史绑定、付款与未开源辅助合约边界见案例说明。',source_qualification='public_original_vulnerable_source_obtained',evidence=rel(resolve_batch(case.get('draft_path',case['case_id'])),BASE))
  else:
   event,reason,status=SKIPS[row]
   item.update(event=event,case_id=None,qualifies=False,status='skipped',reason=reason,source_qualification='not_qualified_this_batch',evidence_status=status)
   if row==88:item['qualification_file']='enjin/qualification.json'
   if row==90:item['official_source']='https://github.com/cosmos/security/blob/main/communications/cosmos_evm_GHSA-7g4w-cg88-2cq2_post_mortem.md';item['evidence']='cosmos-official-postmortem.md'
  decisions.append(item)
 processed,selected=shared.select_qualifying_rows(rows,96,5,decisions)
 assert processed==list(range(96,84,-1))
 assert [c['row'] for c in selected]==[95,92,91,89,85]
 # All gates above run before formal writes.
 params={**snapshot['parameters'],'x':96,'y':5,'actual_scan_range':[min(processed),max(processed)],'processing_order':processed,'selected_source_rows':[c['row'] for c in selected],'source_url':snapshot['source_url'],'export_url':snapshot['export_url'],'retrieved_at':snapshot['retrieved_at'],'timezone':snapshot['timezone'],'raw_export_sha256':sha(raw),'raw_export':raw.name}
 dump(BASE/'snapshot-current.json',{'parameters':params,'header':rows[1],'parsed_record_count':len(rows),'raw_export_sha256':sha(raw),'structure':snapshot['structure'],'rows':[{'row':r,'cells':rows[r-1],'fields':dict(zip(rows[1],rows[r-1]))} for r in processed]})
 counts={'scanned_rows':len(processed),'qualifying_source_rows':len(selected),'new_cases':len(specs),'reused_existing_cases':1,'completed_existing_cases':0,'duplicate_rows_merged':0,'skipped_rows':len(processed)-len(selected)}
 dump(BASE/'results-current.json',{'parameters':params,'counts':counts,'rows':decisions,'included_cases':[{'case_id':s['case_id'],'source_rows':[s['row']],'status':s['status']} for s in selected],'formal_write_gate':'five independently source-qualified rows reached before dataset/CSV writes','decompilation_policy':'public online outputs only, explicitly separate from original source; no local execution of contracts or PoCs'})
 source_count=decomp_count=0
 for c in specs:
  cid=c['case_id'];full=ROOT/'dataset'/cid
  art=ROOT/'dataset_artifacts'/cid
  art.mkdir(parents=True,exist_ok=True)
  prior_bundles={b['id']:b for b in load(art/'provenance.json').get('bundles',[])} if (art/'provenance.json').exists() else {}
  bundles=[];lookup={}
  for s in c['sources']:
   original=resolve_batch(s['response_path']);d=load(original);bundle=s['id'];ba=art/'source-bundles'/bundle;ba.mkdir(parents=True,exist_ok=True)
   shutil.copyfile(original,ba/'source-response.json')
   records=[]
   for name,v in d['sources'].items():
    p=full/'source-bundles'/bundle/safe_name(name);assert p.resolve().is_relative_to(full.resolve())
    p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(v['content'].encode('utf-8'))
    lookup[bundle,name]=p
    records.append({'path':rel(p,art),'original_source_path':name,'sha256':sha(p),'bytes':p.stat().st_size});source_count+=1
   for name,key in [('abi.json','abi'),('standard-input.json','stdJsonInput'),('compiler-settings.json','compilation')]:
    if key in d:dump(ba/name,d[key])
   bundles.append({**{k:v for k,v in s.items() if k not in ['response_path','path','bundle_dir']},'kind':'public_original_source','url':s.get('url',f"https://sourcify.dev/server/v2/contract/{d['chainId']}/{d['address']}?fields=all"),'retrieved_at':s.get('retrieved_at',prior_bundles.get(bundle,{}).get('retrieved_at')),'retrieval_time_basis':s.get('retrieval_time_basis',prior_bundles.get(bundle,{}).get('retrieval_time_basis','archived provenance; null timestamp means unavailable')),'response_path':rel(ba/'source-response.json',art),'response_sha256':sha(ba/'source-response.json'),'chain_id':d['chainId'],'verified_at':d.get('verifiedAt'),'runtime_match':d.get('runtimeMatch'),'creation_match':d.get('creationMatch'),'deployment':d.get('deployment'),'source_files':records})
  decomp=[]
  for d in c.get('decompilations',[]):
   original=resolve_batch(d.get('source_path',d.get('original_file_path')));name=d.get('target_path','decompiled/'+original.name)
   target=full/safe_name(name);assert target.suffix=='.sol' and 'decompiled' in target.name
   target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(original,target);decomp_count+=1
   rec={**d,'path':rel(target,art),'sha256':sha(target)}
   for k in ['source_path','original_file_path','raw_response_path','runtime_path','runtime_hex_path','request_path','provenance_path']:
    if d.get(k):rec[k]=rel(resolve_batch(d[k]),art)
   decomp.append(rec)
  dump(art/'provenance.json',{'case_id':cid,'path_base':'this artifact directory','bundles':bundles,'decompilations':decomp,'batch_evidence_root':rel(BASE,art),'batch_retrieval_inventory':rel(BASE/'retrieval_inventory.json',art),'roles':c.get('roles',[]),'evidence_gaps':c.get('evidence_gaps',[]),'source_vs_history':'Provider source verification, historical deployment binding, state reads and transaction observations are separate; see case document and batch evidence.'})
  meta={**c['metadata'],'case_id':cid,'event_date':rows[c['row']-1][5],'original_rows':[c['row']],'public_original_vulnerable_source':True,'source_sheet_snapshot':'../batches/'+BATCH+'/snapshot.json','batch_results':'../batches/'+BATCH+'/results.json','case_document':'../../docs/cases/'+cid+'.md','evidence_gaps':c.get('evidence_gaps',[]),'local_compilation':'not_run','deployment':'not_run','fork_replay':'not_run','transactions_sent':False,'upstream_scripts_executed':False,'source_provenance_kind':'original_verified_source_with_separately_labelled_online_decompilation' if decomp else 'original_verified_source'}
  dump(art/'case_metadata.json',{**meta,'source_provenance':'provenance.json'})
  (art/'SOURCE.md').write_text('# '+cid+'\n\n[完整源码](../../dataset/'+cid+'/)、[案例说明](../../docs/cases/'+cid+'.md)、[来源清单](provenance.json)。\n\n原始源码和明确标记的在线反编译输出分别记录；失败与历史绑定限制见来源清单及案例说明。未编译、部署或重放。\n',encoding='utf-8')
  doc=resolve_batch(c['draft_path']);shutil.copyfile(doc,ROOT/'docs/cases'/f'{cid}.md')
  checksum(cid)
 # Reuse existing case without duplicate CSV, preserving prior snapshot identity.
 a=ROOT/'dataset_artifacts'/OLD;p=a/'case_metadata.json';m=load(p)
 appearances=[v for v in m.get('batch_appearances',[]) if v.get('batch')!=BATCH]
 appearances.append({'batch':BATCH,'source_rows':[95],'action':'requalified_and_reused','snapshot':'../batches/'+BATCH+'/snapshot.json','evidence':'../batches/'+BATCH+'/allbridge_requalification.json'})
 m['batch_appearances']=appearances;dump(p,m);checksum(OLD)
 doc=ROOT/'docs/cases'/f'{OLD}.md';s=doc.read_text('utf-8');marker='<!-- '+BATCH+' -->'
 paragraph=marker+'\n\n2026-10-26 批次 X=96、Y=5 重新定位为固定快照第 95 行。已重新下载核心 Messenger 与 Router 权威原始源码，30 个文件与既有版本逐字一致，历史复核已通过，因此复用本例和两份 CSV 的原记录，不新增重复事件。旧批次第 88 行仍仅表示原来的快照位置。[本批复核记录](../../dataset_artifacts/batches/'+BATCH+'/allbridge_requalification.json)。\n\n'
 if marker not in s:s=s.split('\n',1)[0]+'\n\n'+paragraph+s.split('\n',1)[1].lstrip('\n')
 doc.write_text(s,encoding='utf-8')
 dump(BASE/'csv_append_current.json',append_missing_rows(ROOT,[c['case_id'] for c in specs]))
 # Index change is confined to one new section.
 p=ROOT/'docs/cases/README.md';old=p.read_text('utf-8');heading='## 2026-10-26 按 X=96、Y=5 向上筛选'
 section=heading+'\n\n使用本次重新下载并固定的 CSV，从第 96 行逆序检查，到第 85 行找到第五条合格记录，扫描 **85–96，共 12 行**。新增 **4** 例，复用 **1** 例，跳过 **7** 行；第 95 行 Allbridge 已重新取得核心原码并复核。\n\n| 源表行 | 案例 | 处理 |\n| --- | --- | --- |\n'
 for c in selected:section+=f"| {c['row']} | [{c['event']}]({c['case_id']}.md) | {'复用' if c['row']==95 else '新增'} |\n"
 section+='\n源码与标明性质的高层反编译代码仅存 dataset；原始响应、ABI、编译设置、下载失败、历史证据和说明存 dataset_artifacts。Sandbox、Term、Moonwell 的美元金额因口径不能统一留空；FH 保留约 20,000 美元估计，并另列原币净流出。未本地编译或分叉重放。\n\n批次入口：[说明与跳过原因](../../dataset_artifacts/batches/'+BATCH+'/README.md)、[固定快照](../../dataset_artifacts/batches/'+BATCH+'/snapshot.json)、[逐行结果](../../dataset_artifacts/batches/'+BATCH+'/results.json)、[验证报告](../../dataset_artifacts/batches/'+BATCH+'/validation.json)。\n\n原始导出 SHA-256：`'+sha(raw)+'`。\n\n'
 if heading in old:
  start=old.index(heading);end=old.find('\n## ',start+len(heading));old=old[:start]+old[end+1:]
 offset=old.index('## ');p.write_text(old[:offset]+section+old[offset:],encoding='utf-8')
 dump(BASE/'materialization-current.json',{'counts':counts,'source_files':source_count,'decompiled_files':decomp_count,'csv_new_rows_each':len(specs),'case_ids':[s['case_id'] for s in selected]})
 print(json.dumps(load(BASE/'materialization-current.json'),ensure_ascii=False))
if __name__=='__main__':main()
