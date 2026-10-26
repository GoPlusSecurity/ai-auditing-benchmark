from collections import Counter
from decimal import Decimal
import json
import sys
import unittest
import validate_20261021_batch as batch

sys.path.insert(0,str(batch.BASE))
import inspect_evidence as decoder

class CausalEvidenceTests(unittest.TestCase):
    def test_keccak_against_independent_known_vectors(self):
        self.assertEqual(decoder.keccak(b'').hex(),'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470')
        self.assertEqual(decoder.keccak(b'balanceOf(address)').hex()[:8],'70a08231')

    def test_usdc_is_six_decimals(self):
        transfers=decoder.transfers('allbridge')
        values=decoder.deltas(transfers,'0x833589fcd6edb6e08f4c7c32d4f71b54bda02913',6)
        self.assertEqual(values['0xaa119f7442ecc28b9a8f236707ada8362cff24ff'],'-190155.976393')
        self.assertEqual(values['0xb6fbdfa5f3cbeb139d4cce86d92f4ac8687b16c0'],'189751.554381')
        self.assertEqual(sum(Decimal(v) for v in values.values()),0)

    def test_moke_has_64_equal_stale_records_and_one_smaller(self):
        events=decoder.decode_events('moke',['moke-token-source.json'])
        syncs=[e['values'] for e in events if e['event']=='UserLPSynced']
        self.assertEqual(Counter(e['oldLP'] for e in syncs),{1334183807563777105758:64,985789028950366818528:1})
        self.assertTrue(all(e['newLP']==0 for e in syncs))

    def test_nex_really_transferred_the_same_amount_twice_from_pair(self):
        transfers=decoder.transfers('nex');pair='0x974c0078740480ae830d379fdb8d5f441c9ddc75'
        router='0x10ed43c718714eb63d5aa57b78b54704e256024e'
        hits=[t for t in transfers if t['token']=='0xae04ae29bdb7ab7eb249d3afa7bc3d37564e8cf9' and t['from']==pair and t['to']==router]
        self.assertEqual([(t['index'],t['amount']) for t in hits],[(9,31739425952813599235352140),(10,31739425952813599235352140)])

    def test_simplification_preserves_parent_balance_math_and_state_writes(self):
        for cid,terms in {
            '20260803_MOKE':['_balances[from] = fromBalance - value','function _update(address from, address to, uint256 value)','function _snapshotUser(address user)','Claim interval not reached','receive() external payable','unprocessedBNB += msg.value'],
            '20260804_NEX_AIC':['mapping(address => uint256) private _balances','library SafeMath','function mul(uint256 a, uint256 b)','function _transfer(address from, address to, uint256 amount) internal virtual'],
            '20260810_USM_FUM':['storedState = StoredState(','uint avgFumSellPrice = fumSellPrice0 + fumSellPrice2','to.sendValue(ethOut)'],
            '20260820_Allbridge_CCTP':['relayers[msg.sender] || msg.sender == recipientAddr','usedMessages[messageHash] = true','function _getDecimals(address token)'],
        }.items():
            root=batch.ROOT/'dataset/benchmark_simplified'/cid
            text='\n'.join(p.read_text('utf-8') for p in root.rglob('*.sol'))
            for term in terms:self.assertIn(term,text,cid+': '+term)

    def test_online_only_policy_and_lula_exclusion(self):
        results=batch.load(batch.BASE/'results.json')
        self.assertIn('prohibited',results['decompilation_policy']['local'])
        row=next(r for r in results['rows'] if r['event']=='LULA')
        self.assertFalse(row['qualifies'])
        self.assertTrue((batch.BASE/'screening/lula-rental-online-decompiler.png').is_file())

class BatchAcceptanceTests(unittest.TestCase):
    def test_fixed_snapshot_and_all_archive_checks(self):
        report=batch.validate()
        self.assertEqual(report['status'],'passed')
        parameters=batch.load(batch.BASE/'snapshot.json')['parameters']
        self.assertEqual(report['parameters'],{k:parameters[k] for k in ('x','y')})

if __name__=='__main__':unittest.main()
