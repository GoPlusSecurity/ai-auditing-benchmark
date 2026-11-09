"""Offline acceptance checks, driven by this snapshot's selected event list."""
import argparse
import csv
from decimal import Decimal
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess

from batch import parse_export, same_event
from build import checked_results

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    return json.loads(path.read_text("utf-8"))


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def check_links(path, content=None):
    if content is None:
        content = path.read_text("utf-8")
    links = []
    for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", content):
        if target.startswith(("https://", "http://", "mailto:", "#")):
            continue
        part, _, anchor = target.partition("#")
        linked = (path.parent / part).resolve()
        check(linked.exists(), f"Broken link {path.name}: {target}")
        line = re.fullmatch(r"L(\d+)", anchor)
        if line:
            check(1 <= int(line[1]) <= len(linked.read_text("utf-8").splitlines()), "Source line outside file: " + target)
        links.append(target)
    return len(links)


def check_document(path):
    content = path.read_text("utf-8")
    check(content.count("```") % 2 == 0, "Unbalanced code fences: " + str(path))
    diagrams = re.findall(r"```mermaid\s*\n(.*?)```", content, re.S)
    check(bool(diagrams), "Missing Mermaid: " + str(path))
    for graph in diagrams:
        lines = [s.strip() for s in graph.strip().splitlines() if s.strip()]
        check(lines[0] in ("flowchart TD", "flowchart LR"), "Unexpected graph syntax")
        defined, referenced = set(), set()
        for line in lines[1:]:
            check(" --> " in line, "Unsupported or malformed graph edge: " + line)
            left, right = line.split(" --> ", 1)
            for node in (left, right):
                hit = re.fullmatch(r'(\w+)(?:\["[^"\n]*"\])?', node)
                check(hit is not None, "Malformed graph node: " + node)
                referenced.add(hit[1])
                if "[" in node:
                    defined.add(hit[1])
        check(referenced <= defined, "Undefined graph nodes")
        check(len(defined) >= 5, "Diagram omits causal chain")
    return {"local_links": check_links(path, content), "mermaid_diagrams": len(diagrams),
            "mermaid_check": "flowchart syntax, defined nodes and complete edge references; not visually rendered"}


