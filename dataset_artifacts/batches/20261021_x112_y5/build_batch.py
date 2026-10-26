"""Materialize the fixed, source-qualified research batch. Does not run contracts."""
from __future__ import annotations
import csv
import datetime as dt
from decimal import Decimal
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import sys

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
sys.path.insert(0, str(ROOT/'docs/cases/sources'))
import validate_20261002_batch as shared

SHEET = 'https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0#gid=0'
EXPORT = 'https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/export?format=csv&gid=0'
SKIPS = {
112:('授权钓鱼','用户通过 multicall 签署恶意授权；没有确认的受害合约代码缺陷。'),
111:('Triple-A','多链热钱包失窃及凭据事件；未确立合约代码缺陷和漏洞原始源码。'),
110:('Solido Cash','官方复盘承认预言机误绑定，但根因仍待源码确认；审计报告指向的 cdp-contracts 仓库及固定提交均返回 404，公开组织仓库不含该模块，未取得相关漏洞原始源码。'),
109:('ChainConnect','公开记录归类为私钥泄漏；未确立合约代码漏洞。'),
108:('Garden Finance','项目澄清指向独立 solver 的链外数据库；已取得 HTLC 原始源码与正常 redeem 调用记录，未确立 HTLC 代码缺陷。'),
107:('Wemix','铸币管理员凭据失窃，管理员路径不等于合约权限绕过。'),
106:('PRO','已取得代币和标准池源码，但缺失关键 exec 实现 0x7fba63d0c45f265c1bea3ed2e49f0691a9d9aa87 的公开漏洞原始源码；报道中的重建伪代码不能满足原始源码门槛。'),
105:('LULA','核心 token 有原始源码，但必要 Rental 合约未开源；BscScan 官网在线反编译点击后未返回可归档代码，按用户追加规则跳过。未运行本地反编译。'),
104:('Coldcard','钱包密码算法或设备事件，不属于本批合约代码漏洞。'),
103:('Swan Treasury','官网显示 ZhaiquanBuy 已验证源码，披露交易使用配置的受信签名签发 discount=1 的订单。签名来源未核实，现有材料未确立签名绕过或不依赖签名系统失守的合约缺陷，不将缺少业务折扣下限单独认定为已证实代码漏洞。'),
102:('Base 非验证 CALL 合约','已取得原始创建交易与回执，并从输入定位 0xa31722ca2a32695280d0e7e325b3dd6d699fc170；Sourcify 返回 404，未取得关键低层 CALL 逻辑的公开原始源码。'),
99:('Nereus','源表描述使用 ProxyAdmin 所有者权限恶意升级提款；未确立被绕过的代码权限检查。'),
97:('Coinsbuy','热钱包失窃；没有确认的合约代码缺陷及相应漏洞原始源码。'),
96:('ODY','增发跑路事件；没有确认的合约代码漏洞。'),
95:('Coreum Bridge','核查材料定位 XRPL 链外 relayer 的入账解析/目的地检查，不是智能合约代码缺陷。'),
94:('地址投毒','钱包地址投毒，不是合约代码漏洞。'),
93:('Harmony','跨分片回执/节点协议验证漏洞，涉及链节点协议，不是本批智能合约代码漏洞。'),
92:('TLBL','公开记录归类为私钥失窃；未确立合约代码缺陷。'),
91:('Arbitrum 钱包钓鱼','钱包钓鱼授权，不是合约代码漏洞。'),
89:('Maya Protocol','Trade Account 与盗窃补贴检查位于链协议节点模块，不属于本批智能合约源码案例。'),
}

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def load(path): return json.loads(path.read_text('utf-8'))
def dump(path, value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
def relative(path, base): return Path(os.path.relpath(path,base)).as_posix()

def checksum(case_id, view):
    art=ROOT/'dataset_artifacts'/view/case_id
    code=ROOT/'dataset'/view/case_id
    entries=[p for tree in (art,code) for p in tree.rglob('*') if p.is_file() and p.name!='SHA256SUMS']
    (art/'SHA256SUMS').write_text(''.join(sha(p)+'  '+relative(p,art)+'\n' for p in sorted(entries,key=lambda p:relative(p,art))),encoding='utf-8')

def main():
    cases=load(BASE/'cases.json'); raw=BASE/'sheet_gid0_raw.csv'
    rows=shared.read_csv(raw); shared.validate_sheet_structure(rows)
    baseline=load(BASE/'baseline.json')
    decisions=[]; by_row={c['row']:c for c in cases}
    for row in range(112,min(by_row)-1,-1):
        original=dict(zip(rows[1],rows[row-1])); case=by_row.get(row)
        item={'row':row,'sheet_event':original['target (社媒 or Addr)'],'qualifies':bool(case),'status':'new' if case else 'skipped','case_id':case['case_id'] if case else None,'references':[original['original_link'].strip()]}
        if case:
            assert case['case_id'][:8]==original['date'].replace('-','')
            matches=[]
            for bundle in case['bundles']:
                response=load(BASE/'screening'/f'{bundle}-source.json')
                assert response['runtimeMatch'] in ('match','exact_match')
                if bundle not in case['context_bundles']: matches.append(bundle+': '+response['runtimeMatch'])
            item.update(event=case['project_cn'],source_qualification='public_original_vulnerable_source: '+ '; '.join(matches),reason='已取得含核心缺陷的公开原始源码；相关历史绑定和状态限制另列，关键逻辑不依赖未取得的反编译。')
        else:
            event,reason=SKIPS[row];item.update(event=event,source_qualification='not_qualified_this_batch',reason=reason)
        decisions.append(item)
    processed,selected=shared.select_qualifying_rows(rows,112,5,decisions)
    assert len(decisions)==len(processed)
    assert [s['case_id'] for s in selected]==[c['case_id'] for c in cases]
    # This guard runs before any formal source or CSV mutation.
    for case in cases:
        for language in ('cn','en'):
            content=(ROOT/f'ai-auditing-benchmark_{language}.csv').read_text('utf-8')
            if case['tx_hash'] in content:
                own=load(BASE/'csv_append_manifest.json') if (BASE/'csv_append_manifest.json').exists() else {}
                assert any(case['tx_hash'] in row[4] for row in own.get(language,{}).get('appended_records',[])), 'existing focal transaction requires surgical reuse review'
    retrieved=dt.datetime.fromtimestamp(raw.stat().st_mtime,dt.timezone(dt.timedelta(hours=8))).isoformat()
    parameters={'x':112,'y':5,'actual_scan_range':[min(processed),max(processed)],'processing_order':processed,'selected_source_rows':[s['row'] for s in selected],'raw_export':raw.name,'raw_export_sha256':sha(raw),'timezone':'Asia/Shanghai','retrieved_at':retrieved,'source_url':SHEET,'export_url':EXPORT}
    snapshot={'parameters':parameters,'raw_export_sha256':sha(raw),'parsed_record_count':len(rows),'header':rows[1],'structure':{'row_1':'explanation','row_2':'header','first_event_row':3},'rows':[{'row':r,'cells':rows[r-1],'fields':dict(zip(rows[1],rows[r-1]))} for r in processed]}
    counts={'scanned_rows':len(processed),'qualifying_source_rows':len(selected),'new_cases':len(set(s['case_id'] for s in selected)),'completed_existing_cases':0,'reused_existing_cases':0,'duplicate_rows_merged':0,'skipped_rows':len(processed)-len(selected)}
    dump(BASE/'snapshot.json',snapshot)
    dump(BASE/'results.json',{'parameters':parameters,'counts':counts,'rows':decisions,'included_cases':[{'case_id':c['case_id'],'source_rows':[c['row']]} for c in cases],'decompilation_policy':{'local':'prohibited and not run','online':'official or authoritative sites only','missing_required_online_output':'skip entire case'},'formal_write_gate':'five source-qualified rows reached before dataset/CSV writes'})
    source_count=slice_count=0
    for case in cases:
        cid=case['case_id']; full=ROOT/'dataset/benchmark_complete'/cid; art=ROOT/'dataset_artifacts/benchmark_complete'/cid
        small=ROOT/'dataset/benchmark_simplified'/cid; sa=ROOT/'dataset_artifacts/benchmark_simplified'/cid
        art.mkdir(parents=True,exist_ok=True);sa.mkdir(parents=True,exist_ok=True)
        bundles=[]; source_lookup={}
        for bundle in case['bundles']:
            original=BASE/'screening'/f'{bundle}-source.json'; response=load(original)
            ba=art/'source-bundles'/bundle;ba.mkdir(parents=True,exist_ok=True)
            response_path=ba/'source-response.json';shutil.copyfile(original,response_path)
            records=[]
            for name,payload in response['sources'].items():
                target=full/'source-bundles'/bundle/name
                assert target.resolve().is_relative_to(full.resolve()) and target.suffix=='.sol'
                target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(payload['content'].encode('utf-8'))
                record={'path':relative(target,art),'original_source_path':name,'sha256':sha(target),'bytes':target.stat().st_size}
                records.append(record);source_lookup[bundle+':'+name]=target;source_count+=1
            dump(ba/'abi.json',response['abi']);dump(ba/'standard-input.json',response['stdJsonInput']);dump(ba/'compiler-settings.json',response['compilation'])
            bundles.append({'id':bundle,'kind':'public_original_source','role':'normal_protocol_reference_context' if bundle in case['context_bundles'] else 'vulnerable_or_required_source','provider':'Sourcify','url':f"https://sourcify.dev/server/v2/contract/{response['chainId']}/{response['address']}?fields=all",'address':response['address'],'chain_id':response['chainId'],'verified_at':response['verifiedAt'],'creation_match':response['creationMatch'],'runtime_match':response['runtimeMatch'],'deployment':response['deployment'],'compiler':response['compilation'],'response_path':relative(response_path,art),'response_sha256':sha(response_path),'abi_path':relative(ba/'abi.json',art),'source_files':records})
        evidence=[]
        for name in case['evidence']:
            original=BASE/'screening'/name
            assert original.is_file(), 'missing requested evidence: '+name
            destination=art/'evidence'/name;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(original,destination)
            evidence.append({'path':relative(destination,art),'sha256':sha(destination),'bytes':destination.stat().st_size})
        prior_slices=load(sa/'slice_manifest.json')['slices'] if (sa/'slice_manifest.json').exists() else []
        slices=[]
        for spec,ranges in case['slices'].items():
            source=source_lookup[spec];lines=source.read_bytes().splitlines(keepends=True)
            if ranges=='all':ranges=[[1,len(lines)]]
            bundle,name=spec.split(':',1)
            for start,end in ranges:
                assert 1<=start<=end<=len(lines),(cid,spec,start,end,len(lines))
                target=small/'slices'/bundle/Path(name).parent/(f'{Path(name).stem}_L{start}_L{end}.sol')
                target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(b''.join(lines[start-1:end]))
                slices.append({'path':relative(target,sa),'complete_path':relative(source,sa),'original_start_line':start,'original_end_line':end,'sha256':sha(target),'complete_source_sha256':sha(source),'kind':'original_source_verbatim_slice'});slice_count+=1
        current_paths={s['path'] for s in slices}
        for old in prior_slices:
            if old['path'] not in current_paths:
                target=(sa/old['path']).resolve()
                assert target.is_relative_to(small.resolve()) and sha(target)==old['sha256']
                target.unlink()
        joined='\n'.join((sa/s['path']).resolve().read_text('utf-8') for s in slices)
        for literal in case['core_requirements']: assert literal in joined,(cid,'missing causal source',literal)
        dump(sa/'slice_manifest.json',{'case_id':cid,'path_base':'simplified_case_root','no_logic_rewritten':True,'standalone_compilation':'not_claimed; verbatim source excerpts can omit wrappers and unrelated declarations','slices':slices})
        dump(art/'provenance.json',{'kind':'public_original_source','path_base':'complete_case_root','bundles':bundles,'evidence':evidence,'context_limits':'PancakePair reference is the verified original source from the separately identified PRO pool, not a claim of bytecode identity at every incident pool. Circle current proxy implementation is context; its historical slot was not independently reconstructed.'})
        explorer='etherscan.io' if case['chain_id']=='1' else ('basescan.org' if case['chain_id']=='8453' else 'bscscan.com')
        base_meta={k:case[k] for k in ['case_id','project_cn','project_en','vulnerability_cn','vulnerability_en','detail_cn','detail_en','loss_usd','loss_scope']}
        base_meta.update(event_date=rows[case['row']-1][5],original_rows=[case['row']],tx_urls=[f"https://{explorer}/tx/{case['tx_hash']}"],vulnerable_contract_urls=[f'https://{explorer}/address/{a}#code' for a in case['victims']],public_original_vulnerable_source=True,requires_decompilation_for_core_vulnerable_logic=False,attack_time_deployment_source_equivalence_verified=False,source_sheet_snapshot='../../batches/20261021_x112_y5/snapshot.json',batch_results='../../batches/20261021_x112_y5/results.json',case_document=f'../../../docs/cases/{cid}.md',verification_status={'original_source':'acquired_hashed_compared_to_provider_response','historical_call_targets':'complete_trace' if case['full_internal_trace'] else 'receipt_emitters_observed; internal calls not independently traced','transaction_receipt_or_transfers':'checked','full_internal_trace':case['full_internal_trace'],'complete_pre_attack_state':'not_independently_reconstructed','local_compilation':'not_run','fork_replay':'not_run','local_decompilation':'prohibited_not_run','online_decompilation':'not_required_for_included_core_logic'})
        for view,a in [('benchmark_complete',art),('benchmark_simplified',sa)]:
            dump(a/'case_metadata.json',{**base_meta,'view':view,'source_provenance':'provenance.json' if view=='benchmark_complete' else 'slice_manifest.json'})
            (a/'SOURCE.md').write_text(f'# {cid}\n\n公开原始源码在[对应代码目录](../../../dataset/{view}/{cid})；本目录只保存配套资料。\n\n- [共同中文说明](../../../docs/cases/{cid}.md)\n- [固定快照](../../batches/20261021_x112_y5/snapshot.json)\n- [逐行结果](../../batches/20261021_x112_y5/results.json)\n- [来源与切片清单]({"provenance.json" if view=="benchmark_complete" else "slice_manifest.json"})\n\n本批不做本地反编译。原始源码取得和 Sourcify 匹配不代替攻击时代理实现、历史状态或交易复现证明。精简版只保留原文连续片段，不保证单独编译。普通 PancakePair 参考源包与 Circle 当前实现的使用范围见完整来源清单；未据此声称所有历史部署都完全等价。\n\n本例完整内部跟踪取得状态：{case["full_internal_trace"]}。未本地编译，未分叉复现。\n',encoding='utf-8')
    # Append records without reserializing any pre-existing CSV byte.
    append={}
    for language,scale in [('cn',10000),('en',1000)]:
        path=ROOT/f'ai-auditing-benchmark_{language}.csv';data=path.read_bytes();old=load(BASE/'csv_append_manifest.json').get(language) if (BASE/'csv_append_manifest.json').exists() else None
        baseline_size=old['baseline_bytes'] if old else len(data)
        assert hashlib.sha256(data[:baseline_size]).hexdigest()==baseline['files'][path.name]
        records=[]
        for case in sorted(cases,key=lambda c:c['case_id']):
            meta=load(ROOT/'dataset_artifacts/benchmark_complete'/case['case_id']/'case_metadata.json')
            records.append([meta['event_date'].replace('-','.'),meta['project_'+language],meta['vulnerability_'+language],meta['detail_'+language],'\n'.join(meta['tx_urls']),'\n'.join(meta['vulnerable_contract_urls']),'' if meta['loss_usd'] is None else format(Decimal(meta['loss_usd'])/scale,'f')])
        buffer=io.StringIO(newline='');csv.writer(buffer,lineterminator='\r\n').writerows(records)
        path.write_bytes(data[:baseline_size]+buffer.getvalue().encode('utf-8'))
        append[language]={'path':path.name,'baseline_bytes':baseline_size,'baseline_sha256':baseline['files'][path.name],'baseline_event_count':len(list(csv.reader(io.StringIO(data[:baseline_size].decode('utf-8'),newline=''))))-1,'appended_records':records}
    dump(BASE/'csv_append_manifest.json',append)
    dump(BASE/'semantic_review.json',{'case_ids':[c['case_id'] for c in cases],'cases':{c['case_id']:{'required_literals':c['core_requirements'],'review_boundary':'Original checks, caller permissions, state/math and real payout preserved; see detailed Chinese case document. Historical-state gaps remain explicit.'} for c in cases}})
    print(json.dumps({'status':'materialized','counts':counts,'source_files':source_count,'verbatim_slices':slice_count,'csv_new_rows_each':len(cases)},ensure_ascii=False))

if __name__=='__main__':main()
