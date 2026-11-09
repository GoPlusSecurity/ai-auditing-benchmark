"""Offline receipt decoding; no contract execution and no decompilation."""
from collections import defaultdict
from decimal import Decimal, getcontext
import json
from pathlib import Path
import re
import sys

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]
sys.path.insert(0, str(ROOT / "dataset_artifacts/batches/20261021_x112_y5"))
from inspect_evidence import keccak

getcontext().prec = 100


def canonical(item):
    typ = item["type"]
    if typ.startswith("tuple"):
        return "(" + ",".join(canonical(x) for x in item["components"]) + ")" + typ[5:]
    return typ


def event_id(event):
    signature = event["name"] + "(" + ",".join(canonical(x) for x in event["inputs"]) + ")"
    return "0x" + keccak(signature.encode()).hex()


def scalar(word, typ):
    raw = word.removeprefix("0x")
    if typ == "address":
        return "0x" + raw[-40:]
    if typ == "bool":
        return bool(int(raw, 16))
    if typ.startswith("uint"):
        return str(int(raw, 16))
    if typ.startswith("int"):
        value = int(raw, 16)
        return str(value - (1 << 256) if value >= (1 << 255) else value)
    return "0x" + raw


def decode(log, event):
    indexed = iter(log["topics"][1:])
    words = iter([log["data"][i:i+64] for i in range(2, len(log["data"]), 64)])
    values = {}
    def consume(item, stream):
        typ = item["type"]
        if typ == "tuple" and all(c["type"] not in ("bytes", "string") and "[" not in c["type"] for c in item["components"]):
            return {c["name"]: consume(c, stream) for c in item["components"]}
        word = next(stream)
        if "[" in typ or typ in ("string", "bytes") or typ.startswith("tuple"):
            return {"raw_word_or_offset": word, "not_decoded": True}
        return scalar(word, typ)
    for item in event["inputs"]:
        values[item["name"]] = consume(item, indexed if item.get("indexed") else words)
    return {"log_index": int(log["logIndex"], 16), "address": log["address"],
            "event": event["name"], "values": values}


def pool_events():
    # The archived original is delivered with this case, so no ignored cache is needed.
    source = ROOT / "dataset/20261101_PremiaV3/pool-core/contracts/pool/IPoolEvents.sol"
    result = []
    text = re.sub(r"//[^\n]*", "", source.read_text("utf-8"))
    for name, args in re.findall(r"event\s+(\w+)\s*\((.*?)\)\s*;", text, re.S):
        fields = []
        for arg in args.split(","):
            parts = arg.split()
            if len(parts) < 2:
                fields = []
                break
            if parts[0] == "Position.Delta":
                fields.append({"name": parts[-1], "type": "tuple", "indexed": False,
                    "components": [{"name": n, "type": "int256"} for n in ("collateral", "longs", "shorts")]})
                continue
            typ = {"UD60x18": "uint256", "SD59x18": "int256"}.get(parts[0], parts[0])
            fields.append({"name": parts[-1], "type": typ, "indexed": "indexed" in parts})
        if fields:
            result.append({"name": name, "type": "event", "inputs": fields})
    return result


def schemas():
    events = {}
    for p in (BASE / "screening").rglob("*.json"):
        if ".http." in p.name:
            continue
        try:
            data = json.loads(p.read_text("utf-8"))
        except (ValueError, UnicodeError):
            continue
        if not isinstance(data, dict) or not data.get("sources"):
            continue
        for event in data.get("abi", []):
            if event["type"] == "event":
                events[event_id(event)] = event
    for event in pool_events():
        events[event_id(event)] = event
    return events


def inspect_receipt(path, events):
    data = json.loads(path.read_text("utf-8"))
    receipt = data.get("result")
    if not receipt or "logs" not in receipt:
        return {"available": False, "response": data}
    decoded, transfers, unknown = [], [], []
    balances = defaultdict(lambda: defaultdict(int))
    for log in receipt["logs"]:
        if not log["topics"]:
            continue
        topic = log["topics"][0]
        if topic == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" and len(log["topics"]) == 3:
            amount = int(log["data"], 16)
            sender = "0x" + log["topics"][1][-40:]
            recipient = "0x" + log["topics"][2][-40:]
            transfers.append({"log_index": int(log["logIndex"], 16), "token": log["address"],
                "from": sender, "to": recipient, "raw_amount": str(amount)})
            balances[log["address"]][sender] -= amount
            balances[log["address"]][recipient] += amount
        elif topic in events:
            try:
                decoded.append(decode(log, events[topic]))
            except (StopIteration, ValueError):
                unknown.append({"log_index": int(log["logIndex"], 16), "address": log["address"], "topic": topic})
        else:
            unknown.append({"log_index": int(log["logIndex"], 16), "address": log["address"], "topic": topic})
    return {"available": True, "transaction_hash": receipt["transactionHash"],
        "status": receipt["status"], "block_number": int(receipt["blockNumber"], 16),
        "log_count": len(receipt["logs"]), "decoded_events": decoded, "transfers": transfers,
        "token_net_raw": {t: {a: str(v) for a, v in aa.items()} for t, aa in balances.items()},
        "unknown_events": unknown,
        "limits": "Receipt events and token deltas only; native transfers and internal calls are not inferred from ERC20 logs."}


if __name__ == "__main__":
    event_schemas = schemas()
    targets = {"corevault": "screening/corevault/receipt.json",
        "premia1": "screening/premia/attack1-receipt-alt.json",
        "premia2": "screening/premia/attack2-receipt-alt.json",
        "x100": "screening/row22/receipt-official.json",
        "nem": "screening/row26/receipt.json", "alpscon": "screening/row29/receipt.json"}
    for name, relative in targets.items():
        result = inspect_receipt(BASE / relative, event_schemas)
        (BASE / "screening" / (name + "-decoded.json")).write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n", "utf-8")
        print(name, result.get("log_count"), len(result.get("decoded_events", [])), "decoded events")
    setup = BASE / "screening/premia/setup-receipt-official.json"
    if setup.exists():
        (BASE / "screening/premia-setup-decoded.json").write_text(
            json.dumps(inspect_receipt(setup, event_schemas), ensure_ascii=False, indent=2) + "\n", "utf-8")
