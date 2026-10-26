"""Offline acceptance tests: byte identity, source-only layout and CSV preservation."""
from pathlib import Path
import csv, hashlib, io, json, subprocess, sys, unittest, zipfile

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
AMOS = '14920dcd252a0f9dee40453f4b6e885708979f78'
CASES = ['20260803_MOKE','20260804_NEX_AIC','20260810_USM_FUM','20260817_Fox','20260820_Allbridge_CCTP','20260822_TheSandbox','20260823_TermLabs','20260826_FH','20260827_Moonwell_MAMO']

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def blob_id(data):
    return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()

def tree(ref):
    return {p.decode(): h.decode() for item in git('ls-tree','-rz',ref).split(b'\0') if item for head,p in [item.split(b'\t',1)] for mode,kind,h in [head.split()] if kind==b'blob'}

def rows(data):
    return list(csv.reader(io.StringIO(data.decode('utf-8-sig'),newline='')))

class MigrationTests(unittest.TestCase):
    def test_old_cases_are_exact_amos_blobs(self):
        checked=0
        for p,h in tree(AMOS).items():
            if p.startswith('dataset/') or (p.startswith('dataset_artifacts/') and not p.startswith('dataset_artifacts/batches/')):
                with self.subTest(path=p):
                    self.assertTrue((ROOT/p).is_file(),p)
                    self.assertEqual(blob_id((ROOT/p).read_bytes()),h,p)
                checked+=1
        self.assertGreater(checked,1000)

    def test_new_776_sources_are_byte_exact_backup(self):
        with zipfile.ZipFile(BASE/'premerge-backup.zip') as z:
            names=[p for p in z.namelist() if p.startswith('dataset/benchmark_complete/')]
            self.assertEqual(len(names),776)
            for old in names:
                new=ROOT/old.replace('dataset/benchmark_complete/','dataset/',1)
                with self.subTest(path=str(new)):
                    self.assertTrue(new.is_file(),str(new))
                    self.assertEqual(new.read_bytes(),z.read(old),old)

    def test_flat_case_counts_and_no_variant_directories(self):
        self.assertEqual(len([p for p in (ROOT/'dataset').iterdir() if p.is_dir()]),65)
        self.assertEqual(len([p for p in (ROOT/'dataset_artifacts').iterdir() if p.is_dir() and p.name!='batches']),58)
        for root in ['dataset','dataset_artifacts']:
            self.assertFalse(any(p.is_dir() and p.name in {'benchmark_complete','benchmark_simplified'} for p in (ROOT/root).rglob('*')))

    def test_csv_keeps_amos_57_records_and_adds_nine_once(self):
        for language in ['cn','en']:
            name=f'ai-auditing-benchmark_{language}.csv'
            base=git('show',AMOS+':'+name);current=(ROOT/name).read_bytes()
            self.assertTrue(current.startswith(base),name+' amos prefix bytes')
            old=rows(base);new=rows(current)
            self.assertEqual(len(old)-1,57)
            self.assertEqual(len(new)-1,66)
            self.assertEqual(new[:58],old)
            for cid,row in zip(CASES,new[58:]):
                meta=json.loads((ROOT/'dataset_artifacts'/cid/'case_metadata.json').read_text('utf-8'))
                self.assertEqual(row[0],meta['event_date'].replace('-','.'))
                self.assertEqual(row[4],'\n'.join(meta['tx_urls']))
                self.assertEqual(sum(r[4]==row[4] for r in new[1:]),1)

    def test_current_metadata_has_single_source_entry(self):
        for cid in CASES:
            root=ROOT/'dataset_artifacts'/cid
            meta=json.loads((root/'case_metadata.json').read_text('utf-8'))
            self.assertNotIn('view',meta)
            self.assertEqual(meta['source_provenance'],'provenance.json')
            for key in ['source_sheet_snapshot','batch_results','case_document','source_provenance']:
                self.assertTrue((root/meta[key]).is_file(),(cid,key,meta[key]))
        meta=json.loads((ROOT/'dataset_artifacts/20260820_Allbridge_CCTP/case_metadata.json').read_text('utf-8'))
        matches=[r for r in meta['batch_appearances'] if r['batch']=='20261026_x96_y5']
        self.assertEqual(len(matches),1)
        self.assertTrue((ROOT/'dataset_artifacts/20260820_Allbridge_CCTP'/matches[0]['evidence']).is_file())

if __name__=='__main__':
    unittest.main()
