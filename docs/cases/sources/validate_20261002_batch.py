#!/usr/bin/env python3
"""Validate the X=116, Y=5 batch from its fixed snapshot and row results."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from decimal import Decimal
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RESULTS_PATH = HERE / "20261002_sheet_rows_106_116_results.json"
SNAPSHOT_PATH = HERE / "20261002_sheet_rows_106_116.json"
SEMANTIC_REVIEW_PATH = HERE / "20261002_semantic_review.json"


class ValidationError(RuntimeError):
    """Raised when a saved batch artifact violates the batch contract."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path):
    return json.loads(path.read_text("utf-8"))


def check_sums(base: Path) -> int:
    sums = base / "SHA256SUMS"
    entries = []
    for line in sums.read_text("utf-8").splitlines():
        digest, relative = line.split("  ", 1)
        target = base / relative
        require(target.is_file(), f"missing SHA256SUMS target: {target}")
        require(sha256(target) == digest, f"hash mismatch: {target}")
        entries.append(relative)
    actual = sorted(
        p.relative_to(base).as_posix()
        for p in base.rglob("*")
        if p.is_file() and p.name != "SHA256SUMS"
    )
    require(sorted(entries) == actual, f"SHA256SUMS inventory mismatch: {base}")
    return len(entries)


def validate_local_links(markdown: Path) -> int:
    checked = 0
    for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", markdown.read_text("utf-8")):
        if target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        local = target.split("#", 1)[0]
        resolved = (markdown.parent / local).resolve()
        require(resolved.exists(), f"broken local link in {markdown}: {target}")
        checked += 1
    return checked


def validate_inline_file_references(markdown: Path) -> int:
    checked = 0
    text = markdown.read_text("utf-8")
    pattern = r"`((?:evidence|source-bundles|slices)/[^`\s]+|(?:provenance|case_metadata|slice_manifest)\.json)`"
    for target in re.findall(pattern, text):
        resolved = markdown.parent / target
        require(resolved.is_file(), f"missing inline file reference in {markdown}: {target}")
        checked += 1
    return checked


