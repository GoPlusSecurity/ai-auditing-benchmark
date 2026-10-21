# ai-auditing-benchmark

A benchmark dataset for **AI smart-contract auditing**. It curates and extracts **vulnerable contract source code** from real-world historical exploits caused by smart-contract vulnerabilities, intended for evaluating and training auditing capabilities (e.g., used together with tools like `ai-auditing-engine`).

## Data sources and goals

- **Sources**: Publicly available on-chain / security incident reports and repository snapshots, corresponding to contracts exploited or found defective in each incident.
- **Goals**:
  - Provide **real vulnerable samples** that are reproducible and comparable.
  - Support evaluating AI auditing performance against the full vulnerable-contract context from historical incidents.

## Directory structure

Only source code lives under `dataset/`; ABI and all other supporting material live under the matching `dataset_artifacts/` tree. Both are organized by incident. Each incident directory name follows: `{IncidentDateYYYYMMDD}_{ProjectOrProtocolSlug}` (date first, to make sorting and searching easier).

```
dataset/
└── {IncidentDateYYYYMMDD}_{ProjectOrProtocolSlug}/    # Full code of the exploited contracts (incl. deps/libs)

dataset_artifacts/
├── {IncidentDateYYYYMMDD}_{ProjectOrProtocolSlug}/    # Metadata, provenance, evidence, compiler inputs and checksums
└── batches/                                           # Batch snapshots and validation records
```

`dataset/` contains `.sol`, `.rs`, `.cairo`, `.pan`, `.ts`, `.cpp` and `.h` source, including previously archived decompiled code, project test source and necessary source-chain context. ABI files live at the corresponding paths under `dataset_artifacts/`. Other supporting files formerly at `dataset/{case}/{path}` are now at `dataset_artifacts/{case}/{path}`. Source paths and bytes are unchanged. Build manifests, lockfiles, recovery tools and compiler inputs are in the artifacts tree; combine the matching trees in a temporary directory when a build needs the original snapshot layout.

Case-relative metadata paths, including `complete_case_root`, use the corresponding artifacts case directory. Source references cross to `../../dataset/{case}/...`; repository-root-relative paths retain their existing meaning. Each `SHA256SUMS` in an artifacts case covers both that case's supporting files and its source files.

The source directories contain the **full source tree** of the exploited contracts (including interfaces, libraries, third-party dependencies, etc.), useful for:
  - Cross-contract and cross-module interaction analysis
  - Audit workflows that require a full call graph and state-flow context

## Incident index (CSV)

The CSV in the repository root lists **all indexed incidents**, including cases with supporting evidence but no source code, and should be treated as the authoritative source of metadata. After the 2026-10-16 batch, each CSV has 57 incidents and the source directory has 56 cases. See the [case-document index](docs/cases/README.md) and [row dispositions](dataset_artifacts/batches/20261016_x123_y5/results.json) for the latest batch. JaredFromSubway has runtime bytecode and evidence only, stored entirely in `dataset_artifacts/`.

- Chinese: [`ai-auditing-benchmark_cn.csv`](ai-auditing-benchmark_cn.csv)
- English: [`ai-auditing-benchmark_en.csv`](ai-auditing-benchmark_en.csv)

Both CSVs describe the same incidents; field language and loss units differ. Column meanings:

- **Attack date**: Incident date (`YYYY.MM.DD`).
- **Project**: The exploited project or protocol (the display name may differ slightly from the directory slug, e.g., with `@` or parenthetical notes).
- **Vulnerability**: A short description of the vulnerability type.
- **Vulnerability details**: The exploit technique and defect description.
- **Attack transaction**: Representative on-chain transaction hash.
- **Vulnerable contract address**: Related contract address(es) (may span multiple lines within a cell).
- **Loss**: Reported or estimated loss amount, in 10,000 USD units in the Chinese CSV and 1,000 USD units in the English CSV.

**Mapping to directory names**: Incident folder names under `dataset/` use `{IncidentDateYYYYMMDD}_{ProjectOrProtocolSlug}`. The date is derived from **Attack date** as an 8-digit number (e.g., `2025.05.28` → `20250528`). `{ProjectOrProtocolSlug}` corresponds to the **Project** column and is typically a filesystem-safe slug in lowercase/camel case (e.g., `@Corkprotocol` in the table maps to `20250528_Corkprotocol`). If the **Project** column includes extra notes (e.g., addresses in parentheses), the directory name usually still uses a short protocol identifier; the actual folder names in the repo are authoritative.

Source-tree paths vary by incident. Browse within the corresponding directory by subproject / contract name.

## Quick start (locate code by incident)

1. Find the target row in the CSV (by **Attack date / Project**).
2. Convert **Attack date** to `YYYYMMDD`, and combine it with the project slug: `{YYYYMMDD}_{ProjectSlug}`.
3. Open `dataset/{dir}/...` for the full audit context.
4. Read `dataset_artifacts/{dir}/SOURCE.md` and `case_metadata.json`, where available, for provenance and source-status limits.

Example: `2025.05.28` + `@Corkprotocol` → `dataset/20250528_Corkprotocol/`

