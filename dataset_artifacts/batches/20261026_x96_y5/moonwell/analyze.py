"""Offline decoding of archived Moonwell evidence. Never executes contracts."""
import collections
import datetime as dt
from decimal import Decimal as D, getcontext
getcontext().prec=60
import hashlib
import json
from pathlib import Path

BASE=Path(__file__).resolve().parent
def load(name): return json.loads((BASE/name).read_text('utf-8'))
def result(name):
    value=load(name)
    assert 'error' not in value and value.get('result') is not None, name
    return value['result']
def words(data): return [int(data[i:i+64],16) for i in range(2,len(data),64)]
def address(word): return '0x'+format(word,'040x')
def dump(name,obj): (BASE/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

ATTACKER='0x719eae70d4a83f35bf82a2740699f5db84be919d'
MMAMO='0x2f90bb22eb3979f5ffad31ea6c3f0792ca66da32'
MAMO='0x7300b37dfdfab110d83290a29dfb31b1740219fe'
TRANSFER='0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'
BORROW='0x13ed6866d4e1ee6da46f845c46d7e54120883d75c5ea9a2dacc1c4ca8984ab80'
UNWRAPPER='0x1382cff3cee10d283dcca55a30496187759e4caf'
WITHDRAWAL='0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65'
MINT='0x4c209b5fc8ad50758f13e2e1088ba56a560dff690a1c6fef26394f4c03821c4f'
TOKENS={'0xcbb7c0000ab88b473b1f5afd9ef808440eed33bf':('cbBTC',8),
 '0x4200000000000000000000000000000000000006':('WETH',18),
 '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913':('USDC',6),
 '0xc1cba3fcea344f92d9239c08c0568f6f2f0ee452':('wstETH',18),MAMO:('MAMO',18)}

receipts={}
for p in BASE.glob('*receipt.json'):
    r=result(p.name)
    assert r['status']=='0x1', p.name
    receipts[r['transactionHash']]=(p.name,r)
borrowings=[]; totals=collections.defaultdict(int); donations=[]
for tx,(file,r) in receipts.items():
    transfers=[]
    for log in r['logs']:
        if log['topics'][0].lower()==TRANSFER and len(log['topics'])==3:
            transfers.append({'token':log['address'].lower(),'from':'0x'+log['topics'][1][-40:].lower(),'to':'0x'+log['topics'][2][-40:].lower(),'amount_raw':int(log['data'],16),'log_index':int(log['logIndex'],16)})
    for log in r['logs']:
        if log['topics'][0].lower()!=BORROW: continue
        w=words(log['data']); who=address(w[0])
        if who!=ATTACKER: continue
        matches=[t for t in transfers if t['from']==log['address'].lower() and t['to']==who and t['amount_raw']==w[1]]
        route='erc20_market_to_borrower'
        if not matches and log['address'].lower()=='0x628ff693426583d9a7fb391e54366292f509d457':
            matches=[t for t in transfers if t['from']==log['address'].lower() and t['to']==UNWRAPPER and t['amount_raw']==w[1] and t['token']=='0x4200000000000000000000000000000000000006']
            withdrawals=[l for l in r['logs'] if l['address'].lower()=='0x4200000000000000000000000000000000000006' and l['topics'][0].lower()==WITHDRAWAL and '0x'+l['topics'][1][-40:].lower()==UNWRAPPER and int(l['data'],16)==w[1]]
            assert len(withdrawals)==1,(tx,'unwrap missing')
            route='market_to_WethUnwrapper_then_WETH_withdraw; final_ETH_recipient_source_proven; first_560_ETH_also_traced'
        assert len(matches)==1,(tx,log['address'],matches)
        t=matches[0]; symbol,decimals=TOKENS[t['token']]
        item={'transaction':tx,'block':int(r['blockNumber'],16),'transaction_index':int(r['transactionIndex'],16),'log_index':int(log['logIndex'],16),'market':log['address'],'borrower':who,'token':t['token'],'symbol':symbol,'amount_raw':str(w[1]),'decimals':decimals,'amount':str(D(w[1])/D(10)**decimals),'receipt':file,'matching_payout_transfer_log_index':t['log_index'],'payout_route':route}
        borrowings.append(item);totals[symbol]+=w[1]
    for t in transfers:
        if t['token']==MAMO and t['from']==ATTACKER and t['to']==MMAMO:
            donations.append({'transaction':tx,'amount_raw':str(t['amount_raw']),'amount_mamo':str(D(t['amount_raw'])/D(10)**18),'receipt':file,'mmamo_mint_event_present':any(l['address'].lower()==MMAMO and l['topics'][0].lower()==MINT for l in r['logs'])})
borrowings.sort(key=lambda x:(x['block'],x['transaction_index'],x['log_index']))
states={}
for tag,block in [('pre-donation',int('302d22d',16)),('post-donation1',int('302d22e',16)),('post-donation2',int('302d251',16))]:
    supply=int(result(tag+'-totalSupply.json'),16);cash=int(result(tag+'-getCash.json'),16);rate=int(result(tag+'-exchangeRateStored.json'),16)
    states[tag]={'block':block,'totalSupply_raw':str(supply),'getCash_raw':str(cash),'cash_mamo':str(D(cash)/D(10)**18),'exchangeRateStored_raw':str(rate),'mamo_per_mmamo':str(D(rate)/D(10)**28)}
assert len({x['totalSupply_raw'] for x in states.values()})==1
bindings=[]
for name in ['market-implementation','comptroller-implementation','chainlink-oracle','mamo-feed','chainlink-feed-proxy','chainlink-aggregator','mweth-implementation','weth-router']:
    source=load(name+'-source.json');code=result(name+'-historical-code.json')
    same=code.lower()==source['runtimeBytecode']['onchainBytecode'].lower()
    assert same,name
    bindings.append({'bundle':name,'address':source['address'],'block':int('302d361',16),'provider_runtime_match':source['runtimeMatch'],'historical_runtime_equals_provider_onchain_runtime':same,'historical_runtime_sha256':hashlib.sha256(bytes.fromhex(code[2:])).hexdigest()})
prices={tag:str(D(int(result(tag+'-mamo-price.json'),16))/D(10)**18) for tag in ['before-rise','peak-price','final-borrow']}
snap=words(result('mamo-borrower-snapshot.json'))
assert snap[0]==0 and snap[2]==0
claim=D(snap[1])*D(snap[3])/D(10)**36
market=words(result('mamo-historical-market.json'));assert market[0]==1
factor=D(market[1])/D(10)**18
trace=load('weth-borrow-raw-trace.json')
def walk(call):
    yield call
    for child in call.get('calls',[]): yield from walk(child)
native=[c for c in walk(trace) if c.get('from','').lower()==UNWRAPPER and c.get('to','').lower()==ATTACKER and int(c.get('value','0x0'),16)==560*10**18]
assert len(native)==1 and not native[0].get('error')
assert int(result('mmamo-decimals.json'),16)==8
for tag,symbol in [('cbbtc','cbBTC'),('weth','WETH'),('usdc','USDC'),('wsteth','wstETH'),('mamo','MAMO')]:
    assert int(result(tag+'-decimals.json'),16)==next(v[1] for v in TOKENS.values() if v[0]==symbol)
summary={'native_ETH_560_payment':{'from':UNWRAPPER,'to':ATTACKER,'value_wei':str(560*10**18),'trace_file':'weth-borrow-raw-trace.json','error':native[0].get('error')},'borrow_events':len(borrowings),'borrow_transactions':len({x['transaction'] for x in borrowings}),'gross_borrowed':{symbol:str(D(raw)/D(10)**next(v[1] for v in TOKENS.values() if v[0]==symbol)) for symbol,raw in totals.items()},'donations':donations,'states':states,'exchange_rate_multiplier':str(D(states['post-donation2']['exchangeRateStored_raw'])/D(states['pre-donation']['exchangeRateStored_raw'])),'historical_prices_usd':prices,'historical_collateral_factor':str(factor),'historical_supply_cap_mamo':str(D(int(result('mamo-historical-supply-cap.json'),16))/D(10)**18),'borrower_mmamo_raw':str(snap[1]),'borrower_mamo_claim_at_peak':str(claim),'nominal_capacity_scope':'Approximate gross collateral value using shares/rate/price at 50516812 and factor at 50516833; not same-block exact net available borrowing and not full integer-math reconstruction','nominal_capacity_usd_at_peak':str(claim*D(prices['peak-price'])*factor),'bindings':bindings,'borrowings':borrowings,'limits':['Historical calls are block-end state, not intra-transaction state snapshots.','Only selected funding, donation, borrow and bridge receipts were obtained; full swaps, liquidations, all liabilities and final profit were not independently reconstructed.','Source verification is reported by Sourcify; no local compilation or fork replay was run.']}
dump('decoded_evidence.json',summary)
print(json.dumps({k:v for k,v in summary.items() if k in ['borrow_events','borrow_transactions','gross_borrowed','donations','exchange_rate_multiplier','historical_prices_usd','historical_collateral_factor','historical_supply_cap_mamo','borrower_mamo_claim_at_peak','nominal_capacity_usd_at_peak']},ensure_ascii=False,indent=2))
