# ai-auditing-benchmark

A benchmark dataset for **AI smart-contract auditing**. It curates and extracts **vulnerable contract source code** from real-world historical exploits caused by smart-contract vulnerabilities, intended for evaluating and training auditing capabilities (e.g., used together with tools like `ai-auditing-engine`).

## Data sources and goals

- **Sources**: Publicly available on-chain / security incident reports and repository snapshots, corresponding to contracts exploited or found defective in each incident.
- **Goals**:
  - Provide **real vulnerable samples** that are reproducible and comparable.
  - Support evaluating AI auditing performance at two granularities: **full context** and **reduced attack surface**.

## Directory structure

Data lives under `dataset/` and is organized by incident. Each incident directory name follows: `{IncidentDateYYYYMMDD}_{ProjectOrProtocolSlug}` (date first, to make sorting and searching easier).

```
dataset/
├── benchmark_complete/    # Full code of the exploited contracts (incl. deps/libs), as close as possible to an auditable/compilable snapshot
└── benchmark_simplified/  # Only vulnerability-related functions + minimal required deps; obviously irrelevant logic removed
```

### `benchmark_complete`

- Contains the **full source tree** of the exploited contracts (including interfaces, libraries, third-party dependencies, etc.), useful for:
  - Cross-contract and cross-module interaction analysis
  - Audit workflows that require a full call graph and state-flow context

### `benchmark_simplified`

- Based on the code for the **same incident**, it **keeps only the vulnerable functions** (and the minimal dependencies required for compilation and semantic understanding) and **removes functions unrelated to the vulnerability**, for:
  - **Reducing input scope** when integrating with engines like **ai-auditing-engine**, making it easier to **pinpoint vulnerabilities precisely**
  - **Lowering token and compute costs**, speeding up iterative evaluation

> Note: `benchmark_simplified` may still include some library files or interfaces, because the vulnerable functions can be coupled via types, constants, or math libraries. The guiding principle is “minimum necessary,” not “single-file (.sol) only.”

## Incident index (CSV)

The CSV in the repository root lists **all incidents** currently included in `dataset/` and should be treated as the authoritative source of metadata:

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

**Mapping to directory names**: Incident folder names under both `dataset/benchmark_complete` and `benchmark_simplified` use `{IncidentDateYYYYMMDD}_{ProjectOrProtocolSlug}`. The date is derived from **Attack date** as an 8-digit number (e.g., `2025.05.28` → `20250528`). `{ProjectOrProtocolSlug}` corresponds to the **Project** column and is typically a filesystem-safe slug in lowercase/camel case (e.g., `@Corkprotocol` in the table maps to `20250528_Corkprotocol`). If the **Project** column includes extra notes (e.g., addresses in parentheses), the directory name usually still uses a short protocol identifier; the actual folder names in the repo are authoritative.

Source-tree paths vary by incident. Browse within the corresponding directory by subproject / contract name.

## Quick start (locate code by incident)

1. Find the target row in the CSV (by **Attack date / Project**).
2. Convert **Attack date** to `YYYYMMDD`, and combine it with the project slug: `{YYYYMMDD}_{ProjectSlug}`.
3. Choose a granularity:
   - `dataset/benchmark_complete/{dir}/...`: Full context (closer to real audit inputs).
   - `dataset/benchmark_simplified/{dir}/...`: Minimal necessary slice (fewer tokens, faster regression).

Example: `2025.05.28` + `@Corkprotocol` → `dataset/benchmark_simplified/20250528_Corkprotocol/`

[Chinese case explanations](docs/cases/README.md) describe each system's purpose, defect, attack sequence, asset flow, and evidence limits. The 2026-09-10 import follows the sheet's current rows 99–103: JaredFromSubway, BnbLabubu, Namada, Axelar / Secret, and mySwap. A [source-row snapshot](docs/cases/sources/20260910_sheet_rows_99_103.json) preserves the mapping as sheet rows can move.

This batch includes Rust protocol code and incident evidence for which victim source has not been obtained. Each new directory's `case_metadata.json` exposes `source_status`; missing victim source or incomplete historical-transaction correlation must be filtered before treating the entry as a verified exploit-code sample. Unknown transaction/address fields remain blank and are explained in the CSV. Chinese loss values use 10,000 USD units; English loss values use 1,000 USD units.

mySwap CL now includes the historically executed on-chain Sierra class in both views, with its class hash verified. Its `decompiled_sierra` status distinguishes the recovered SSA / pseudo-Cairo code from verified original Cairo: the complete view retains 425 functions, and the simplified view retains 276 functions covering the five attack entries and their internal dependencies. [Case documentation](docs/cases/20260619_mySwap.md) links the recovered checks to the raw RPC trace; no local Cairo recompilation or exploit replay is claimed.

JaredFromSubway now includes the victim's full 13,835-byte EVM runtime in both views, as `.hex` and `.bin`. Block-hash-pinned reads at attack block 25360696 and preceding block 25360695 match. Status `runtime_bytecode_only` distinguishes these machine-code inputs from original Solidity or decompiled source, which remain unavailable. [Bytecode provenance](dataset/benchmark_complete/20260621_JaredFromSubway/bytecode.json) records the address, block hashes, raw RPC evidence and checksums.

## Suggested usage with AI auditing engines

1. **Regression and comparison**: For the same incident, run the same audit prompts/pipeline on both `benchmark_complete` and `benchmark_simplified`, and compare detection rate, false positives, and cost.
2. **Day-to-day iteration**: During development, use `benchmark_simplified` for quick validation; before release, spot-check with `benchmark_complete` for more production-like context.

## License and disclaimer

- Code snippets in this repository come from publicly available project sources or incident-related public materials; **copyright belongs to the original authors**. They are provided solely for security research and benchmark evaluation.
- Vulnerable code can be **destructive**. Do not use it for illegal purposes. If you use this dataset in papers or products, please cite the dataset name and the version/commit information.

## Contributing and updates

Issues and PRs are welcome for adding new incidents, fixing paths, or improving the “vulnerable function” slicing rules. For new entries, please maintain the mapping between `benchmark_complete` and `benchmark_simplified` **and update** the CSV metadata ([`ai-auditing-benchmark_cn.csv`](ai-auditing-benchmark_cn.csv), [`ai-auditing-benchmark_en.csv`](ai-auditing-benchmark_en.csv)). In your PR, briefly describe the incident source and the vulnerability type.