The 2026-09-14 sheet rows 98–102 are documented in a [five-row snapshot](docs/cases/sources/20260914_sheet_rows_98_102.json) and [five Chinese case explanations](docs/cases/README.md). ATM and the non-contract SecondFi wallet incident were removed from the dataset and both CSV indexes; their documents and supporting evidence remain under docs/cases. This batch now contributes three dataset entries: DLMC, Royalties, and Taiko. Taiko distinguishes verified SGX source from upstream context. Check source_status and SOURCE.md in each case's dataset_artifacts directory before selecting audit inputs.

The 2026-10-02 `X=116, Y=5` batch scans parsed sheet rows 116 down through 106 and selects source rows 113, 110, 108, 107 and 106: [`20260709_BFB`](docs/cases/20260709_BFB.md), [`20260711_Bonzo_Supra`](docs/cases/20260711_Bonzo_Supra.md), [`20260713_PHX`](docs/cases/20260713_PHX.md), [`20260713_Lumi_Sodium`](docs/cases/20260713_Lumi_Sodium.md) and [`20260714_VECAndETH`](docs/cases/20260714_VECAndETH.md). The [fixed 11-row snapshot](docs/cases/sources/20261002_sheet_rows_106_116.json) is bound to raw-export SHA-256 `862e92ed5b738acce956be4d560e1e5f747375a92839debc3eb7ec7cc00c5b90`; [row decisions](docs/cases/sources/20261002_sheet_rows_106_116_results.json) explain six skips. All five cases have public vulnerable original source. BFB is a Sourcify match; PHX, Lumi/Sodium and VECAndETH are Sourcify exact matches. Bonzo/Supra archives original Supra source with the same defective verifier path plus Hedera attack actions, while explicitly marking XDC-to-Hedera runtime/source equivalence unverified. Transactions and receipts/actions were checked; no local compilation or fork replay was run.

The 2026-10-01 sheet rows 114–118 contribute one new entry, [`20260701_EdelFinance_decompiled`](dataset_artifacts/20260701_EdelFinance_decompiled/SOURCE.md). The full 74-logical-line Etherscan Palkeoramix/Panoramix output for the price adapter is retained, and its 3,577-byte input matches `eth_getCode` at attack block 25434062. Verified AaveOracle and wGOOGLx source provide the surrounding price path. This is explicitly decompiled pseudocode, not verified original Solidity; no compilation, source-equivalence proof, or fork replay is claimed. Conflicting public USD scopes remain unresolved, so both CSV loss fields are blank.

[Chinese case explanations](docs/cases/README.md) describe each system's purpose, defect, attack sequence, asset flow, and evidence limits. The 2026-09-10 import follows that date's sheet rows 99–103: JaredFromSubway, BnbLabubu, Namada, Axelar / Secret, and mySwap. A [source-row snapshot](docs/cases/sources/20260910_sheet_rows_99_103.json) preserves the mapping as sheet rows can move.

This batch includes Rust protocol code and incident evidence for which victim source has not been obtained. Each case's `dataset_artifacts/{case}/case_metadata.json` exposes `source_status`; missing victim source or incomplete historical-transaction correlation must be filtered before treating the entry as a verified exploit-code sample. Unknown transaction/address fields remain blank and are explained in the CSV. Chinese loss values use 10,000 USD units; English loss values use 1,000 USD units.

mySwap CL now includes the historically executed on-chain Sierra class, with its class hash verified. Its `decompiled_sierra` status distinguishes the recovered SSA / pseudo-Cairo code from verified original Cairo: the archive retains 425 functions covering the attack entries and their internal dependencies. [Case documentation](docs/cases/20260619_mySwap.md) links the recovered checks to the raw RPC trace; no local Cairo recompilation or exploit replay is claimed.

JaredFromSubway now includes the victim's full 13,835-byte EVM runtime, as `.hex` and `.bin`. Block-hash-pinned reads at attack block 25360696 and preceding block 25360695 match. Status `runtime_bytecode_only` distinguishes these machine-code inputs from original Solidity or decompiled source, which remain unavailable. [Bytecode provenance](dataset_artifacts/20260621_JaredFromSubway/bytecode.json) records the address, block hashes, raw RPC evidence and checksums.

## Suggested usage with AI auditing engines

1. **Regression**: For each incident, run the audit prompts/pipeline on `dataset/{case}` and record detection rate, false positives, and cost.
2. **Release checks**: Use the same full-context inputs for the checks that gate a release.

## License and disclaimer

- Code snippets in this repository come from publicly available project sources or incident-related public materials; **copyright belongs to the original authors**. They are provided solely for security research and benchmark evaluation.
- Vulnerable code can be **destructive**. Do not use it for illegal purposes. If you use this dataset in papers or products, please cite the dataset name and the version/commit information.

## Contributing and updates

Issues and PRs are welcome for adding new incidents or fixing paths. For new entries, please add the case under `dataset/` and `dataset_artifacts/` **and update** the CSV metadata ([`ai-auditing-benchmark_cn.csv`](ai-auditing-benchmark_cn.csv), [`ai-auditing-benchmark_en.csv`](ai-auditing-benchmark_en.csv)). In your PR, briefly describe the incident source and the vulnerability type.
