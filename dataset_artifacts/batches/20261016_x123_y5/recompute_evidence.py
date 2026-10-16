import collections
import datetime
import json
import pathlib
from decimal import Decimal, getcontext

getcontext().prec = 100

ROOT=pathlib.Path(__file__).resolve().parents[3]
CASE_IDS={'drips': '20260715_Drips', 'ostium': '20260715_Ostium', 'crc': '20260717_CrowdRingCircle', 'verus': '20260723_Verus', 'lien': '20260724_LienFinance'}
COMPUTED={}
TRANSFER='0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'

def read(name):
    key,tail=name.split('/',1)
    if name=='crc/token-lower.json': tail='source-bundles/token/source-response.json'
    else: tail='evidence/'+tail
    return json.loads((ROOT/'dataset_artifacts/benchmark_complete'/CASE_IDS[key]/tail).read_text('utf-8'))
def write(name,value):
    if value != read(name): raise ValueError('recomputation differs: '+name)
    COMPUTED[name]=value
def word(data,offset): return int.from_bytes(data[offset:offset+32],'big')
def dynamic(data,offset):
    length=word(data,offset)
    assert offset+32+length<=len(data)
    return data[offset+32:offset+32+length]
def units(n,decimals): return format(Decimal(n)/Decimal(10)**decimals,'f')
def receipt_transfers(receipt, token):
    return [{'from':'0x'+log['topics'][1][-40:],'to':'0x'+log['topics'][2][-40:],'raw':str(int(log['data'],16)),'log_index':int(log['logIndex'],16)}
            for log in receipt['logs'] if log['address'].lower()==token.lower() and log['topics'][0]==TRANSFER]
def net(transfers,address):
    return sum((int(t['raw']) if t['to'].lower()==address.lower() else 0)-(int(t['raw']) if t['from'].lower()==address.lower() else 0) for t in transfers)

# The signed uint128 conversion and the actual historical delegatecall are independently checked.
drips=read('drips/raw-trace.json')
give=next(t for t in drips if t['action'].get('callType')=='delegatecall')
data=bytes.fromhex(give['action']['input'][2:])
receiver='0x'+data[16:36].hex()
amount=word(data,36)
reserve_read=next(t for t in drips if t['action'].get('input')=='0xb69ef8a8')
balance=int(reserve_read['result']['output'],16)
assert amount==2**128-balance and 2**127<amount<2**128
signed=amount-2**128
assert -signed==balance
write('drips/recomputed.json',{'given_receiver':receiver,'unsigned_amount':str(amount),'reserve_balance_raw':str(balance),'signed_int128':str(signed),'withdraw_raw':str(-signed),'withdraw_DAI':units(balance,18),'give_selector':data[:4].hex(),'historical_delegatecall_target':give['action']['to'],'checked_trace_calls':len(drips),'historical_state_boundary':'Reserve amount is the value returned during the transaction, not an independently read pre-block storage snapshot.'})

# Decode the top-level batch and both submitted oracle reports directly from public calldata.
tx=read('ostium/transaction-rpc.json')['result']
data=bytes.fromhex(tx['input'][2:])[4:]
addr_base=word(data,0); call_base=word(data,32)
n=word(data,addr_base); assert n==word(data,call_base)==4
targets=['0x'+data[addr_base+32+i*32+12:addr_base+64+i*32].hex() for i in range(n)]
calls=[dynamic(data,call_base+32+word(data,call_base+32+i*32)) for i in range(n)]
decoded=[]
for i,(target,call) in enumerate(zip(targets,calls)):
    row={'index':i,'target':target,'selector':'0x'+call[:4].hex(),'calldata_bytes':len(call)}
    if i in (1,3):
        outer=call[4:]; perform=dynamic(outer,word(outer,0))
        order=word(perform,32); report=dynamic(perform,word(perform,0))
        reportdata=dynamic(report,word(report,0))
        row.update(order_id=order,feed='0x'+reportdata[:32].hex(),timestamp=word(reportdata,32),price_raw=str(word(reportdata,64)),bid_raw=str(word(reportdata,96)),ask_raw=str(word(reportdata,128)),is_market_open=bool(word(reportdata,160)),signature={'r':'0x'+report[32:64].hex(),'s':'0x'+report[64:96].hex(),'v':word(report,96)})
    decoded.append(row)
assert decoded[1]['timestamp']==decoded[3]['timestamp']==2000000000
receipt=read('ostium/receipt-alt.json')['result']; assert int(receipt['status'],16)==1
transfers=receipt_transfers(receipt,'0xaf88d065e77c8cc2239327c5edb3a432268e5831')
trader='0x321df194646029e7a6193ea05573d4b9c398bfd9'; vault='0x20d419a8e12c45f88fda7c5760bb6923cee27f98'
write('ostium/recomputed.json',{'batch_calls':decoded,'block_number':int(receipt['blockNumber'],16),'USDC_transfers':transfers,'trader_net_USDC':units(net(transfers,trader),6),'vault_net_USDC':units(net(transfers,vault),6),'full_internal_trace_obtained':False,'signer_recovery_independently_run':False,'note':'Signature bytes and future timestamps decoded; signature recovery and historical authorized-signer/forwarder mappings were not independently read.'})

