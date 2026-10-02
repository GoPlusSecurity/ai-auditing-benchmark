from __future__ import annotations

import csv
import io
import json
import sys
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))

import validate_20261002_batch as batch  # noqa: E402


HEADER = ["timestamp", *[f"column_{i}" for i in range(1, 13)], "attack_analysis"]


def records_through(last_row: int) -> list[list[str]]:
    records = [["Explanation", *([""] * 13)], HEADER]
    for row in range(3, last_row + 1):
        records.append([f"event-{row}", *([""] * 13)])
    return records


def decision(row: int, qualifies: bool, case_id: str | None = None) -> dict:
    item = {
        "row": row,
        "qualifies": qualifies,
        "reason": "qualifies" if qualifies else "skip",
        "source_qualification": "public_original_source" if qualifies else "not_applicable",
    }
    if case_id is not None:
        item["case_id"] = case_id
    return item


class SelectionRuleTests(unittest.TestCase):
    def test_y_one_selects_starting_row(self):
        processed, selected = batch.select_qualifying_rows(
            records_through(8), 8, 1, [decision(8, True, "case-8")]
        )
        self.assertEqual(processed, [8])
        self.assertEqual([item["row"] for item in selected], [8])

    def test_ineligible_start_and_consecutive_skips_continue_upward(self):
        decisions = [
            decision(8, False),
            decision(7, False),
            decision(6, True, "case-6"),
            decision(5, False),
            decision(4, True, "case-4"),
        ]
        processed, selected = batch.select_qualifying_rows(records_through(8), 8, 2, decisions)
        self.assertEqual(processed, [8, 7, 6, 5, 4])
        self.assertEqual([item["row"] for item in selected], [6, 4])

    def test_row_three_is_valid_lower_boundary(self):
        processed, selected = batch.select_qualifying_rows(
            records_through(3), 3, 1, [decision(3, True, "case-3")]
        )
        self.assertEqual(processed, [3])
        self.assertEqual(selected[0]["case_id"], "case-3")

    def test_last_parsed_row_is_valid_upper_boundary(self):
        records = records_through(9)
        processed, _ = batch.select_qualifying_rows(
            records, len(records), 1, [decision(9, True, "case-9")]
        )
        self.assertEqual(processed, [9])

    def test_non_integer_x_or_y_is_rejected_including_bool(self):
        records = records_through(8)
        for bad_x in ("8", 8.0, True):
            with self.subTest(x=bad_x), self.assertRaises(batch.ValidationError):
                batch.select_qualifying_rows(records, bad_x, 1, [])
        for bad_y in ("1", 1.0, True):
            with self.subTest(y=bad_y), self.assertRaises(batch.ValidationError):
                batch.select_qualifying_rows(records, 8, bad_y, [])

    def test_non_positive_y_is_rejected(self):
        for bad_y in (0, -1):
            with self.subTest(y=bad_y), self.assertRaises(batch.ValidationError):
                batch.select_qualifying_rows(records_through(8), 8, bad_y, [])

    def test_x_must_name_an_event_row_inside_the_export(self):
        records = records_through(8)
        for bad_x in (1, 2, 9):
            with self.subTest(x=bad_x), self.assertRaises(batch.ValidationError):
                batch.select_qualifying_rows(records, bad_x, 1, [])

    def test_y_cannot_exceed_rows_available_through_x(self):
        with self.assertRaises(batch.ValidationError):
            batch.select_qualifying_rows(records_through(4), 4, 3, [])

    def test_insufficient_qualifying_rows_raises(self):
        decisions = [decision(5, False), decision(4, True, "only-one"), decision(3, False)]
        with self.assertRaisesRegex(batch.ValidationError, "only 1 qualifying rows"):
            batch.select_qualifying_rows(records_through(5), 5, 2, decisions)

    def test_missing_or_non_boolean_decision_fails_closed(self):
        with self.assertRaisesRegex(batch.ValidationError, "missing qualification decision"):
            batch.select_qualifying_rows(records_through(5), 5, 1, [])
        bad = decision(5, False)
        bad["qualifies"] = "yes"
        with self.assertRaisesRegex(batch.ValidationError, "boolean qualification"):
            batch.select_qualifying_rows(records_through(5), 5, 1, [bad])

    def test_duplicate_case_ids_still_count_as_two_qualifying_rows(self):
        decisions = [decision(5, True, "same-case"), decision(4, True, "same-case")]
        processed, selected = batch.select_qualifying_rows(records_through(5), 5, 2, decisions)
        self.assertEqual(processed, [5, 4])
        self.assertEqual([item["case_id"] for item in selected], ["same-case", "same-case"])

    def test_embedded_csv_newline_is_one_parsed_sheet_row(self):
        stream = io.StringIO(newline="")
        writer = csv.writer(stream, lineterminator="\r\n")
        writer.writerow(["Explanation", *([""] * 13)])
        writer.writerow(HEADER)
        writer.writerow(["line one\nline two", *([""] * 13)])
        parsed = list(csv.reader(io.StringIO(stream.getvalue(), newline="")))
        self.assertGreater(len(stream.getvalue().splitlines()), len(parsed))
        processed, _ = batch.select_qualifying_rows(
            parsed, 3, 1, [decision(3, True, "multiline-case")]
        )
        self.assertEqual(processed, [3])


class FormalBatchArtifactTests(unittest.TestCase):
    def test_saved_batch_recomputes_to_expected_selection(self):
        report = batch.main()
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["parameters"], {"x": 116, "y": 5})
        self.assertEqual(report["qualifying_source_rows"], [113, 110, 108, 107, 106])
        self.assertTrue(report["checks"]["selection_rule_recomputed_from_raw_export"])

    def test_only_successful_panoramix_assembly_is_archived(self):
        complete = ROOT / "dataset" / "benchmark_complete" / "20260711_Bonzo_Supra"
        simplified = ROOT / "dataset" / "benchmark_simplified" / "20260711_Bonzo_Supra"
        evidence = complete / "evidence"
        run = json.loads((evidence / "bonzo-panoramix-run.json").read_text("utf-8"))
        self.assertEqual([item["path"] for item in run["outputs"]], ["bonzo-panoramix-disassembly.asm"])
        self.assertFalse(
            any(token in key.lower() for key in run["tool"] for token in ("commit", "revision"))
        )
        self.assertNotIn("compatibility_changes", run)
        all_files = [path for root in (complete, simplified) for path in root.rglob("*") if path.is_file()]
        forbidden_extensions = [
            path for path in all_files if path.suffix.lower() in {".pan", ".patch", ".diff"}
        ]
        self.assertEqual(forbidden_extensions, [])
        panoramix_json = sorted(
            path.name
            for path in all_files
            if "panoramix" in path.name.lower() and path.suffix.lower() == ".json"
        )
        self.assertEqual(panoramix_json, ["bonzo-panoramix-run.json"])

    def test_bonzo_standard_input_contains_only_solidity_sources(self):
        bundle = (
            ROOT
            / "dataset"
            / "benchmark_complete"
            / "20260711_Bonzo_Supra"
            / "source-bundles"
            / "xdc-reference"
        )
        standard_input = json.loads((bundle / "standard-input.json").read_text("utf-8"))
        self.assertEqual(len(standard_input["sources"]), 18)
        self.assertTrue(all(name.endswith(".sol") for name in standard_input["sources"]))
        self.assertNotIn("settings.json", standard_input["sources"])
        self.assertEqual(
            standard_input["settings"],
            json.loads((bundle / "settings.json").read_text("utf-8")),
        )


if __name__ == "__main__":
    unittest.main()
