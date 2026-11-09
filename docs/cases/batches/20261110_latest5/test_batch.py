import csv
import io
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import batch
import analyze
import build


HEADER = ["timestamp", "target (社媒 or Addr)", "description", "data_source",
          "original_link", "date", "lost", "lost_u", "malicious_tx",
          "malicious_address", "malicious_url", "malicious_social_account",
          "attack_category", "attack_analysis"]


def export(records, header=HEADER):
    out = io.StringIO(newline="")
    w = csv.writer(out)
    w.writerow(["说明"] + [""] * 13)
    w.writerow(header)
    for record in records:
        w.writerow([record.get(k, "") for k in header])
    return out.getvalue().encode("utf-8")


def record(row, date, name=None):
    return {"original_row": row, "event_date": date,
            "fields": {"target (社媒 or Addr)": name or str(row)}}


def accept(row, tx=None, victim=None, chain=56):
    return {"original_row": row, "status": "accepted", "qualifies": True,
            "case_id": f"case_{row}", "public_original_vulnerable_source": True,
            "identity": {"chain_id": chain, "transactions": [tx or f"tx_{row}"],
                         "victims": [victim or f"victim_{row}"],
                         "event_date": "2026-11-01"}, "reason": "original source and causal path checked"}


class ScreeningTests(unittest.TestCase):
    def test_multiline_cells_do_not_change_sheet_row_numbers(self):
        rows, invalid = batch.parse_export(export([
            {"date": "2026-11-01", "description": 'a, "b"\n第二行'},
            {"date": "2026-11-02"}]))
        self.assertEqual([r["original_row"] for r in rows], [4, 3])
        self.assertEqual(rows[1]["fields"]["description"], 'a, "b"\n第二行')
        self.assertEqual(invalid, [])

    def test_unsorted_dates_and_same_day_use_date_then_original_row(self):
        rows, _ = batch.parse_export(export([{"date": "2026-10-30"},
            {"date": "2026-11-02"}, {"date": "2026-11-01"}, {"date": "2026-11-02"}]))
        self.assertEqual([r["original_row"] for r in rows], [4, 6, 5, 3])

    def test_invalid_and_missing_dates_are_pending_and_not_selected(self):
        rows, invalid = batch.parse_export(export([{"date": ""},
            {"date": "2026-02-30"}, {"date": "2026-11-01"}]))
        self.assertEqual([r["original_row"] for r in rows], [5])
        self.assertEqual([r["original_row"] for r in invalid], [3, 4])

    def test_wrong_header_or_missing_note_rejected_before_selection(self):
        with self.assertRaises(ValueError):
            batch.parse_export(export([], header=list(reversed(HEADER))))
        with self.assertRaises(ValueError):
            batch.parse_export((",".join(HEADER) + "\n").encode())

    def test_newest_skips_and_existing_events_do_not_fill_five_places(self):
        rows = [record(i, f"2026-11-{12-i:02d}") for i in range(3, 11)]
        decisions = {3: {"status": "skipped", "qualifies": False, "reason": "key theft"},
                     4: accept(4, tx="old"), **{i: accept(i) for i in range(5, 11)}}
        result = batch.select_rows(rows, decisions, [{"case_id": "old_case", "identity":
            {"chain_id": 56, "transactions": ["old"], "victims": [], "event_date": "2026-11-01"}}])
        self.assertEqual([x["original_row"] for x in result["selected"]], [5, 6, 7, 8, 9])
        self.assertEqual([x["original_row"] for x in result["rows"]], [3, 4, 5, 6, 7, 8, 9])
        self.assertEqual(result["rows"][1]["status"], "duplicate_existing")
        self.assertTrue(result["ready"])

    def test_same_transaction_under_different_names_is_one_event(self):
        rows = [record(i, "2026-11-01", name) for i, name in
                [(3, "AAA"), (4, "BBB"), (5, "CCC"), (6, "DDD"), (7, "EEE"), (8, "FFF")]]
        decisions = {i: accept(i, tx="shared" if i in (3, 4) else None) for i in range(3, 9)}
        result = batch.select_rows(rows, decisions)
        self.assertEqual([x["original_row"] for x in result["selected"]], [3, 5, 6, 7, 8])
        self.assertEqual(result["selected"][0]["original_rows"], [3, 4])
        self.assertEqual(result["rows"][1]["status"], "duplicate_batch")

    def test_same_victim_date_chain_is_duplicate_but_name_alone_is_not(self):
        rows = [record(i, "2026-11-01", "SAME") for i in range(3, 10)]
        decisions = {i: accept(i, victim="same" if i in (3, 4) else None) for i in range(3, 10)}
        result = batch.select_rows(rows, decisions)
        self.assertEqual([x["original_row"] for x in result["selected"]], [3, 5, 6, 7, 8])

    def test_uninvestigated_row_blocks_later_acceptance(self):
        result = batch.select_rows([record(i, "2026-11-01") for i in range(3, 10)],
                                   {i: accept(i) for i in range(4, 10)})
        self.assertFalse(result["ready"])
        self.assertEqual(result["selected"], [])
        self.assertEqual(result["rows"][0]["status"], "pending")

    def test_source_only_decompiled_or_postfix_cannot_qualify(self):
        d = accept(3)
        d["public_original_vulnerable_source"] = False
        result = batch.select_rows([record(3, "2026-11-01")], {3: d})
        self.assertFalse(result["ready"])
        self.assertEqual(result["selected"], [])

    def test_insufficient_batch_and_bad_structure_write_nothing(self):
        result = batch.select_rows([record(i, "2026-11-01") for i in range(3, 7)],
                                   {i: accept(i) for i in range(3, 7)})
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "index.csv"
            p.write_bytes(b"a,b,c,d,e,f,g\r\n")
            original = p.read_bytes()
            with self.assertRaises(ValueError):
                batch.append_csv(p, result, [["x"] * 7] * 4)
            self.assertEqual(p.read_bytes(), original)

    def test_csv_append_preserves_prefix_newlines_and_is_idempotent(self):
        result = batch.select_rows([record(i, "2026-11-01") for i in range(3, 8)],
                                   {i: accept(i) for i in range(3, 8)})
        new = [[f"event{i}", 'quoted, "cell"\nline', "", "", "", "", ""] for i in range(5)]
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "index.csv"
            original = b"a,b,c,d,e,f,g\r\n"
            p.write_bytes(original)
            batch.append_csv(p, result, new)
            first = p.read_bytes()
            self.assertTrue(first.startswith(original))
            self.assertEqual(len(list(csv.reader(io.StringIO(first.decode())))), 6)
            batch.append_csv(p, result, new)
            self.assertEqual(p.read_bytes(), first)

    def test_distinct_same_name_same_date_event_is_not_dropped_on_append(self):
        result = batch.select_rows([record(i, "2026-11-01") for i in range(3, 8)],
                                   {i: accept(i) for i in range(3, 8)})
        new = [["2026.11.01", "Shared" if i == 0 else f"event{i}", "", "", f"newtx{i}", f"victim{i}", ""] for i in range(5)]
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "index.csv"
            p.write_text("a,b,c,d,e,f,g\n2026.11.01,Shared,,,oldtx,oldvictim,\n", "utf-8")
            batch.append_csv(p, result, new)
            self.assertEqual(len(list(csv.reader(io.StringIO(p.read_text())))), 7)