receipt=read('crc/receipt-alt.json')['result']; assert int(receipt['status'],16)==1
token=read('crc/token-lower.json')
burn_sig=next(x['signatureHash32'] for x in token['signatures']['event'] if x['signature'].startswith('BurnFromPair('))
burns=[]
for log in receipt['logs']:
    if log['address'].lower()==token['address'].lower() and log['topics'][0]==burn_sig:
        data=bytes.fromhex(log['data'][2:]); burns.append({'burn_raw':str(int(log['topics'][1],16)),'pair_before_raw':str(word(data,0)),'pair_after_raw':str(word(data,32)),'kind':dynamic(data,word(data,64)).decode(),'log_index':int(log['logIndex'],16)})
usdt=receipt_transfers(receipt,'0x55d398326f99059ff775485246999027b3197955')
pair='0xd8799a644850c065388c22df4ee0c28472922526'; eoa='0x34579ea92a07a88f5505dfaa4d99ab94b2784087'
write('crc/recomputed.json',{'block_number':int(receipt['blockNumber'],16),'USDT_transfers':usdt,'pair_net_USDT':units(net(usdt,pair),18),'eoa_net_USDT':units(net(usdt,eoa),18),'burn_events':burns,'full_internal_trace_obtained':False,'note':'Amounts here come from the actual historical receipt, not a third-party reproduction trace.'})

tx=read('lien/transaction.json'); trace=read('lien/trace.json')
exchange=[]
registered_groups=[]
for t in trace:
    call=t.get('action',{}); raw=call.get('input','')
    if raw.startswith('0xe59455e0'):
        groupdata=bytes.fromhex(raw[2:])[4:]; off=word(groupdata,0); count=word(groupdata,off)
        registered_groups.append({'target':call['to'],'returned_group_id':int(t['result']['output'],16),'maturity':word(groupdata,32),'bond_ids':['0x'+groupdata[off+32+i*32:off+64+i*32].hex() for i in range(count)],'trace_address':t['traceAddress']})
    if raw.startswith('0x529aa16b'):
        data=bytes.fromhex(raw[2:])[4:]; off=word(data,96); count=word(data,off)
        exchange.append({'target':call['to'],'input_group':word(data,0),'output_group':word(data,32),'amount_raw':str(word(data,64)),'exceptions':['0x'+data[off+32+i*32:off+64+i*32].hex() for i in range(count)],'trace_address':t['traceAddress']})
transfers=[{'from':x['from']['hash'],'to':x['to']['hash'],'raw':x['total']['value']} for x in tx['token_transfers'] if x['token']['symbol']=='USDC']
write('lien/recomputed.json',{'registered_groups':registered_groups,'exchangeEquivalentBonds_calls':exchange,'USDC_transfers':transfers,'victim_net_USDC':units(net(transfers,'0xA961684a3a654fb2cCA8F8991226C0CEfc514d80'),6),'attacker_net_USDC':units(net(transfers,'0x0D7d9023531aD1A88414E216Ee2715F63561808a'),6),'full_internal_trace_obtained':True,'trace_calls':len(trace),'bondmaker_addresses_are_two_deployments_not_proxy_implementation':True})

tx=read('verus/transaction.json'); trace=read('verus/trace.json')
assets=[{'symbol':x['token']['symbol'],'token':x['token']['address_hash'],'from':x['from']['hash'],'to':x['to']['hash'],'raw':x['total']['value'],'decimals':int(x['token']['decimals']),'amount':units(int(x['total']['value']),int(x['token']['decimals']))} for x in tx['token_transfers']]
native=[{'from':x['action'].get('from'),'to':x['action'].get('to'),'wei':str(int(x['action'].get('value','0x0'),16)),'ETH':units(int(x['action'].get('value','0x0'),16),18),'trace_address':x['traceAddress']} for x in trace if x['type']=='call' and int(x['action'].get('value','0x0'),16)>0]
write('verus/recomputed.json',{'ERC20_transfers':assets,'native_ETH_calls':native,'proof_and_payout_delegatecalls':list(dict.fromkeys(x['action']['to'] for x in trace if x['type']=='call' and x['action'].get('callType')=='delegatecall')),'full_internal_trace_obtained':True,'USD_valuation_independently_verified':False,'trace_calls':len(trace)})

print(json.dumps({'status':'passed','independent_recomputations_compared':len(COMPUTED),'cases':list(CASE_IDS.values())},ensure_ascii=False,indent=2))
