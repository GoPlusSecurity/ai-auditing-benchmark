# DLMC source provenance

- Dataset view: `complete`; date `2026.06.25`, preserving [source sheet row 98](https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0).
- BNB Smart Chain (56); source-sheet loss USD 222,600. [Original TenArmor alert](https://x.com/TenArmorAlert/status/2069957542109958498).
- Actual vulnerable contract: [DLMCToken 0xf2ca2a3572b26ae7c479dc7ae36d922113b1bdf2](https://bscscan.com/address/0xf2ca2a3572b26ae7c479dc7ae36d922113b1bdf2#code).
- [Attack transaction](https://bscscan.com/tx/0x151025d3f0a782340a74d30ef33a5fad044b838e74437a803f0652e70c231306) executed on 2026-06-24 11:15:10 UTC; the sheet date is not overwritten.

[DLMCToken.sol](contracts/DLMCToken.sol) is the actual token implementation. The complete view preserves all 14 UTF-8 source contents from [Sourcify](https://sourcify.dev/server/v2/contract/56/0xf2ca2a3572b26ae7c479dc7ae36d922113b1bdf2?fields=all), including original OpenZeppelin dependencies. Sourcify reports creation and runtime `exact_match`. This is the registry's verified-address match; an independent historical runtime comparison was not performed.

The simplified view retains 10 Solidity files with registerAffiliate, buy, sell, referral splitting, income limits, investment accounting, price calculation, token transfers, constructors and their dependencies. AST selection removes unrelated functions and comments, preserving all retained function bodies. State declarations and constructors remain so that the relevant accounting context is explicit. The slice is not expected to reproduce deployed bytecode. Original compiler configuration and ABI describe the complete deployed source.

Both views compile with solc `0.8.31+commit.fd3a2265`, zero errors or warnings. 59 retained function bodies match the original after ignoring comments and whitespace. See [validation](evidence/validation.json), [slice size report](evidence/slice-report.json), [provenance](provenance.json) and [SHA256SUMS](SHA256SUMS). Original source hashes are in provenance; current archived file hashes are in SHA256SUMS.

[Transaction receipt](evidence/transaction-receipt.json) and [transaction](evidence/transaction.json) were independently fetched from the public BNB Chain RPC. Their events establish token movements and price updates. The sold amount is independently obtained from the DLMC burn event, and its product with the recorded price matches the USDT payment exactly under integer arithmetic. Function reachability is analyzed from original source. [Historical calls](evidence/historical-calls.json) and [independent trace attempt](evidence/independent-trace-attempt.json) returned `missing trie node`; no complete call trace or historical storage reconstruction is available. No fork reproduction was run and no attacker PoC is admitted as vulnerable source.

The recipient received 222,560.221693222099016479 USDT before gas; the victim contract's transaction net USDT outflow was 226,119.118936329868440038, including the flash fee ultimately paid to the Pancake pair. Gross redemption of 1,646,119.118936329868440038 includes 1,420,000 flash principal. These figures are distinct from the source sheet's rounded USD loss. See [amount reconciliation](evidence/transaction-summary.json).

The source-sheet malicious addresses belong to the transaction sender and payout receiver, not the vulnerable contract. The Pancake pair supplies flash liquidity and is not classified as the faulty contract. The original X and BscScan pages returned 403 through the web reader; this did not prevent source-registry and RPC verification.

攻击链路与原理说明：[中文详细分析](../../../docs/cases/20260625_DLMC.md)。
