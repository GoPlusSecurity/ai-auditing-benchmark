"""Exercise maintained offline builders in a disposable copy, never upstream code."""
from pathlib import Path
import hashlib, importlib.util, json, os, shutil, subprocess, sys, tempfile, unittest
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
sys.path.insert(0,str(BASE))
from test_migration import CASES
sys.path.insert(0,str(ROOT/'docs/cases/sources'))
import validate_20261002_batch as shared

class FlatToolTests(unittest.TestCase):
    def test_rebuilding_both_batches_keeps_all_csv_rows_and_exact_sources(self):
        cache=ROOT/".cache"
        cache.mkdir(exist_ok=True)
        temp=tempfile.TemporaryDirectory(prefix="m-",dir=cache)
        target=Path(temp.name).resolve()
        self.assertTrue(target.is_relative_to(cache.resolve()))
        if os.name=="nt":
            temp.name="\\\\?\\"+temp.name
            target=Path(temp.name)
        try:
            for name in ['20261021_x112_y5','20261026_x96_y5']:
                shutil.copytree(ROOT/'dataset_artifacts/batches'/name,target/'dataset_artifacts/batches'/name,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
            shutil.copytree(ROOT/'docs/cases/sources',target/'docs/cases/sources',ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
            for cid in CASES:
                for tree in ['dataset','dataset_artifacts']:
                    shutil.copytree(ROOT/tree/cid,target/tree/cid)
                shutil.copyfile(ROOT/'docs/cases'/f'{cid}.md',target/'docs/cases'/f'{cid}.md')
            shutil.copyfile(ROOT/'docs/cases/README.md',target/'docs/cases/README.md')
            for name in ['README.md','README_cn.md','ai-auditing-benchmark_cn.csv','ai-auditing-benchmark_en.csv']:
                shutil.copyfile(ROOT/name,target/name)
            csv_before={lang:(target/f'ai-auditing-benchmark_{lang}.csv').read_bytes() for lang in ['cn','en']}
            historical=['baseline.json','snapshot.json','results.json','validation.json','csv_append_manifest.json','retrieval_inventory.json']
            hashes={p.relative_to(target):hashlib.sha256(p.read_bytes()).hexdigest() for batch in ['20261021_x112_y5','20261026_x96_y5'] for name in historical for p in [target/'dataset_artifacts/batches'/batch/name] if p.is_file()}
            for batch in ['20261021_x112_y5','20261026_x96_y5']:
                for tool in ['build_batch.py','finalize_batch.py']:
                    run=subprocess.run([sys.executable,'-X','utf8','-B',str(target/'dataset_artifacts/batches'/batch/tool)],cwd=target,capture_output=True,text=True,encoding='utf-8')
                    self.assertEqual(run.returncode,0,(batch,tool,run.stdout,run.stderr))
            errors=[]
            # Rebuilding must leave both case and batch checksum inventories usable.
            for cid in CASES:
                shared.check_sums(target/'dataset_artifacts'/cid)
            for batch in ['20261021_x112_y5','20261026_x96_y5']:
                try:shared.check_sums(target/'dataset_artifacts/batches'/batch)
                except shared.ValidationError as error:errors.append(str(error))
            derived=target/'dataset_artifacts/batches/20261026_x96_y5/retrieval_inventory-current.json'
            first=derived.read_bytes()
            rerun=subprocess.run([sys.executable,'-X','utf8','-B',str(derived.parent/'finalize_batch.py')],cwd=target,capture_output=True,text=True,encoding='utf-8')
            self.assertEqual(rerun.returncode,0,rerun.stderr)
            second=derived.read_bytes()
            if first!=second:errors.append('Repeated finalizer changed its retrieval inventory')
            parsed=json.loads(second)
            if any(x['path']=='retrieval_inventory-current.json' for x in parsed['raw_log_files']):errors.append('Derived inventory treated as a raw acquisition log')
            if any('download_completion_file_time_utc' in x for x in parsed['records']):errors.append('Current filesystem mtime labelled as acquisition time')
            self.assertEqual(errors,[])
            for lang,content in csv_before.items():
                self.assertEqual((target/f'ai-auditing-benchmark_{lang}.csv').read_bytes(),content)
            for rel,digest in hashes.items():
                self.assertEqual(hashlib.sha256((target/rel).read_bytes()).hexdigest(),digest,str(rel))
            for tree in ['dataset','dataset_artifacts']:
                self.assertFalse((target/tree/'benchmark_complete').exists())
                self.assertFalse((target/tree/'benchmark_simplified').exists())
            for cid in CASES:
                old={p.relative_to(ROOT/'dataset'/cid):p.read_bytes() for p in (ROOT/'dataset'/cid).rglob('*') if p.is_file()}
                new={p.relative_to(target/'dataset'/cid):p.read_bytes() for p in (target/'dataset'/cid).rglob('*') if p.is_file()}
                self.assertEqual(new,old,cid)
                meta=json.loads((target/'dataset_artifacts'/cid/'case_metadata.json').read_text('utf-8'))
                self.assertNotIn('view',meta)
                for key in ['source_sheet_snapshot','batch_results','case_document','source_provenance']:
                    self.assertTrue((target/'dataset_artifacts'/cid/meta[key]).resolve().is_file(),(cid,key))
            meta=json.loads((target/'dataset_artifacts/20260820_Allbridge_CCTP/case_metadata.json').read_text('utf-8'))
            self.assertEqual(len([a for a in meta['batch_appearances'] if a['batch']=='20261026_x96_y5']),1)
        finally:
            clean=Path(str(target).removeprefix("\\\\?\\")).resolve()
            self.assertTrue(clean.is_relative_to(cache.resolve()))
            temp.cleanup()

if __name__=='__main__':unittest.main()
