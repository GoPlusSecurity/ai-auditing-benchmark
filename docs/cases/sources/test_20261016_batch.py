import hashlib
from pathlib import Path
import tempfile
import unittest
import validate_20261016_batch as batch

def source_text(case_id, ending):
    root=batch.ROOT/'dataset'/case_id
    matches=[path for path in root.rglob('*') if path.is_file() and path.as_posix().endswith(ending)]
    if len(matches)!=1:
        raise AssertionError(f'{case_id} {ending} matched {len(matches)} files')
    return matches[0].read_text('utf-8')

class CausalCoverageTests(unittest.TestCase):
    def test_ostium_keeps_profit_to_payment_formula(self):
        text=source_text('20260715_Ostium','/src/OstiumPairInfos.sol')
        self.assertIn('signedCollateral + (signedCollateral * percentProfit) / int32(PRECISION_6) / 100 - rolloverFee - fundingFee',text)
        self.assertIn('if (value < 0)',text)
        self.assertIn('PRECISION_6 = 1e6',text)

    def test_verus_keeps_raw_transfer_to_packed_payment_fields(self):
        text=source_text('20260723_Verus','/transfer-serializer/contracts/VerusBridge/VerusSerializer.sol')
        self.assertIn('function deserializeTransfers(',text)
        self.assertIn('currencyAndAmount = uint256(temporaryRegister1) << VerusConstants.UINT160_BITS_SIZE',text)
        self.assertIn('destinationAndFlags = uint256(uint160(tempaddress))',text)
        self.assertIn('function readVarint(',text)
        self.assertIn('function readCompactSizeLE(',text)

    def test_verus_source_is_bound_to_actual_serializer_target(self):
        provenance=batch.load(batch.ROOT/'dataset_artifacts/20260723_Verus/provenance.json')
        bundles=[b for b in provenance['bundles'] if b['address'].lower()=='0x747d5eed7aa4436b3d7a6cf2db7d78b8e93600fc']
        self.assertEqual(len(bundles),1,'actual staticcall target has no separately verified original source bundle')
        self.assertIn(bundles[0]['runtime_match'],('match','exact_match'))

class PreservationTests(unittest.TestCase):
    def test_prefix_rejects_reformatted_old_csv(self):
        original=b'a,b\r\n"embedded\nline",value\r\n'
        entry={'baseline_bytes':len(original),'baseline_sha256':hashlib.sha256(original).hexdigest()}
        self.assertEqual(batch.check_prefix(original+b'new,row\r\n',entry),b'new,row\r\n')
        with self.assertRaises(batch.shared.ValidationError):
            batch.check_prefix(original.replace(b'\r\n',b'\n')+b'new,row\r\n',entry)

    def test_migration_rejects_changed_abi_or_retained_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); old=root/'dataset/view/case/abi.json'; new=root/'dataset_artifacts/view/case/abi.json'
            new.parent.mkdir(parents=True); new.write_bytes(b'[]\n')
            entry={'source':'dataset/view/case/abi.json','destination':'dataset_artifacts/view/case/abi.json','sha256':hashlib.sha256(new.read_bytes()).hexdigest(),'bytes':3}
            batch.check_move(root,entry)
            new.write_bytes(b'{}\n')
            with self.assertRaises(batch.shared.ValidationError): batch.check_move(root,entry)
            new.write_bytes(b'[]\n'); old.parent.mkdir(parents=True); old.write_bytes(b'[]\n')
            with self.assertRaises(batch.shared.ValidationError): batch.check_move(root,entry)

class BatchTests(unittest.TestCase):
    def test_fixed_batch_validates(self):
        report=batch.validate()
        self.assertEqual(report['status'],'passed')
        self.assertEqual(report['parameters'],{'x':123,'y':5})
        self.assertEqual(report['actual_scan_range'],[106,123])
        self.assertEqual(report['counts']['new_cases'],5)

if __name__=='__main__': unittest.main()
