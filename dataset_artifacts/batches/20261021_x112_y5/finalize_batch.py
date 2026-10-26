"""Refresh research indices and hashes after the batch's source/doc edits."""
import datetime as dt
import hashlib
import json
from pathlib import Path
import shutil
from build_batch import BASE, ROOT, checksum, dump, load, sha, relative

def compare_current_pool_runtimes(records):
    source_path=BASE/'screening/pro-pair-source.json'
    source=load(source_path)
    reference=bytes.fromhex(source['runtimeBytecode']['onchainBytecode'][2:])
    comparisons=[]
    for label,names in {
        'moke':['moke-main-pair-runtime.json','moke-reserve-pair-runtime.json'],
        'nex':['nex-main-pair-runtime.json','nex-flash-pair-runtime.json'],
        'fox':['fox-main-pair-runtime.json'],
    }.items():
        for name in names:
            path=BASE/'screening'/name
            record=max((r for r in records if r.get('path')=='screening/'+name and r.get('sha256')==sha(path)),key=lambda r:r['retrieved_at'])
            payload=record['payload'];code=bytes.fromhex(load(path)['result'][2:])
            assert payload['method']=='eth_getCode' and payload['params'][1]=='latest'
            assert code==reference, 'current pool runtime differs: '+name
            comparisons.append({'case_label':label,'address':payload['params'][0],'rpc_url':record['url'],'block_selector':'latest','retrieved_at':record['retrieved_at'],'response_path':relative(path,BASE),'response_sha256':sha(path),'runtime_bytes':len(code),'runtime_sha256':hashlib.sha256(code).hexdigest(),'byte_equal_to_reference':True})
    report={'kind':'read_only_current_runtime_byte_comparison','reference':{'address':source['address'],'source_provider':'Sourcify','source_runtime_match':source['runtimeMatch'],'response_path':relative(source_path,BASE),'response_sha256':sha(source_path),'runtime_bytes':len(reference),'runtime_sha256':hashlib.sha256(reference).hexdigest()},'targets':comparisons,'limitation':'eth_getCode latest only. Attack-block runtime, historical proxy binding and pre-attack state were not independently reconstructed. No local compilation, decompilation or EVM execution.'}
    dump(BASE/'pool_runtime_comparison.json',report)
    return report

