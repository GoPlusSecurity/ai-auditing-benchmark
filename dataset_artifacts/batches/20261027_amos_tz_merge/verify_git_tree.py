"""Verify raw index/commit blobs against delivery files, without Git text filters."""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
sys.path.insert(0,str(BASE))
from test_migration import AMOS, CASES, blob_id, tree

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)

def verify(ref):
    assert git('rev-parse','--show-object-format').strip()==b'sha1'
    assert not git('ls-files','-u'), 'Unresolved index stages'
    checkpoint=json.loads((BASE/'post-fetch-refs.json').read_text('utf-8'))['HEAD']
    if ref=='INDEX':
        blobs={}
        for row in git('ls-files','-sz').split(b'\0'):
            if not row:continue
            head,path=row.split(b'\t',1);mode,oid,stage=head.split()
            assert stage==b'0'
            blobs[path.decode()]=oid.decode()
        assert git('rev-parse','HEAD').decode().strip()==checkpoint
        assert git('rev-parse','MERGE_HEAD').decode().strip()==AMOS
        parents=[checkpoint,AMOS]
    else:
        blobs=tree(ref)
        info=git('rev-list','--parents','-n','1',ref).decode().split()
        parents=info[1:]
        assert parents==[checkpoint,AMOS],parents
        for ancestor in [checkpoint,AMOS,json.loads((BASE/'premerge-state.json').read_text('utf-8'))['tz_head']]:
            subprocess.run(['git','merge-base','--is-ancestor',ancestor,ref],cwd=ROOT,check=True)
    for path,oid in blobs.items():
        p=ROOT/path
        assert p.is_file(),('tracked file missing',path)
        assert blob_id(p.read_bytes())==oid,('Git filters or uncommitted bytes differ',path)
    expected={p.relative_to(ROOT).as_posix() for folder in ['dataset','dataset_artifacts','docs'] for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc'}
    assert not expected-set(blobs),('physical files omitted from Git',sorted(expected-set(blobs)))
    assert not git('ls-files','--others','--exclude-standard'), 'Untracked task files remain'
    assert all('benchmark_complete' not in Path(p).parts and 'benchmark_simplified' not in Path(p).parts for p in blobs if p.startswith(('dataset/','dataset_artifacts/')))
    counts={name:len({Path(p).parts[1] for p in blobs if p.startswith(name+'/') and Path(p).parts[1]!='batches'}) for name in ['dataset','dataset_artifacts']}
    assert counts=={'dataset':65,'dataset_artifacts':58}
    for path,oid in tree(AMOS).items():
        if path.startswith('dataset/') or (path.startswith('dataset_artifacts/') and not path.startswith('dataset_artifacts/batches/')):
            assert blobs.get(path)==oid,('amos case differs in actual Git tree',path)
    shared_changes={'README.md','README_cn.md','ai-auditing-benchmark_cn.csv','ai-auditing-benchmark_en.csv','docs/cases/README.md','docs/cases/sources/validate_20261002_batch.py','docs/cases/sources/test_20261002_batch.py','docs/cases/sources/validate_20261016_batch.py'}
    for path,oid in tree(AMOS).items():
        if path not in shared_changes:
            assert blobs.get(path)==oid,('unexpected change to amos shared content',path)
    manifest=json.loads((BASE/'migration-manifest.json').read_text('utf-8'))
    for rec in manifest['files']:
        if rec['new_path']:
            path=rec['new_path'];assert path in blobs,path
            assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==rec['new_sha256'],path
        else:
            assert rec['old_path'] not in blobs
    return {'status':'passed','reference':ref,'commit':None if ref=='INDEX' else git('rev-parse',ref).decode().strip(),'parents':parents,'raw_blobs_compared_to_worktree':len(blobs),'physical_delivery_files_present_in_git':len(expected),'case_counts':counts,'unmerged_paths':0,'untracked_paths':0,'new_sources_byte_exact':776,'verification_method':'raw Git blob object IDs computed from physical bytes; no autocrlf, clean/smudge or text normalization'}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--ref',default='INDEX');parser.add_argument('--output',type=Path);a=parser.parse_args()
    report=verify(a.ref);text=json.dumps(report,ensure_ascii=False,indent=2)+'\n'
    if a.output:a.output.write_bytes(text.encode())
    print(text,end='')
