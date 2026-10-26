"""Offline decoding of archived public ABI/receipts, not contract execution."""
from collections import Counter, defaultdict
from decimal import Decimal, getcontext
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent
getcontext().prec = 100
SCREEN = BASE / 'screening'
MASK = (1 << 64) - 1
ROUNDS = [0x1, 0x8082, 0x800000000000808a, 0x8000000080008000,
          0x808b, 0x80000001, 0x8000000080008081, 0x8000000000008009,
          0x8a, 0x88, 0x80008009, 0x8000000a, 0x8000808b,
          0x800000000000008b, 0x8000000000008089, 0x8000000000008003,
          0x8000000000008002, 0x8000000000000080, 0x800a,
          0x800000008000000a, 0x8000000080008081, 0x8000000000008080,
          0x80000001, 0x8000000080008008]
ROT = [0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, 21, 8, 18, 2, 61, 56, 14]

def keccak(data):
    def rot(value, shift):
        return ((value << shift) | (value >> ((64 - shift) % 64))) & MASK
    padded = bytearray(data); padded.append(1)
    padded += bytes((135 - len(padded)) % 136); padded.append(128)
    state = [0] * 25
    for block in range(0, len(padded), 136):
        for i in range(17):
            state[i] ^= int.from_bytes(padded[block + i * 8:block + i * 8 + 8], 'little')
        for rc in ROUNDS:
            c = [state[x] ^ state[x+5] ^ state[x+10] ^ state[x+15] ^ state[x+20] for x in range(5)]
            d = [c[(x-1) % 5] ^ rot(c[(x+1) % 5], 1) for x in range(5)]
            for i in range(25): state[i] ^= d[i % 5]
            buf = [0] * 25
            for x in range(5):
                for y in range(5): buf[y + 5 * ((2*x + 3*y) % 5)] = rot(state[x + 5*y], ROT[x + 5*y])
            for x in range(5):
                for y in range(5): state[x+5*y] = buf[x+5*y] ^ ((~buf[(x+1)%5+5*y]) & buf[(x+2)%5+5*y])
            state[0] ^= rc
    return b''.join(n.to_bytes(8, 'little') for n in state)[:32]

def signature(entry):
    return entry['name'] + '(' + ','.join(p['type'] for p in entry['inputs']) + ')'

def load(name): return json.loads((SCREEN / name).read_text('utf-8'))
def units(n, decimals=18): return format(Decimal(n) / Decimal(10) ** decimals, 'f')

def decode_events(label, source_names):
    events = {}
    for name in source_names:
        source = load(name)
        for entry in source['abi']:
            if entry['type'] == 'event': events['0x'+keccak(signature(entry).encode()).hex()] = entry
    receipt = load(label+'-receipt.json')['result']; output = []
    for log in receipt['logs']:
        abi = events.get(log['topics'][0]) if log['topics'] else None
        if not abi or abi['name'] in ('Transfer', 'Approval'): continue
        words = [log['data'][i:i+64] for i in range(2, len(log['data']), 64)]
        topic = iter(log['topics'][1:]); data = iter(words); values = {}
        try:
            for field in abi['inputs']:
                word = next(topic) if field.get('indexed') else next(data)
                val = int(word, 16)
                if field['type'] == 'address':
                    values[field['name']] = '0x'+word.removeprefix('0x')[-40:]
                elif field['type'] in ('bytes','string') and not field.get('indexed'):
                    raw = bytes.fromhex(log['data'][2:]); size = int.from_bytes(raw[val:val+32], 'big')
                    values[field['name']] = '0x'+raw[val+32:val+32+size].hex()
                elif field['type'].startswith('bytes'):
                    values[field['name']] = '0x'+word.removeprefix('0x')
                else:
                    values[field['name']] = val
        except StopIteration: continue
        output.append({'log_index': int(log['logIndex'], 16), 'address': log['address'], 'event': abi['name'], 'values': values})
    return output

