# Independent read-only review package

Repository: D:/code/vibe-coding/ai-auditing-benchmark/ai-auditing-benchmark
Baseline HEAD and current HEAD: 921ac86312dca74cdf6dda8786890b539b0aeb37 (all task changes uncommitted).

## Scope and authority

The user requested execution of supplied_plan.txt with X=112,Y=5 and dataset source only. Later amendment: decompilation must be online on an official or authoritative site; local decompilation prohibited; skip an incident if required unverified core/link code has no usable online decompilation result. No local decompiler ran. LULA was skipped after the BscScan official online result remained empty, with DOM/screenshot archived.

The fixed export SHA-256 is dc2c5338c964434d780f49bf215d112ec0bb06ee24cad24a12435bf5453ea794. It contains 1057 parsed records, row 1 explanation, row 2 headers, 14 columns. Scan rows 112 down to 88: 5 admitted rows (101,100,98,90,88), 20 skipped. All 5 cases are new. See snapshot.json, results.json and cases.json for exact records.

## Deliverables to inspect

- docs/cases/20260803_MOKE.md
- docs/cases/20260804_NEX_AIC.md
- docs/cases/20260810_USM_FUM.md
- docs/cases/20260817_Fox.md
- docs/cases/20260820_Allbridge_CCTP.md
- Matching complete and simplified source directories in dataset, with mirrored provenance, case_metadata, SOURCE.md, ABI, compiler inputs, SHA256SUMS, slice_manifest and evidence in dataset_artifacts.
- Both root CSVs have 5 appended records each, old bytes unchanged; docs/cases/README.md and both root README counts updated.
- docs/cases/sources/validate_20261021_batch.py and test_20261021_batch.py, plus batch helpers build_batch.py, inspect_evidence.py and finalize_batch.py.

## Review focus

This is a data/source curation review, not a contract repair. Do not edit any file, run contracts, compile, replay, decompile locally, stage, commit, push or spawn another agent. Inspect from disk; no network is necessary. Existing final validation.json has passed. Do not treat passing structural checks as semantic proof.

For each admitted case, deliberately check:

1. Core vulnerable original source really exists and is not patched/reconstructed code masquerading as historical source.
2. Simplification retains permissions, relevant state, formulas, parent balance writes, input checks and the actual payout path. Exact source slices may not be standalone compilable, but cannot omit a causal transition.
3. Chinese prose and both CSVs explain normal business, defect, reachable preconditions, steps, and funds flow with correct roles. Logs vs full trace vs inference vs historical state are clearly distinguished.
4. MOKE has 64 identical old LP records and one smaller record, all current LP=0, not 65 identical ones. Decoded evidence and both language descriptions were corrected against raw receipts.
5. NEX raw transfers at indices 9 and 10, reserve0=1 and the final AIC outflow support the double-debit mechanism. Neither router nor standard pair is falsely blamed.
6. USM has full raw trace, 1 fund and 64 defund, net pool outflow 70.830977367697708372 ETH. No unsupported claim of external oracle manipulation or locally executed counterfactual/replay.
7. Fox historical proxy implementation slots failed with missing trie node. Source at the reported implementation is present, but historical equality is not claimed. Distinguish pool loss, attack-contract multi-asset gains and locked bond face value.
8. Allbridge's body sender differs semantically from authenticated header sender; its mapping credit leads to Router payout and six-decimal USDC. Router's relayer-or-self-recipient restriction and usedMessages matter. Public Circle current implementation is context, not attack-time implementation proof.
9. Loss values: four CSV loss fields blank because dollar values/scopes conflict; Allbridge retains the source sheet's approximate USD 191000, distinct from Router net USDC loss 190155.976393 and profit 189751.554381.
10. Selection skips remain justified, especially PRO missing original exec code, LULA no online result, and Swan valid signed order without a confirmed contract-code bypass. Do not relax the admission gate just to reach Y.

Read-only verification command if useful (bundled Python):

`python -X utf8 -B docs/cases/sources/validate_20261021_batch.py`

Report actual Critical/Important/Minor findings with exact file:line and supporting evidence. Include a list of anything deliberately set aside as outside scope, and a clear readiness verdict. Do not spend effort on cosmetic refactors of one-off research utilities.
