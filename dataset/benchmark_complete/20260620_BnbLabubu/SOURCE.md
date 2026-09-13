# BnbLabubu / OLPCToken source provenance

- Dataset view: `complete`.
- Sheet: [GoPlus incident sheet, row 100 at retrieval](https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0).
- Dataset date: `2026.06.20`, preserving the sheet date.
- Chain: BNB Smart Chain, chain ID 56.
- Reported loss for CSV: USD 1,115,000. Successful receipt gives an attacker USDT net inflow of 1,115,903.663412131721557252 before startup funds and gas; these are different accounting scopes.
- Vulnerable contract: [OLPCToken 0x58815CDF9955121a6274680ab396a36FC9e00000](https://bscscan.com/address/0x58815CDF9955121a6274680ab396a36FC9e00000#code).
- Exploit transaction: [0x8dabb60a…c24764](https://bscscan.com/tx/0x8dabb60a94e5124462e5f494a25c14bcd52f6f4d1f7c665a249496f4c6c24764).

The three flattened files retain the original source contents, including interfaces, libraries, inherited state, permissions and the transfer/reserve accounting paths:

- [contracts/OLPCToken.sol](contracts/OLPCToken.sol): vulnerable token. [Original Sourcify bundle](https://sourcify.dev/server/v2/contract/56/0x58815CDF9955121a6274680ab396a36FC9e00000?fields=all).
- [contracts/LABUBUToken.sol](contracts/LABUBUToken.sol): paired asset and downstream transfer/tax context. [Original Sourcify bundle](https://sourcify.dev/server/v2/contract/56/0x3494dfE19b721DAC6c5c8d7470c8F89548177777?fields=all).
- [contracts/PancakePair.sol](contracts/PancakePair.sol): pool context. The target pair has no source match on Sourcify. This file comes from [reference pair 0x16b9a82891338f9ba80e2d6970fdda79d1eb0dae](https://sourcify.dev/server/v2/contract/56/0x16b9a82891338f9ba80e2d6970fdda79d1eb0dae?fields=all), whose complete deployed runtime exactly equals the target pool runtime retrieved with `latest`. See [runtime comparison](evidence/pair-runtime-comparison.json). This is not a claim of historical target-pool verification at the exploit block.

All three Sourcify source bundles return creationMatch and runtimeMatch `match`; metadata-exact matching is not claimed. Tokens use solc `0.8.33+commit.64118f21`; Pair uses `0.5.16+commit.9c3226ce`. The original settings, ABI, metadata, source URLs and source SHA-256 hashes are in `compiler-settings.*.json`, `abi.*.json`, `metadata.*.json` and [provenance.json](provenance.json). [SHA256SUMS](SHA256SUMS) records the archived files.

Receipt, transaction, decoded events and amount summary are under [evidence/](evidence/transaction-summary.json). They were fetched read-only from the BNB Chain public dataseed RPC. OLPC and LABUBU compile locally without errors using solc 0.8.33. Pair was not recompiled locally because solc 0.5.16 was unavailable. No fork reproduction or full debug trace was run; no historical owner-setting transaction was independently obtained.

The root cause is an unbounded owner-configured burn multiplier combined with pair-originated transfers that debit more than the requested amount. It is not classified as reentrancy. Attacker addresses are not used as vulnerable-contract metadata. The complete source is not an exploit PoC.

References: [original sheet report](https://x.com/f12sec/status/2068325913935122673), [GoPlus root cause](https://x.com/GoPlusSecurity/status/2068705985011851465), [GoPlus configuration history claim](https://x.com/GoPlusSecurity/status/2068705989365530729), [BlockSec weekly report](https://blocksec.com/blog/web3-security-jaredfromsubway-aztec-more). The auxiliary [public reproduction report](https://github.com/BackwardLabs/Q1-2026/blob/12beb4db9880788deb49ce39cc5659a4b8bb2510/test/2026-06/pancakeswap_v2/README.md) is pinned to commit `12beb4db9880788deb49ce39cc5659a4b8bb2510`; its PoC was not admitted as vulnerable source.

攻击链路与原理说明：[阅读本 case 分析](../../../docs/cases/20260620_BnbLabubu.md)。