class EvidenceDecodingTests(unittest.TestCase):
    def test_pool_event_schemas_work_without_investigation_cache(self):
        relative = Path("dataset/20261101_PremiaV3/pool-core/contracts/pool/IPoolEvents.sol")
        source = (analyze.ROOT / relative).read_bytes()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            delivered = root / relative
            delivered.parent.mkdir(parents=True)
            delivered.write_bytes(source)
            with mock.patch.object(analyze, "ROOT", root):
                events = analyze.pool_events()
            trade = next(e for e in events if e["name"] == "Trade")
            self.assertEqual(trade["inputs"][2]["type"], "tuple")
            self.assertIn("ClaimFees", {e["name"] for e in events})

    def test_static_tuple_does_not_shift_later_event_amounts(self):
        event = {"name": "Trade", "inputs": [
            {"name": "delta", "type": "tuple", "components": [
                {"name": "collateral", "type": "int256"},
                {"name": "longs", "type": "int256"},
                {"name": "shorts", "type": "int256"}]},
            {"name": "premium", "type": "uint256"}]}
        data = "0x" + "".join(f"{v % (1 << 256):064x}" for v in [-3, 4, 0, 5])
        actual = analyze.decode({"topics": ["0x00"], "data": data,
                                  "logIndex": "0x20", "address": "pool"}, event)
        self.assertEqual(actual["values"], {"delta": {"collateral": "-3", "longs": "4", "shorts": "0"}, "premium": "5"})

    def test_large_raw_amount_is_not_rounded_through_float(self):
        self.assertEqual(analyze.scalar(f"{726307101124801946565030:064x}", "uint256"),
                         "726307101124801946565030")


class QualificationGateTests(unittest.TestCase):
    def test_unconfirmed_or_missing_scope_blocks_official_writes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ("snapshot.json", "sheet_gid0_raw.csv", "results.json", "existing_events.json"):
                (root / name).write_bytes((build.BASE / name).read_bytes())
            with self.assertRaisesRegex(ValueError, "scope"):
                build.checked_results(root)
            (root / "scope-confirmation.json").write_text('{"status":"not_confirmed"}', "utf-8")
            with self.assertRaisesRegex(ValueError, "scope"):
                build.checked_results(root)


if __name__ == "__main__":
    unittest.main()