def validate(before_append=False):
    result = checked_results()
    snapshot = load(BASE / "snapshot.json")
    baseline = load(BASE / "baseline.json")
    inventory = load(BASE / "existing_events.json")
    definitions = {d["case_id"]: d for d in load(BASE / "cases.json")}
    selected = result["selected"]
    ids = [r["case_id"] for r in selected]
    check(len(ids) == result["fixed_target"] == 5 and len(set(ids)) == len(ids), "Wrong new-event count")
    check(result["scan_order"] == [r["original_row"] for r in snapshot["ordered_rows"][:len(result["rows"])]], "Scan is not the latest-date prefix")
    check(result["rows"][-1]["status"] == "accepted", "Did not stop at the fifth qualified event")
    check(sum(r["status"] == "accepted" for r in result["rows"]) == result["fixed_target"], "Accepted rows mismatch")
    by_row = {r["original_row"]: r for r in snapshot["ordered_rows"]}
    for row in result["rows"]:
        check(row["fields"] == by_row[row["original_row"]]["fields"], "Complete raw row changed")
        check(row["event_date"] == by_row[row["original_row"]]["event_date"], "Event date changed")
        check(row["status"] in ("accepted", "skipped", "duplicate_existing", "duplicate_batch") and row["reason"], "Missing row disposition")
    for row in selected:
        check(not any(same_event(row, old) for old in inventory["events"]), "Selected an existing event")
        check(row["case_id"] not in [e["case_id"] for e in inventory["events"]], "Reused a case ID")
        check(row["case_id"][:8] == row["event_date"].replace("-", ""), "Directory date differs from source date")
    report_cases = []
    all_source_paths = set()
    for row in selected:
        cid = row["case_id"]
        definition = definitions[cid]
        art = ROOT / "dataset_artifacts" / cid
        code = ROOT / "dataset" / cid
        metadata = load(art / "case_metadata.json")
        provenance = load(art / "provenance.json")
        check(metadata["original_rows"] == row["original_rows"], "Metadata row mismatch")
        check((art / metadata["source_qualification_scope"]).resolve() == BASE / "scope-confirmation.json", "Source qualification scope missing or inconsistent")
        check((art / metadata["necessary_code_coverage"]).resolve() == BASE / "source-coverage.md", "Source coverage missing or inconsistent")
        check(metadata["event_date"] == row["event_date"] and metadata["public_original_vulnerable_source"], "Wrong date/source qualification")
        check(metadata["victims"] == definition["victims"], "Victim roles differ")
        malicious = set(x.lower() for x in re.findall(r"0x[a-fA-F0-9]{40}", row["fields"]["malicious_address"]))
        check(not malicious.intersection(a.lower() for a in metadata["victims"]), "Copied an attacker address into the victim field")
        expected_paths = set()
        for package in provenance["source_packages"]:
            raw = art / package["response_path"]
            check(sha(raw) == package["response_sha256"], "Source response hash mismatch")
            data = load(raw)
            retrieval = load(raw.parent / "retrieval.json")
            check(sha(raw) == retrieval["sha256"], "Downloaded bytes no longer match retrieval hash")
            check(data["runtimeMatch"] in ("match", "exact_match"), "Provider did not verify runtime")
            check(len(package["source_files"]) == len(data["sources"]), "Incomplete original source package")
            for source in package["source_files"]:
                path = ROOT / source["path"]
                expected = data["sources"][source["original_path"]]["content"].encode("utf-8")
                check(path.read_bytes() == expected, "Original source bytes changed: " + source["path"])
                check(sha(path) == source["sha256"], "Source file hash mismatch")
                check(len(expected.splitlines()) == source["lines"], "Source line inventory mismatch")
                expected_paths.add(path.resolve())
                all_source_paths.add(path.resolve())
        actual_paths = {p.resolve() for p in code.rglob("*") if p.is_file()}
        check(actual_paths == expected_paths, "Unarchived dependency or extra code in case")
        check(len(expected_paths) == metadata["source_file_count"], "Source count is not from current provenance")
        for evidence in provenance["evidence"]:
            check(sha(art / evidence["path"]) == evidence["sha256"], "Evidence bytes changed")
        checksummed = set()
        for line in (art / "SHA256SUMS").read_text("utf-8").splitlines():
            digest, name = line.split("  ", 1)
            check(sha(art / name) == digest, "Case checksum mismatch: " + name)
            checksummed.add((art / name).resolve())
        expected_checksums = expected_paths | {p.resolve() for p in art.rglob("*")
                                               if p.is_file() and p.name != "SHA256SUMS"}
        check(checksummed == expected_checksums, "Checksum manifest omits or adds case files")
        document = check_document(ROOT / "docs/cases" / (cid + ".md"))
        document["source_readme_local_links"] = check_links(art / "SOURCE.md")
        report_cases.append({"case_id": cid, "sheet_rows": row["original_rows"],
            "source_files": len(expected_paths), **document})
    csv_counts = {}
    for language, divisor in [("cn", Decimal(10000)), ("en", Decimal(1000))]:
        path = ROOT / f"ai-auditing-benchmark_{language}.csv"
        previous = (BASE / "baseline" / path.name).read_bytes()
        current = path.read_bytes()
        check(current.startswith(previous), "Existing CSV bytes/order/encoding changed")
        old = list(csv.reader(io.StringIO(previous.decode("utf-8-sig"), newline="")))
        new = list(csv.reader(io.StringIO(current.decode("utf-8-sig"), newline="")))
        check(all(len(r) == 7 for r in new), "CSV no longer has seven columns")
        check(new[:len(old)] == old, "Old CSV records differ")
        ordered = sorted(selected, key=lambda r: (r["event_date"], r["case_id"]))
        expected = []
        for row in ordered:
            case = definitions[row["case_id"]]
            meta = load(ROOT / "dataset_artifacts" / row["case_id"] / "case_metadata.json")
            amount = "" if case["loss_usd"] is None else format(Decimal(case["loss_usd"]) / divisor, "f")
            expected.append([row["event_date"].replace("-", "."), case["project_"+language],
                case["vulnerability_"+language], case["detail_"+language],
                "\n".join(meta["tx_urls"]), "\n".join(meta["vulnerable_contract_urls"]), amount])
        check(new[len(old):] == ([] if before_append else expected), "New CSV rows/units/order differ from selected cases")
        csv_counts[language] = {"baseline": len(old)-1, "current": len(new)-1, "new": len(new)-len(old)}
    # Historical source binding is distinct from provider verification and source acquisition.
    historical = {}
    for label, filename in definitions["20261024_X100"]["sources"]:
        source = load(BASE / filename)
        historic = BASE / "screening/row22" / ("historical-code-" + source["address"].lower() + ".json")
        value = load(historic)["result"]
        check(value.lower() == source["runtimeBytecode"]["onchainBytecode"].lower(), "X100 historical code mismatch")
        request = load(historic.with_name(historic.name + ".http.json"))["request_body"]
        check(request["params"][1] == load(BASE / "screening/row22/receipt-official.json")["result"]["blockNumber"], "Historical request used the wrong block")
        historical[label] = {"matches": True, "bytes": (len(value)-2)//2}
    pair_source = load(BASE / definitions["20261022_NEM"]["sources"][1][1])
    pair_current = load(BASE / "screening/row26/current-pair-code.json")["result"]
    check(pair_current == pair_source["runtimeBytecode"]["onchainBytecode"], "NEM current reference runtime mismatch")
    # The exact baseline protects unrelated cases, not just the files listed in git diff.
    permitted_tracked = {"ai-auditing-benchmark_cn.csv", "ai-auditing-benchmark_en.csv", "docs/cases/README.md"}
    untouched = 0
    for name, digest in baseline["tracked_sha256"].items():
        if name not in permitted_tracked:
            check((ROOT / name).exists() and sha(ROOT / name) == digest, "Out-of-scope baseline change: " + name)
            untouched += 1
    untracked = subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard", "-z"], cwd=ROOT).decode().split("\0")
    permitted_prefixes = [BASE.relative_to(ROOT).as_posix() + "/"]
    permitted_prefixes += ["dataset/" + cid + "/" for cid in ids]
    permitted_prefixes += ["dataset_artifacts/" + cid + "/" for cid in ids]
    permitted_documents = {"docs/cases/" + cid + ".md" for cid in ids}
    for name in untracked:
        if name:
            check(name in permitted_documents or any(name.startswith(prefix) for prefix in permitted_prefixes), "Out-of-scope new file: " + name)
    # The final report is created after validation; exclude only that forward link.
    batch_readme = (BASE / "README.md").read_text("utf-8").replace("[验证报告](validation.json)", "验证报告")
    report_links = check_links(BASE / "README.md", batch_readme)
    index = ROOT / "docs/cases/README.md"
    new_index = index.read_text("utf-8").split("## 2026-10-26", 1)[0]
    new_index = new_index.replace("[验证报告](batches/20261110_latest5/validation.json)", "验证报告")
    report_links += check_links(index, new_index)
    report_links += check_links(BASE / "source-coverage.md")
    report_links += check_links(BASE / "review-resolution.md")
    return {"status": "pre_append_passed" if before_append else "passed", "fixed_target": result["fixed_target"],
        "latest_event_date": snapshot["latest_event_date"], "raw_sha256": snapshot["raw_sha256"],
        "scan_order": result["scan_order"], "scanned": len(result["rows"]),
        "new_cases": ids, "new_case_count": len(ids), "source_file_count": len(all_source_paths),
        "skipped": sum(r["status"] == "skipped" for r in result["rows"]),
        "existing_duplicates": sum(r["status"] == "duplicate_existing" for r in result["rows"]),
        "pending_dates": len(snapshot["pending_date_rows"]), "csv": csv_counts,
        "cases": report_cases, "x100_historical_runtime_checks": historical,
        "nem_pair_runtime_check": "CURRENT runtime exact equality; attack-time binding not established",
        "unrelated_tracked_files_unchanged": untouched, "new_file_scope_checked": True,
        "report_and_new_index_local_links": report_links,
        "source_qualification": "necessary defect/permission/payment code complete under explicit user confirmation in scope-confirmation.json; pure orchestration/recipient internals remain unverified",
        "compilation": "not_run", "deployment": "not_run", "fork_replay": "not_run",
        "decompilation": "not_used; local prohibited, no official online output archived",
        "trace_coverage": "three X100 complete call trees; other four cases have receipts but no complete call trace",
        "limits": "Offline structural/hash/arithmetic checks do not constitute attack replay, local compilation or complete historical-state verification."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--before-append", action="store_true")
    args = parser.parse_args()
    report = validate(args.before_append)
    filename = "pre-append-validation.json" if args.before_append else "validation.json"
    (BASE / filename).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", "utf-8")
    print(json.dumps({k: report[k] for k in ("status", "new_case_count", "scanned", "skipped", "existing_duplicates", "source_file_count", "csv", "unrelated_tracked_files_unchanged")}, ensure_ascii=False))
