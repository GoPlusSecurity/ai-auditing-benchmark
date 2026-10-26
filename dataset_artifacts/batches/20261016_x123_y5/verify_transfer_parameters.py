"""Decode archived historical ABI input/output and compare the eight Verus payouts.

No RPC calls, compiler, archived Solidity execution or exploit replay.
"""
import argparse
from decimal import Decimal, getcontext
import hashlib
import json
from pathlib import Path

getcontext().prec=100
ROOT=Path(__file__).resolve().parents[3]
ART=ROOT/'dataset_artifacts/20260723_Verus'
def load(path): return json.loads(path.read_text('utf-8'))
def word(data,offset):
    if offset<0 or offset+32>len(data): raise ValueError('ABI word outside captured data')
    return int.from_bytes(data[offset:offset+32],'big')
def dynamic(data,offset):
    size=word(data,offset)
    if offset+32+size>len(data): raise ValueError('dynamic bytes outside captured data')
    return data[offset+32:offset+32+size]

def recompute():
    trace=load(ART/'evidence/trace.json'); expected=load(ART/'evidence/recomputed.json')
    call=next(t for t in trace if t['traceAddress']==[0,1,0])
    if call['action']['to']!='0x747d5eed7aa4436b3d7a6cf2db7d78b8e93600fc' or call['action']['callType']!='staticcall':
        raise ValueError('unexpected historical serializer target')
    raw=bytes.fromhex(call['action']['input'][2:]); data=raw[4:]
    if raw[:4].hex()!='9d56cf89': raise ValueError('wrong serializer selector')
    transfer_bytes=dynamic(data,word(data,0)); n=word(data,32)
    parent=next(t for t in trace if t['traceAddress']==[0,1])
    parent_data=bytes.fromhex(parent['action']['input'][2:])[4:]
    if dynamic(parent_data,word(parent_data,0))!=transfer_bytes or word(parent_data,32)!=n:
        raise ValueError('TokenManager input is not the serializer input')
    output=bytes.fromhex(call['result']['output'][2:]); start=word(output,0)
    count=word(output,start); counter=word(output,64)
    if count!=n or counter!=n or n!=8: raise ValueError('historical transfer counts differ')
    # Bind labels by the observed payment order, not an independently read currency-mapping slot.
    native=expected['native_ETH_calls'][0]
    payments=[{'symbol':'ETH','raw':native['wei'],'decimals':18,'to':native['to']}]+expected['ERC20_transfers']
    if len(payments)!=count: raise ValueError('observed payment count differs')
    records=[]
    for i,payment in enumerate(payments):
        packed=word(output,start+32+i*64); flags=word(output,start+64+i*64)
        amount=packed>>160; currency='0x'+format(packed&((1<<160)-1),'040x')
        destination='0x'+format(flags&((1<<160)-1),'040x')
        if destination.lower()!=payment['to'].lower(): raise ValueError('payout recipient differs')
        decimals=payment['decimals']
        converted=amount*10**(decimals-8) if decimals>=8 else amount//10**(8-decimals)
        observed=int(payment['raw']); delta=observed-converted
        if delta!=(1 if payment['symbol']=='DAI' else 0): raise ValueError('packed amount does not reconcile to payout')
        records.append({'index':i,'currency_identifier':currency,'amount_in_source_8_decimal_units':str(amount),'destination':destination,'currency_and_amount_word':'0x'+format(packed,'064x'),'destination_and_flags_word':'0x'+format(flags,'064x'),'observed_asset':payment['symbol'],'asset_decimals':decimals,'requested_payout_raw':str(converted),'observed_transfer_raw':str(observed),'observed_minus_requested_raw':str(delta),'requested_units':format(Decimal(converted)/Decimal(10)**decimals,'f')})
    source_bundle=next(b for b in load(ART/'provenance.json')['bundles'] if b['id']=='transfer-serializer')
    return {'historical_target':call['action']['to'],'trace_address':call['traceAddress'],'call_type':'staticcall','selector':'0x'+raw[:4].hex(),'serialized_transfer_bytes':len(transfer_bytes),'serialized_transfers_sha256':hashlib.sha256(transfer_bytes).hexdigest(),'same_serialized_bytes_as_TokenManager_input':True,'input_transfer_count':n,'returned_array_count':count,'returned_counter':counter,'source_provider':source_bundle['provider'],'source_runtime_match':source_bundle['runtime_match'],'source_verified_at':source_bundle['verified_at'],'payments':records,'evidence_boundary':'Actual staticcall ABI output and observed payments checked. Asset labels use historical payment order/quantities; complete source-chain currency mapping storage was not independently read. DAI exit emits one wei more than the requested conversion. No contract execution or replay.'}

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--output',type=Path); args=parser.parse_args()
    result=recompute()
    if args.output: args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    elif result!=load(ART/'evidence/transfer-parameters.json'): raise ValueError('saved transfer-parameter record differs')
    print(json.dumps({'status':'passed','decoded_transfers':len(result['payments']),'input_and_output_recipient_amounts_checked':True},ensure_ascii=False))
