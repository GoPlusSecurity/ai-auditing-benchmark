from pathlib import Path
import json, hashlib, datetime as dt
ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[3]
BATCH=ROOT.parent
CASE='20260826_FH'
TX='https://bscscan.com/tx/0x7a3cadc2f33e000b0091307df62db2f5cc79ab8e0b022fd84de9e1c2c0745bd2'
TOKEN='0xdCf0DFe0053677A67610c6d08EA1f5c78DF8cA37'
PAIR='0x8f2d1A3992856a860304f1B86534B6B129Cc4df7'
PREFIX='dataset_artifacts/batches/20261026_x96_y5/fh/'
SOURCES=[
 {'id':'fh-token','response_path':PREFIX+'token-source.json','role':'vulnerable_contract','provider':'Sourcify','address':TOKEN},
 {'id':'pancake-v2-router','response_path':PREFIX+'v2-router-source.json','role':'normal_dependency_fee_on_transfer_swap','provider':'Sourcify','address':'0x10ED43C718714eb63d5aA57B78B54704E256024E'},
 {'id':'pancake-v3-router','response_path':PREFIX+'v3-router-source.json','role':'normal_dependency_whitelisted_recipient_and_sweep','provider':'Sourcify','address':'0x1b81D678ffb9C0263b24A97847620C99d213eB14'},
 {'id':'pancake-pair-reference','response_path':PREFIX+'pair-reference-source.json','role':'normal_protocol_reference_context_pending_target_runtime_binding','provider':'Sourcify','address':'0x63844BD4BFad910B1643713302a1cC1ed20d50c3','target_pool':PAIR}
]
SLICES={
 'fh-token':{'contracts/FHToken.sol':[[1,127],[139,175],[186,233],[241,418],[420,461],[522,537]]},
 'pancake-v2-router':{'PancakeRouter.sol':[[1,29],[279,321],[704,738]]},
 'pancake-v3-router':{'contracts/SwapRouter.sol':[[1,40]],'contracts/base/PeripheryPaymentsWithFee.sol':[[1,13]],'contracts/base/PeripheryPayments.sol':[[1,13],[29,41]],'contracts/libraries/TransferHelper.sol':[[24,36]]},
 'pancake-pair-reference':{'PancakePair.sol':[[260,335],[408,436],[446,449]]}
}
metadata={
 'project_cn':'Falcon Heavy（FH）','project_en':'Falcon Heavy (FH)',
 'vulnerability_cn':'卖出时扣除资金池自己的代币并提前同步储备，导致 USDT 被超额换出',
 'vulnerability_en':'Sell-side removal of pair-owned tokens and premature reserve sync cause excessive USDT output',
 'detail_cn':'FHToken._transfer 的卖出分支先从资金池余额销毁净卖出额的80%、向国库转走20%，调用 pair.sync() 后才把卖方净额转入池子。Pancake V2 的手续费代币路径随后按余额减已降低储备计算输入，并按降低后的FH储备报价。构造函数预设的V3 Router买入白名单与公开sweepToken使普通攻击者可以取得FH再卖出。原回执记录25轮买卖；逐轮卖出金额与公开Router算式吻合，池子USDT净流出与攻击者净流入均为19999018106552928530404原始单位（18位口径为19,999.018106552928530404 USDT）。保留源表约2万美元估计与8月26日日期，实际交易为8月25日UTC。核心原始源码来自Sourcify；未取得完整内部调用跟踪，未重放。',
 'detail_en':'FHToken._transfer burns 80% of the net sell amount from the pair balance, sends the remaining 20% from the pair to treasury, calls pair.sync(), and only then credits the seller net amount. The Pancake V2 fee-on-transfer route measures input as balance minus the reduced reserve and quotes against the depleted FH reserve. A constructor-whitelisted V3 router and its public sweepToken allow an ordinary attacker to acquire FH for the sell path. The receipt records 25 buy/sell cycles; each sell output exactly matches the public router formula. Pool USDT net outflow and attacker net inflow both equal 19999018106552928530404 raw units (19,999.018106552928530404 USDT at 18 decimals). The sheet estimate of about USD 20000 and August 26 date are retained; the transaction occurred on August 25 UTC. Core original source is from Sourcify. Full internal tracing and replay were not performed.',
 'loss_usd':'20000','loss_scope':'源表和TenArmor警报的约数；原回执单笔USDT池净流出等于攻击者EOA净收入，按18位为19,999.018106552928530404 USDT，未扣BNB交易成本，不另行给FH记美元价值。',
 'event_date':'2026-08-26','onchain_timestamp_utc':'2026-08-25T09:54:52Z','chain_id':56,
 'tx_urls':[TX], 'vulnerable_contract_urls':['https://bscscan.com/address/'+TOKEN+'#code'],
 'victim_pool_urls':['https://bscscan.com/address/'+PAIR+'#code'],
 'verification_status':'core_original_source_and_receipt_confirmed; target_pair_runtime_and_usdt_decimals_pending; full_trace_unavailable; no_replay',
 'sheet_row':89,'source_disclosure':'https://x.com/TenArmorAlert/status/2092427353456812207'
}
spec={'case_id':CASE,'qualified':True,'sources':SOURCES,'slices':SLICES,'metadata':metadata,
 'draft_path':PREFIX+'draft.md','provenance_path':PREFIX+'provenance.json','decoded_evidence_path':PREFIX+'decoded_evidence.json',
 'roles':[
  {'address':TOKEN,'role':'vulnerable FH token; owns balances and sell-time tokenomics'},
  {'address':PAIR,'role':'victim FH/USDT AMM pool; funds paid out here'},
  {'address':'0x727Fb666E3F2531e807E987532C6e2C22ADC45aD','role':'attacker execution contract; not the vulnerable source'},
  {'address':'0x7FA3bC0d5667fFd14d7ACD6Ce5f2432AC13a6FDA','role':'transaction sender and USDT profit recipient; sheet malicious_address'},
  {'address':'0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C','role':'temporary USDT funding source; equal returned amount in same receipt'}],
 'evidence_gaps':['Full internal call trace unavailable; particular intermediate entry-point calldata is inferred from source, event sender, and exact output arithmetic.',
 'Target pool Sourcify request returned 404. Reference PancakePair is original verified source for another address; target historical runtime comparison is pending.',
 'USDT decimals evidence requested; do not treat the normalization as independently confirmed until that response is archived.',
 'No complete historical whitelist, fee-setting, or totalSupply snapshot was reconstructed; successful receipt proves the exercised path conditions, not all other state.'],
 'not_performed':['execution of upstream code or PoC','local Solidity compilation','deployment','fork replay','transactions']}
