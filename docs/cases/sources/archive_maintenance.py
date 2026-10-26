"""Offline helpers for current flat archives; historical batch reports stay immutable."""
from pathlib import Path
from decimal import Decimal
import csv, io, json, hashlib, os

def load(path):
    return json.loads(path.read_text("utf-8-sig"))

def expected_row(meta, language):
    scale = 10000 if language == "cn" else 1000
    return [meta["event_date"].replace("-", "."), meta["project_"+language], meta["vulnerability_"+language], meta["detail_"+language], "\n".join(meta["tx_urls"]), "\n".join(meta["vulnerable_contract_urls"]), "" if meta["loss_usd"] is None else format(Decimal(meta["loss_usd"])/scale, "f")]

def append_missing_rows(root, case_ids):
    """Append only missing events. Never truncate later batches or rewrite old bytes."""
    report = {}
    for language in ("cn", "en"):
        path = root/f"ai-auditing-benchmark_{language}.csv"
        data = path.read_bytes()
        rows = list(csv.reader(io.StringIO(data.decode("utf-8-sig"), newline="")))
        added = []
        for cid in sorted(case_ids):
            expected = expected_row(load(root/"dataset_artifacts"/cid/"case_metadata.json"), language)
            matches = [r for r in rows[1:] if r[4] == expected[4]]
            if matches:
                assert matches == [expected], (cid, "existing event differs or duplicates")
            else:
                added.append(expected); rows.append(expected)
        output = io.StringIO(newline="")
        csv.writer(output, lineterminator="\r\n").writerows(added)
        if added:
            assert data.endswith(b"\n"), "CSV must end with a newline before append"
            path.write_bytes(data+output.getvalue().encode("utf-8"))
        report[language] = {"path":path.name, "baseline_bytes":len(data), "baseline_sha256":hashlib.sha256(data).hexdigest(), "appended_records":added}
    return report

def validate_csv_records(root, case_ids):
    counts = {}
    for language in ("cn", "en"):
        rows = list(csv.reader(io.StringIO((root/f"ai-auditing-benchmark_{language}.csv").read_text("utf-8-sig"), newline="")))
        assert all(len(row)==7 for row in rows), "CSV column count"
        for cid in case_ids:
            expected = expected_row(load(root/"dataset_artifacts"/cid/"case_metadata.json"), language)
            assert [r for r in rows[1:] if r[4]==expected[4]] == [expected], (cid,language,"CSV content/duplicates")
        counts[language]=len(rows)-1
    return counts

def refresh_batch_inventory(base):
    files=sorted(p for p in base.rglob("*") if p.is_file() and "__pycache__" not in p.parts and p.suffix!=".pyc" and p.name not in {"file_inventory.json","SHA256SUMS"})
    inventory={"files":[{"path":p.relative_to(base).as_posix(),"bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()} for p in files],"excludes":["file_inventory.json","SHA256SUMS","__pycache__","*.pyc"]}
    (base/"file_inventory.json").write_bytes((json.dumps(inventory,ensure_ascii=False,indent=2)+"\n").encode())
    files.append(base/"file_inventory.json")
    (base/"SHA256SUMS").write_bytes("".join(hashlib.sha256(p.read_bytes()).hexdigest()+"  "+p.relative_to(base).as_posix()+"\n" for p in sorted(files)).encode())
    return len(files)
