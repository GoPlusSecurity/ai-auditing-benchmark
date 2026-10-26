from pathlib import Path
import json
b=Path('dataset_artifacts/batches/20261026_x96_y5/term')
for n in ['blockscout-vote-logs.json','blockscout-deposit-logs.json']:
 d=json.loads((b/n).read_text());print(n,'total',len(d['items']),'next',d['next_page_params'])
 for x in d['items']:
  z=x.get('decoded') or {};m=z.get('method_call','')
  if 'vote-'in n or (x['address']['hash'].lower()=='0x26fcb50eec367ddab060ccf5e7394cecd95f7db2' and ('Deposit' in m or 'Transfer' in m)):
   print(x['index'],x['address']['hash'],x['topics'],x['data'],z)
print('Files:')
for n in ['voting','voting-token-implementation','dao','delay-owner','owner-dependency','delay-implementation','safe']:
 d=json.loads((b/'sources'/f'{n}-source.json').read_text());print(n, '\n'.join(d['sources']))
