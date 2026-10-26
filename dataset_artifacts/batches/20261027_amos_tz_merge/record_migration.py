"""Record and verify this fixed migration against the byte-exact premerge backup."""
from pathlib import Path
import collections, csv, hashlib, io, json, os, subprocess, sys, zipfile
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
sys.path.insert(0,str(ROOT/'docs/cases/sources'))
from archive_maintenance import refresh_batch_inventory
from test_migration import AMOS, CASES, blob_id, tree

def sha(data):return hashlib.sha256(data).hexdigest()
def dump(name,data):
    (BASE/name).write_bytes((json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode())

def main():
    originals=json.loads((BASE/'premerge-inventory.json').read_text('utf-8'))
    state=json.loads((BASE/'premerge-state.json').read_text('utf-8'))
    assert sha((BASE/'premerge-backup.zip').read_bytes())==state['backup_sha256']
    rows=[];counts=collections.Counter();removed=[]
    batch_updates={
      '20261021_x112_y5':{'build_batch.py','finalize_batch.py','README.md'},
      '20261026_x96_y5':{'build_batch.py','finalize_batch.py','validate_batch.py','README.md','file_inventory.json','SHA256SUMS','term/validate_final.py','fh/build_case.py','fh/finish_case.py','sandbox/draft.md','term/draft.md','fh/draft.md','moonwell/draft.md'},
    }
    with zipfile.ZipFile(BASE/'premerge-backup.zip') as backup:
        assert backup.testzip() is None
        for rec in originals:
            old=rec['old_path']
            if 'sha256' not in rec:continue
            assert sha(backup.read(old))==rec['sha256'],old
            new=old.replace('dataset/benchmark_complete/','dataset/',1).replace('dataset_artifacts/benchmark_complete/','dataset_artifacts/',1)
            if '/benchmark_simplified/' in old:
                assert not (ROOT/old).exists(),old
                action='removed_simplified_archived_in_zip';new=None;current=None
                removed.append(old)
            else:
                target=ROOT/new;assert target.is_file(),new
                current=sha(target.read_bytes())
                if current==rec['sha256']:
                    action='moved_byte_exact' if new!=old else 'preserved_byte_exact'
                else:
                    allowed=False
                    if old.startswith('dataset_artifacts/benchmark_complete/'):
                        allowed=Path(old).name in {'case_metadata.json','provenance.json','SOURCE.md','SHA256SUMS'}
                        action='current_paths_metadata_or_checksums_updated'
                    elif old.startswith('dataset_artifacts/batches/'):
                        parts=Path(old).parts;allowed='/'.join(parts[3:]) in batch_updates.get(parts[2],set())
                        action='current_batch_tool_doc_or_inventory_updated'
                    elif old.startswith('docs/cases/'):
                        allowed=old=='docs/cases/README.md' or old in {f'docs/cases/{c}.md' for c in CASES} or old in {'docs/cases/sources/validate_20261021_batch.py','docs/cases/sources/test_20261021_batch.py'}
                        action='current_doc_or_validator_updated'
                    else:
                        allowed=old in {'.gitignore','README.md','README_cn.md','ai-auditing-benchmark_cn.csv','ai-auditing-benchmark_en.csv'}
                        action='amos_base_with_required_new_entries'
                    assert allowed,('unexpected modification of original material',old)
                if old.startswith('dataset/benchmark_complete/'):
                    assert current==rec['sha256'],('source changed',old)
            counts[action]+=1
            rows.append({'old_path':old,'new_path':new,'old_bytes':rec['bytes'],'old_sha256':rec['sha256'],'new_sha256':current,'action':action,'backup_member':old})
    sources=[x for x in rows if x['old_path'].startswith('dataset/benchmark_complete/')]
    assert len(sources)==776 and len(removed)==252
    old_files=[]
    for path,oid in tree(AMOS).items():
        if path.startswith('dataset/') or (path.startswith('dataset_artifacts/') and not path.startswith('dataset_artifacts/batches/')):
            assert blob_id((ROOT/path).read_bytes())==oid,path
            old_files.append({'path':path,'git_blob':oid})
    old_counts={name:len({Path(x['path']).parts[1] for x in old_files if x['path'].startswith(name+'/')}) for name in ['dataset','dataset_artifacts']}
    assert old_counts=={'dataset':56,'dataset_artifacts':49}
    csv_info={}
    for lang in ['cn','en']:
        name=f'ai-auditing-benchmark_{lang}.csv';old=subprocess.check_output(['git','show',AMOS+':'+name],cwd=ROOT);new=(ROOT/name).read_bytes()
        assert new.startswith(old)
        parsed=list(csv.reader(io.StringIO(new.decode('utf-8-sig'),newline='')))
        appended=list(csv.reader(io.StringIO(new[len(old):].decode('utf-8'),newline='')))
        assert len(parsed)==67 and len(appended)==9
        csv_info[lang]={'path':name,'amos_prefix_bytes':len(old),'amos_prefix_sha256':sha(old),'current_sha256':sha(new),'event_count':66,'appended_records':appended}
    dump('migration-manifest.json',{'amos':AMOS,'checkpoint':json.loads((BASE/'post-fetch-refs.json').read_text())['HEAD'],'backup_sha256':state['backup_sha256'],'actions':dict(counts),'files':rows})
    dump('old-amos-cases.json',{'commit':AMOS,'case_counts':old_counts,'files':old_files})
    dump('csv-merge-manifest.json',csv_info)
    report={'status':'passed','original_files_accounted_for':len(rows),'new_source_files_byte_identical':len(sources),'removed_simplified_files':len(removed),'removed_simplified_source_files':sum(p.startswith('dataset/') for p in removed),'removed_simplified_artifact_files':sum(p.startswith('dataset_artifacts/') for p in removed),'old_amos_case_counts':old_counts,'old_amos_files_byte_identical':len(old_files),'csv_events_each':66,'allbridge_supplement_sha256':sha((ROOT/'dataset_artifacts/batches/20261026_x96_y5/allbridge_requalification.json').read_bytes()),'actions':dict(counts)}
    dump('preservation-verification.json',report)
    for name in ['20261021_x112_y5','20261026_x96_y5','20261027_amos_tz_merge']:
        refresh_batch_inventory(ROOT/'dataset_artifacts/batches'/name)
    print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
