# BnbLabubu / OLPCToken source provenance

- Dataset view: `simplified`, derived from the same incident's [complete view](../../benchmark_complete/20260620_BnbLabubu/SOURCE.md).
- Source sheet: [GoPlus incident sheet, row 100 at retrieval](https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0).
- Dataset date: `2026.06.20`; chain ID 56; sheet loss USD 1,115,000.
- Actual vulnerable address: [OLPCToken 0x58815CDF9955121a6274680ab396a36FC9e00000](https://bscscan.com/address/0x58815CDF9955121a6274680ab396a36FC9e00000#code).

This view keeps the original code of selected whole functions and supporting declarations. It removes unrelated members and comments, without changing the vulnerable function bodies:

- [contracts/OLPCToken.sol](contracts/OLPCToken.sol): ERC20 entry/allowance/balance paths, the complete `_update` override, multiplier setter with ownership checks, tax/exemption/pair configuration, price and tax functions reached by the override, and required interfaces, inherited state and constructors.
- [contracts/LABUBUToken.sol](contracts/LABUBUToken.sol): paired-asset transfer and sell-tax context, including the reached checks and pricing dependencies.
- [contracts/PancakePair.sol](contracts/PancakePair.sol): `skim`, `sync`, `swap`, `_safeTransfer`, `_update`, reserves, lock, constructors, initialization, required types and arithmetic. Unrelated liquidity mint/burn and LP transfer/permit functions were removed as whole declarations, including their interface entries.

Source URLs, original source SHA-256 hashes and matching boundaries are in [provenance.json](provenance.json). Current file hashes are in [SHA256SUMS](SHA256SUMS). OLPC and LABUBU original bundles are Sourcify creation/runtime `match` at their own addresses; metadata exactness is not claimed. The Pair file comes from a verified reference pool with a complete deployed runtime equal to the target pool runtime at retrieval, as documented in [runtime comparison](evidence/pair-runtime-comparison.json). No historical bytecode comparison at the exploit block was obtained.

Both token slices compile without errors using solc `0.8.33+commit.64118f21`, and retained function bodies are checked against the original. The Pair source requires `0.5.16+commit.9c3226ce`, unavailable locally; its local compilation is not claimed. Simplified source is an audit slice and is not expected to reproduce deployed bytecode. Full implementation context and original compiler settings remain in the complete view.

The successful transaction's [receipt and decoded summary](evidence/transaction-summary.json) prove event ordering and asset movements. The attacker received 1,115,903.663412131721557252 USDT in this transaction, before costs. This does not replace the sheet's USD 1,115,000 field. No local fork exploit or complete debug trace was run; May 5 owner configuration history remains attributed to the report.

References: [original report](https://x.com/f12sec/status/2068325913935122673), [GoPlus technical analysis](https://x.com/GoPlusSecurity/status/2068705985011851465), [configuration report](https://x.com/GoPlusSecurity/status/2068705989365530729), [exploit transaction](https://bscscan.com/tx/0x8dabb60a94e5124462e5f494a25c14bcd52f6f4d1f7c665a249496f4c6c24764), [auxiliary reproduction report at fixed commit](https://github.com/BackwardLabs/Q1-2026/blob/12beb4db9880788deb49ce39cc5659a4b8bb2510/test/2026-06/pancakeswap_v2/README.md). No attacker PoC is used as source code.

攻击链路与原理说明：[阅读本 case 分析](../../../docs/cases/20260620_BnbLabubu.md)。
