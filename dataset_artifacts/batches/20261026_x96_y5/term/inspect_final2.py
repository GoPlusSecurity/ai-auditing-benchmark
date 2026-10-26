import json
from pathlib import Path
b=Path('dataset_artifacts/batches/20261026_x96_y5/term')
t=json.loads((b/'blockscout-execution-transaction.json').read_text()); print({k:t.get(k) for k in ['hash','status','result','timestamp','block_number']})
logs=sum([json.loads((b/n).read_text())['items'] for n in ['blockscout-execution-logs.json','blockscout-execution-logs2.json']],[])
for e in logs:
 d=e.get('decoded') or {};m=d.get('method_call','')
 if m.startswith(('Executed','DebtUpdated','Transfer','ProposalExecuted')):
  ps={p['name']:p['value'] for p in d['parameters']}
  if 'actions'in ps:ps['actions']=f'{len(ps["actions"])} actions'
  if 'execResults'in ps:ps['execResults']=f'{len(ps["execResults"])} results'
  print(e['index'],e['address']['hash'],m,ps)
for n in ['blockscout-proposal-trace.json','blockscout-vote-trace.json']:
 print(n)
 for f in json.loads((b/n).read_text()):
  a=f.get('action',{});i=a.get('input','')
  if i[:10]in['0x8e539e8c','0x3a46b1a8']:print(a.get('from'),a.get('to'),i,f.get('result'))
for n in ['weth/WETH9.sol','voting-token-implementation/src/token/ERC20/governance/GovernanceWrappedERC20.sol','safe/contracts/base/ModuleManager.sol']:
 p=b/'extracted'/n; print(n,len(p.read_text().splitlines()))
 for x,l in enumerate(p.read_text().splitlines(),1):
  if (n.startswith('weth') and x<85) or ('GovernanceWrapped' in n and 75<=x<=118) or('ModuleManager' in n and 55<=x<=85):print(f'{x}: {l}')
