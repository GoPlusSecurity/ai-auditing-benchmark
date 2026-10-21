#!/usr/bin/env python3
"""Offline validation of the fixed X=123,Y=5 batch. No contract code is executed."""
from __future__ import annotations
import argparse
import csv
import datetime as dt
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from decimal import Decimal
import validate_20261002_batch as shared

ROOT=Path(__file__).resolve().parents[3]
BATCH=ROOT/'dataset_artifacts/batches/20261016_x123_y5'
HASH='d62e6e56755ab3c678bb9645eb0e0fa3a5aae6bf378f0b582a49814cab480c30'
require=shared.require
load=shared.load_json
sha=shared.sha256

def check_prefix(data, entry):
    size=entry['baseline_bytes']
    require(hashlib.sha256(data[:size]).hexdigest()==entry['baseline_sha256'],'existing CSV bytes changed')
    return data[size:]

def check_move(root, entry):
    old=root/entry['source']; new=root/entry['destination']
    require(entry['source'].startswith('dataset/') and entry['destination'].startswith('dataset_artifacts/'),'wrong ABI tree')
    require(new.resolve().is_relative_to(root.resolve()),'ABI destination escaped repository')
    require(not old.exists() and new.is_file(),'ABI not moved exactly')
    require(sha(new)==entry['sha256'] and new.stat().st_size==entry['bytes'],'ABI bytes changed')

def nested_records(payload):
    if isinstance(payload,dict):
        if isinstance(payload.get('path'),str) and isinstance(payload.get('sha256'),str): yield payload
        for value in payload.values(): yield from nested_records(value)
    elif isinstance(payload,list):
        for item in payload: yield from nested_records(item)

