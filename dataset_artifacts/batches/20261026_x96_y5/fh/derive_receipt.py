"""Offline receipt arithmetic; does not execute any EVM or downloaded code."""
from pathlib import Path
import json
from collections import Counter
from decimal import Decimal
ROOT = Path(__file__).resolve().parent
PAIR = '0x8f2d1a3992856a860304f1b86534b6b129cc4df7'
TOKEN = '0xdcf0dfe0053677a67610c6d08ea1f5c78df8ca37'
ATTACK = '0x727fb666e3f2531e807e987532c6e2c22adc45ad'
SYNC = '0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1'
SWAP = '0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822'
receipt = json.loads((ROOT / 'receipt-bnb-official.json').read_text())['result']
decoded = json.loads((ROOT / 'decoded_evidence.json').read_text())
logs = receipt['logs']
pair_events = []
for log in logs:
    if log['address'].lower() != PAIR:
        continue
    words = [int(log['data'][i:i+64], 16) for i in range(2, len(log['data']), 64)]
    event = {'log_index': int(log['logIndex'], 16), 'topic0': log['topics'][0]}
    if log['topics'][0] == SYNC:
        event.update(event='Sync', reserve0_raw=str(words[0]), reserve1_raw=str(words[1]))
    elif log['topics'][0] == SWAP:
        event.update(event='Swap', sender='0x'+log['topics'][1][-40:], to='0x'+log['topics'][2][-40:],
                     amount0_in_raw=str(words[0]), amount1_in_raw=str(words[1]),
                     amount0_out_raw=str(words[2]), amount1_out_raw=str(words[3]))
    pair_events.append(event)
checks = []
for event in pair_events:
    if event['event'] != 'Swap' or int(event['amount1_in_raw']) == 0:
        continue
    idx = event['log_index']
    incoming = [t for t in decoded['transfers'] if t['token'] == TOKEN and t['from'] == ATTACK and t['to'] == PAIR and t['log_index'] < idx][-1]
    synced = [e for e in pair_events if e['event'] == 'Sync' and e['log_index'] < incoming['log_index']][-1]
    amount_in = int(event['amount1_in_raw'])
    reserve_in, reserve_out = int(synced['reserve1_raw']), int(synced['reserve0_raw'])
    calculated = amount_in * 9975 * reserve_out // (reserve_in * 10000 + amount_in * 9975)
    check = {'cycle': len(checks)+1, 'sync_before_seller_transfer_log': synced['log_index'],
             'seller_transfer_log': incoming['log_index'], 'swap_log': idx,
             'reserve_input_raw': str(reserve_in), 'reserve_output_raw': str(reserve_out),
             'seller_input_raw': str(amount_in), 'receipt_output_raw': event['amount0_out_raw'],
             'router_formula_output_raw': str(calculated),
             'input_matches_transfer': amount_in == int(incoming['raw_amount']),
             'output_matches_formula': calculated == int(event['amount0_out_raw'])}
    checks.append(check)
assert len(checks) == 25
assert all(c['input_matches_transfer'] and c['output_matches_formula'] for c in checks)
decoded['pair_event_abi_source'] = 'source-bundles/pancake-pair-reference/PancakePair.sol:298-308 (reference source; target runtime binding tracked separately)'
decoded['pair_events'] = pair_events
decoded['cycle_checks'] = checks
decoded['cycle_check_summary'] = {'count': len(checks), 'all_25_input_transfer_matches': True,
                                  'all_25_formula_matches': True,
                                  'formula_source': 'source-bundles/pancake-v2-router/PancakeRouter.sol:314-321',
                                  'full_internal_trace_available': False,
                                  'execution_or_replay_performed': False}
(ROOT / 'decoded_evidence.json').write_text(json.dumps(decoded,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(decoded['cycle_check_summary']))