def read_csv(path: Path) -> list[list[str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.reader(handle))


def validate_sheet_structure(records: list[list[str]]) -> list[str]:
    require(len(records) >= 3, "sheet must contain explanation, header and an event")
    require(len(records[0]) == 14, "sheet explanation row must contain 14 parsed cells")
    require(all(not cell for cell in records[0][1:]), "sheet row 1 no longer matches the contract")
    header = records[1]
    require(len(header) == 14, "sheet header must contain 14 columns")
    require(header[0] == "timestamp" and header[-1] == "attack_analysis", "unexpected sheet header")
    return header


def select_qualifying_rows(records, x, y, decisions):
    """Apply the physical-record selection rule without writing any artifacts."""

    validate_sheet_structure(records)
    require(type(x) is int, "X must be an integer")
    require(type(y) is int, "Y must be an integer")
    require(y >= 1, "Y must be at least 1")
    require(3 <= x <= len(records), "X must identify a parsed event row")
    require(y <= x - 2, "Y exceeds the rows available from row 3 through X")

    by_row = {}
    for decision in decisions:
        row = decision.get("row")
        require(type(row) is int and row not in by_row, f"invalid or duplicate decision row: {row!r}")
        by_row[row] = decision

    processed = []
    selected = []
    for row in range(x, 2, -1):
        require(row in by_row, f"missing qualification decision for scanned row {row}")
        decision = by_row[row]
        require(type(decision.get("qualifies")) is bool, f"row {row} has no boolean qualification")
        require(bool(decision.get("reason")), f"row {row} has no disposition reason")
        processed.append(row)
        if decision["qualifies"]:
            require(bool(decision.get("case_id")), f"qualifying row {row} has no case id")
            require(
                decision.get("source_qualification") not in {None, "", "not_applicable"},
                f"qualifying row {row} has no public-source qualification",
            )
            selected.append(decision)
            if len(selected) == y:
                return processed, selected
    raise ValidationError(
        f"only {len(selected)} qualifying rows found from row {x} through row 3; required {y}"
    )


def unique_preserving_order(values):
    seen = set()
    result = []
    for value in values:
        if value not in seen:
            seen.add(value)
            result.append(value)
    return result


def resolve_declared_file(base: Path, relative: str, label: str) -> Path:
    require(isinstance(relative, str) and relative, f"{label} has an empty path")
    require("://" not in relative, f"{label} must be a local path: {relative}")
    resolved = (base / relative).resolve()
    try:
        resolved.relative_to(ROOT.resolve())
    except ValueError as exc:
        raise ValidationError(f"{label} escapes the repository: {relative}") from exc
    require(resolved.is_file(), f"{label} does not resolve to a file: {relative}")
    return resolved


def validate_source_reference(base: Path, record: dict, label: str) -> Path:
    path = resolve_declared_file(base, record["path"], label)
    require(sha256(path) == record["sha256"], f"{label} hash mismatch: {path}")
    require(len(path.read_bytes()) == record["bytes"], f"{label} size mismatch: {path}")
    return path


def validate_panoramix_run(run_path: Path, artifact: dict, runtime: Path) -> int:
    run = load_json(run_path)
    require(run["tool"]["repository"] == "https://github.com/eveem-org/panoramix", "wrong decompiler repository")
    require("git_commit" not in run["tool"], "Panoramix commit must not be archived")
    require("compatibility_changes" not in run, "temporary compatibility changes must not be archived")
    require("compatibility_patch" not in run, "temporary compatibility patch must not be archived")
    require(run["input"]["runtime_sha256"] == sha256(runtime), "Panoramix input hash mismatch")
    require(run["input"]["runtime_bytes"] == len(runtime.read_bytes()), "Panoramix input size mismatch")
    require(run["input"]["target_selector"] == artifact["target_selector"], "target selector mismatch")
    require(
        any(item["result"] == "manually_terminated_no_convergence" for item in run["runs"]),
        "Panoramix non-convergence is not retained",
    )
    checked = 0
    require(
        len(run["outputs"]) == 1 and run["outputs"][0]["path"].endswith(".asm"),
        "only the successful Panoramix disassembly may be archived",
    )
    for output in run["outputs"]:
        path = resolve_declared_file(run_path.parent, output["path"], "Panoramix output")
        require(sha256(path) == output["sha256"], f"Panoramix output hash mismatch: {path}")
        require(len(path.read_bytes()) == output["bytes"], f"Panoramix output size mismatch: {path}")
        checked += 1
    disassembly = resolve_declared_file(
        run_path.parent, "bonzo-panoramix-disassembly.asm", "Panoramix disassembly"
    ).read_text("utf-8")
    require("push4, 0x2818300e" in disassembly, "target selector missing from disassembly")
    require(bool(run.get("evidence_boundary")), "Panoramix evidence boundary missing")
    return checked


def validate_machine_references(case_root: Path, metadata: dict) -> int:
    checked = 0
    source = metadata["source_verification"]
    expected_base = "simplified_case_root" if metadata.get("view") else "complete_case_root"
    require(source.get("path_base") == expected_base, f"wrong path_base in {case_root}")
    for record in source["source_files"]:
        validate_source_reference(case_root, record, "source file")
        checked += 1
    if "compiler_settings" in source:
        validate_source_reference(case_root, source["compiler_settings"], "compiler settings")
        checked += 1
    if "runtime_comparison" in source:
        resolve_declared_file(case_root, source["runtime_comparison"], "runtime comparison")
        checked += 1
    for artifact in source.get("closed_source_chain_artifacts", []):
        runtime = resolve_declared_file(case_root, artifact["runtime_path"], "closed-source runtime")
        require(sha256(runtime) == artifact["runtime_sha256"], "closed-source runtime hash mismatch")
        require(len(runtime.read_bytes()) == artifact["runtime_bytes"], "closed-source runtime size mismatch")
        status = artifact.get("decompilation_status")
        if status == "partial_disassembly_complete_target_pseudocode_not_converged":
            require(
                artifact.get("decompiled_output") is None,
                "failed Panoramix pseudocode must not be archived",
            )
            require("structured_output" not in artifact, "failed Panoramix JSON must not be archived")
            require("compatibility_patch" not in artifact, "temporary compatibility patch must not be archived")
            for field in ("disassembly_output", "run_record"):
                resolve_declared_file(case_root, artifact[field], f"decompiler {field}")
                checked += 1
            run_path = resolve_declared_file(case_root, artifact["run_record"], "decompiler run record")
            checked += validate_panoramix_run(run_path, artifact, runtime)
        elif artifact.get("decompiled_output") is None:
            require(
                status == "not_run_no_approved_decompiler_available",
                "missing decompiler output must retain the approved-tool limitation",
            )
        else:
            resolve_declared_file(case_root, artifact["decompiled_output"], "decompiler output")
            checked += 1
        checked += 1
    return checked


def validate_transaction_summary(summary_path: Path) -> int:
    summary = load_json(summary_path)
    require(
        summary.get("rpc_path_base") == "transaction_summary_parent",
        f"transaction summary has no explicit path base: {summary_path}",
    )
    for relative in summary["rpc_files"]:
        resolve_declared_file(summary_path.parent, relative, "archived transaction evidence")
    return len(summary["rpc_files"])


def validate_standard_input(complete: Path, provenance: dict) -> int:
    candidates = list(complete.rglob("standard-input.json"))
    require(len(candidates) == 1, f"expected one standard-input.json in {complete}")
    standard_input = load_json(candidates[0])
    require(standard_input.get("language") == "Solidity", f"wrong compiler language: {candidates[0]}")
    require(isinstance(standard_input.get("settings"), dict), f"missing settings: {candidates[0]}")
    sources = standard_input.get("sources")
    require(isinstance(sources, dict) and sources, f"missing sources: {candidates[0]}")
    require("settings.json" not in sources, f"settings treated as source: {candidates[0]}")
    require(all(name.endswith(".sol") for name in sources), f"non-Solidity compiler source: {candidates[0]}")
    by_original = {record["original_source_path"]: record for record in provenance["source_files"]}
    require(set(sources) == set(by_original), f"standard input/provenance mismatch: {complete}")
    for original_path, payload in sources.items():
        require(isinstance(payload.get("content"), str), f"source has no content: {original_path}")
        archived = resolve_declared_file(complete, by_original[original_path]["path"], "compiler source")
        require(
            archived.read_bytes().decode("utf-8") == payload["content"],
            f"source differs: {original_path}",
        )
    if provenance.get("compiler_settings"):
        settings_path = validate_source_reference(
            complete, provenance["compiler_settings"], "compiler settings"
        )
        require(load_json(settings_path) == standard_input["settings"], "compiler settings differ")
    return len(sources)


def main() -> dict:
    results = load_json(RESULTS_PATH)
    snapshot = load_json(SNAPSHOT_PATH)
    semantic_review = load_json(SEMANTIC_REVIEW_PATH)
    raw_path = HERE / results["parameters"]["raw_export"]
    expected_hash = results["parameters"]["raw_export_sha256"]
    require(sha256(raw_path) == expected_hash, "raw export hash mismatch")
    require(snapshot["raw_export_sha256"] == expected_hash, "snapshot/export hash mismatch")

    parsed = read_csv(raw_path)
    header = validate_sheet_structure(parsed)
    require(len(parsed) == snapshot["parsed_record_count"], "parsed record count mismatch")
    require(header == snapshot["header"], "snapshot header mismatch")

    x = results["parameters"]["x"]
    y = results["parameters"]["y"]
    processed_rows, selected = select_qualifying_rows(parsed, x, y, results["rows"])
    require(processed_rows == results["parameters"]["processing_order"], "processing order mismatch")
    require(
        [item["row"] for item in selected] == results["parameters"]["selected_source_rows"],
        "selected rows mismatch",
    )
    require(
        results["parameters"]["actual_scan_range"] == [processed_rows[-1], processed_rows[0]],
        "actual scan range mismatch",
    )
    require([item["row"] for item in snapshot["rows"]] == processed_rows, "snapshot coverage mismatch")
    for item in snapshot["rows"]:
        expected = {"row": item["row"], **dict(zip(header, parsed[item["row"] - 1]))}
        require(item == expected, f"snapshot row mismatch: {item['row']}")

    selected_case_ids = [item["case_id"] for item in selected]
    case_ids = unique_preserving_order(selected_case_ids)
    included = results["included_cases"]
    require([item["case_id"] for item in included] == case_ids, "included case inventory mismatch")
    for item in included:
        expected_rows = [
            decision["row"] for decision in selected if decision["case_id"] == item["case_id"]
        ]
        require(item["source_rows"] == expected_rows, f"source-row aggregation mismatch: {item['case_id']}")

    counts = results["counts"]
    require(counts["scanned_rows"] == len(processed_rows), "scanned count mismatch")
    require(counts["qualifying_source_rows"] == len(selected) == y, "qualifying count mismatch")
    require(counts["skipped_rows"] == len(processed_rows) - len(selected), "skipped count mismatch")
    require(
        counts["duplicate_rows_merged"] == len(selected_case_ids) - len(case_ids),
        "duplicate-row count mismatch",
    )
    require(
        counts["new_cases"] + counts["completed_existing_cases"] == len(case_ids),
        "included case count mismatch",
    )

    semantic_cases = {item["case_id"]: item for item in semantic_review["cases"]}
    require(semantic_review["status"] == "reviewed", "semantic review is not complete")
    require(set(semantic_cases) == set(case_ids), "semantic review inventory mismatch")

    cn_rows = read_csv(ROOT / "ai-auditing-benchmark_cn.csv")
    en_rows = read_csv(ROOT / "ai-auditing-benchmark_en.csv")
    require(len(cn_rows[0]) == len(en_rows[0]) == 7, "CSV schema is not seven columns")

    required_headings = [
        "## 1. 背景和正常业务",
        "## 2. 正常逻辑和角色",
        "## 3. 漏洞到底是什么",
        "## 4. 利用条件",
        "## 5. 攻击步骤",
        "## 6. 钱为什么能流出",
        "## 7. 多个缺陷与外部合约",
        "## 8. 攻击流程图",
        "## 9. 证据、影响与限制",
    ]

    source_files = 0
    sum_entries = 0
    slices = 0
    local_links = 0
    inline_file_references = 0
    standard_input_sources = 0
    semantic_literals = 0
    machine_references = 0
    csv_positions = {"cn": [], "en": []}
    for case_id in case_ids:
        complete = ROOT / "dataset" / "benchmark_complete" / case_id
        simplified = ROOT / "dataset" / "benchmark_simplified" / case_id
        document = ROOT / "docs" / "cases" / f"{case_id}.md"
        require(
            complete.is_dir() and simplified.is_dir() and document.is_file(),
            f"missing case artifact: {case_id}",
        )
        metadata = load_json(complete / "case_metadata.json")
        simplified_metadata = load_json(simplified / "case_metadata.json")
        require(
            metadata["folder"] == simplified_metadata["folder"] == case_id,
            f"folder mismatch: {case_id}",
        )
        require(
            metadata["public_original_vulnerable_source"] is True,
            f"case is not backed by a public original vulnerable source: {case_id}",
        )
        require(
            metadata["original_rows"]
            == next(item["source_rows"] for item in included if item["case_id"] == case_id),
            f"metadata source rows mismatch: {case_id}",
        )
        require(
            metadata["verification_status"]["fork_replay"] == "not_run",
            f"unsupported replay claim: {case_id}",
        )
        require(
            metadata["verification_status"]["local_compilation"] == "not_run",
            f"unsupported compilation claim: {case_id}",
        )
        paired_fields = [
            "folder",
            "date",
            "project_cn",
            "project_en",
            "vulnerability_cn",
            "vulnerability_en",
            "detail_cn",
            "detail_en",
            "tx_urls",
            "vulnerable_contract_urls",
            "loss_usd",
            "original_rows",
            "source_sheet_snapshot",
            "batch_results",
            "verification_status",
        ]
        for field in paired_fields:
            require(
                metadata[field] == simplified_metadata[field],
                f"complete/simplified metadata mismatch for {case_id}: {field}",
            )

        provenance = load_json(complete / "provenance.json")
        require(
            metadata["source_verification"] == provenance,
            f"complete metadata/provenance mismatch: {case_id}",
        )
        for source in provenance["source_files"]:
            validate_source_reference(complete, source, "public Solidity source")
            source_files += 1
        standard_input_sources += validate_standard_input(complete, provenance)
        machine_references += validate_machine_references(complete, metadata)
        machine_references += validate_machine_references(simplified, simplified_metadata)
        machine_references += validate_transaction_summary(
            complete / "evidence" / "transaction-summary.json"
        )
        machine_references += validate_transaction_summary(
            simplified / "evidence" / "transaction-summary.json"
        )

        manifest = load_json(simplified / "slice_manifest.json")
        require(manifest, f"empty slice manifest: {case_id}")
        manifest_paths = [item["path"] for item in manifest]
        slice_text_by_path = {}
        for item in manifest:
            full = resolve_declared_file(complete, item["complete_path"], "complete source slice")
            short = resolve_declared_file(simplified, item["path"], "simplified source slice")
            full_lines = full.read_bytes().splitlines(keepends=True)
            start = item["original_start_line"]
            end = item["original_end_line"]
            require(
                type(start) is int and type(end) is int and 1 <= start <= end <= len(full_lines),
                f"invalid slice range in {case_id}: {item['path']}",
            )
            expected = b"".join(
                full_lines[start - 1 : end]
            )
            require(short.read_bytes() == expected, f"slice is not byte-exact: {short}")
            require(sha256(short) == item["sha256"], f"slice hash mismatch: {short}")
            slice_text_by_path[item["path"]] = short.read_text("utf-8")
            slices += 1

        semantic_case = semantic_cases[case_id]
        require(bool(semantic_case.get("status")), f"semantic status missing: {case_id}")
        require(
            sorted(semantic_case["reviewed_slice_paths"]) == sorted(manifest_paths),
            f"semantic review does not cover every slice: {case_id}",
        )
        require(
            bool(semantic_case.get("manual_conclusion")),
            f"semantic conclusion missing: {case_id}",
        )
        reviewed_text = "\n".join(
            slice_text_by_path[path] for path in semantic_case["reviewed_slice_paths"]
        )
        for element in semantic_case["required_path_elements"]:
            require(bool(element.get("role")), f"semantic role missing: {case_id}")
            literal = element.get("literal")
            require(
                isinstance(literal, str) and literal in reviewed_text,
                f"required causal element missing from slices for {case_id}: {literal!r}",
            )
            semantic_literals += 1

        sum_entries += check_sums(complete)
        sum_entries += check_sums(simplified)
        text = document.read_text("utf-8")
        for heading in required_headings:
            require(heading in text, f"missing heading in {document}: {heading}")
        require("```mermaid" in text, f"missing Mermaid flowchart: {document}")
        require("源码能够确认的机制" in text, f"missing source evidence boundary: {document}")
        require("交易中观察到的行为" in text, f"missing transaction evidence boundary: {document}")
        require("由证据推断的部分" in text, f"missing inference evidence boundary: {document}")
        require("尚未核实" in text, f"missing unverified evidence boundary: {document}")
        local_links += validate_local_links(document)
        local_links += validate_local_links(complete / "SOURCE.md")
        local_links += validate_local_links(simplified / "SOURCE.md")
        inline_file_references += validate_inline_file_references(complete / "SOURCE.md")
        inline_file_references += validate_inline_file_references(simplified / "SOURCE.md")

        date = metadata["date"]
        project_cn = metadata["project_cn"]
        project_en = metadata["project_en"]
        cn_match = [
            (position, row)
            for position, row in enumerate(cn_rows[1:], start=1)
            if len(row) == 7 and row[:2] == [date, project_cn]
        ]
        en_match = [
            (position, row)
            for position, row in enumerate(en_rows[1:], start=1)
            if len(row) == 7 and row[:2] == [date, project_en]
        ]
        require(len(cn_match) == len(en_match) == 1, f"CSV row count mismatch: {case_id}")
        cn_position, cn_row = cn_match[0]
        en_position, en_row = en_match[0]
        require(
            cn_row[:6]
            == [
                date,
                project_cn,
                metadata["vulnerability_cn"],
                metadata["detail_cn"],
                metadata["tx_urls"][0],
                metadata["vulnerable_contract_urls"][0],
            ],
            f"Chinese CSV detail mismatch: {case_id}",
        )
        require(
            en_row[:6]
            == [
                date,
                project_en,
                metadata["vulnerability_en"],
                metadata["detail_en"],
                metadata["tx_urls"][0],
                metadata["vulnerable_contract_urls"][0],
            ],
            f"English CSV detail mismatch: {case_id}",
        )
        loss = Decimal(str(metadata["loss_usd"]))
        require(Decimal(cn_row[6]) == loss / Decimal(10000), f"Chinese loss mismatch: {case_id}")
        require(Decimal(en_row[6]) == loss / Decimal(1000), f"English loss mismatch: {case_id}")
        csv_positions["cn"].append((cn_position, case_id))
        csv_positions["en"].append((en_position, case_id))

    expected_csv_order = sorted(
        case_ids,
        key=lambda case_id: (
            load_json(ROOT / "dataset" / "benchmark_complete" / case_id / "case_metadata.json")[
                "date"
            ],
            case_id,
        ),
    )
    for language in ("cn", "en"):
        actual_csv_order = [case_id for _, case_id in sorted(csv_positions[language])]
        require(
            actual_csv_order == expected_csv_order,
            f"{language} CSV rows are not in chronological order",
        )

    for index in [ROOT / "README.md", ROOT / "README_cn.md", ROOT / "docs" / "cases" / "README.md"]:
        index_text = index.read_text("utf-8")
        for case_id in case_ids:
            require(
                case_id in index_text or f"{case_id}.md" in index_text,
                f"case missing from index {index}: {case_id}",
            )

    bonzo_provenance = load_json(
        ROOT / "dataset" / "benchmark_complete" / "20260711_Bonzo_Supra" / "provenance.json"
    )
    bonzo_closed = bonzo_provenance.get("closed_source_chain_artifacts", [])
    require(len(bonzo_closed) == 1, "Bonzo closed-source attack-time runtime is not recorded")
    require(
        bonzo_closed[0]["decompiled_output"] is None
        and bonzo_closed[0]["decompilation_status"]
        == "partial_disassembly_complete_target_pseudocode_not_converged",
        "Bonzo partial Panoramix result is not represented exactly",
    )

    return {
        "status": "passed",
        "parameters": {"x": results["parameters"]["x"], "y": results["parameters"]["y"]},
        "actual_scan_range": results["parameters"]["actual_scan_range"],
        "qualifying_source_rows": results["parameters"]["selected_source_rows"],
        "case_ids": case_ids,
        "checks": {
            "selection_rule_recomputed_from_raw_export": True,
            "raw_export_sha256": expected_hash,
            "snapshot_rows_compared_to_raw_csv": len(snapshot["rows"]),
            "public_solidity_source_files_hashed": source_files,
            "standard_input_source_entries_checked": standard_input_sources,
            "exact_slices_compared": slices,
            "semantic_path_elements_checked": semantic_literals,
            "machine_readable_file_references_checked": machine_references,
            "sha256sum_entries_checked": sum_entries,
            "local_markdown_links_checked": local_links,
            "inline_file_references_checked": inline_file_references,
            "bilingual_csv_rows_checked": len(case_ids) * 2,
            "documents_with_required_sections_and_mermaid": len(case_ids),
        },
        "unresolved_evidence_gaps": [
            {
                "case_id": "20260711_Bonzo_Supra",
                "gap": "Panoramix disassembled the 13,293-byte Hedera attack-time runtime, but full-contract and selector 0x2818300e symbolic execution did not converge to high-level pseudocode.",
            }
        ],
        "not_claimed": {
            "local_compilation": "not run",
            "fork_replay": "not run",
            "complete_historical_state_reconstruction": "not run",
            "closed_source_attack_time_runtime_decompilation": "full-runtime disassembly and selector recovery only; target high-level pseudocode not recovered",
            "full_internal_trace": "only Hedera actions for Bonzo were archived; other cases use receipts plus public analyses",
        },
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = main()
    rendered = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_bytes(rendered.encode("utf-8"))
    print(rendered, end="")
