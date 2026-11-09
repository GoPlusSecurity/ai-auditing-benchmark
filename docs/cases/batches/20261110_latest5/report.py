"""Write the batch entry point and reconcile prior formal inclusion records."""
import hashlib
import json
from pathlib import Path
import re

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]


if __name__ == "__main__":
    snapshot = json.loads((BASE / "snapshot.json").read_text("utf-8"))
    results = json.loads((BASE / "results.json").read_text("utf-8"))
    inventory = json.loads((BASE / "existing_events.json").read_text("utf-8"))
    existing = {x["case_id"]: x for x in inventory["events"]}
    checked = []
    for entry in inventory["prior_batch_result_files"]:
        path = ROOT / entry["path"]
        value = json.loads(path.read_text("utf-8-sig"))
        def walk(node, formal=False):
            if isinstance(node, list):
                for child in node:
                    walk(child, formal)
            elif isinstance(node, dict):
                included = node.get("qualifies") is True or node.get("status") in ("new", "accepted", "included", "reused", "reuse", "existing")
                cid = node.get("case_id")
                if cid and re.fullmatch(r"\d{8}_.+", str(cid)) and (included or formal):
                    checked.append({"case_id": cid, "batch_results": entry["path"]})
                    if cid not in existing:
                        existing[cid] = {"case_id": cid,
                            "identity": {"event_date": f"{cid[:4]}-{cid[4:6]}-{cid[6:8]}", "chain_id": None,
                                         "transactions": re.findall(r"0x[a-fA-F0-9]{64}", json.dumps(node)), "victims": []},
                            "entries": [{"kind": "prior_formal_batch_record", "path": entry["path"]}]}
                for key, child in node.items():
                    walk(child, key in ("included_cases", "selected_cases", "accepted_cases"))
        walk(value)
    inventory["events"] = sorted(existing.values(), key=lambda x: x["case_id"])
    inventory["prior_formal_records_checked"] = checked
    (BASE / "existing_events.json").write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + "\n", "utf-8")
    summary = json.loads((BASE / "archive-summary.json").read_text("utf-8"))
    total_sources = sum(x["source_files"] for x in summary)
    text = ["# 2026-11-10：从最新日期筛选 5 个新合约漏洞事件", "",
        "本批固定目标为 **5 个符合条件、且此前未收录的不同事件**。沿用同一份原始导出完成调查与验收。", "",
        f"- 来源：[指定 Google 表格]({snapshot['source_url']})；[原始 CSV](sheet_gid0_raw.csv)；[固定快照](snapshot.json)。",
        f"- 读取时间：`{snapshot['read_at']}`，时区 `Asia/Shanghai`；最新事件日期 **{snapshot['latest_event_date']}**。",
        f"- 导出 SHA-256：`{snapshot['raw_sha256']}`；{snapshot['raw_bytes']} 字节。",
        "- 结构已核对：第 1 条为说明、第 2 条为 14 列表头；行号按 CSV 解析记录计算，单元格换行不新增行号。",
        f"- 全表 {len(snapshot['ordered_rows'])} 条有有效日期，另有 {len(snapshot['pending_date_rows'])} 条日期待核实，不猜测日期、不计入 5 例。",
        "- 按 date 从新到旧，同日按原始行号升序。表格并非完全按日期排列，因此 26、27 行先于 25 行检查。",
        f"- 实际裁决顺序：`{', '.join(map(str,results['scan_order']))}`；共 **{len(results['rows'])} 条**，到源表第 **29** 条取得第 5 个新事件后停止。",
        "- [既有事件清单](existing_events.json)核对了原有源码目录、中文/英文 CSV、案例文档和历次正式收录记录；基线两份 CSV 各 **67** 条。",
        "- 本批新增 **5** 例、已有重复 **1** 条、跳过 **21** 条；不复用或补全旧事件。逐行完整字段和理由见 [results.json](results.json)。", "",
        "## 本批新增", "", "| 源表行 | 日期 | 案例 | 核心错误 |", "| --- | --- | --- | --- |"]
    descriptions = {5: "结算时可操纵的逆价格样本放大BNB赎回", 10: "头寸拆分未维护边界计数，边界重建产生虚假手续费", 22: "实时持仓立即夺取多数并同交易执行国库兑换", 26: "未成交转账的卖出额度在skim后仍可烧池", 29: "新旧版本余额衔接时没有正确奖励起点"}
    for row in results["selected"]:
        text.append(f"| {row['original_row']} | {row['event_date']} | [{row['event']}](../../{row['case_id']}.md) | {descriptions[row['original_row']]} |")
    text += ["", f"归档 **{total_sources} 个原始源码文件**，源码位于 `dataset/<case_id>/`，配套编译输入、来源响应、元数据和证据位于 `dataset_artifacts/<case_id>/`。既有目录不搬迁。", "",
        "目录以用户后续更正为准：本批五例直接位于dataset一级。原始plan.txt保留附件原文；移动及前后哈希见[目录迁移记录](directory-relocation.json)。", "",
        "## 逐行处理", "", "| 检查次序 | 源表行 | 事件 | 结果与原因 |", "| --- | --- | --- | --- |"]
    for index, row in enumerate(results["rows"], 1):
        status = {"accepted": "新增", "duplicate_existing": "已有重复", "skipped": "跳过"}[row["status"]]
        text.append(f"| {index} | {row['original_row']} | {row['event']} | {status}：{row['reason'].replace('|','/')} |")
    text += ["", "## 证据范围与用户追加要求", "",
        "未开源部分只允许区块浏览器或工具厂商官方线上反编译。本批未运行本地反编译，也未取得可归档的官方线上反编译输出。BscScan 内置浏览器实查停在安全验证；Dedaub 厂商官网能定位合约，但 Decompiled 视图要求登录。用户选择继续跳过。见 [执行记录](progress.md)和 [采集中断说明](collection-incidents.json)。", "",
        "TENDRIL 的关键 PoolControl、b14g 的关键实现、TranchePool 和 Slice 的关键漏洞逻辑未取得合格原码，因此未收录。WAX 只取得技术披露而未取得漏洞版本原码，也未收录。", "",
        "用户在最终复核后明确确认：‘只要求漏洞、权限和付款因果链的必要代码完整’。原话及边界见[范围确认](scope-confirmation.json)，逐包角色见[必要代码覆盖](source-coverage.md)。本批正式案例的缺陷计算、权限和付款代码有公开原始源码；未公开的纯编排或收款地址不被标为原始源码，其内部程序也不用于补写缺失代码。原始源码、提供方验证、历史运行码、历史状态和复现分开记录。", "",
        "X100 的三个核心历史运行码与提供方运行码逐字节一致；NEM 的普通池仅做了当前运行码对应，不能代替历史比对。其余历史部署/路由/状态缺口逐例列出。X100 有三笔完整跟踪，其余四例没有完整跟踪。", "",
        "金额使用十进制：NEM 保留源表约820000美元报道估值，中文82万美元、英文820千美元，另列精确USDT池净流出与攻击者收款。其他四例因口径或估值未统一，两份CSV金额均留空。未知没有填0。", "",
        "较早的30、31、33、35、36、38行线索曾只读预取以备筛选延伸；它们不是已裁决扫描行，未生成正式案例或CSV记录。它们保留在screening中作为预取来源，不改变严格按快照顺序确定的前5个合格新事件。", "",
        "## 验证入口", "",
        "- [验证报告](validation.json)：快照、顺序、去重、五例数量、原始代码逐字节/哈希、CSV前缀与单位、文档链接/行号、图代码块和改动范围。",
        "- [筛选/解码回归测试](test-results.txt)：日期乱序、同日排序、单元格换行、重复/不合格连续跳过、不足5个拒写、未知日期、幂等追加、同名不同事件及整数/tuple解码。",
        "- [解码可重跑核对](derivation-checks.json)与[整数金额核对](quantitative-checks.json)：交付接口不依赖调查缓存，七份解码保持一致；逐原币核对池子净流出、收款和费用公式。",
        "- [独立复核及处理](review-resolution.md)：保留原评审结论、用户后续范围确认及修正，未发起第二次评审。",
        "- [工作区基线](baseline.json)与[归档数量](archive-summary.json)。", "",
        "没有本地编译、部署、运行上游PoC、分叉重放或发送交易。文档和离线检查通过也不代表已经复现历史攻击。", ""]
    (BASE / "README.md").write_text("\n".join(text), "utf-8")
    (BASE / "sheet_gid0_raw.csv.sha256").write_text(snapshot["raw_sha256"] + "  sheet_gid0_raw.csv\n", "utf-8")
    incidents = {"scope": "Failures observed during this batch; absence of a successful fetch is not proof that public material can never exist.",
        "observations": [
            {"kind": "sandbox_network", "outcome": "Initial public downloads failed with DNS resolution errors inside the sandbox; rerun with approved network access succeeded where responses were available.", "timestamp": None, "basis": "execution output; no precise timestamp archived"},
            {"kind": "temporary_directory_redirect", "outcome": "First initialization command referenced the sandbox TEMP path instead of the already downloaded host TEMP file. Corrected to the exact observed file; fixed export bytes and SHA256 were unchanged."},
            {"kind": "path_guard", "outcome": "Two concurrent downloader runs stopped on path containment checks. Paths were inspected, diagnostic paths added, and retries completed; no path outside this batch was written."},
            {"kind": "windows_path_length", "outcome": "Initial duplicate investigation extraction exceeded Windows path length. Original HTTP responses remained intact; extraction moved to shorter ignored paths. Formal case sources were separately checked against the original responses."},
            {"kind": "browser_bscscan", "url": "https://bscscan.com/bytecode-decompiler?a=0xd00be871eb7a5cb8a69aea41e4c95affc92e54fe", "outcome": "Cloudflare security verification; no usable decompiler output."},
            {"kind": "browser_dedaub", "url": "https://app.dedaub.com/binance/address/0xd00be871eb7a5cb8a69aea41e4c95affc92e54fe/disassembled", "outcome": "Official vendor decompiler located; Decompiled locked, members-only login prompt. User chose to skip rather than log in. No local decompiler was run."},
            {"kind": "incorrect_history_parameter", "outcome": "One exploratory Premia code request used 0x1f012c4f. Excluded from conclusions; corrected requests derive the actual 0x1f011c4f from the archived receipt and also fail to recover historical state."}],
        "http_failures": [p.relative_to(BASE).as_posix() for p in sorted((BASE / "screening").rglob("*.http.json"))
                          if json.loads(p.read_text("utf-8")).get("error")],
        "rpc_errors": [p.relative_to(BASE).as_posix() for p in sorted((BASE / "screening").rglob("*.json"))
                       if ".http." not in p.name and p.stat().st_size < 2000
                       and isinstance((v:=json.loads(p.read_text("utf-8"))), dict) and v.get("error")]}
    (BASE / "collection-incidents.json").write_text(json.dumps(incidents, ensure_ascii=False, indent=2) + "\n", "utf-8")
    print(json.dumps({"new_cases": len(results["selected"]), "source_files": total_sources,
        "prior_formal_records_checked": len(checked), "existing_inventory": len(existing)}, ensure_ascii=False))
