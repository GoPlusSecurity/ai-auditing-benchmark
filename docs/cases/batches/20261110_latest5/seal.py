"""Seal the ordered screening decisions from this batch's fixed snapshot."""
import hashlib
import json
from pathlib import Path
import re

from batch import select_rows

BASE = Path(__file__).resolve().parent

SKIPS = {
    3: ("Keplr / Web3Auth", "签名服务/私钥控制事件；未确认智能合约代码缺陷。"),
    4: ("TENDRIL", "取得代币原码但决定烧池和sync的PoolControl原码未取得；BscScan官网安全验证未结束，Dedaub线上反编译需登录；用户要求继续跳过。"),
    6: ("Credit Mutuel Arkea", "源表为管理账户被入侵，未确认合约代码缺陷。"),
    7: ("King bot wallet", "钱包密钥或签名服务控制问题，未确认合约代码缺陷。"),
    8: ("Mercado Bitcoin", "多链热钱包被盗，未取得能够确认的合约代码缺陷及对应漏洞源码。"),
    9: ("b14g", "仅取得代理原码；当前显示实现未取得漏洞原码，历史槽读取失败，整起事件不能仅凭代理、字节码重构或报道收录。"),
    11: ("Flap / Kintsu", "DNS劫持及克隆前端，非已确认合约代码漏洞。"),
    12: ("Polymarket / DebugBear", "网页脚本供应链污染及签名权限滥用，未确认合约代码缺陷。"),
    13: ("Binance", "热钱包签名/提现系统被控制；使用EIP-7702批量转账不自动构成合约漏洞。"),
    15: ("USDT address poisoning", "地址投毒误转，非合约代码漏洞。"),
    16: ("Valinor / Fence TranchePool", "回执相关关键合约0xf09d...和0xe25c...的漏洞原始源码均未取得；未取得合格官方线上反编译结果，不将报道或运行码当源码。"),
    17: ("Predict.fun", "第三方API文档站被入侵后权限被滥用，未确认合约代码缺陷。"),
    18: ("Safe pre-approved undeployed spender", "源表描述提前授权未部署地址并被公开部署工具占用；未确认Safe或部署工具违反其合约代码承诺的缺陷，不能只因转账损失收录。"),
    19: ("Polkadot Asset Hub", "主要缺陷为XCM/运行时供应量记账与协议模块组合；本批仅收合约代码漏洞，不将链运行时问题等同为受害合约源码样本。"),
    20: ("DotSwap V1", "旧版服务器签名路径被利用，未取得已确认合约代码缺陷及对应漏洞原码。"),
    21: ("Ethereum / Base wallet compromise", "疑似私钥泄露，未确认合约代码缺陷。"),
    23: ("Initia MoveVM", "缺陷位于虚拟机已验证脚本缓存/ABI处理，属于链执行环境代码，本批不将其作为合约代码漏洞收录。"),
    24: ("WAX Multi-Chain Bridge", "原始披露指出eth.token负max_fee，但本次未取得该漏洞版本公开原始源码；官方组织仓库和defi树查询只取得说明，不能用报道或WASM代替原码。"),
    25: ("Fearless Wallet", "浏览器扩展供应链投毒/私钥外传，非合约代码漏洞。"),
    27: ("CoinDCX", "热钱包被盗，未确认合约代码缺陷。"),
    28: ("Slice", "取得代理源码，但关键实现0x1f08...未取得漏洞原始源码；未取得符合要求的官方线上反编译补充，跳过。")
}


if __name__ == "__main__":
    snapshot = json.loads((BASE / "snapshot.json").read_text("utf-8"))
    inventory = json.loads((BASE / "existing_events.json").read_text("utf-8"))
    cases = json.loads((BASE / "cases.json").read_text("utf-8"))
    decisions = {}
    for number, (event, reason) in SKIPS.items():
        decisions[number] = {"event": event, "status": "skipped", "qualifies": False,
            "case_id": None, "duplicate_existing": False, "duplicate_batch": False,
            "public_original_vulnerable_source": False,
            "source_qualification": "not_eligible_or_incomplete", "reason": reason}
    decisions[14] = {"event": "zkLink Nova", "status": "duplicate_existing", "qualifies": False,
        "case_id": "20261029_zkLink_Nova", "duplicate_case_id": "20261029_zkLink_Nova",
        "duplicate_existing": True, "duplicate_batch": False,
        "source_qualification": "existing_event_not_reused", "public_original_vulnerable_source": False,
        "reason": "既有源码目录、CSV和元数据已收录同一Ethereum攻击交易0x4f3c23e7...；不复用、不补全、不计入本批5例。"}
    by_row = {r["original_row"]: r for r in snapshot["ordered_rows"]}
    for case in cases:
        number = case["sheet_row"]
        row = by_row[number]
        decisions[number] = {"event": case["project_en"], "case_id": case["case_id"],
            "status": "accepted", "qualifies": True, "duplicate_existing": False, "duplicate_batch": False,
            "public_original_vulnerable_source": True,
            "source_qualification": "critical_vulnerable_original_source_acquired",
            "source_packages": [p for label, p in case["sources"]],
            "identity": {"chain_id": case["chain_id"], "event_date": row["event_date"],
                "transactions": re.findall(r"0x[a-fA-F0-9]{64}", row["fields"]["malicious_tx"]),
                "victims": case["victims"]},
            "reason": "已取得决定漏洞和付款的公开原始源码；来源资格、历史部署及状态核实分别记录。"}
    result = select_rows(snapshot["ordered_rows"], decisions, inventory["events"])
    if not result["ready"]:
        raise SystemExit("Not five qualified new cases; no official case or CSV writes are permitted")
    result.update(snapshot="snapshot.json", raw_sha256=snapshot["raw_sha256"],
        latest_event_date=snapshot["latest_event_date"],
        sorting=snapshot["sort"], existing_events="existing_events.json",
        pending_date_rows=snapshot["pending_date_rows"],
        scanned_count=len(result["rows"]),
        preliminary_prefetch_rows=[30, 31, 33, 35, 36, 38],
        prefetch_note="较早线索曾只读预取，不是已裁决扫描行，未创建其正式案例；正式裁决依固定快照逐条进行，到第5个新事件停止。",
        decompilation_policy={"allowed": "official online explorer/vendor services only",
            "local": "prohibited by user", "used": False,
            "dedaub": "official service checked in browser; output locked behind login; user chose to skip affected candidates",
            "bscscan": "official online decompiler checked in browser; Cloudflare security verification, no usable output"})
    (BASE / "results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", "utf-8")
    print(json.dumps({"ready": result["ready"], "scan_order": result["scan_order"],
        "selected": [x["case_id"] for x in result["selected"]], "skipped": sum(x["status"] == "skipped" for x in result["rows"])}, ensure_ascii=False))
