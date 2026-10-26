"""Offline verification of the fixed X=112,Y=5 research batch; no EVM execution."""
from __future__ import annotations
import argparse
from collections import Counter
import csv
import datetime as dt
from decimal import Decimal
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import validate_20261002_batch as shared
from archive_maintenance import validate_csv_records

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'dataset_artifacts/batches/20261021_x112_y5'
require=shared.require
load=shared.load_json
sha=shared.sha256

def validate():
    result=load(BASE/'results.json');snapshot=load(BASE/'snapshot.json');cases=load(BASE/'cases.json')
    parameters=result['parameters'];raw=BASE/parameters['raw_export']
    require(sha(raw)==parameters['raw_export_sha256']==snapshot['raw_export_sha256'],'raw export hash differs')
    rows=shared.read_csv(raw);shared.validate_sheet_structure(rows)
    require(len(rows)==snapshot['parsed_record_count'],'parsed record count differs')
    processed,selected=shared.select_qualifying_rows(rows,parameters['x'],parameters['y'],result['rows'])
    require(processed==parameters['processing_order']==snapshot['parameters']['processing_order'],'processing order differs')
    require(len(processed)==len(result['rows'])==len(snapshot['rows']),'row dispositions exceed or miss scan boundary')
    require([min(processed),max(processed)]==parameters['actual_scan_range'],'scan range differs')
    for original in snapshot['rows']:
        require(original['cells']==rows[original['row']-1] and original['fields']==dict(zip(rows[1],rows[original['row']-1])),'snapshot cells or fields differ')
    ids=[s['case_id'] for s in selected]
    require(ids==[c['case_id'] for c in cases]==[c['case_id'] for c in result['included_cases']],'included case inventory differs')
    require(result['counts']['qualifying_source_rows']==parameters['y']==len(selected),'qualified count differs')
    require(result['counts']['skipped_rows']==len(processed)-len(selected),'skip count differs')
    sources=slices=bundles=evidence=links=literal_count=0
    metadata={}
    for case in cases:
        cid=case['case_id'];art=ROOT/'dataset_artifacts'/cid
        code=ROOT/'dataset'/cid
        meta=load(art/'case_metadata.json');metadata[cid]=meta
        require(meta['public_original_vulnerable_source'] and not meta['requires_decompilation_for_core_vulnerable_logic'],'original vulnerable source gate not met')
        require(meta['event_date']==rows[case['row']-1][5] and cid[:8]==meta['event_date'].replace('-',''),'date differs from source snapshot')
        require(meta['original_rows']==[case['row']],'source row binding differs')
        prov=load(art/'provenance.json');original_paths=set()
        for bundle in prov['bundles']:
            bundles+=1;response_path=(art/bundle['response_path']).resolve();response=load(response_path)
            require(sha(response_path)==bundle['response_sha256'],'provider response hash differs')
            require(response['runtimeMatch'] in ('match','exact_match'),'source not matched')
            require(response['address'].lower()==bundle['address'].lower(),'source deployment address differs')
            expected=response['sources'];require(set(expected)=={r['original_source_path'] for r in bundle['source_files']},'source inventory differs')
            for record in bundle['source_files']:
                target=(art/record['path']).resolve();original_paths.add(target)
                require(target.is_relative_to(code.resolve()),'complete source escapes case')
                require(target.read_bytes()==expected[record['original_source_path']]['content'].encode('utf-8'),'original source bytes differ')
                require(sha(target)==record['sha256'] and target.stat().st_size==record['bytes'],'source size/hash differs');sources+=1
            standard=load(response_path.parent/'standard-input.json')
            require(standard==response['stdJsonInput'],'compiler input differs from raw response')
            for name,payload in standard['sources'].items():
                require(name in expected and payload['content']==expected[name]['content'],'standard-input source differs')
            require((art/bundle['abi_path']).is_file(),'ABI missing from artifacts')
        require(original_paths=={p.resolve() for p in code.rglob('*') if p.is_file()},'unrecorded complete source files')
        for record in prov['evidence']:
            target=(art/record['path']).resolve();require(target.is_relative_to(art.resolve()) and sha(target)==record['sha256'],'evidence hash/path differs');evidence+=1
        joined='\n'.join(p.read_text('utf-8') for p in original_paths)
        for literal in case['core_requirements']:
            require(literal in joined,'missing causal source: '+cid+': '+literal);literal_count+=1
        document=ROOT/'docs/cases'/f'{cid}.md';text=document.read_text('utf-8')
        require(text.count('```')%2==0 and '```mermaid\n' in text,'unclosed code block or missing Mermaid')
        require(all(t in text for t in ['背景','正常','错误','条件','步骤','资金','限制']),'case document missing required explanation')
        links+=shared.validate_local_links(document)
        for a in (art,):
            require(f'../../docs/cases/{cid}.md' in (a/'SOURCE.md').read_text('utf-8'),'source views do not link to common doc')
            links+=shared.validate_local_links(a/'SOURCE.md');shared.check_sums(a)
    validate_csv_records(ROOT,ids)
    for record in load(BASE/'screening_manifest.json')['files']:
        require(sha(BASE/record['path'])==record['sha256'],'screening archive changed')
    comparison=load(BASE/'pool_runtime_comparison.json');reference=comparison['reference']
    require(sha(BASE/reference['response_path'])==reference['response_sha256'],'pool reference response hash differs')
    reference_code=bytes.fromhex(load(BASE/reference['response_path'])['runtimeBytecode']['onchainBytecode'][2:])
    require(len(reference_code)==reference['runtime_bytes']==14981 and hashlib.sha256(reference_code).hexdigest()==reference['runtime_sha256'],'pool reference runtime differs')
    require(len(comparison['targets'])==5 and Counter(t['case_label'] for t in comparison['targets'])=={'moke':2,'nex':2,'fox':1},'actual pool inventory differs')
    retrievals=load(BASE/'retrieval_inventory.json')
    for target in comparison['targets']:
        path=BASE/target['response_path'];require(sha(path)==target['response_sha256'],'actual pool response hash differs')
        actual_code=bytes.fromhex(load(path)['result'][2:])
        require(actual_code==reference_code and target['byte_equal_to_reference'],'actual pool runtime not byte equal')
        require(len(actual_code)==target['runtime_bytes'] and hashlib.sha256(actual_code).hexdigest()==target['runtime_sha256'],'actual pool runtime digest differs')
        require(target['block_selector']=='latest','pool comparison must preserve current-only boundary')
        require(any(r.get('path')==target['response_path'] and r.get('sha256')==target['response_sha256'] and r.get('payload',{}).get('method')=='eth_getCode' and r['payload']['params']==[target['address'],'latest'] for r in retrievals),'pool response lacks read-only address/block request binding')
    decoded=load(BASE/'decoded_evidence.json')['cases']
    require(decoded['usm']['function_counts']['fund']==1 and decoded['usm']['function_counts']['defund']==64,'USM historical call counts differ')
    require(decoded['usm']['outgoing_eth_wei']-decoded['usm']['incoming_eth_wei']==70830977367697708372,'USM net outflow differs')
    m=decoded['moke']['decoded_events'];syncs=[e for e in m if e['event']=='UserLPSynced'];claims=[e for e in m if e['event']=='DividendClaimed']
    require(len(syncs)==len(claims)==65 and all(e['values']['newLP']==0 for e in syncs),'MOKE stale-record zero ownership evidence differs')
    require(Counter(e['values']['oldLP'] for e in syncs)=={1334183807563777105758:64,985789028950366818528:1},'MOKE 64 full and one partial stale position differ')
    require(sum(e['values']['amount'] for e in claims)==1664616180024096093973,'MOKE payout total differs')
    nex=[e for e in decoded['nex']['decoded_events'] if e['event']=='Sync' and e['address']=='0x974c0078740480ae830d379fdb8d5f441c9ddc75']
    require(any(e['values']['reserve0']==1 for e in nex),'NEX reserve collapse missing')
    d=decoded['allbridge']['deltas']['0x833589fcd6edb6e08f4c7c32d4f71b54bda02913']
    require(Decimal(d['0xaa119f7442ecc28b9a8f236707ada8362cff24ff'])+Decimal(d['0xb6fbdfa5f3cbeb139d4cce86d92f4ac8687b16c0'])+Decimal(d['0x4e65fe4dba92790696d040ac24aa414708f5c0ab'])==0,'Allbridge net outflow/fee/profit do not reconcile')
    layout=shared.validate_dataset_layout(ROOT)
    require(layout['dataset_files']==layout['source_files'],'dataset contains non-source')
    return {'status':'passed','validated_at':dt.datetime.now(dt.timezone(dt.timedelta(hours=8))).isoformat(),'parameters':{'x':parameters['x'],'y':parameters['y']},'actual_scan_range':parameters['actual_scan_range'],'counts':result['counts'],'case_ids':ids,'raw_export_sha256':sha(raw),'checks':{'source_bundles':bundles,'original_source_files_compared':sources,'evidence_hashes':evidence,'semantic_source_literals':literal_count,'case_links':links,'csv_events_each':len(shared.read_csv(ROOT/'ai-auditing-benchmark_cn.csv'))-1,'independent_raw_receipt_or_trace_decoding':'passed','current_pool_runtime_byte_comparisons':len(comparison['targets']),'local_decompilation':'prohibited_not_run'},'whole_archive_layout':layout,'not_claimed':{'local_compilation':'not_run','fork_replay':'not_run','complete_pre_attack_state':'not_reconstructed','fox_historical_proxy_slots':'RPC missing trie node','complete_internal_traces':'USM only; remaining four cases receipts and public analysis'}}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path);args=parser.parse_args()
    if args.output: require(args.output.resolve()!=(BASE/'validation.json').resolve(),'historical validation.json is immutable')
    if args.output and not args.output.exists():args.output.write_text('{"status":"in_progress"}\n',encoding='utf-8')
    report=validate();rendered=json.dumps(report,ensure_ascii=False,indent=2)+'\n'
    if args.output:args.output.write_bytes(rendered.encode('utf-8'))
    print(rendered,end='')
