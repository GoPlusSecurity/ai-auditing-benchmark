"""Build Term case artifacts from archived source/data, without network or EVM execution."""
from pathlib import Path
from decimal import Decimal,getcontext
import json,hashlib,datetime
BASE=Path(__file__).resolve().parent
REPO=BASE.parents[3]
PREFIX='dataset_artifacts/batches/20261026_x96_y5/term/'
CASE='20260823_TermLabs'
getcontext().prec=70

def read(n):return json.loads((BASE/n).read_text('utf-8-sig'))
def write(n,d):(BASE/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def word(b,p):return int.from_bytes(b[p:p+32],'big')
def adr(b,p):return '0x'+b[p+12:p+32].hex()
def dec(n):return str(Decimal(n)/Decimal(10**18))
def actions_at(b,offset):
 ap=word(b,offset);out=[]
 for k in range(word(b,ap)):
  p=ap+32+word(b,ap+32+32*k);dp=p+word(b,p+64)
  out.append([adr(b,p),str(word(b,p+32)),'0x'+b[dp+32:dp+32+word(b,dp)].hex()])
 return out

A={
'vault':'0x26fCb50eEC367ddAB060ccf5E7394Cecd95F7Db2','wrapper':'0x5b96c5bBdcB361E1E9944bAa071b237E27829Be0',
'voting':'0x213771693A4411446b4ECce5bce4a405778b2171','dao':'0x0ae12AF3878a2d896f5C4DCE3Be7250FB187c0a6',
'roles':'0xD9DdE54D99a27F0f0E2b282369BFaa95528e9B75','delay':'0x35C99CF4a5DF2D9bCd822BeE32676D9590229e33',
'safe':'0x46DA347d1Db6EdCA62BF6Cd5892Dc284fC938613','weth':'0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
'helper':'0x64E477800051EFb06Ae4086f4b258b270668b4dF','attacker':'0xa908b3472d76e7744baB0A5911768a4a6300612B',
'strategy':'0x184f2E57b4cE135181FA2A2166AC394339016338'}
TX={
'deposit':'0x724e377f0523898061b9e2f504ab7792e06846c3cb728a6d5b19a2fa58d2ca0e',
'wrap':'0x7876693645d08038b7072bfd206f8c1aeb7d0a445b87a8b27b78786ed2ae8cc2',
'proposal':'0x284fc544f39c21388e17ca9669970dda9fe0f31921c38676f56073573f73a8b8',
'vote':'0x6e73533304c28686928bf274ec89e8baedbccaed6e8b9211ef54ca90a54e2a8d',
'execution':'0xd354a15b15cb73d30908f411aee3f795ec86737a4d080e9a818ac4d6d3014129'}
SELECT=[
 ('term-voting','voting','voting','vulnerable_governance_composition_snapshot_and_action_executor'),
 ('term-voting-token','voting-token-implementation','wrapper','vulnerable_governance_composition_opt_in_wrapped_electorate'),
 ('term-dao','dao','dao','normal_permissioned_arbitrary_action_executor_in_vulnerable_composition'),
 ('term-roles','delay-owner','roles','normal_roles_owner_route_with_overbroad_deployment_permissions'),
 ('term-permissions','owner-dependency',None,'normal_linked_role_permission_library'),
 ('term-delay','delay-implementation','delay','normal_owner_controlled_delay_in_vulnerable_composition'),
 ('term-safe','safe','safe','normal_enabled_module_execution_dependency'),
 ('term-vault','vault-implementation','vault','victim_vault_authorized_strategy_and_debt_allocation'),
 ('term-weth','weth','weth','normal_payout_asset')]
TRACES={k:read('blockscout-'+k+'-trace.json') for k in ['wrap','proposal','vote','execution']}
LOGS={k:read('blockscout-'+k+'-logs.json')['items'] for k in ['deposit','wrap','proposal','vote','execution']}
LOGS['execution']+=read('blockscout-execution-logs2.json')['items']
assert read('blockscout-execution-logs2.json')['next_page_params'] is None
assert len(LOGS['execution'])==78
assert sorted(e['index']for e in LOGS['execution'])==list(range(1133,1211))
assert len(TRACES['execution'])==395 and not any('error'in f for f in TRACES['execution'])
assert read('blockscout-execution-transaction.json')['status']=='ok'

retrievals=read('retrievals.json');bundles=[];sources=[];bindings=[];source_count=0
for bid,stem,proxyrole,role in SELECT:
 n='sources/'+stem+'-source.json';p=BASE/n;d=read(n);root=BASE/'extracted'/stem
 assert d.get('runtimeMatch')in['match','exact_match']
 files=[]
 for name,value in d['sources'].items():
  content=value['content'].encode('utf-8');ep=root/name
  assert ep.read_bytes()==content,(bid,name,'extraction mismatch')
  files.append({'original_file':name,'sha256':hashlib.sha256(content).hexdigest(),'bytes':len(content),'lines':len(content.splitlines())})
 source_count+=len(files)
 records=[r for r in retrievals if r['path']=='term/'+n];assert records,n
 rec=records[-1]
 bundles.append({'id':bid,'provider':'Sourcify','address':d['address'],'download_url':rec['url'],'response_path':PREFIX+n,'response_sha256':sha(p),'retrieved_at':rec.get('retrieved_at'),'retrieved_at_basis':rec.get('retrieved_at_basis'),'runtime_match':d['runtimeMatch'],'creation_match':d.get('creationMatch'),'compilation':d.get('compilation'),'deployment':d.get('deployment'),'files':files})
 sources.append({'id':bid,'response_path':PREFIX+n,'provider':'Sourcify','address':d['address'],'role':role})
 if proxyrole and proxyrole!='weth':
  hits=[]
  for stage,frames in TRACES.items():
   for i,f in enumerate(frames):
    ac=f.get('action',{})
    if ac.get('callType')=='delegatecall'and ac.get('from','').lower()==A[proxyrole].lower() and ac.get('to','').lower()==d['address'].lower():
     hits.append({'stage':stage,'transaction':TX[stage],'trace_file':PREFIX+'blockscout-'+stage+'-trace.json','array_index':i,'trace_address':f['traceAddress'],'input_selector':ac.get('input','')[:10]})
  assert hits,(proxyrole,'no historical binding')
  bindings.append({'role':proxyrole,'proxy':A[proxyrole],'implementation':d['address'],'source_bundle':bid,'status':'historical_delegatecall_observed','observations':hits})
 elif proxyrole is None:
  hits=[]
  for i,f in enumerate(TRACES['execution']):
   ac=f.get('action',{})
   if ac.get('to','').lower()==d['address'].lower():hits.append({'array_index':i,'trace_address':f['traceAddress'],'call_type':ac['callType'],'caller':ac['from']})
  assert hits
  bindings.append({'role':'permission_library','implementation':d['address'],'source_bundle':bid,'status':'historical_library_delegatecall_observed','trace_file':PREFIX+'blockscout-execution-trace.json','observations':hits})
write('historical_bindings.json',{'binding_method':'Historical parity rawtrace call frames, independent of present-day explorer proxy labels. Source verification is the provider assertion; no local recompilation.','bindings':bindings,'weth_status':'Historical direct WETH calls/transfers at the verified non-proxy address observed; independent historical eth_getCode unavailable.','not_reconstructed':'All historical storage/configuration and upgrades outside these calls.'})

proposal=read('decoded-proposal.json')
proposal_actions=[[a['to'],a['value'],a['data']]for a in proposal['actions']]
executed=next(e for e in LOGS['execution']if (e.get('decoded')or{}).get('method_call','').startswith('Executed('))
b=bytes.fromhex(executed['data'][2:]);executed_actions=actions_at(b,32)
assert proposal_actions==executed_actions
assert word(b,0)==5 and word(b,64)==0 and word(b,96)==0
assert '0x'+executed['topics'][1][-40:]==A['voting'].lower()
# Decode transfer events from raw topics/data, then compare explorer decoding independently.
TRANSFER='0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'
def transfers(stage,token):
 out=[]
 for e in LOGS[stage]:
  if e['address']['hash'].lower()!=token.lower()or e['topics'][0]!=TRANSFER:continue
  x={'log_index':e['index'],'from':'0x'+e['topics'][1][-40:],'to':'0x'+e['topics'][2][-40:],'amount_raw':str(int(e['data'],16))}
  values=[p['value']for p in e['decoded']['parameters']]
  assert[x['from'],x['to'],x['amount_raw']]==[values[0].lower(),values[1].lower(),values[2]]
  x['amount_18_decimals']=dec(int(x['amount_raw']));out.append(x)
 return out
weth=transfers('execution',A['weth'])
payout=next(x for x in weth if x['from']==A['vault'].lower()and x['to']==A['strategy'].lower())
forward=next(x for x in weth if x['from']==A['strategy'].lower()and x['to']==A['attacker'].lower())
assert payout['amount_raw']==forward['amount_raw']=='2841743535791961701401'
withdrawals=[x for x in weth if x['to']==A['vault'].lower()]
assert len(withdrawals)==4 and sum(int(x['amount_raw'])for x in withdrawals)==int(payout['amount_raw'])
debts=[]
for e in LOGS['execution']:
 if (e.get('decoded')or{}).get('method_call','').startswith('DebtUpdated('):
  raw=bytes.fromhex(e['data'][2:]);debts.append({'log_index':e['index'],'strategy':'0x'+e['topics'][1][-40:],'old_debt_raw':str(word(raw,0)),'new_debt_raw':str(word(raw,32))})
assert debts[-1]['new_debt_raw']==payout['amount_raw']
pt=TRACES['proposal']
total=next(f for f in pt if f['action'].get('to','').lower()==A['wrapper'].lower()and f['action'].get('input','').startswith('0x8e539e8c'))
power=next(f for f in pt if f['action'].get('to','').lower()==A['wrapper'].lower()and f['action'].get('input','').startswith('0x3a46b1a8'))
total_raw=int(total['result']['output'],16);power_raw=int(power['result']['output'],16)
snapshot=int(total['action']['input'][10:],16)
assert snapshot==25772693 and total_raw==535216182805348480 and power_raw==485216182805348480
assert int(power['action']['input'][-64:],16)==snapshot
vote=LOGS['vote'][0];vbytes=bytes.fromhex(vote['data'][2:]);assert word(vbytes,0)==2 and word(vbytes,32)==power_raw
mint=next(x for x in transfers('wrap',A['wrapper'])if int(x['from'],16)==0);assert int(mint['amount_raw'])==power_raw
entry=next(e for e in LOGS['deposit']if e['address']['hash'].lower()==A['vault'].lower()and(e.get('decoded')or{}).get('method_call','').startswith('Deposit('))
dep=bytes.fromhex(entry['data'][2:]);assert word(dep,0)==500000000000000000 and word(dep,32)==power_raw
assert transfers('deposit',A['vault'])[-1]['to']==A['attacker'].lower()
end=datetime.datetime.fromisoformat(proposal['end_utc'])
executed_at=datetime.datetime.fromisoformat(read('blockscout-execution-transaction.json')['timestamp'].replace('Z','+00:00'))
assert int((executed_at-end).total_seconds())==12
# Historical execution frames of the three owner controls and WETH payment, with raw arguments kept.
selectors={'0xebb2b4a2':'setTxCooldown(0)','0x9b56d5be':'setTxExpiration(0)','0x610b5925':'enableModule(DAO)','0x23b872dd':'transferFrom','0xa9059cbb':'transfer'}
keyframes=[]
for i,f in enumerate(TRACES['execution']):
 ac=f.get('action',{});sel=ac.get('input','')[:10]
 if sel in selectors and ac.get('callType')=='call'and ac.get('to','').lower()in[A['delay'].lower(),A['weth'].lower()]:
  keyframes.append({'array_index':i,'trace_address':f['traceAddress'],'method':selectors[sel],'action':ac,'result':f.get('result')})
write('decoded_evidence.json',{
 'decoding_method':'Offline ABI word decoding of raw topics/data/call frames; compared against explorer decoded fields. No PoC, EVM, compilation or replay.',
 'transactions':TX,'proposal':proposal,'executed_event':{'log_index':executed['index'],'call_id':5,'action_count':17,'raw_actions_identical_to_proposal':True,'allow_failure_map':'0','failure_map':'0'},
 'snapshot':{'block':snapshot,'wrapper':A['wrapper'],'helper':A['helper'],'total_wrapped_power_raw':str(total_raw),'attacker_wrapped_power_raw':str(power_raw),'prior_wrapped_supply_raw':str(total_raw-power_raw),'attacker_percent':str(Decimal(power_raw)*100/Decimal(total_raw)),'raw_total_call':total,'raw_power_call':power},
 'purchase':{'transaction':TX['deposit'],'assets_raw':str(word(dep,0)),'lp_shares_raw':str(word(dep,32)),'deposit_log_index':entry['index'],'lp_transfers':transfers('deposit',A['vault'])},
 'wrap':{'transaction':TX['wrap'],'mint':mint,'lp_transfers':transfers('wrap',A['vault'])},
 'vote':{'transaction':TX['vote'],'proposal':int(vote['topics'][1],16),'voter':'0x'+vote['topics'][2][-40:],'vote_option':word(vbytes,0),'power_raw':str(word(vbytes,32)),'log_index':vote['index']},
 'execution':{'transaction':TX['execution'],'block':25816049,'timestamp_utc':executed_at.isoformat(),'after_proposal_end_seconds':12,'trace_frames':395,'trace_has_error':False,'log_count':78,'log_pages_complete':True,'key_frames':keyframes},
 'funds':{'asset':A['weth'],'decimals':18,'decimals_evidence':'Sourcify verified WETH9.sol line21; no independent historical eth_call','normal_strategy_withdrawals':withdrawals,'withdrawal_sum_raw':str(sum(int(x['amount_raw'])for x in withdrawals)),'vault_to_malicious_strategy':payout,'malicious_strategy_to_attacker':forward,'debt_events':debts,'scope':'ETH Meta Vault execution transaction gross outflow and recipient inflow, not attacker net profit, not all event vaults, no USD conversion'},
 'limitations':['Two normal strategies retain positive debt after the requested zero-debt update because source caps withdrawals to withdrawable assets. Do not describe all four debts as fully zeroed.','No complete historical configuration dump; successful runtime checks prove the exercised calls, not all possible role targets/selectors.']})

SLICES={
 'term-voting':{'src/plugins/governance/majority-voting/token/TokenVoting.sol':'all','src/plugins/governance/majority-voting/MajorityVotingBase.sol':'all','src/core/plugin/proposal/ProposalUpgradeable.sol':'all','src/plugins/governance/majority-voting/IMajorityVoting.sol':'all','src/core/plugin/dao-authorizable/DaoAuthorizableUpgradeable.sol':'all','src/plugins/utils/Ratio.sol':'all'},
 'term-voting-token':{'src/token/ERC20/governance/GovernanceWrappedERC20.sol':'all','@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20WrapperUpgradeable.sol':'all','@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol':'all','@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol':[[1,75],[275,320],[380,410]],'@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol':'all'},
 'term-dao':{'src/core/dao/DAO.sol':[[1,299]],'src/core/permission/PermissionManager.sol':'all','src/core/dao/IDAO.sol':'all'},
 'term-roles':{'contracts/Roles.sol':'all','@gnosis.pm/zodiac/contracts/core/Modifier.sol':'all'},
 'term-permissions':{'contracts/Permissions.sol':[[1,290]]},
 'term-delay':{'contracts/Delay.sol':'all','@gnosis.pm/zodiac/contracts/core/Module.sol':'all','@gnosis.pm/zodiac/contracts/core/Modifier.sol':'all','@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol':'all'},
 'term-safe':{'contracts/base/ModuleManager.sol':'all','contracts/base/Executor.sol':'all','contracts/common/Enum.sol':'all'},
 'term-vault':{'YearnV3Vault.vy':[[1,327],[486,510],[667,712],[911,930],[965,1112],[1521,1526],[1698,1707],[1731,1762]]},
 'term-weth':{'WETH9.sol':[[1,77]]}}
# Avoid split ERC20 callables: use the original file instead of guessing function boundaries.
SLICES['term-voting-token']['@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol']='all'
linecounts={x['id']:{f['original_file']:f['lines']for f in x['files']}for x in bundles}
for bid,files in SLICES.items():
 for name,ranges in files.items():
  count=linecounts[bid][name]
  if ranges=='all':continue
  last=0
  for a,z in ranges:assert 1<=a<=z<=count and a>last,(bid,name,a,z,count);last=z

GAPS=[
 '完整 JSON-RPC receipt 查询未得到可用结果；使用 Blockscout 原始 topics/data 日志、交易成功状态和完整 rawtrace 交叉核对，不把 null 或错误响应称为成功回执。',
 '未取得全部历史 Roles 存储与投票参数。历史调用和正常检查源码证明 DAO 的 role 1 实际获准执行三个 Delay 管理动作；不推断该角色是否使用通配目标、具体 selector 白名单或某种参数规则，也不声称完整支持率/参与率配置。',
 '历史 rawtrace 绑定了本案受害治理代理的实际实现地址；源码匹配等级由 Sourcify 提供，未本地编译或重新做完整部署字节码验证。部分 creationMatch 为 null，不能写成所有合约都是完整创建匹配。',
 '官方治理文档描述正常七日延时和 LP 否决流程，但该现行页面本身不是攻击前状态快照；此前 cooldown 精确值没有重读。实际三项管理调用、设置为零和同交易执行由历史 trace 证明。',
 '四个普通子策略及其 Aave/Morpho 深层依赖未形成完整原始源码包；本案不把它们列为漏洞点。原始 trace、WETH 日志和 DebtUpdated 证明这次提款确实发生。获取初始 LP 的路由器源码也未完整归档。',
 '恶意策略原始源码不可得；高层反编译仅作辅助，原始创建 runtime 与当前 explorer runtime 一致且返回反汇编完整对上输入。未获得攻击区块独立 eth_getCode，不能声称完整证明期间从无变更。',
 '攻击 helper 实现无已验证原始源码；ethervm 提交 runtime 和按地址查询均超时，无高层输出。保留实际失败页，不用手写伪代码或反汇编冒充高层反编译。历史 wrap/proposal/vote/execute rawtrace 仍展示其实际调用边界。',
 '本案独立核验 ETH Meta Vault 资金流；未逐笔核验其他 USDC vault 的全部损失、追回与净额，未核定事发时美元价格。loss_usd 留空。',
 '展示的调用链不需要管理员私钥泄露即可完成；这不是对所有链外事件或密钥安全的全面取证结论。']
metadata={
 'project_cn':'Term Labs（ETH Meta Vault 治理）','project_en':'Term Labs (ETH Meta Vault governance)',
 'vulnerability_cn':'少量封装 LP 取得多数票权，过宽治理权限允许关闭延时并把金库资金配置给恶意策略',
 'vulnerability_en':'Thin wrapped-LP electorate and overbroad governance authority allow delay removal and allocation to a malicious strategy',
 'detail_cn':'TokenVoting 以主动封装 LP 的历史供给计算总票权，攻击者用 0.5 ETH 取得并封装 0.485216182805348480 LP，在快照总量 0.535216182805348480 中占约 90.65798%。提案 5 的 17 个动作通过 DAO 已有 Roles 权限将 Delay 冷却期和有效期设为零，并启用 DAO 为模块；随后同笔交易排队并执行四笔普通策略减债及恶意策略注册、放宽债务上限和注资。历史 trace 与日志确认 2841.743535791961701401 WETH 经恶意策略进入攻击钱包。正常 onlyOwner、角色和 Safe 模块检查未被绕过；缺陷是部署中的治理权限和票权范围组合。核心原始源码来自 Sourcify，辅助反编译不替代源码；未重放。美元及全事件 USDC 损失未独立核定，留空。',
 'detail_en':'TokenVoting uses the historical supply of voluntarily wrapped LP shares as total voting power. With 0.5 ETH the attacker acquired and wrapped 0.485216182805348480 LP against 0.535216182805348480 total wrapped supply, about 90.65798%. Proposal 5 used 17 DAO actions and existing Roles authority to set Delay cooldown and expiration to zero and enable the DAO as a module, then queued and executed four normal-strategy debt reductions, malicious-strategy registration, a maximum-debt increase and allocation in the same transaction. Historical trace and raw logs confirm 2841.743535791961701401 WETH passed through the malicious strategy to the attacker. Standard onlyOwner, role and Safe-module checks were satisfied; the vulnerability is the deployed composition of voting scope and governance authority. Core original sources come from Sourcify; supplementary decompilation does not replace them. No replay. USD valuation and event-wide USDC loss were not independently established.',
 'loss_usd':None,'loss_scope':'本笔 ETH Meta Vault 毛流出和攻击钱包毛入账均为 2841.743535791961701401 WETH，未扣初始 0.5 ETH、gas 或计追回。源表约 850 万美元覆盖更广事件；官方 USDC 赔付、追回与 RepoToken 口径不同，不能直接相加或替代本笔美元损失。',
 'event_date':'2026-08-23','onchain_timestamp_utc':'2026-08-23T06:25:47Z','chain_id':1,'tx_urls':['https://etherscan.io/tx/'+TX[k]for k in ['deposit','wrap','proposal','vote','execution']],
 'vulnerable_contract_urls':['https://etherscan.io/address/'+A[k]+'#code'for k in ['vault','wrapper','voting','dao','roles','delay']],
 'verification_status':'authoritative_original_source_archived;historical_proxy_delegatecalls_bound;raw_snapshot_votes_and_17_actions_and_WETH_payment_confirmed;strategy_online_decompilation_archived;helper_decompilation_timeout;normal_deep_dependencies_incomplete;no_replay',
 'sheet_row':91,'source_disclosure':'https://x.com/certikalert/status/2091433962795106499?s=46'}
roles=[{'address':A[k],'role':v}for k,v in[
 ('vault','受害 ETH Meta Vault，持有 WETH 并向策略分配债务；Vyper Yearn V3 实现'),('wrapper','LP 封装投票代币，只统计已经主动封装的 LP'),('voting','TokenVoting 提案/快照投票插件'),('dao','执行通过提案的任意动作，具有 Roles 模块身份与 role 1'),('roles','Delay owner；通过成员/目标权限检查后直接调用 Delay'),('delay','模块队列与冷却时间；本次先被 owner 调整，再允许 DAO 排队'),('safe','金库管理 Safe，已启用 Delay 模块；无需另外提供 owner 签名即可走模块入口'),('weth','普通结算资产，已验证原始源码'),('helper','攻击者代理辅助合约，包装/提案/投票/执行；实现未开源且反编译超时'),('strategy','恶意策略，接收金库授权后拉走并转发 WETH；仅补充反编译'),('attacker','攻击交易发起人和最终 WETH 收款 EOA')]]
meta=read('decompilation-provenance.json')[0]
decomp={
 'id':'term-attacker-strategy-ethervm','kind':'public_online_high_level_decompiler_output','role':'attacker_strategy_supplementary_context','address':A['strategy'],'chain_id':1,
 'source_path':PREFIX+'attacker-strategy.ethervm.decompiled.sol','original_file_path':PREFIX+'attacker-strategy.ethervm.decompiled.sol','target_path':'decompiled/attacker-strategy.ethervm.decompiled.sol',
 'raw_response_path':PREFIX+'attacker-strategy-ethervm-response.html','request_path':PREFIX+'attacker-strategy-ethervm-request.txt','runtime_path':PREFIX+'blockscout-attacker-strategy-creation-trace.json','runtime_hex_path':PREFIX+'attacker-strategy-creation-runtime.hex',
 'historical_block':25772662,'creation_transaction':meta['creation_transaction'],'tool':meta['service'],'tool_url':meta['service_url'],'tool_version':None,'tool_version_status':meta['engine_version_status'],
 'sha256':sha(BASE/'attacker-strategy.ethervm.decompiled.sol'),'runtime_sha256':meta['runtime_sha256'],'raw_response_sha256':sha(BASE/'attacker-strategy-ethervm-response.html'),'runtime_bytes':2497,'decompiled_error_comment_count':0,
 'retrieved_at_utc':next(r['retrieved_at']for r in retrievals if r['path']=='term/attacker-strategy-ethervm-response.html'),'retrieved_at_basis':'local downloaded response file last-write time',
 'bytecode_binding':'Submitted original creation runtime matches current explorer runtime; all 2497 returned disassembly bytes match submitted runtime. Archive eth_getCode at attack block unavailable; this is not an independent attack-block code dump.',
 'not_original_source':True,'not_used_to_replace_core_original_source':True,'provenance_path':PREFIX+'decompilation-provenance.json'}
spec={'case_id':CASE,'sheet_row':91,'qualified':True,'sources':sources,'slices':SLICES,'metadata':metadata,'draft_path':PREFIX+'draft.md','provenance_path':PREFIX+'provenance.json','decoded_evidence_path':PREFIX+'decoded_evidence.json','historical_bindings_path':PREFIX+'historical_bindings.json','roles':roles,'evidence_gaps':GAPS,'decompilations':[decomp],'not_performed':['execution of upstream scripts or PoC','Solidity/Vyper compilation','deployment','fork replay','transactions']}
write('case_spec.json',spec)
write('qualification.json',{'case_id':CASE,'sheet_row':91,'qualified':True,'decision':'qualifies_as_deployed_governance_composition_vulnerability_with_public_original_core_source','reason_cn':'普通参与者取得多数封装票权后，经已有合约权限成功关闭延时并分配金库资产。核心合约原始源码与历史实际调用可以独立证明该路径，不依赖假设管理员凭据被盗，不把正常 onlyOwner 函数单独定性为漏洞。','source_policy':'All 9 selected original bundles are unmodified source content from saved Sourcify verified responses. Official project documents describe intended operations. Articles/PoCs are locators only. Attacker decompilation is separate supplementary reconstructed code.','selected_original_bundles':len(bundles),'selected_original_source_files':source_count,'historical_scope':'ETH Meta Vault proposal 5, voting snapshot 25772693, execution block 25816049','root_cause_status':'original_source_plus_historical_trace_and_events','funds_status':'raw WETH transfer topics/data independently decoded and matched; 2841.743535791961701401 WETH two-hop gross flow','loss_usd':None,'evidence_gaps':GAPS,'decompilation_status':{'attacker_strategy':'successful public high-level output, complete input/disassembly binding, engine version unknown','helper_implementation':'two public service attempts timed out; failure archived'},'artifacts':{'case_spec':PREFIX+'case_spec.json','draft':PREFIX+'draft.md','provenance':PREFIX+'provenance.json','decoded':PREFIX+'decoded_evidence.json','bindings':PREFIX+'historical_bindings.json'}})
write('provenance.json',{'case_id':CASE,'created_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_policy':'Official project documentation and authoritative verified-source platform. Raw provider response and exact source text hashes preserved. Research article and proposed PoC were not treated as original source or executed.','original_bundles':bundles,'acquisitions':PREFIX+'retrievals.json','historical_bindings':PREFIX+'historical_bindings.json','independent_raw_decode':PREFIX+'decoded_evidence.json','decompilations':PREFIX+'decompilation-provenance.json','evidence_gaps':GAPS,'filename_caveat':'proposal-tx.json is the initially supplied 0x724e... purchase transaction, not ProposalCreated. The actual proposal is tx-284fc5.json / blockscout-proposal-logs.json.','provider_status_caveat':'Saved JSON RPC responses with error/null, HTTP failure pages and empty source responses remain failed evidence even when shell exit code is zero. HTTP headers were not archived for every download; retrieval timestamps sometimes use file last-write time and are labelled.','not_performed':spec['not_performed']})
write('validation.json',{'passed':True,'checks':['9 original source responses have provider runtime match or exact_match','158 extracted source files byte-identical to response content','all requested slice paths and inclusive ranges valid','8 historical proxy/library bindings observed in actual rawtrace','proposal and executed raw action arrays identical (17)','execution rawtrace 395 frames without error; log pages complete with 78 sequential indexes','snapshot total/votes decoded from actual historical calls','raw VoteCast Yes option and power match','deposit amount and LP shares match raw logs and final EOA transfer','4 normal strategy WETH withdrawals sum exactly to payout','vault->strategy and strategy->EOA exact equal raw WETH amount','proposal end to execution interval 12 seconds'],'selected_bundles':len(bundles),'source_files':source_count,'originals_changed':False,'validation_scope':'Static extraction, source range and archived data consistency only. Does not claim local build, replay, complete historical storage or all-event loss verification.'})
print(json.dumps({'case_id':CASE,'qualified':True,'bundles':len(bundles),'source_files':source_count,'historical_bindings':len(bindings),'vote_percent':str(Decimal(power_raw)*100/Decimal(total_raw)),'weth':payout['amount_18_decimals'],'normal_debt_residuals':[d for d in debts[:-1]if int(d['new_debt_raw'])]},ensure_ascii=False))
