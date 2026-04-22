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

Both CSVs have identical rows; only the field language differs. Column meanings:

- **Attack date**: Incident date (`YYYY.MM.DD`).
- **Project**: The exploited project or protocol (the display name may differ slightly from the directory slug, e.g., with `@` or parenthetical notes).
- **Vulnerability**: A short description of the vulnerability type.
- **Vulnerability details**: The exploit technique and defect description.
- **Attack transaction**: Representative on-chain transaction hash.
- **Vulnerable contract address**: Related contract address(es) (may span multiple lines within a cell).
- **Loss (10k USD)**: Reported or estimated loss amount.

**Mapping to directory names**: Incident folder names under both `dataset/benchmark_complete` and `benchmark_simplified` use `{IncidentDateYYYYMMDD}_{ProjectOrProtocolSlug}`. The date is derived from **Attack date** as an 8-digit number (e.g., `2025.05.28` → `20250528`). `{ProjectOrProtocolSlug}` corresponds to the **Project** column and is typically a filesystem-safe slug in lowercase/camel case (e.g., `@Corkprotocol` in the table maps to `20250528_Corkprotocol`). If the **Project** column includes extra notes (e.g., addresses in parentheses), the directory name usually still uses a short protocol identifier; the actual folder names in the repo are authoritative.

Source-tree paths vary by incident. Browse within the corresponding directory by subproject / contract name.

## Quick start (locate code by incident)

1. Find the target row in the CSV (by **Attack date / Project**).
2. Convert **Attack date** to `YYYYMMDD`, and combine it with the project slug: `{YYYYMMDD}_{ProjectSlug}`.
3. Choose a granularity:
   - `dataset/benchmark_complete/{dir}/...`: Full context (closer to real audit inputs).
   - `dataset/benchmark_simplified/{dir}/...`: Minimal necessary slice (fewer tokens, faster regression).

Example: `2025.05.28` + `@Corkprotocol` → `dataset/benchmark_simplified/20250528_Corkprotocol/`

## Suggested usage with AI auditing engines

1. **Regression and comparison**: For the same incident, run the same audit prompts/pipeline on both `benchmark_complete` and `benchmark_simplified`, and compare detection rate, false positives, and cost.
2. **Day-to-day iteration**: During development, use `benchmark_simplified` for quick validation; before release, spot-check with `benchmark_complete` for more production-like context.

## License and disclaimer

- Code snippets in this repository come from publicly available project sources or incident-related public materials; **copyright belongs to the original authors**. They are provided solely for security research and benchmark evaluation.
- Vulnerable code can be **destructive**. Do not use it for illegal purposes. If you use this dataset in papers or products, please cite the dataset name and the version/commit information.

## Contributing and updates

Issues and PRs are welcome for adding new incidents, fixing paths, or improving the “vulnerable function” slicing rules. For new entries, please maintain the mapping between `benchmark_complete` and `benchmark_simplified` **and update** the CSV metadata ([`ai-auditing-benchmark_cn.csv`](ai-auditing-benchmark_cn.csv), [`ai-auditing-benchmark_en.csv`](ai-auditing-benchmark_en.csv)). In your PR, briefly describe the incident source and the vulnerability type.
