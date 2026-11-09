"""Materialize only the five events selected by the sealed snapshot results."""
import argparse
import csv
from decimal import Decimal
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil

from batch import append_csv, parse_export, select_rows

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path, base):
    return Path(os.path.relpath(path, base)).as_posix()


def dump(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", "utf-8")


def checked_results(base=BASE):
    scope = base / "scope-confirmation.json"
    if (not scope.exists() or json.loads(scope.read_text("utf-8")).get("status")
            != "explicitly_confirmed_by_user"):
        raise ValueError("Source scope is not explicitly confirmed; no official writes")
    snapshot = json.loads((base / "snapshot.json").read_text("utf-8"))
    raw = (base / "sheet_gid0_raw.csv").read_bytes()
    ordered, invalid = parse_export(raw)
    if hashlib.sha256(raw).hexdigest() != snapshot["raw_sha256"]:
        raise ValueError("Raw snapshot hash changed; no official writes")
    if ordered != snapshot["ordered_rows"] or invalid != snapshot["pending_date_rows"]:
        raise ValueError("Snapshot no longer represents its raw CSV; no official writes")
    results = json.loads((base / "results.json").read_text("utf-8"))
    existing = json.loads((base / "existing_events.json").read_text("utf-8"))["events"]
    replay = select_rows(ordered, {r["original_row"]: r for r in results["rows"]}, existing)
    if (not replay["ready"] or replay["scan_order"] != results["scan_order"]
            or [r["case_id"] for r in replay["selected"]] != [r["case_id"] for r in results["selected"]]):
        raise ValueError("Sealed decisions are not five ordered new qualified events; no official writes")
    return results


def materialize(case, selected):
    cid = selected["case_id"]
    code = ROOT / "dataset" / cid
    art = ROOT / "dataset_artifacts" / cid
    records = []
    packages = []
    for label, name in case["sources"]:
        response = BASE / name
        data = json.loads(response.read_text("utf-8"))
        if not data.get("sources") or data.get("runtimeMatch") not in ("match", "exact_match"):
            raise ValueError("No provider-verified original source: " + name)
        http = response.with_name(response.name + ".http.json")
        origin = json.loads(http.read_text("utf-8"))
        bundle = art / "source-bundles" / label
        bundle.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(response, bundle / "source-response.json")
        shutil.copyfile(http, bundle / "retrieval.json")
        for key, filename in [("stdJsonInput", "standard-input.json"), ("compilation", "compiler-settings.json"),
                              ("metadata", "metadata.json"), ("abi", "abi.json")]:
            dump(bundle / filename, data.get(key))
        files = []
        for original_path, value in data["sources"].items():
            target = (code / label / original_path).resolve()
            if not target.is_relative_to(code.resolve()):
                raise ValueError(original_path)
            # Only original source belongs in dataset; no code is reformatted or patched.
            target.parent.mkdir(parents=True, exist_ok=True)
            original = value["content"].encode("utf-8")
            if target.exists() and target.read_bytes() != original:
                raise ValueError("Refusing to overwrite a different source: " + str(target))
            target.write_bytes(original)
            entry = {"path": target.relative_to(ROOT).as_posix(), "original_path": original_path,
                "sha256": sha(target), "bytes": len(original),
                "lines": len(value["content"].splitlines()), "kind": "public_original_source"}
            files.append(entry)
            records.append(entry)
        packages.append({"label": label, "kind": "public_original_source", "url": origin["url"],
            "retrieved_at": origin["retrieved_at"], "timezone": origin["timezone"],
            "response_path": relative(bundle / "source-response.json", art),
            "response_sha256": sha(bundle / "source-response.json"),
            "chain_id": data["chainId"], "address": data["address"],
            "compiler": data.get("compilation"), "provider_runtime_match": data.get("runtimeMatch"),
            "provider_creation_match": data.get("creationMatch"), "provider_verified_at": data.get("verifiedAt"),
            "provider_deployment": data.get("deployment"),
            "provider_current_proxy_resolution": data.get("proxyResolution"),
            "historical_implementation_warning": "Current provider resolution is not proof of attack-time implementation.",
            "source_files": files})
    evidence = []
    for name in case["evidence"]:
        path = BASE / name
        target = art / "evidence" / path.name
        if not path.exists():
            raise ValueError("Missing evidence: " + name)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        provenance = {"path": relative(target, art), "sha256": sha(target),
            "batch_original": name, "kind": "archived_public_response_or_offline_derivative"}
        http = path.with_name(path.name + ".http.json")
        if http.exists():
            meta = json.loads(http.read_text("utf-8"))
            shutil.copyfile(http, target.with_name(target.name + ".http.json"))
            provenance.update(url=meta["url"], retrieved_at=meta["retrieved_at"], request_body=meta.get("request_body"))
        evidence.append(provenance)
    metadata = {k: v for k, v in case.items() if k not in ("sources", "evidence", "explorer", "group")}
    metadata.update(event_date=selected["event_date"], original_rows=selected["original_rows"],
        source_sheet_snapshot=relative(BASE / "snapshot.json", art),
        batch_results=relative(BASE / "results.json", art),
        source_qualification_scope=relative(BASE / "scope-confirmation.json", art),
        necessary_code_coverage=relative(BASE / "source-coverage.md", art),
        case_document=f"../../docs/cases/{cid}.md",
        code_root=relative(code, art), source_status="original_verified_source",
        source_provenance_kind="original_verified_source", source_provenance="provenance.json",
        public_original_vulnerable_source=True,
        tx_urls=[case["explorer"] + "/tx/" + h for h in selected["identity"]["transactions"]],
        vulnerable_contract_urls=[case["explorer"] + "/address/" + a + "#code" for a in case["victims"]],
        verification_status={"source": "original source, provider-reported runtime/creation matches; no local recompile",
            "historical_code": ("three core historical runtimes match provider onchain bytecode at attack block" if cid == "20261024_X100" else "not independently established; see evidence_gaps"),
            "historical_state": "only specific archived observations; no complete pre-attack state reconstruction",
            "receipts": "successful archived transaction receipts and decoded asset movements/events",
            "trace": ("three full archived X100 attack traces" if cid == "20261024_X100" else "no full internal trace; archived receipts and source-based interpretation only"),
            "compilation": "not_run", "deployment": "not_run", "fork_replay": "not_run",
            "decompilation": "not_used; official online output unavailable where essential, those candidates skipped"},
        local_compilation="not_run", deployment="not_run", fork_replay="not_run", transactions_sent=False,
        upstream_scripts_executed=False, source_file_count=len(records))
    dump(art / "case_metadata.json", metadata)
    dump(art / "provenance.json", {"case_id": cid, "snapshot_sha256": selected.get("raw_sha256"),
        "source_packages": packages, "evidence": evidence,
        "source_vs_deployment_vs_state": "Acquisition, provider verification, historical binding and historical state are separate claims.",
        "no_decompiler_output": True})
    dump(art / "source-files.json", records)
    (art / "SOURCE.md").write_text(f"# {cid}\n\n"
        f"- [完整原始源码]({relative(code, art)})\n"
        f"- [中文案例说明](../../docs/cases/{cid}.md)\n"
        f"- [来源和响应哈希](provenance.json)\n- [逐文件原码哈希与行数](source-files.json)\n"
        f"- [固定快照]({relative(BASE / 'snapshot.json', art)})\n"
        f"- [逐行筛选结果]({relative(BASE / 'results.json', art)})\n\n"
        f"- [用户确认的来源范围]({relative(BASE / 'scope-confirmation.json', art)})\n"
        f"- [必要代码逐包覆盖]({relative(BASE / 'source-coverage.md', art)})\n\n"
        "所有源码文件均按提供方返回的原始内容归档，未修补逻辑、未为编译改写。每个来源包分别保存完整编译输入、设置、ABI和原始响应。\n\n"
        "公开原码取得与提供方验证，不代表历史部署、代理路由及攻击前状态已经完全核实。具体界限见 case_metadata.json 和案例正文。"
        "没有将未知编排合约或字节码标为原始源码，也没有自写反编译替代。\n\n"
        "本批没有本地编译、部署、上游脚本执行、分叉重放或发送链上交易。各包可使用不同编译器、依赖路径和设置，"
        "不能直接把所有来源包合成一个项目编译；本批未验证独立构建。\n", "utf-8")
    checksum_lines = []
    for path in sorted(art.rglob("*")):
        if path.is_file() and path.name != "SHA256SUMS":
            checksum_lines.append(f"{sha(path)}  {relative(path, art)}")
    for path in sorted(code.rglob("*")):
        if path.is_file():
            checksum_lines.append(f"{sha(path)}  {relative(path, art)}")
    (art / "SHA256SUMS").write_text("\n".join(checksum_lines) + "\n", "utf-8")
    return {"case_id": cid, "source_files": len(records), "source_packages": len(packages), "evidence_files": len(evidence)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--append-csv", action="store_true")
    args = parser.parse_args()
    results = checked_results()
    definitions = {x["case_id"]: x for x in json.loads((BASE / "cases.json").read_text("utf-8"))}
    selected = results["selected"]
    if not results.get("ready") or len(selected) != results["fixed_target"] or results["fixed_target"] != 5:
        raise SystemExit("Five-case gate is closed; no official writes")
    if any(not x["public_original_vulnerable_source"] for x in selected):
        raise SystemExit("Missing vulnerable original source; no official writes")
    if args.append_csv:
        ordered = sorted(selected, key=lambda x: (x["event_date"], x["case_id"]))
        for row in ordered:
            document = ROOT / "docs/cases" / (row["case_id"] + ".md")
            if not document.exists() or "```mermaid" not in document.read_text("utf-8"):
                raise SystemExit("Missing reviewed case document/diagram: " + str(document))
        for language, divisor in [("cn", Decimal(10000)), ("en", Decimal(1000))]:
            new_rows = []
            for row in ordered:
                case = definitions[row["case_id"]]
                metadata = json.loads((ROOT / "dataset_artifacts" / row["case_id"] / "case_metadata.json").read_text("utf-8"))
                loss = "" if case["loss_usd"] is None else format(Decimal(case["loss_usd"]) / divisor, "f")
                new_rows.append([row["event_date"].replace("-", "."), case["project_"+language],
                    case["vulnerability_"+language], case["detail_"+language],
                    "\n".join(metadata["tx_urls"]), "\n".join(metadata["vulnerable_contract_urls"]), loss])
            changed = append_csv(ROOT / f"ai-auditing-benchmark_{language}.csv", results, new_rows)
            print(language, "appended" if changed else "already present")
    else:
        summaries = []
        for row in selected:
            row["raw_sha256"] = results["raw_sha256"]
            summaries.append(materialize(definitions[row["case_id"]], row))
        dump(BASE / "archive-summary.json", summaries)
        print(json.dumps(summaries, ensure_ascii=False))
