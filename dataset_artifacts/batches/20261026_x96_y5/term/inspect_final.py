import json
from pathlib import Path
b=Path('dataset_artifacts/batches/20261026_x96_y5/term')
for name in ['blockscout-execution-trace.json','blockscout-execution-logs.json','blockscout-proposal-logs.json','blockscout-wrap-logs.json','blockscout-execution-transaction.json','decoded-proposal.json']:
 d=json.loads((b/name).read_text());print(name,type(d).__name__,len(d), list(d)[:15] if isinstance(d,dict) else '')
 if 'trace' in name: print(str(d[:1])[:1200])
 if 'logs' in name:
  for x in d['items'][:2]: print({k:x.get(k) for k in ['index','block_number','transaction_hash','address','topics','decoded']})
for s in ['weth','voting','voting-token-implementation','dao','delay-owner','owner-dependency','delay-implementation','safe','vault-implementation']:
 d=json.loads((b/'sources'/f'{s}-source.json').read_text());print(s,d['address'],d['runtimeMatch'],d['creationMatch'],len(d['sources']))
for rel,a,z in [('weth/WETH9.sol',1,85),('vault-implementation/YearnV3Vault.vy',965,1115),('delay-implementation/contracts/Delay.sol',90,207),('voting/src/plugins/governance/majority-voting/token/TokenVoting.sol',60,240)]:
 p=b/'extracted'/rel;print('\nFILE',rel)
 for n,l in enumerate(p.read_text().splitlines(),1):
  if a<=n<=z:print(f'{n}: {l}')
