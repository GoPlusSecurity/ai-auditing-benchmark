# mySwap CL chain program and decompilation provenance

- Dataset view: simplified.
- Status: `decompiled_sierra`.
- Slice: 276 functions and 29,303 statements, selected from the same 425-function historical class.

## Exact chain object

- Network: Starknet Mainnet (`SN_MAIN`). Incident date: `2026.06.19`, from current source-sheet row 103. Sheet snapshot: [saved five rows](../../../docs/cases/sources/20260910_sheet_rows_99_103.json).
- Victim: [0x01114c7103e12c2b2ecbd3a2472ba9c48ddcbf702b1c242dd570057e26212111](https://voyager.online/contract/0x01114c7103e12c2b2ecbd3a2472ba9c48ddcbf702b1c242dd570057e26212111).
- Historically executed class: [0x008fade1a36f2bfcaa55b53c96dfb615e8e60110b87765cf449d09b6e0397b17](https://voyager.online/class/0x008fade1a36f2bfcaa55b53c96dfb615e8e60110b87765cf449d09b6e0397b17).
- Exploit: [0x1c15c4064cb3d72df27a35dfcd2da17c108abfb8e671428cb9d457f698f588](https://voyager.online/tx/0x1c15c4064cb3d72df27a35dfcd2da17c108abfb8e671428cb9d457f698f588), block `10951100`, `2026-06-19 07:15:46 UTC`.
- Class declaration: [0x42e2b10ab20722eb62e244ed73b4f78f075edf15b371e79ea7b42fcc0e6dbf1](https://voyager.online/tx/0x42e2b10ab20722eb62e244ed73b4f78f075edf15b371e79ea7b42fcc0e6dbf1), displayed date `2024-01-28 16:28:27`.
- Attacker account: `0x029f9de5cafb30f55e4a6f4f032e8774958520c1649b3a0441f1354c0b330518`. Attacker token EVIL: `0x028c9acd8eb7dc1cd7e3da98da3997cb57beca3c39d425e90780195df3a9a49e`. Neither is substituted for victim code.
- Loss: USD 305,000 retains the source-sheet estimate; Chinese CSV uses 30.5 in USD 10,000 units, English CSV 305 in USD 1,000 units. No current-price revaluation or net-loss calculation is implied.

## What the code represents

Status is `decompiled_sierra`. The chain's **complete Sierra contract class is available and cryptographically bound to the historical execution**. Original human-authored Cairo remains unverified/unavailable.

[onchain/mySwap.contract_class.json](onchain/mySwap.contract_class.json) preserves the node's class result as formatted JSON, including all 27,287 Sierra felts, the entry-point table and the exact original ABI string. It is byte-identical between the two dataset views. Its JSON whitespace differs from the raw RPC envelope; the envelope is preserved in the complete view.

[mySwap.decompiled.cairo](mySwap.decompiled.cairo) is a conservative SSA / pseudo-Cairo recovery. It preserves the original numeric private function identifiers, every included instruction, branch ordinal, branch output and absolute branch target. ABI names are assigned only to entry functions after their selector hashes match. `L12342`, for example, means original zero-based Sierra statement 12342, not an original Cairo source line. Builtins, range checks and panic branches remain visible. This is **not compilable original Cairo**, and no Solidity substitute was created.

Both [case_metadata.json](case_metadata.json) and [source-status.json](evidence/source-status.json) expose these distinctions. Original-source SHA-256 and original repository commit remain unknown. Serialized version words identify Sierra `1.3.0` and compiler `2.2.0`; original compiler flags and dependency settings are still unavailable.

## Exact slice rule

The five roots are ABI entries `create_pool` (function 27), `mint` (14), `initialize_pool_price` (28), `burn` (16), and `collect` (15). The slice recursively retains every statically referenced internal user function, plus referenced libfunc/type declarations. Each retained function is copied in full, including unsuccessful paths, builtin plumbing, range checks, locking and transfer-result checks. Original `L` indices remain unchanged.

[recovery.json](evidence/recovery.json) lists all retained function IDs, ranges and calls. No retained call references an omitted internal function. The complete graph and all other public entry points remain in the [complete recovery](../../benchmark_complete/20260619_mySwap/mySwap.decompiled.cairo). Internal names are numeric because original private symbols were not recovered.

The full on-chain class is intentionally retained under `onchain/` as the hash-verifiable input. For reduced audit input, use `mySwap.decompiled.cairo`; feeding the full provenance JSON into an audit would defeat the slice reduction.

## Evidence and verification

[rounds.json](evidence/rounds.json) keeps the first ETH round, and [first-round-internal-calls.json](evidence/first-round-internal-calls.json) retains its selected browser transfer observations. [raw-trace-verification.json](evidence/raw-trace-verification.json) records the corresponding raw trace pointers and verified zero ETH deposit / actual ETH payment. The complete view contains all twelve rounds, the raw RPC requests/responses and the 128-event receipt.

Local verification includes exact decode/encode/compression round-trips, the historical class hash, ABI selector matching and dependency closure. A fixed upstream converter fixture independently validates the standard Sierra decoder. [Complete provenance](../../benchmark_complete/20260619_mySwap/SOURCE.md) describes the retrieval and limits; [recovery tool usage](../../benchmark_complete/20260619_mySwap/recovery/README.md) explains reproduction.

The recovered code supports static analysis. Original Cairo compilation and local exploit replay have not been performed. The `.cairo` extension marks pseudo-Cairo notation and does not imply a buildable Cairo package. [SHA256SUMS](SHA256SUMS) fixes this slice and its exact local inputs.

攻击链路与原理说明：[阅读本 case 分析](../../../docs/cases/20260619_mySwap.md)。
