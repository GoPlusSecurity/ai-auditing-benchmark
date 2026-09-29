# ATM / misplaced LP redemption source provenance

> Documentation archive only. Removed from dataset and both CSV indexes on 2026-09-15 at the user's request. Source and transaction evidence remain here to support the case document.

- View: complete. Sheet row 101, retrieved 2026-09-14; preserve date `2026.06.22` and loss USD `949900`.
- Sheet: [original Google Sheet](https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0); [local snapshot](../../20260914_sheet_rows_98_102.json).
- Original disclosure link: [TenArmor](https://x.com/TenArmorAlert/status/2068993748936151209). Its body was not independently recovered during this import.
- Sheet transaction: [0x939fc929…](https://bscscan.com/tx/0x939fc92996c9205eac83b86817abe2ef5f7f1eeadfb43557e2cfb3123720b3f1). Successful but no logs, index 68 in block 105692848; input names the same pair and assets. Do not treat it as the funds-out transaction.
- Verified funds-out transaction: [0x4e9f3dc3…](https://bscscan.com/tx/0x4e9f3dc3ce3c0a6aa19dae0f1384ff46e801b433b7e3bc4c780de486db6c950a), index 1 of the same block.
- Affected pair/redemption surface: [0x9753a64f…](https://bscscan.com/address/0x9753a64fb7c233fdc43f04dab9cca88e1e229eba#code). This is standard PancakePair functionality exposed to LP sent separately to the pair; no implementation defect in standard PancakeSwap is established.
- ATM asset: `0xFdC76B8b2F775656E8A867FcC3282c969D2d86b0`. Its source was not recovered. It is distinct from the token in `20260604_ATMToken` (`0x986058ec93756E57b4e55b406dD0BeE24bcD95e3`); common project ownership has not been verified.

[contracts/PancakePair.sol](contracts/PancakePair.sol) preserves the entire original flattened source, including interfaces, libraries, LP accounting, mint, burn, swap and their dependencies. It comes from [Sourcify reference pair 0x16b9a828…](https://sourcify.dev/server/v2/contract/56/0x16b9a82891338f9ba80e2d6970fdda79d1eb0dae?fields=all), with creationMatch and runtimeMatch `match`. The target pair itself has no Sourcify match. The entire current deployed target runtime, including its metadata suffix, equals the reference runtime byte for byte; see [comparison](evidence/pair-runtime-comparison.json). Historical code at block 105692847 returned `missing trie node`, so historical runtime equality is not claimed.

Compiler: `0.5.16+commit.9c3226ce`. Original ABI, metadata and compiler settings are archived beside this file. [provenance.json](provenance.json) records source and bundle hashes; [SHA256SUMS](SHA256SUMS) covers the archive files. The original and simplified sources both compiled locally with zero errors and zero warnings using that compiler. This does not establish historical replay success.

The locally compiled complete executable runtime also equals the target current runtime after stripping each Solidity CBOR metadata suffix. The local metadata suffix differs, so local metadata-exact recompilation is not claimed. This is separate from the reference-onchain-versus-target-onchain comparison above, which is equal in full including metadata.

The independent public research is [DeFiHackLabs ATM_LP_Burn_exp.sol, commit 4962249351708c1b28d138d934f44e9f51a58430](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/4962249351708c1b28d138d934f44e9f51a58430/src/test/2026-06/ATM_LP_Burn_exp.sol). It supplied candidate setup, LP-transfer and burn transaction hashes, which were checked against successful public RPC receipts. The research PoC is not included as vulnerable source.

Evidence from [BNB Chain public RPC](https://bsc-dataseed.bnbchain.org) is stored under [evidence/](evidence/transaction-summary.json): setup, LP transfer, funds-out and sheet-call records; decoded logs; block transaction order; source/runtime comparison; historical lookup/trace failure responses. Receipt evidence shows 1,603.989214300816939995 WBNB redeemed, 1,571.909430014800601194 WBNB withdrawn to native BNB, and 32.079784286016338801 WBNB transferred to the final receiver. The native builder payment destination is a research claim, not independently confirmed here: debug trace returned `missing trie node`. No full campaign net profit or dollar conversion is claimed. No local fork or exploit execution was run.

中文详细解释：[ATM LP 误转案例](../../../20260622_ATM.md)。
