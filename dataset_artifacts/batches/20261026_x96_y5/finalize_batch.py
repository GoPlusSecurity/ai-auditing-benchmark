"""Write audit inventories and batch guide from actual materialized results."""
import datetime as dt, hashlib, json, os, sys
from pathlib import Path
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[2]
sys.path.insert(0,str(ROOT/'docs/cases/sources'))
from archive_maintenance import refresh_batch_inventory
def load(p):return json.loads(p.read_text('utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def rel(p,b=BASE):return Path(os.path.relpath(p,b)).as_posix()
def walk(value):
 if isinstance(value,dict):
  if ('url' in value or 'source_url' in value) and any(k in value for k in ['path','response_path','file','output_path','destination']):yield value
  for v in value.values():yield from walk(v)
 elif isinstance(value,list):
  for v in value:yield from walk(v)
def resolve(value,owner):
 if not isinstance(value,str):return None
 p=Path(value)
 candidates=[p] if p.is_absolute() else [BASE/p,owner.parent/p,ROOT/p]
 for c in candidates:
  if c.is_file() and c.resolve().is_relative_to(BASE.resolve()):return c.resolve()
 return None
def main():
 snap=load(BASE/'snapshot.json');results=load(BASE/'results.json');mat=load(BASE/('materialization-current.json' if (BASE/'materialization-current.json').exists() else 'materialization.json'))
 records=[];logs=[]
 for log in sorted(BASE.rglob('*.json')):
  if log.name in ['retrieval_inventory.json','retrieval_inventory-current.json','file_inventory.json','validation.json']:continue
  if not any(t in log.name for t in ['fetch','retrieval','provenance','jobs']):continue
  try:data=load(log)
  except Exception:continue
  found=list(walk(data))
  if not found:continue
  logs.append({'path':rel(log),'sha256':sha(log)})
  for item in found:
   path=next((item.get(k) for k in ['path','response_path','file','output_path','destination'] if isinstance(item.get(k),str)),None)
   file=resolve(path,log)
   entry={'log':rel(log),'url':item.get('url',item.get('source_url')),'requested_path':path,'original_record':item}
   if file:
    entry.update(path=rel(file),bytes=file.stat().st_size,sha256=sha(file),observed_file_mtime_utc=dt.datetime.fromtimestamp(file.stat().st_mtime,dt.timezone.utc).isoformat(),file_time_note='Filesystem modification time observed during this run; copying or checkout can change it. Acquisition time is only the value retained in the original record.')
    if file.suffix=='.json':
     try:
      body=load(file)
      if isinstance(body,dict) and 'jsonrpc' in body:
       entry['rpc_response_status']='error' if 'error' in body else ('null_result' if body.get('result') is None else 'non_null_result')
     except Exception:entry['response_json_parse']='failed_or_non_json_body'
   else:entry['local_response']='absent; consult original error/status, not counted as source acquired'
   records.append(entry)
 # Explicit authoritative source entries ensure each formal source response is covered.
 for selected in results['included_cases']:
  cid=selected['case_id'];a=ROOT/'dataset_artifacts'/cid;p=load(a/'provenance.json')
  for bundle in p['bundles']:
   records.append({'kind':'formal_original_source','case_id':cid,'bundle':bundle['id'],'url':bundle['url'],'path':rel((a/bundle['response_path']).resolve()),'sha256':bundle['response_sha256'],'runtime_match':bundle.get('runtime_match'),'creation_match':bundle.get('creation_match'),'retrieval_time':bundle.get('retrieved_at'),'time_basis':bundle.get('retrieval_time_basis','existing response; see original case provenance')})
 records.insert(0,{'kind':'archived_fixed_sheet_export','url':snap['parameters']['export_url'],'path':'sheet_gid0_raw.csv','sha256':snap['raw_export_sha256'],'retrieved_at':snap['parameters']['retrieved_at'],'timezone':'Asia/Shanghai'})
 dump(BASE/'retrieval_inventory-current.json',{'records':records,'raw_log_files':logs,'interpretation':'A recorded HTTP success or saved file is not proof of a valid RPC result or verified source. Null results, service errors, pending command records, and failed requests are retained separately. File times are labelled when exact request times were not captured.'})
 rows=results['rows'];newids=[x['case_id'] for x in rows if x['status']=='new']
 guide='# X=96、Y=5：公开合约漏洞源码整理\n\n'
 guide+='本批重新下载指定 Google 表格，按 CSV 解析记录从 **96** 行逐行向上检查，到 **85** 行达到 **5** 条合格记录即停止。实际扫描 **12** 行，新增 **4** 例、复用 **1** 例、跳过 **7** 行。表格第 1 行说明、第 2 行表头、14 列及含换行单元格已核对；原始导出共 '+str(snap['parsed_record_count'])+' 条解析记录。\n\n'
 guide+='原始 CSV SHA-256：`'+snap['raw_export_sha256']+'`。\n\n'
 guide+='固定资料：[原始CSV](sheet_gid0_raw.csv)、[本批快照](snapshot.json)、[逐行结果](results.json)、[抓取来源与失败](retrieval_inventory.json)、[验证结果](validation.json)、[选行边界测试](selection_tests.txt)。读取时间：'+str(snap['parameters']['retrieved_at'])+'（Asia/Shanghai）。\n\n'
 guide+='## 每一行的处理\n\n| 行号 | 事件 | 结果 | 原因 |\n| --- | --- | --- | --- |\n'
 for item in rows:
  event=item['event'];cid=item['case_id']
  if cid:event=f'[{event}](../../../docs/cases/{cid}.md)'
  status={'new':'新增','reused_existing':'复用','skipped':'跳过'}[item['status']]
  guide+=f"| {item['row']} | {event} | {status} | {item['reason']} |\n"
 guide+='\n## 数据位置和来源规则\n\n'
 guide+='- `dataset` 保存权威原始 Solidity/Vyper 代码及明确标名的高层反编译代码；仅保留完整源码。\n'
 guide+='- 所有原始源码直接下载自 Sourcify 等权威验证站点；源文件逐字来自对应原始响应，保留原名、编译配置、ABI、URL、时间和 SHA-256。官方复盘作为背景，与原始代码资格分别处理。\n'
 guide+='- 原始响应、运行码、纯反汇编、HTML、元数据、说明、编译配置及核验脚本都在 `dataset_artifacts`，不会进入源码目录。\n'
 guide+='- 反编译结果不是原始源码。公开在线工具的输入、原始输出、历史块、字节码散列、未报告版本及恢复错误单独记录；未执行本地反编译程序或下载合约。\n'
 guide+='- 四个新事件在源码/资料目录和中英文 CSV 对齐；两个 CSV 的旧字节完整保留，只按日期和案例ID追加。Allbridge 重新核查核心30原文件并复用旧记录，不再新增 CSV 行。\n\n'
 guide+='## 金额与证据范围\n\n'
 guide+='Sandbox 的源表67万美元和官方后续约69.7万美元没有统一统计口径；Term 的全案美元估计不能用本批单笔WETH付款替代；Moonwell 早期估计、毛借款、剩余债务与净收益不同。因此这三例的两份 CSV 金额均留空。FH 保留源表/初始警报约20,000美元，Decimal换算为中文2万美元、英文20千美元；同时另列已核实19,999.018106552928530404 USDT净流出。已有Allbridge原CSV记录保持原样。\n\n'
 guide+='本批原始源码、历史部署绑定、历史状态、交易行为和复现状态分别记录。Sandbox已核实接管、改验证配置、首铸与首卖，Ethereum跨链总付款未完全汇总；FH有目标池runtime与验证参考池的字节等同性，仍无目标池直接验证记录与完整内部trace；Term已解码治理快照、17步提案和WETH付款，helper反编译服务失败仍列明；Moonwell已核对捐赠端点、报价和17笔/18次借款，但全部外部价格操纵、清算及最终净损益未重建。\n\n'
 guide+='未编译 Solidity/Vyper，未部署、分叉重放或发送交易，未执行上游 PoC。未执行编译。\n\n'
 guide+='## 验收与复查\n\n'
 guide+='本批验证名单来自 snapshot/results；检查五例源码、资料和索引同步、原始响应与源码字节、全部文件散列、金额换算、旧 CSV 前缀、源码目录纯代码、文档本地链接/行号/Mermaid块及工作区基线。结构通过不能替代经济损益或历史全状态证明。\n\n'
 guide+='批次离线工具：[物化脚本](build_batch.py)、[核验脚本](validate_batch.py)、[汇总脚本](finalize_batch.py)。它们是本任务编写的数据处理工具，不执行合约；合约编译或攻击重放不在本批验证范围。\n'
 (BASE/'README.md').write_bytes(('> 当前仅使用平铺完整源码；原快照、取证记录与 validation.json 均为历史记录。当前验收见 [迁移批次](../20261027_amos_tz_merge/README.md)。\n\n'+guide).encode('utf-8'))
 count=refresh_batch_inventory(BASE)
 print(json.dumps({'retrieval_records':len(records),'raw_logs':len(logs),'batch_files_hashed':count},ensure_ascii=False))
if __name__=='__main__':main()
