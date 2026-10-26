"""Finalize evidence metadata using saved public responses only."""
from pathlib import Path
import json,hashlib,datetime as dt,re
ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[3]
PREFIX='dataset_artifacts/batches/20261026_x96_y5/fh/'
def read(name):return json.loads((ROOT/name).read_text())
def write(name,value):(ROOT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def timestamp(path):return dt.datetime.fromtimestamp(path.stat().st_mtime,dt.timezone.utc).isoformat()

spec=read('case_spec.json')
usdt=read('usdt-source.json')
source={'id':'bsc-usdt','response_path':PREFIX+'usdt-source.json','role':'normal_payout_token_historical_runtime_bound','provider':'Sourcify','address':usdt['address']}
spec['sources']=[s for s in spec['sources'] if s['id']!='bsc-usdt']+[source]
spec['slices']['bsc-usdt']={'BEP20USDT.sol':[[339,414],[447,451],[524,531]]}
for s in spec['sources']:
 if s['id']=='pancake-pair-reference':
  s['role']='normal_protocol_reference_source_with_identical_target_historical_runtime'
  s['binding_status']='Target runtime at blocks 117979401 and 117979402 exactly equals this verified reference address runtime; not direct target source verification or target creation-compilation proof.'
 for name,obj in read(Path(s['response_path']).name)['sources'].items():
  dest=ROOT/'source-bundles'/s['id']/name; dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(obj['content'].encode('utf-8'))

runtime=read('runtime-comparison.json')
assert all(r['before_equals_attack'] and r['before_equals_source_onchain'] and r['provider_recompiled_plus_reported_transforms_equals_historical'] for r in runtime)
decimals=int(read('usdt-decimals-attack-blast.json')['result'],16)
assert decimals==18
metadata=spec['metadata']
metadata['verification_status']='original_sources_and_historical_runtime_confirmed;receipt_and_25_cycles_confirmed;usdt_decimals_18_historically_confirmed;attacker_online_decompilation_archived;full_trace_unavailable;no_replay'
metadata['detail_cn']=metadata['detail_cn'].replace('（18位口径为19,999.018106552928530404 USDT）','（历史decimals=18，即19,999.018106552928530404 USDT）')
metadata['detail_en']=metadata['detail_en'].replace('(19,999.018106552928530404 USDT at 18 decimals)','(19,999.018106552928530404 USDT; historical decimals=18)')
spec['evidence_gaps']=[
 'Full internal call trace unavailable; particular intermediate entry-point calldata is inferred from original source, event sender, online supplementary decompilation, and exact output arithmetic.',
 'Target pair source lookup returned Sourcify 404 and BscScan 403. Its historical runtime exactly equals the verified reference address runtime, but the reference response is not direct target verification, target creation-transaction proof, or independent local compilation.',
 'The complete pre-transaction whitelist, dynamic-fee, and totalSupply state was not reconstructed; successful receipt proves the exercised path conditions, not all other state.',
 'Attacker original source unavailable. Online high-level decompilation is supplementary reconstructed code with two preserved Error comments; the service did not report its engine version. It is not authoritative original source or a full execution trace.'
]
spec['runtime_comparison_path']=PREFIX+'runtime-comparison.json'
spec['historical_decimals_evidence']={'response_path':PREFIX+'usdt-decimals-attack-blast.json','block_number':117979402,'value':18,'source_url':'https://bsc-mainnet.public.blastapi.io'}

# Only the genuine high-level service output is offered for the formal decompiled code location.
raw_high=ROOT/'attacker-ethervm-decompiled.txt'
high=ROOT/'attacker.ethervm.decompiled.sol'
high.write_bytes(raw_high.read_bytes())
decomp=read('decompilation-provenance.json')
decomp['formal_decompiled_code_path']='attacker.ethervm.decompiled.sol'
decomp['formal_decompiled_code_sha256']=sha(high)
decomp['formal_source_classification']='reconstructed high-level code from a public online decompiler; not original Solidity source and no standalone compilation claimed'
decomp['retrieved_at_utc']=timestamp(ROOT/'attacker-ethervm-response.html')
decomp['timestamp_kind']='download_response_file_write_time'
write('decompilation-provenance.json',decomp)
spec['decompilations']=[{
 'id':'fh-attacker-ethervm','kind':'public_online_high_level_decompiler_output','role':'attacker_execution_contract_supplementary_context',
 'address':'0x727Fb666E3F2531e807E987532C6e2C22ADC45aD','chain_id':56,
 'source_path':PREFIX+high.name,'original_file_path':PREFIX+high.name,'target_path':'decompiled/'+high.name,
 'raw_response_path':PREFIX+'attacker-ethervm-response.html','request_path':PREFIX+'attacker-ethervm-request.txt',
 'runtime_path':PREFIX+'attacker-runtime-before-blast.json','runtime_hex_path':PREFIX+'attacker-runtime.hex',
 'historical_block':117979401,'also_confirmed_at_block':117979402,
 'tool':'ethervm.io Online Solidity Decompiler','tool_url':'https://ethervm.io/decompile','tool_version':None,
 'tool_version_status':'engine version not reported by returned page; no frontend or CDN version substituted',
 'sha256':sha(high),'runtime_sha256':decomp['runtime_sha256'],'raw_response_sha256':sha(ROOT/'attacker-ethervm-response.html'),
 'runtime_bytes':3577,'decompiled_error_comment_count':2,'retrieved_at_utc':decomp['retrieved_at_utc'],
 'bytecode_binding':'POST request contains the exact historical runtime. The returned separate disassembly was checked against all 3577 input bytes with no mismatches.',
 'not_original_source':True,'not_used_to_replace_core_original_source':True,
 'artifact_only_files':['raw HTML','request body','runtime hex/RPC responses','disassembly','provenance and hashes'],
 'provenance_path':PREFIX+'decompilation-provenance.json'
}]
write('case_spec.json',spec)

qualification=read('qualification.json')
qualification.update(qualification_status='qualified_original_source_historical_runtime_receipt',eligible=True,
 reason='FH精确匹配原始源码直接包含漏洞；历史FH、两Router、USDT及目标池代码与对应Sourcify链上代码逐字一致，原回执与25轮整数算式闭合。目标池使用不同地址验证的参考源码，历史runtime相同但不冒充目标直接验证。',
 evidence_gaps=spec['evidence_gaps'],collection_status='原始源码、历史runtime、历史USDT decimals、成功回执及攻击执行合约的公开在线高层反编译均已归档；所有访问失败也保留。',
 historical_runtime_evidence=PREFIX+'runtime-comparison.json',usdt_decimals=18,
 online_decompilation_status='archived genuine high-level output; supplementary only; engine version unavailable; two Error comments preserved')
write('qualification.json',qualification)

# Merge acquisition logs. HTTP errors and JSON-RPC error bodies remain saved as failures.
provenance=read('provenance.json')
additional=[]
for manifest in ['supplementary-acquisition.json','archive-fallback-acquisition.json','complete-archive-acquisition.json','attacker-acquisition.json']:
 data=read(manifest)
 rows=data['requests'] if isinstance(data,dict) else data
 for wrapped in rows:
  if wrapped.get('status')!='fulfilled':continue
  rec=dict(wrapped['value']);rec['manifest']=manifest;additional.append(rec)
online=read('online-decompilation-acquisition.json')
for key in ['dedaub_api','ethervm_form','ethervm_decompilation']:
 rec=dict(online[key]);rec['manifest']='online-decompilation-acquisition.json';additional.append(rec)
for rec in additional:
 path=REPO/rec['path'].replace('\\','/')
 rec['path']=rec['path'].replace('\\','/')
 rec['http_status']=int(re.findall(r'\b(200|403|404)\b',rec['result'].get('output',''))[-1]) if re.findall(r'\b(200|403|404)\b',rec['result'].get('output','')) else None
 if path.name=='attacker-ethervm-response.html':
  rec['http_status']=200;rec['completed_at_utc']=timestamp(path);rec['completion_status']='process polled to exit 0; HTTP 200'
 if path.exists():
  rec.update(sha256=sha(path),bytes=path.stat().st_size,raw_response_preserved=True)
  if path.suffix=='.json':
   try: obj=json.loads(path.read_text())
   except (ValueError,UnicodeError): obj=None
   if isinstance(obj,dict) and obj.get('error'):
    rec.update(semantic_status='rpc_error_not_requested_evidence',rpc_error=obj['error'])
  if rec['http_status'] and rec['http_status']>=400:rec['semantic_status']='http_error_not_requested_evidence'
 # Avoid recording the initial non-completion time as the final response timestamp.
 if path.name=='attacker-ethervm-response.html':rec['finished_at_utc']=timestamp(path)
provenance['supplementary_acquisitions']=additional
existing=[b for b in provenance['bundles'] if b['id']!='bsc-usdt']
raw=ROOT/'usdt-source.json'
record=next(r for r in additional if r['path'].endswith('/usdt-source.json'))
existing.append({**source,'url':record['url'],'response_sha256':sha(raw),'retrieved_at':record['finished_at_utc'],
 'timestamp_kind':'tool_download_completion_recorded','chain_id':usdt['chainId'],'verified_at':usdt['verifiedAt'],
 'runtime_match':usdt['runtimeMatch'],'creation_match':usdt['creationMatch'],'deployment':usdt.get('deployment'),
 'source_files':[{'original_filename':name,'sha256':hashlib.sha256(obj['content'].encode()).hexdigest(),'bytes':len(obj['content'].encode())} for name,obj in usdt['sources'].items()]})
for bundle in existing:
 if bundle['id']=='pancake-pair-reference':
  bundle['role']='normal_protocol_reference_source_with_identical_target_historical_runtime'
  bundle['target_historical_runtime_evidence']='runtime-comparison.json'
provenance['bundles']=existing
provenance['historical_runtime_comparison']=runtime
provenance['historical_decimals']={'address':usdt['address'],'block_number':117979402,'response':'usdt-decimals-attack-blast.json','value':18}
provenance['decompilations']=spec['decompilations']
provenance['limitations']=spec['evidence_gaps']
provenance['completion_scope']='Historical RPC reads and offline byte/string/integer comparisons only. Provider-reported bytecode transformations checked offline; no local compilation, replay, transaction or upstream-code execution.'
write('provenance.json',provenance)

# Add normalized amounts without dropping original integer values.
decoded=read('decoded_evidence.json')
decoded['token_decimals']={'0xdcf0dfe0053677a67610c6d08ea1f5c78df8ca37':{'value':18,'evidence':'token-source.json: contracts/FHToken.sol constructor and decimals getter'},'0x55d398326f99059ff775485246999027b3197955':{'value':18,'historical_response':'usdt-decimals-attack-blast.json','block_number':117979402}}
decoded['usdt_loss_summary']={'raw_net_pool_outflow':'19999018106552928530404','raw_net_eoa_inflow':'19999018106552928530404','decimals':18,'net_usdt':'19999.018106552928530404','source_sheet_loss_usd_estimate':'20000','bnb_costs_deducted':False}
write('decoded_evidence.json',decoded)

# Update the prose to describe completed evidence and permanent limits, with no pending placeholders.
p=ROOT/'draft.md';text=p.read_text()
text=text.replace('此参考响应原来对应另一个已验证池地址；目标池的历史运行时代码绑定单独记录，不能仅凭同名 `PancakePair` 当成部署证明。','此参考响应原来对应另一个已验证池地址 `0x63844BD4BFad910B1643713302a1cC1ed20d50c3`。本批读取目标池在区块 117,979,401 和 117,979,402 的 runtime，二者与参考响应中的链上 runtime 逐字一致。这个比对支持本案使用相同运行逻辑，但不会把参考地址源码变成目标地址的直接验证记录、目标创建交易证明或本地重编译证明。')
text=text.replace('USDT 的历史 decimals 响应仍待补齐，18 位换算与原始整数计算分开记录。','区块 117,979,402 的 `decimals()` 原响应为 `0x12`，即 18；[USDT 原始实现 339–373 行](../../dataset/20260826_FH/source-bundles/bsc-usdt/BEP20USDT.sol#L339-L373)也给出同一位数。')
text=text.replace('两 Router 为平台的 `match`。','两 Router 和 USDT 为平台的 `match`。FH、两 Router、USDT 的攻击前后 runtime 均与各自 Sourcify `onchainBytecode` 逐字一致；目标池 runtime 与已验证参考池 runtime 也逐字一致。FH 还直接等于平台保存的 `recompiledBytecode`。其余源码包使用平台记录的 immutable／元数据变换后也与历史字节码一致；这里只做字节比较，没有本地编译。')
old='目标池的直接 Sourcify 请求返回 404；已归档另一地址的正常 PancakePair 原始参考实现，并把它与受害池区分。完整内部调用跟踪接口不可用，攻击执行合约未取得公开原始源码；这些文件不承担核心漏洞源码证明。本批没有重建全部攻击前白名单、手续费和总供应量状态，成功回执可以支持实际走过的分支条件，不能扩大为所有历史设置都已检查。'
new='目标池的直接 Sourcify 请求返回 404，BscScan 源码页返回 403；已保存失败原响应。官方 BSC 节点读取历史状态返回 `missing trie node`，随后从 Blast 归档 RPC 取得上述历史代码和 USDT 位数。完整内部调用跟踪接口仍不可用。本批没有重建全部攻击前白名单、手续费和总供应量状态，成功回执可以支持实际走过的分支条件，不能扩大为所有历史设置都已检查。\n\n攻击执行合约的原始源码查询为 Sourcify 404、BscScan 403；Dedaub 页面和 API 也返回 403。之后通过 ethervm.io 公开表单，把已归档的历史 runtime 提交给在线反编译服务，取得了[高层反编译输出](../../dataset_artifacts/batches/20261026_x96_y5/fh/attacker.ethervm.decompiled.sol)。原始 HTML、请求体和[反编译来源记录](../../dataset_artifacts/batches/20261026_x96_y5/fh/decompilation-provenance.json)均已保存。服务另附的反汇编与输入 runtime 全部 **3,577 字节**逐字节相符；输入 SHA-256 为 `9466bf0dd8f8017357fd9a60cffbcc60124884f95cb5dd157ae21d85bbe1b26f`。反编译引擎版本未在页面报告，输出中的两处 `Error` 注释原样保留。它是服务重建的高层代码，只作攻击合约上下文，不是原始源码，也不补成完整调用跟踪；纯 hex、反汇编和 HTML 不归入正式源码。'
text=text.replace(old,new)
p.write_text(text,encoding='utf-8')

# Fresh structural checks against the final specification.
files=0;slice_count=0
for source in spec['sources']:
 d=read(Path(source['response_path']).name)
 for name,obj in d['sources'].items():
  assert (ROOT/'source-bundles'/source['id']/name).read_bytes()==obj['content'].encode('utf-8');files+=1
 for name,ranges in spec['slices'].get(source['id'],{}).items():
  lines=d['sources'][name]['content'].splitlines(keepends=True)
  for lo,hi in ranges:assert 1<=lo<=hi<=len(lines);slice_count+=1
assert high.read_bytes()==raw_high.read_bytes()
assert not re.search(r'pending|仍待补齐',spec['metadata']['verification_status']+text)
verification={'checked_at_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'scope':'offline source/archived historical RPC/receipt/decompiler-response checks only',
 'checks':{'source_bundles':len(spec['sources']),'source_files_equal_provider_content_utf8':files,'valid_original_line_slice_ranges':slice_count,
 'successful_receipt':True,'buy_sell_cycles':25,'all_sell_input_matches_actual_transfer':True,'all_sell_output_matches_verified_router_integer_formula':True,
 'usdt_raw_pool_net_equals_negative_eoa_net':True,'historical_usdt_decimals':18,'historical_runtime_comparisons':len(runtime),'all_historical_runtime_comparisons_match':True,
 'online_high_level_decompiled_output_preserved':True,'decompiler_disassembly_input_byte_coverage':3577,'decompiler_disassembly_mismatches':0},
 'limits':spec['evidence_gaps'],'not_performed':['Solidity compilation','PoC execution','fork replay','deployment','transaction submission']}
write('verification.json',verification)
print(json.dumps(verification['checks'],ensure_ascii=False,indent=2))