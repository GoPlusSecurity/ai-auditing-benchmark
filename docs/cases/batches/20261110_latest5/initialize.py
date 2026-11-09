"""Freeze export and baseline once; never silently refresh an existing batch."""
import csv
import datetime as dt
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

from batch import parse_export

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]


def save(name, data):
    (BASE / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", "utf-8")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == "__main__":
    if (BASE / "snapshot.json").exists():
        raise SystemExit("Already frozen; use this snapshot, do not refresh")
    raw_path = Path(sys.argv[1])
    raw = raw_path.read_bytes()
    ordered, invalid = parse_export(raw)
    shutil.copyfile(raw_path, BASE / "sheet_gid0_raw.csv")
    shutil.copyfile(sys.argv[2], BASE / "plan.txt")
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=8))).isoformat()
    save("snapshot.json", {
        "batch_id": BASE.name, "fixed_target": 5, "read_at": now, "timezone": "Asia/Shanghai",
        "source_url": "https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0#gid=0",
        "export_url": "https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/export?format=csv&gid=0",
        "raw_file": "sheet_gid0_raw.csv", "raw_sha256": hashlib.sha256(raw).hexdigest(),
        "raw_bytes": len(raw), "note_record": 1, "header_record": 2,
        "row_number_basis": "csv.reader records including note and header; embedded newlines are not new rows",
        "sort": "date descending; original_row ascending for equal dates",
        "latest_event_date": ordered[0]["event_date"],
        "ordered_rows": ordered, "pending_date_rows": invalid})
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    hashes = {name: sha(ROOT / name) for name in tracked if name and (ROOT / name).is_file()}
    save("baseline.json", {"recorded_at": now,
        "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
        "branch": subprocess.check_output(["git", "branch", "--show-current"], cwd=ROOT).decode().strip(),
        "initial_status": "clean (observed before batch helper creation)",
        "tracked_sha256": hashes,
        "source_case_directories": sorted(p.name for p in (ROOT / "dataset").iterdir() if p.is_dir()),
        "document_case_ids": sorted(p.stem for p in (ROOT / "docs/cases").glob("2*.md"))})
    backups = BASE / "baseline"
    backups.mkdir()
    for name in ("ai-auditing-benchmark_cn.csv", "ai-auditing-benchmark_en.csv"):
        shutil.copyfile(ROOT / name, backups / name)
    ids = set(p.name for p in (ROOT / "dataset").iterdir() if p.is_dir())
    ids.update(p.stem for p in (ROOT / "docs/cases").glob("2*.md"))
    items = {cid: {"case_id": cid, "identity": {"event_date": f"{cid[:4]}-{cid[4:6]}-{cid[6:8]}",
             "chain_id": None, "transactions": [], "victims": []}, "entries": []} for cid in ids}
    csvs = {}
    for lang in ("cn", "en"):
        path = ROOT / f"ai-auditing-benchmark_{lang}.csv"
        csvs[lang] = list(csv.reader(io.StringIO(path.read_text("utf-8-sig"), newline="")))
    for index, row in enumerate(csvs["en"][1:], 2):
        date = row[0].replace(".", "-")
        compact = date.replace("-", "")
        candidates = [cid for cid in ids if cid.startswith(compact + "_")]
        # Exact tx/address information is retained even when directory mapping is ambiguous.
        key = candidates[0] if len(candidates) == 1 else f"csv_record_{index}"
        item = items.setdefault(key, {"case_id": key, "identity": {"event_date": date,
            "chain_id": None, "transactions": [], "victims": []}, "entries": []})
        item["entries"].append({"kind": "csv", "record": index, "cn": csvs["cn"][index-1], "en": row})
        item["identity"]["transactions"].extend(re.findall(r"0x[a-fA-F0-9]{64}", row[4]))
        item["identity"]["victims"].extend(re.findall(r"0x[a-fA-F0-9]{40}", row[5]))
    for cid, item in list(items.items()):
        for folder in (ROOT / "dataset_artifacts" / cid, ROOT / "docs/cases/sources" / cid):
            p = folder / "case_metadata.json"
            if p.is_file():
                data = json.loads(p.read_text("utf-8-sig"))
                identity = item["identity"]
                identity["chain_id"] = data.get("chain_id", data.get("chainId", identity["chain_id"]))
                for field in ("tx_urls", "attack_transactions", "transactions"):
                    identity["transactions"].extend(re.findall(r"0x[a-fA-F0-9]{64}", json.dumps(data.get(field, []))))
                item["entries"].append({"kind": "case_metadata", "path": p.relative_to(ROOT).as_posix(), "sha256": sha(p)})
        item["identity"]["transactions"] = sorted(set(item["identity"]["transactions"]))
        item["identity"]["victims"] = sorted(set(item["identity"]["victims"]))
    batch_files = []
    for parent in (ROOT / "dataset_artifacts/batches", ROOT / "docs/cases/sources"):
        for p in parent.rglob("*results.json"):
            batch_files.append({"path": p.relative_to(ROOT).as_posix(), "sha256": sha(p)})
    save("existing_events.json", {"recorded_at": now, "csv_count_cn": len(csvs["cn"])-1,
        "csv_count_en": len(csvs["en"])-1, "source_case_count": len([p for p in (ROOT / "dataset").iterdir() if p.is_dir()]),
        "events": sorted(items.values(), key=lambda x: x["case_id"]),
        "prior_batch_result_files": batch_files,
        "note": "Union of existing source directories, bilingual CSV records and case documents; prior formal batch results are separately hashed for cross-check. Names alone do not establish identity."})
    print(json.dumps({"raw_sha256": hashlib.sha256(raw).hexdigest(), "ordered": len(ordered),
        "invalid_dates": len(invalid), "latest": ordered[0]["event_date"], "csv_existing": len(csvs["en"])-1,
        "tracked_files": len(hashes), "inventory_entries": len(items)}, ensure_ascii=False))
