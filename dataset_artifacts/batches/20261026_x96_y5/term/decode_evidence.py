"""Decode archived event bytes offline; no RPC or executable contract interaction."""
from pathlib import Path
import json,datetime
BASE=Path(__file__).resolve().parent

def word(b,p):return int.from_bytes(b[p:p+32],'big')
def addr(b,p):return '0x'+b[p+12:p+32].hex()
def dyn(b,p):return b[p+32:p+32+word(b,p)]
entry=json.loads((BASE/'blockscout-proposal-logs.json').read_text())['items'][0]
b=bytes.fromhex(entry['data'][2:]); ap=word(b,96); n=word(b,ap); actions=[]
for k in range(n):
 p=ap+32+word(b,ap+32+32*k)
 payload=dyn(b,p+word(b,p+64))
 a={'index':k,'to':addr(b,p),'value':str(word(b,p+32)),'data':'0x'+payload.hex(),'selector':'0x'+payload[:4].hex()}
 if k<3:
  a['inner_to']=addr(payload,4);a['role']=word(payload,68);inner=dyn(payload,4+word(payload,36));a['inner_data']='0x'+inner.hex();a['inner_selector']='0x'+inner[:4].hex();a['inner_argument_word']='0x'+inner[4:].hex()
 else:
  a['inner_to']=addr(payload,4);a['operation']=word(payload,100);inner=dyn(payload,4+word(payload,68));a['inner_data']='0x'+inner.hex();a['inner_selector']='0x'+inner[:4].hex();a['inner_argument_words']=['0x'+inner[j:j+32].hex() for j in range(4,len(inner),32)]
 actions.append(a)
explorer={i['name']:i['value'] for i in entry['decoded']['parameters']}
assert [[a['to'].lower(),a['value'],a['data'].lower()] for a in actions]==[[a.lower(),v,d.lower()] for a,v,d in explorer['actions']]
metadata=dyn(b,word(b,64)).decode()
out={'evidence':'blockscout-proposal-logs.json','transaction_hash':entry['transaction_hash'],'block':entry['block_number'],'proposal_id':int(entry['topics'][1],16),'creator':'0x'+entry['topics'][2][-40:],'start_utc':datetime.datetime.fromtimestamp(word(b,0),datetime.timezone.utc).isoformat(),'end_utc':datetime.datetime.fromtimestamp(word(b,32),datetime.timezone.utc).isoformat(),'seconds':word(b,32)-word(b,0),'allow_failure_map':str(word(b,128)),'metadata':json.loads(metadata),'actions':actions,'raw_decode_matches_explorer':True}
(BASE/'decoded-proposal.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in out.items() if k not in ['actions','metadata']},indent=2))
for a in actions: print(a['index'],a['to'],a['selector'],a['inner_to'],a['inner_selector'],a.get('inner_argument_word',a.get('inner_argument_words')))
