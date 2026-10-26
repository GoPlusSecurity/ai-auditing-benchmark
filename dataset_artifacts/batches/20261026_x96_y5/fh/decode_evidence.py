"""Offline only: decode already archived receipt and call-trace data."""
from collections import defaultdict
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TRANSFER = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'


def read_response(name):
    path = ROOT / name
    if not path.exists():
        return None, None
    raw = path.read_bytes()
    obj = json.loads(raw)
    return obj.get('result', obj), {'path': name, 'sha256': hashlib.sha256(raw).hexdigest()}


def walk_calls(call, path='0', parent=None):
    yield {'path': path, 'parent': parent, 'type': call.get('type'),
           'from': call.get('from'), 'to': call.get('to'),
           'input': call.get('input'), 'output': call.get('output'),
           'value': call.get('value'), 'error': call.get('error')}
    for index, child in enumerate(call.get('calls', [])):
        yield from walk_calls(child, f'{path}.{index}', path)


def main():
    result = {'method': 'Offline JSON parsing only; amounts are raw integer token units.',
              'inputs': [], 'transfers': [], 'net_transfers_raw': {}, 'call_trace': []}
    receipt, provenance = read_response('receipt.json' if (ROOT / 'receipt.json').exists() else 'receipt-bnb-official.json')
    if provenance:
        result['inputs'].append(provenance)
    if isinstance(receipt, dict) and 'logs' in receipt:
        result['receipt_summary'] = {k: receipt.get(k) for k in
                                    ('transactionHash', 'blockHash', 'blockNumber', 'status', 'from', 'to')}
        balances = defaultdict(lambda: defaultdict(int))
        for log in receipt['logs']:
            topics = log.get('topics', [])
            if len(topics) == 3 and topics[0].lower() == TRANSFER:
                token = log['address'].lower()
                src, dst = ('0x' + topics[i][-40:].lower() for i in (1, 2))
                amount = int(log['data'], 16)
                result['transfers'].append({'log_index': int(log['logIndex'], 16),
                                            'token': token, 'from': src, 'to': dst, 'raw_amount': str(amount)})
                balances[token][src] -= amount
                balances[token][dst] += amount
        result['net_transfers_raw'] = {token: {addr: str(amount) for addr, amount in accounts.items()}
                                       for token, accounts in balances.items()}
    trace, provenance = read_response('trace.json')
    if provenance:
        result['inputs'].append(provenance)
    if isinstance(trace, dict) and ('calls' in trace or 'type' in trace):
        result['call_trace'] = list(walk_calls(trace))
    (ROOT / 'decoded_evidence.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'transfers': len(result['transfers']), 'calls': len(result['call_trace'])}))


if __name__ == '__main__':
    main()