def main():
    cases=load(BASE/'cases.json'); result=load(BASE/'results.json'); decoded=load(BASE/'decoded_evidence.json')
    records=[]
    for p in sorted(BASE.glob('*fetch-results.json')):
        records.extend(load(p))
    dump(BASE/'retrieval_inventory.json',records)
    pool_comparison=compare_current_pool_runtimes(records)
    def retrieval(name,digest):
        options=[r for r in records if r.get('path')=='screening/'+name and r.get('sha256')==digest]
        return max(options,key=lambda r:r['retrieved_at']) if options else None
    for case in cases:
        art=ROOT/'dataset_artifacts/benchmark_complete'/case['case_id']
        prov=load(art/'provenance.json')
        for bundle in prov['bundles']:
            record=retrieval(bundle['id']+'-source.json',bundle['response_sha256'])
            if record: bundle['retrieved_at']=record['retrieved_at']
        for evidence in prov['evidence']:
            record=retrieval(Path(evidence['path']).name,evidence['sha256'])
            if record: evidence.update(url=record['url'],retrieved_at=record['retrieved_at'])
        target=art/'evidence/decoded-events-and-flows.json'
        dump(target,decoded['cases'][case['label']])
        prov['evidence']=[e for e in prov['evidence'] if e['path']!=relative(target,art)]
        prov['evidence'].append({'path':relative(target,art),'sha256':sha(target),'bytes':target.stat().st_size,'kind':'offline_decode_of_archived_receipts_or_trace'})
        if any(t['case_label']==case['label'] for t in pool_comparison['targets']):
            target=art/'evidence/pool-runtime-comparison.json'
            subset={**pool_comparison,'targets':[t for t in pool_comparison['targets'] if t['case_label']==case['label']],'path_base':'batch_root: dataset_artifacts/batches/20261021_x112_y5'}
            dump(target,subset)
            prov['evidence']=[e for e in prov['evidence'] if e['path']!=relative(target,art)]
            prov['evidence'].append({'path':relative(target,art),'sha256':sha(target),'bytes':target.stat().st_size,'kind':'current_pool_runtime_byte_comparison_not_historical_binding'})
            prov['current_pool_runtime_comparison']='evidence/pool-runtime-comparison.json'
        prov['context_limits']='PancakePair verified source comes from the separately identified PRO pool. Five actual incident pools have byte-identical current runtime, recorded in the batch comparison; no attack-block runtime equivalence is claimed. Circle current proxy implementation is context; its historical slot was not independently reconstructed.'
        dump(art/'provenance.json',prov)
        for view in ['benchmark_complete','benchmark_simplified']:checksum(case['case_id'],view)
    section=['## 2026-10-21 按 X=112、Y=5 向上筛选','',
        '本批使用重新导出并固定的 CSV，按解析记录从第 112 行逆序检查，到第 88 行找到第 5 行合格记录即停止。实际扫描 **88–112 行，共 25 行**；新增 **5** 例，跳过 **20** 行；没有旧例补全或重复合并。源表第 1 行说明、第 2 行表头、14 列结构已核对。','',
        '| 源表行 | 案例 | 核心错误 | 本批独立交易证据 |','| --- | --- | --- | --- |',
        '| 101 | [MOKE](20260803_MOKE.md) | 现货价释放与陈旧 LP 分红记录 | 原始回执、65 次旧份额清零和领取、逐币收支 |',
        '| 100 | [NEX / AIC](20260804_NEX_AIC.md) | 路由器分支重复扣账，使 skim 后储备为 1 wei | 原始回执、双转账、Sync 与付款整数 |',
        '| 98 | [USM / FUM](20260810_USM_FUM.md) | 平均价格近似与逐次状态收缩造成拆分赎回差异 | 完整 raw trace、1 次 fund 和 64 次 defund、ETH 净流出 |',
        '| 90 | [Fox LP Bonds](20260817_Fox.md) | 交易前现货价决定权益，变价后仍按旧数发推荐奖励 | 回执 UserStake、铸币和资产转移；历史代理槽未取得 |',
        '| 88 | [Allbridge CCTP](20260820_Allbridge_CCTP.md) | 通用消息被当作真正 USDC 入金 | calldata、回执、消息和 TokenReceived 事件、USDC 收支 |','',
        '全部 5 例取得核心漏洞相关公开原始源码；源码仅保存在 `dataset`。本批禁止本地反编译，未运行任何本地反编译工具；LULA 的必要 Rental 合约未开源，BscScan 官网线上反编译未返回可归档代码，按用户要求跳过。PRO 与 Base CALL 合约未取得关键缺陷原始源码；Swan 的签名来源和代码缺陷归因未确立，也未作为已确认代码漏洞收录。其他跳过项逐行列明。','',
        'MOKE、NEX/AIC、USM/FUM、Fox 的美元估值或口径不能统一，两份 CSV 对应金额留空；Allbridge 保留源表约 191,000 美元的事件估计，并与净流出及净收益分列。5 例均未本地编译、未分叉重放。普通池参考源码、当前实现与历史部署绑定的区别在来源和案例文档中明确说明。','',
        '批次入口：[说明与逐行表](../../dataset_artifacts/batches/20261021_x112_y5/README.md)、[原始 CSV](../../dataset_artifacts/batches/20261021_x112_y5/sheet_gid0_raw.csv)、[固定快照](../../dataset_artifacts/batches/20261021_x112_y5/snapshot.json)、[逐行结果](../../dataset_artifacts/batches/20261021_x112_y5/results.json)、[验证报告](../../dataset_artifacts/batches/20261021_x112_y5/validation.json)。','',
        '原始导出 SHA-256：`'+result['parameters']['raw_export_sha256']+'`。','']
    index=ROOT/'docs/cases/README.md';data=index.read_bytes();new=('\n'.join(section)+'\n').encode('utf-8')
    first=b'## 2026-10-21 '; old=b'## 2026-10-16 '
    if first in data:
        a=data.index(first);z=data.index(old,a);data=data[:a]+new+data[z:]
    else:
        assert old in data;data=data.replace(old,new+old,1)
    index.write_bytes(data)
    for name in ['README.md','README_cn.md']:
        path=ROOT/name; raw=path.read_bytes()
        lines=raw.splitlines(keepends=True)
        for i,line in enumerate(lines):
            if b'2026-10-16' in line and (b'57' in line or b'20261016_x123_y5/results.json' in line):
                line=line.replace(b'2026-10-16',b'2026-10-21').replace(b'20261016_x123_y5/results.json',b'20261021_x112_y5/results.json').replace(b'57',b'62').replace(b'56',b'61')
                lines[i]=line
        path.write_bytes(b''.join(lines))
    rows=result['rows']; text=['# X=112，Y=5 批次结果','',
        '固定导出读取时间：'+result['parameters']['retrieved_at']+'，时区 Asia/Shanghai。原始导出解析为 '+str(load(BASE/'snapshot.json')['parsed_record_count'])+' 条记录，前两条分别为说明和表头，均为 14 列。','',
        '从第 112 行向上检查，实际范围 88–112，共 25 行，5 行合格、20 行跳过。新增 5 个 case，无旧例补全或重复。源码仅放 dataset；ABI、编译输入、提供方响应、交易证据、清单和校验结果均在 dataset_artifacts。','',
        '导出 SHA-256：`'+result['parameters']['raw_export_sha256']+'`。','',
        '- [原始导出](sheet_gid0_raw.csv)','- [固定快照](snapshot.json)','- [逐行机器结果](results.json)','- [逐次网络取证记录](retrieval_inventory.json)','- [独立离线事件与收支解码](decoded_evidence.json)','- [当前交易池运行字节码比对](pool_runtime_comparison.json)','- [独立只读复核及修正](independent_review.md)','- [验证报告](validation.json)','- [选行与批次测试](test_results.json)','- [执行记录](execution_notes.md)','',
        '| 源表行 | 事件 | 处置 | 原因 |','| --- | --- | --- | --- |']
    for row in rows:
        label=row['event'];cid=row['case_id']
        if cid:label=f'[{label}](../../../docs/cases/{cid}.md)'
        text.append(f"| {row['row']} | {label} | {'新增' if row['qualifies'] else '跳过'} | {row['reason']} |")
    text += ['', '## 核查范围','',
        '207 个完整原始 Solidity 文件逐字节与归档的 Sourcify response sources.content 对照。精简版所有片段均来自连续原始行，实际片段数量以验证报告为准；不增删、修复或重写合约逻辑，不保证片段单独编译。所有 ABI 和 standard-input.json 位于资料目录。','',
        'USM 取得完整 raw trace；其他 4 例独立取得原始回执、交易数据和事件，未声称拥有完整内部跟踪。Fox 历史实现槽与早期 BSC 跟踪接口返回 missing trie node；备用节点返回 429。Base Blockscout 返回 403，后用 Base 官方 RPC 取得交易和回执。错误响应本身不构成源码不存在或历史实现已核实的证明。','',
        '只允许官网或权威网站在线反编译；本地反编译禁止且未执行。LULA 的官网在线反编译结果未取得，证据见 [页面 DOM](screening/lula-rental-online-decompiler-dom.html) 与 [截图](screening/lula-rental-online-decompiler.png)。预先取得的报告、字节码及软件发布信息均不属于已执行反编译。','',
        '普通 PancakePair 公开验证参考版本来自单独记录的 PRO 池地址。另对 MOKE 两个实际池、NEX 两个实际池及 Fox 实际池读取当前 eth_getCode latest：5 个结果均与参考池完整运行字节码逐字节相同，长度 14,981 字节，SHA-256 为 ab89a0244c7e5a86aa8e1673b4c5b825db93bc406c7934e923ebb0a7c4548ac7。该检查只证明当前运行代码一致；没有取得攻击区块代码，不能将其作为历史绑定证明。Circle 当前代理实现是原始源码上下文；其历史关联没有独立完全重建。攻击编排合约不承担本批原始漏洞源码资格证明。','',
        'MOKE、NEX/AIC、USM/FUM、Fox 的 USD 金额留空，并分别保留原始代币数量。Allbridge 191,000 美元是源表事件估计，按 USDC 约等于美元的披露口径保留；190,155.976393 USDC 是已核查 Router 净流出，189,751.554381 USDC 是最终收益，999,000 USDC 毛付款包含借款补入金额。','',
        '全部案例未本地编译、未分叉重放，未重建全部攻击前状态。本次只在原有 tz 工作区增量写入，没有提交或推送。','']
    (BASE/'README.md').write_text('\n'.join(text),encoding='utf-8')
    # Keep the supplied plan as input evidence; user amendments remain in execution_notes.
    shutil.copyfile(Path('C:/Users/cccsh/.codex/attachments/06eccfc4-5661-4760-a63b-a5de1ec382dc/已粘贴的文本.txt'),BASE/'supplied_plan.txt')
    manifest=[{'path':relative(p,BASE),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted((BASE/'screening').rglob('*')) if p.is_file()]
    dump(BASE/'screening_manifest.json',{'files':manifest})
    print(json.dumps({'indexed_cases':len(cases),'screening_files':len(manifest)},ensure_ascii=False))

if __name__=='__main__':main()
