# Execution ledger — plan: user amos → tz merge, 2026-10-27

Task 1: complete. Backed up 2715 files / 97849535 bytes; 776 new original source files; committed all 1919 local changes as abee605182854ba42b846f5674903f89a386d8f1. Raw staged blobs checked with git cat-file --batch, zero byte mismatches.

Task 2: fetched origin via C:/Windows/System32/OpenSSH/ssh.exe; origin/amos = 14920dcd252a0f9dee40453f4b6e885708979f78. Formal --no-ff --no-commit merge active.

Ruling: Work on the current tz checkout, as explicitly requested; no extra branch/worktree. Merge and commits are already authorized.
Ruling: Use amos as the full old-content baseline and restore only the specified nine cases, two new batches, and their docs/tools from the verified byte backup. This preserves all old amos case blobs and prevents tz legacy files from overriding amos. Risk is an omitted new path; final inventory comparison covers every backed-up file.
Ruling: Preserve historical snapshots, raw downloads, original validation reports and script originals in a byte-exact ZIP; adapt only current paths, indexes and active tools. No network evidence collection, upstream execution, compilation or replay.

Tasks remaining: migrate; adapt active tools; verify working tree/index/final tree; independent final review; local merge commit without push.

Task 2: complete. amos baseline restored; nine complete case trees flattened; original simplified payloads removed only after byte backup. CSV is byte-exact amos prefix plus nine reviewed records.
Task 3: complete. Current docs, metadata, provenance, batch builders/finalizers/validators adapted; .vy supported; old histories, failures and raw evidence remain immutable. .gitattributes disables text conversion for archive/data/docs paths.
Task 4: complete. 5 migration tests pass; 39 offline batch/selector/preservation tests pass; disposable-copy build/finalize/repeat integration test passes. Migration manifest accounts for every 2715 backed-up files; 776 sources unchanged; 252 new-case simplified files explicitly removed/archived; all 2572 old-case files equal amos blobs.
Final review: independent read-only reviewer found two Important maintenance issues (stale batch checksums, derived-inventory self-ingestion). Both reproduced RED and fixed GREEN in test_flat_tools.py; acquisition-time mislabelling was treated as an evidence-quality issue and fixed in the same pass. No declined judgments or deferred minors.
Ruling: Preserve historical batch scope evidence while adapting the old 20261016 validator to permit later appended records/cases and unrelated later-batch untracked paths. Existing rows, source bytes and batch membership remain checked; this merge's separate whole-tree tests enforce its complete scope. Cost if wrong would be overlooked additions; Git tree verification checks every delivery path.
Verification finding: Git stat caching retained CRLF worktree bytes in LICENSE and the 20260910 sheet snapshot despite restore. Materialized exact amos blobs for these two unchanged tracked files; recorded hashes in amos-working-tree-materialization.json. No historical source content was rewritten.
Remaining: final raw index blob comparison, local merge commit, then final raw commit blob/ancestry/cleanliness verification. No push.

Task 5 precommit gate: complete. Current full layout passes (839 local links, 2023 JSON references, 3612 SHA entries at report snapshot, zero preserved historical-source hash differences). First staged snapshot checks 5225 raw Git blobs against physical bytes; no unmerged or untracked paths. Final audit reports are now being staged; repeat raw-index verification before committing, and raw-commit/ancestry/cleanliness verification afterwards. The postcommit receipt must remain outside its own commit to avoid a self-referential commit hash.