def validate():
    results=load(BATCH/'results.json'); snapshot=load(BATCH/'snapshot.json')
    raw=BATCH/results['parameters']['raw_export']
    require(sha(raw)==HASH==snapshot['raw_export_sha256']==results['parameters']['raw_export_sha256'],'snapshot hash differs')
    rows=shared.read_csv(raw); shared.validate_sheet_structure(rows)
    require(len(rows)==snapshot['parsed_record_count'],'snapshot record count differs')
    require('\ufffd' not in raw.read_text('utf-8-sig'),'replacement characters in raw export')
    x=results['parameters']['x']; y=results['parameters']['y']
    processed,selected=shared.select_qualifying_rows(rows,x,y,results['rows'])
    require(processed==results['parameters']['processing_order']==snapshot['parameters']['processing_order'],'processing order differs')
    require([min(processed),max(processed)]==results['parameters']['actual_scan_range']==snapshot['parameters']['actual_scan_range'],'scan range differs')
    require(len(selected)==y and [item['row'] for item in selected]==snapshot['parameters']['selected_source_rows'],'selected source rows differ')
    require(len(results['rows'])==len(processed),'results contain rows after the stop boundary')
    for item in snapshot['rows']:
        require(item['cells']==rows[item['row']-1],'snapshot cell differs')
        require(item['fields']==dict(zip(rows[1],rows[item['row']-1])),'snapshot field differs')
    require([a['row'] for a in snapshot['rows']]==processed,'snapshot row inventory differs')
    ids=[item['case_id'] for item in selected]
    require(len(set(ids))==y,'duplicate selected case id')
    require(ids==[item['case_id'] for item in results['included_cases']],'included case inventory differs')
    counts=results['counts']
    require(counts['scanned_rows']==len(processed) and counts['qualifying_source_rows']==y and counts['skipped_rows']==len(processed)-y,'derived counts differ')
    require(counts['new_cases']==y and not counts['completed_existing_cases'] and not counts['duplicate_rows_merged'],'unexpected disposition')

    source_count=bundles=source_inputs=evidence_count=links=semantic_literals=0
    semantic_review=load(BATCH/'semantic_review.json')
    require(set(semantic_review['cases'])==set(ids),'semantic review case set differs from selected snapshot')
    metadata={}
    for decision in selected:
        cid=decision['case_id']; art=ROOT/'dataset_artifacts'/cid
        code=ROOT/'dataset'/cid
        meta=load(art/'case_metadata.json'); metadata[cid]=meta
        require(meta['case_id']==cid and meta['original_rows']==[decision['row']],'metadata row binding differs')
        require(meta['public_original_vulnerable_source'] and not meta['requires_decompilation_for_core_vulnerable_logic'],'source qualification not met')
        require(meta['event_date']==rows[decision['row']-1][5],'source-sheet date lost')
        provenance=load(art/'provenance.json'); original_paths=set()
        for bundle in provenance['bundles']:
            bundles+=1
            response_path=(art/bundle['response_path']).resolve(); response=load(response_path)
            require(sha(response_path)==bundle['response_sha256'],'source response hash differs')
            if bundle['provider']=='Sourcify':
                require(response['address'].lower()==bundle['address'].lower(),'source address differs')
                require(response['runtimeMatch'] in ('match','exact_match'),'original source not matched')
                originals={name:value['content'] for name,value in response['sources'].items()}
            else:
                require(response['is_verified'],'explorer source unverified')
                originals={response['file_path']:response['source_code'],**{r['file_path']:r['source_code'] for r in response['additional_sources']}}
            require(set(originals)=={r['original_source_path'] for r in bundle['source_files']},'original source inventory differs')
            for record in bundle['source_files']:
                path=(art/record['path']).resolve(); original_paths.add(path)
                require(path.is_relative_to(code.resolve()),'source path escaped case')
                data=path.read_bytes()
                require(data==originals[record['original_source_path']].encode('utf-8'),'original source bytes changed')
                require(sha(path)==record['sha256'] and len(data)==record['bytes'],'source digest/size differs')
                source_count+=1
            standard=response_path.parent/'standard-input.json'
            if standard.exists():
                payload=load(standard)
                if isinstance(payload,str): payload=json.loads(payload)
                require(set(payload['sources'])==set(originals),'compiler input source inventory differs')
                for name,entry in payload['sources'].items():
                    require(entry['content']==originals[name],'compiler input source differs'); source_inputs+=1
            require((art/bundle['abi_path']).is_file(),'ABI missing from artifacts')
        for record in provenance['source_context']:
            path=(art/record['path']).resolve(); original_paths.add(path)
            require(path.is_relative_to(code.resolve()) and sha(path)==record['sha256'],'reference source hash differs')
        require({p.resolve() for p in code.rglob('*') if p.is_file()}==original_paths,'unrecorded complete source')
        for record in provenance['evidence']:
            path=(art/record['path']).resolve()
            require(path.is_relative_to(art.resolve()) and sha(path)==record['sha256'],'evidence hash differs')
            evidence_count+=1
        for requirement in semantic_review['cases'][cid]['required_source']:
            matches=[p for p in code.rglob('*') if p.is_file() and p.as_posix().endswith(requirement['source_suffix'])]
            require(matches,f'missing causal source file: {cid}: {requirement["source_suffix"]}')
            text='\n'.join(p.read_text('utf-8') for p in matches)
            for literal in requirement['literals']:
                require(literal in text,f'missing causal source element: {cid}: {literal}')
                semantic_literals+=1
        doc=ROOT/'docs/cases'/f'{cid}.md'; text=doc.read_text('utf-8')
        require(text.count('```')%2==0 and text.count('```mermaid')>=1,'unclosed document/Mermaid code block')
        require(all(term in text for term in ('正常','源码','未','交易')),'case document missing explanation')
        links+=shared.validate_local_links(doc)
        source_doc=art/'SOURCE.md'
        require('../../docs/cases/'+cid+'.md' in source_doc.read_text('utf-8'),'case source note does not link to its document')
        links+=shared.validate_local_links(source_doc)

    append=load(BATCH/'csv_append_manifest.json'); csv_checks=0
    for language,scale in [('cn',10000),('en',1000)]:
        entry=append[language]; data=(ROOT/entry['path']).read_bytes(); suffix=check_prefix(data,entry)
        require(entry['baseline_sha256']==load(BATCH/'baseline.json')['files'][entry['path']],'CSV baseline not bound')
        actual=list(csv.reader(io.StringIO(suffix.decode('utf-8'),newline='')))
        expected=[]
        for cid in sorted(ids):
            m=metadata[cid]; day=cid[:8]
            expected.append([day[:4]+'.'+day[4:6]+'.'+day[6:8],m['project_'+language],m['vulnerability_'+language],m['detail_'+language],'\n'.join(m['tx_urls']),'\n'.join(m['vulnerable_contract_urls']),'' if m['loss_usd'] is None else format(Decimal(m['loss_usd'])/scale,'f')])
        require(actual==expected==entry['appended_records'],'CSV new rows or order differ')
        parsed=shared.read_csv(ROOT/entry['path'])
        require(all(len(row)==7 for row in parsed),'CSV column count changed')
        require(len(parsed)-1==entry['baseline_event_count']+len(ids),'CSV count differs')
        for row in expected: require(sum(r[4]==row[4] for r in parsed[1:])==1,'duplicate focal transaction in CSV')
        csv_checks+=len(actual)

    baseline=load(BATCH/'baseline.json'); moves=load(BATCH/'abi_relocations.json')['files']
    for entry in moves:
        require(baseline['files'][entry['source']]==entry['sha256'],'ABI not bound to baseline'); check_move(ROOT,entry)
    checksum_updates=set(load(BATCH/'checksum_updates.json'))
    moved_case_ids={Path(m['source']).parts[1] for m in moves}
    for name in checksum_updates:
        parts=Path(name).parts
        require(parts[0]=='dataset_artifacts' and parts[-1]=='SHA256SUMS' and parts[1] in set(ids)|moved_case_ids,'checksum update outside allowed cases')
    allowed={'README.md','README_cn.md','docs/cases/README.md','docs/cases/20260619_mySwap.md','docs/cases/20260619_JB_decompiled.md','docs/cases/20260620_Namada.md','.gitignore','dataset_artifacts/20260619_mySwap/SOURCE.md','ai-auditing-benchmark_cn.csv','ai-auditing-benchmark_en.csv','docs/cases/sources/test_20261002_batch.py','docs/cases/sources/validate_20261002_batch.py',*checksum_updates}
    move_sources={m['source'] for m in moves}; changed=[]; unchanged=0; old_source_count=0
    for name,digest in baseline['files'].items():
        path=ROOT/name
        if name in move_sources: continue
        require(path.is_file(),f'baseline file disappeared: {name}')
        current=sha(path)
        if current!=digest:
            require(name in allowed,f'unrelated baseline bytes changed: {name}'); changed.append(name)
        else: unchanged+=1
        if name.startswith('dataset/'):
            require(current==digest,'pre-existing source bytes changed'); old_source_count+=1
    prior={Path(name).parts[1] for name in baseline['files'] if name.startswith('dataset/')}
    now={p.name for p in (ROOT/'dataset').iterdir() if p.is_dir()}
    require(now-prior==set(ids),'new source case directories differ from this snapshot')
    for record in load(BATCH/'screening_manifest.json')['files']:
        path=BATCH/record['path']; require(sha(path)==record['sha256'],'screening record changed')
    # The baseline was clean: every newly visible path must also stay in this task's scope.
    new_allowed={m['destination'] for m in moves}
    new_allowed.update('docs/cases/'+cid+'.md' for cid in ids)
    new_allowed.update({'docs/cases/sources/validate_20261016_batch.py','docs/cases/sources/test_20261016_batch.py'})
    new_prefixes=['dataset_artifacts/batches/20261016_x123_y5/']
    new_prefixes += [tree+'/'+cid+'/' for tree in ('dataset','dataset_artifacts') for cid in ids]
    status=subprocess.check_output(['git','status','--porcelain=v1','-z','--untracked-files=all'],cwd=ROOT).decode('utf-8')
    checked_new_paths=0
    for item in status.split('\0'):
        if not item: continue
        state,name=item[:2],item[3:]
        if state=='??':
            require(name in new_allowed or any(name.startswith(prefix) for prefix in new_prefixes),f'new file outside batch scope: {name}')
            checked_new_paths+=1
    proc=subprocess.run([sys.executable,'-X','utf8','-B',str(BATCH/'recompute_evidence.py')],capture_output=True,text=True,encoding='utf-8')
    require(proc.returncode==0,'offline arithmetic failed: '+proc.stderr)
    arithmetic=json.loads(proc.stdout); require(arithmetic['status']=='passed','offline arithmetic did not pass')
    transfer_check=subprocess.run([sys.executable,'-X','utf8','-B',str(BATCH/'verify_transfer_parameters.py')],capture_output=True,text=True,encoding='utf-8')
    require(transfer_check.returncode==0,'Verus transfer parameter reconciliation failed: '+transfer_check.stderr)
    arithmetic['verus_transfer_parameters']=json.loads(transfer_check.stdout)
    arithmetic['semantic_source_elements_checked']=semantic_literals
    # This existing whole-archive check includes historical source manifests and local links.
    layout=shared.validate_dataset_layout(ROOT)
    require(layout['dataset_files']==layout['source_files'],'dataset still contains non-source material')
    return {'status':'passed','validated_at':dt.datetime.now(dt.timezone(dt.timedelta(hours=8))).isoformat(),'parameters':{'x':x,'y':y},'actual_scan_range':[min(processed),max(processed)],'counts':counts,'case_ids':ids,'raw_export_sha256':HASH,'checks':{'snapshot_rows_compared':len(processed),'original_source_bundles':bundles,'original_source_files_compared_to_raw_responses':source_count,'standard_input_source_entries_compared':source_inputs,'evidence_hashes_checked':evidence_count,'bilingual_appended_records_checked':csv_checks,'abi_files_moved_without_byte_changes':len(moves),'pre_existing_source_files_unchanged':old_source_count,'unchanged_baseline_files':unchanged,'changed_baseline_files_within_allowlist':changed,'new_paths_checked_against_batch_scope':checked_new_paths,'case_local_links_checked':links,'offline_recalculation':arithmetic},'whole_archive_layout_checks':layout,'not_claimed':{'included_case_compilation':'not run','fork_replay':'not run','complete_pre_attack_state':'not reconstructed','full_internal_traces':'Drips, Verus and Lien only; Ostium calldata/receipt and CRC receipt independently checked','source_chain_notarizations':'not independently re-read from Verus RPC'},'screening_compilation_only':'42DAO upstream Spotter compiled with solc 0.5.12 and compared to current target excluding CBOR metadata; skipped case, not attack-time equality or included-case replay.'}

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--output',type=Path); args=parser.parse_args()
    # The final report links to itself through the index during whole-archive link checks.
    if args.output and not args.output.exists(): args.output.write_text('{"status":"in_progress"}\n',encoding='utf-8')
    report=validate(); rendered=json.dumps(report,ensure_ascii=False,indent=2)+'\n'
    if args.output: args.output.write_bytes(rendered.encode('utf-8'))
    print(rendered,end='')