(ROOT/'case_spec.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
old=json.loads((ROOT/'qualification.json').read_text())
old.update(qualification_status='qualified_core_original_source_and_receipt',eligible=True,
 reason='Sourcify精确匹配的FH原始源码直接包含漏洞；两Router原始源码与原回执支持白名单绕行、储备顺序、25轮报价和付款，已排除仅报告或PoC定性。',
 source_provider_requirement_met=True,core_source_response=PREFIX+'token-source.json',source_match='exact_match',
 victim_token=TOKEN,victim_pool=PAIR,evidence_gaps=spec['evidence_gaps'],
 collection_status='父agent成功取得FH和两Router原始Sourcify响应、交易与官方BSC RPC回执。完整trace不可用；目标pair源码请求404，正常Pair参考源码来自既有Sourcify原响应。',
 source_gate_complete=True,source_only_root_cause_confirmed=True)
(ROOT/'qualification.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
# Preserve actual download records; a local last-write timestamp is explicitly labelled, not presented as a request-start time.
records=json.loads((ROOT/'acquisition_merged.json').read_text())
for rec in records:
 path=BATCH/rec['path']
 if path.exists() and path.stat().st_size:
  rec['sha256']=hashlib.sha256(path.read_bytes()).hexdigest(); rec['bytes']=path.stat().st_size
  if not rec.get('retrieved_at'):
   rec['retrieved_at']=dt.datetime.fromtimestamp(path.stat().st_mtime,dt.timezone.utc).isoformat()
   rec['timestamp_kind']='filesystem_write_time_after_download'
  else: rec['timestamp_kind']='download_helper_recorded'
  rec['raw_response_preserved']=True
bundles=[]
for source in SOURCES:
 path=ROOT/Path(source['response_path']).name
 raw=path.read_bytes(); d=json.loads(raw)
 item={**source,'response_sha256':hashlib.sha256(raw).hexdigest(),'chain_id':d.get('chainId'),
       'verified_at':d.get('verifiedAt'),'runtime_match':d.get('runtimeMatch'),'creation_match':d.get('creationMatch'),
       'deployment':d.get('deployment'),'source_files':[]}
 if source['id']=='pancake-pair-reference':
  item.update(url='https://sourcify.dev/server/v2/contract/56/0x63844BD4BFad910B1643713302a1cC1ed20d50c3?fields=all',
              retrieved_at='2026-10-21T05:40:34.869871+08:00',timestamp_kind='original_archive_provenance',
              copied_from='dataset_artifacts/20260804_NEX_AIC/source-bundles/pro-pair/source-response.json')
 else:
  rec=next(r for r in records if r['path']=='fh/'+path.name)
  item.update(url=rec['url'],retrieved_at=rec['retrieved_at'],timestamp_kind=rec['timestamp_kind'])
 for name,v in d['sources'].items():
  b=v['content'].encode('utf-8'); item['source_files'].append({'original_filename':name,'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)})
 bundles.append(item)
provenance={'case_id':CASE,'kind':'public_original_source','original_code_policy':'Only Sourcify verified original source responses are included as source. Third-party articles and PoCs are not source substitutes.',
 'bundles':bundles,'acquisitions':records,'initial_sandbox_failures':'acquisition.jsonl','limitations':spec['evidence_gaps'],
 'extraction':'Each source content is decoded from the provider JSON and UTF-8 encoded without editing tokens or line endings.'}
(ROOT/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Wrote qualification.json, case_spec.json, provenance.json')