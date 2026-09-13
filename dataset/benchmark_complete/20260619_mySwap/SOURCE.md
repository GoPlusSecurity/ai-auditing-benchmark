# mySwap CL chain program and decompilation provenance

- Dataset view: complete.
- Chain material retrieved for the 2026-09-13 recovery; earlier selected browser observations retain their 2026-09-10 labels.
- Scope: all 425 functions, 50,567 statements, 406 type declarations and 2,061 libfunc declarations from the executed class.

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

## Retrieval and independent checks

Read-only JSON-RPC requests used `https://api.cartridge.gg/x/starknet/mainnet`, a provider listed in the [official Starknet configuration documentation](https://docs.starknet.io/build/starkzap/configuration). No chain transaction was submitted.

| Request | Saved request | Saved raw response |
| --- | --- | --- |
| `starknet_getClass` for the exact class hash | [get-class-request.json](evidence/get-class-request.json) | [class-response.cartridge.json](evidence/class-response.cartridge.json) |
| `starknet_getClassHashAt` at block 10951100, transaction receipt, chain ID | [history-request.json](evidence/history-request.json) | [history-response.json](evidence/history-response.json) |
| `starknet_traceTransaction` | [trace-request.json](evidence/trace-request.json) | [trace-response.json](evidence/trace-response.json) |

`getClass` uses the class hash directly, and the historical `getClassHashAt` binds that immutable class to this victim at the exploit block. The local implementation recomputes the Sierra class hash using Poseidon, the exact ABI string's Starknet Keccak, all three entry-point groups and the serialized program. The result equals the historical class hash. All 60 mySwap calls in the raw trace name the same class.

The deterministic decoder follows the Cairo v2.2.0 serialization reference: [felt252_serde.rs](https://github.com/starkware-libs/cairo/blob/v2.2.0/crates/cairo-lang-starknet/src/felt252_serde.rs) and [felt252_vec_compression.rs](https://github.com/starkware-libs/cairo/blob/v2.2.0/crates/cairo-lang-starknet/src/felt252_vec_compression.rs). It uses Python's standard library, with no installed decompiler dependencies. The requested dependency installation was rejected; it was not retried through another installation route. Thoth itself was not executed.

- All 416,294 uncompressed words are decoded with no trailing data. Re-encoding and re-compression exactly reproduce the serialized program after its six version words.
- The standard text decoder was compared with the `test.json` / `test.sierra` converter fixture from [Thoth commit 7e023904bc2869ff43e25c3fcc8fa03f573a25ff](https://github.com/FuzzingLabs/thoth/tree/7e023904bc2869ff43e25c3fcc8fa03f573a25ff/contract-class-converter/tests/files). All types, libfuncs, 2,224 statements, 36 function signatures and PC comments matched exactly. [Validation record](evidence/decoder-validation.json) fixes the fixture hashes.
- Known Keccak empty-input and `abc` vectors passed. Recomputing the target class hash provides an independent expected result for the complete serialized input.
- All 42 ABI entry points match their selector hashes. Every local branch remains inside its original function.

[recovery.json](evidence/recovery.json) records exact counts, version words, selected functions, original function ranges and their internal call graph. [mySwap.sierra](onchain/mySwap.sierra) is the complete decoded standard Sierra text. [entry-points.json](onchain/entry-points.json) and [abi.json](onchain/abi.json) provide readable entry and type definitions. [Recovery script](recovery/restore.py) can verify or reproduce the output; see its [usage](recovery/README.md).

## Attack evidence and located code path

The raw trace and receipt confirm twelve rounds of `create_pool → mint → initialize_pool_price → burn → collect`. All twelve real-token `transferFrom` amounts are zero. Each corresponding real-token `transfer` pays the attacker, returns success and equals the `collect` result. The receipt includes 128 events. Every mySwap invocation is a direct child of the attacker's execution; this trace contains no EVIL-to-mySwap callback re-entry. These assertions and raw JSON pointers are recorded in [raw-trace-verification.json](evidence/raw-trace-verification.json).

The recovered `mint` path calls `fn_117`, whose `L15138–L15183` checks the nonzero `fee` member of `PoolParams`. That only establishes pool creation. Price initialization's `fn_92`, `L12325–L12389`, checks the old square-root price against zero and then writes the new tick/price. Both mint and burn use `fn_201`; its current-tick comparisons select different asset-side calculations before and after initialization. [Case explanation](../../../docs/cases/20260619_mySwap.md) connects these instructions to the first real ETH payment and the repeated asset withdrawals.

Earlier [rounds.json](evidence/rounds.json), [first-round-internal-calls.json](evidence/first-round-internal-calls.json) and [amounts.json](evidence/amounts.json) remain labelled as normalized browser observations. Their recorded pool keys, ticks, liquidity, prices and results were cross-checked against the newly saved raw trace. They are not presented as the original node responses.

## Scope and remaining limits

The class hash verifies the identity of the input class; it does not prove recovery of the original Cairo project or a successful local exploit replay. No Cairo recompilation, Cairo VM execution or mainnet write was performed. Original source licensing, compiler flags, private symbol names and repository commit remain unresolved. SHA256SUMS covers the exact local files, including the raw chain inputs and recovered outputs; it is separate from the Starknet class hash.

Product and disclosure context: [official product docs](https://docs.myswap.xyz/), [project incident statement](https://x.com/mySwapxyz/status/2067941891010711560), [GoPlus alert](https://x.com/GoPlusSecurity/status/2068336316061028626). The initial disclosure text was accessed via the public mirror identified in the case document. The source lookup history remains in source-status.json; the previously rejected GitHub repository-list request was not repeated.

攻击链路与原理说明：[阅读本 case 分析](../../../docs/cases/20260619_mySwap.md)。
