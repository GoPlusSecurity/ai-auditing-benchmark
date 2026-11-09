"""Fixed-snapshot screening and gated append for this research batch.

No network requests and no source-code rewriting. Dates use ISO source fields;
row numbers are CSV records including the note and header records.
"""
import copy
import csv
import datetime as dt
import io
from pathlib import Path

HEADER = ["timestamp", "target (社媒 or Addr)", "description", "data_source",
          "original_link", "date", "lost", "lost_u", "malicious_tx",
          "malicious_address", "malicious_url", "malicious_social_account",
          "attack_category", "attack_analysis"]
TARGET = 5


def parse_export(raw):
    records = list(csv.reader(io.StringIO(raw.decode("utf-8-sig"), newline="")))
    if (len(records) < 2 or len(records[0]) != len(HEADER)
            or not records[0][0].strip() or records[0][0] == "timestamp"
            or records[1] != HEADER):
        raise ValueError("Expected note at record 1 and the 14-column header at record 2")
    valid, invalid = [], []
    for number, values in enumerate(records[2:], 3):
        if len(values) != len(HEADER):
            raise ValueError(f"Wrong field count at parsed record {number}")
        fields = dict(zip(HEADER, values))
        row = {"original_row": number, "fields": fields}
        try:
            value = fields["date"].strip()
            if len(value) != 10:
                raise ValueError("Expected YYYY-MM-DD")
            row["event_date"] = dt.date.fromisoformat(value).isoformat()
            valid.append(row)
        except ValueError:
            row.update(status="pending_date", reason="Missing or invalid date; no date inferred")
            invalid.append(row)
    valid.sort(key=lambda r: (-dt.date.fromisoformat(r["event_date"]).toordinal(), r["original_row"]))
    return valid, invalid


def same_event(a, b):
    ia, ib = a.get("identity", {}), b.get("identity", {})
    ta = {x.lower() for x in ia.get("transactions", []) if x}
    tb = {x.lower() for x in ib.get("transactions", []) if x}
    chains_match = ia.get("chain_id") == ib.get("chain_id")
    if ta & tb and (chains_match or not ia.get("chain_id") or not ib.get("chain_id")):
        return True
    va = {x.lower() for x in ia.get("victims", []) if x}
    vb = {x.lower() for x in ib.get("victims", []) if x}
    return bool(chains_match and ia.get("chain_id") is not None and va & vb
                and ia.get("event_date") == ib.get("event_date")
                and ia.get("event_date"))


def select_rows(rows, decisions, existing=()):
    selected, examined = [], []
    for row in rows:
        number = row["original_row"]
        decision = copy.deepcopy(decisions.get(number, {"status": "pending", "qualifies": False,
                                                      "reason": "Not yet investigated"}))
        item = {**copy.deepcopy(row), **decision, "original_row": number}
        if item["status"] == "pending":
            examined.append(item)
            break
        if item.get("qualifies") and not item.get("public_original_vulnerable_source"):
            item.update(status="skipped", qualifies=False,
                        reason="No vulnerable public original source; decompilation or patched code alone is insufficient")
        if item.get("qualifies"):
            old = next((x for x in existing if same_event(item, x)), None)
            current = next((x for x in selected if same_event(item, x)), None)
            if old:
                item.update(status="duplicate_existing", qualifies=False,
                            duplicate_case_id=old["case_id"])
            elif current:
                item.update(status="duplicate_batch", qualifies=False,
                            duplicate_case_id=current["case_id"])
                current["original_rows"].append(number)
            else:
                item.update(status="accepted", original_rows=[number])
                selected.append(item)
        examined.append(item)
        if len(selected) == TARGET:
            break
    return {"fixed_target": TARGET, "selected": selected, "rows": examined,
            "ready": len(selected) == TARGET,
            "scan_order": [r["original_row"] for r in examined]}


def append_csv(path, result, new_rows):
    if not result.get("ready") or len(result.get("selected", [])) != TARGET or len(new_rows) != TARGET:
        raise ValueError("Exactly five qualified distinct new events are required before any write")
    path = Path(path)
    original = path.read_bytes()
    bom = original.startswith(b"\xef\xbb\xbf")
    records = list(csv.reader(io.StringIO(original.decode("utf-8-sig"), newline="")))
    if not records or any(len(r) != 7 for r in records) or any(len(r) != 7 for r in new_rows):
        raise ValueError("Expected seven CSV columns")
    # Same project/date can represent distinct chains or attacks; names alone are not identity.
    old_keys = {(r[0], r[1], r[4], r[5]) for r in records[1:]}
    pending = [r for r in new_rows if (r[0], r[1], r[4], r[5]) not in old_keys]
    if not pending:
        return False
    if len(pending) != TARGET:
        raise ValueError("Partial prior append; refusing a mixed or incomplete batch")
    newline = "\r\n" if b"\r\n" in original else "\n"
    out = io.StringIO(newline="")
    writer = csv.writer(out, lineterminator=newline)
    writer.writerows(pending)
    separator = b"" if original.endswith((b"\n", b"\r")) else newline.encode()
    path.write_bytes(original + separator + out.getvalue().encode("utf-8"))
    return True