def transfers(label):
    receipt = load(label+'-receipt.json')['result']; out=[]
    for log in receipt['logs']:
        if log['topics'] and log['topics'][0] == '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef' and len(log['topics']) == 3:
            out.append({'index': int(log['logIndex'],16),'token':log['address'],'from':'0x'+log['topics'][1][-40:],'to':'0x'+log['topics'][2][-40:],'amount':int(log['data'],16)})
    return out

def deltas(items, token, decimals=18):
    result=defaultdict(int)
    for item in items:
        if item['token'].lower()==token.lower():
            result[item['from']]-=item['amount']; result[item['to']]+=item['amount']
    assert sum(result.values()) == 0
    return {address: units(n, decimals) for address,n in result.items() if n}

def main():
    assert keccak(b'').hex() == 'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470'
    assert keccak(b'Transfer(address,address,uint256)').hex() == 'ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'
    assert keccak(b'balanceOf(address)').hex()[:8] == '70a08231'
    assert units(1_000_000, 6) == '1'
    report={'kind':'offline archival decoding, no decompilation or EVM execution','keccak_known_vectors':'passed','cases':{}}
    for label, source_names in {
        'moke':['moke-token-source.json','moke-actual-token-source.json','moke-release-source.json','moke-tokenx-source.json','pro-pair-source.json'],
        'nex':['nex-token-source.json','aic-token-source.json','pro-pair-source.json'],
        'fox':['fox-bonds-source.json','fox-treasury-source.json','fox-actual-token-source.json','pro-pair-source.json'],
        'allbridge':['allbridge-router-source.json','allbridge-messenger-source.json','allbridge-circle-implementation-source.json'],
    }.items():
        events=decode_events(label,source_names); ts=transfers(label)
        decimals = 6 if label == 'allbridge' else 18
        report['cases'][label]={'decoded_events':events,'token_transfers':ts,'delta_decimals':decimals,'deltas':{token:deltas(ts,token,decimals) for token in sorted({t['token'] for t in ts})}}
    trace=load('usm-trace.json'); usm='0x2a7fff44c19f39468064ab5e5c304de01d591675'
    abi=load('usm-source.json')['abi']; names={'0x'+keccak(signature(e).encode()).hex()[:8]:e['name'] for e in abi if e['type']=='function'}
    calls=[]; incoming=outgoing=0
    for row in trace:
        a=row.get('action',{}); target=a.get('to','').lower(); sender=a.get('from','').lower(); value=int(a.get('value','0x0'),16)
        if target==usm:
            name=names.get(a.get('input','')[:10],a.get('input','')[:10]); incoming+=value
            calls.append({'trace_address':row.get('traceAddress'),'from':sender,'function':name,'value_wei':value,'input':a.get('input'),'output':row.get('result',{}).get('output'),'error':row.get('error')})
        if sender==usm and not row.get('error'): outgoing+=value
    price_selector='0x'+keccak(b'latestPrice()').hex()[:8]
    oracle_reads=[{'to':r['action'].get('to'),'output':r.get('result',{}).get('output'),'trace_address':r.get('traceAddress')} for r in trace if r.get('action',{}).get('input')==price_selector]
    report['cases']['usm']={'target_calls':calls,'function_counts':dict(Counter(c['function'] for c in calls)),'incoming_eth_wei':incoming,'outgoing_eth_wei':outgoing,'net_outflow_eth':units(outgoing-incoming),'trace_rows':len(trace),'latest_price_reads':oracle_reads}
    (BASE/'decoded_evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for label,item in report['cases'].items():
        print(label,json.dumps({'event_counts':dict(Counter(e['event'] for e in item.get('decoded_events',[]))),'deltas':item.get('deltas',{}),'function_counts':item.get('function_counts'),'net_outflow_eth':item.get('net_outflow_eth')},ensure_ascii=False))

if __name__=='__main__': main()
