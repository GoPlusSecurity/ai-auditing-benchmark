# @LittleBoyPlus source provenance

- Dataset view: `complete`.
- Source sheet: [GoPlus incident sheet, row 101](https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0#gid=0).
- Dataset date: `2026.06.18`. The sheet's `date` is intentionally preserved; it is not converted from the transaction's UTC timestamp.
- Chain: BNB Smart Chain (chain ID 56).
- Reported loss: USD 377,642, copied from the sheet's `lost_u` value. Chinese CSV units are USD 10,000; English CSV units are USD 1,000.
- Solidity compiler: `0.8.35+commit.47b9dedd`. Original optimizer/remapping settings are in `compiler-settings.*.json`.

Entry source files:

- [src/LBP.sol](src/LBP.sol)
- [src/LBPHashrate.sol](src/LBPHashrate.sol)

Source retrieval:

- [Source bundle 1](https://sourcify.dev/server/v2/contract/56/0x88886f0fd371dff856291badced45922bc888888?fields=all)
- [Source bundle 2](https://sourcify.dev/server/v2/contract/56/0x5e3cbc82d020be91a989eb747934104e9ab585fe?fields=all)

Both Sourcify bundles report creationMatch and runtimeMatch as `match`; metadata-exact matching is not claimed. Shared source files are byte-for-byte identical across the two bundles.

The complete view merges the LBP and LBPHashrate verified source bundles with their dependencies. The simplified view retains LP settlement, hashrate credit/debit, reward harvesting, token updates, constructors, and the declarations they require. Compiler settings include viaIR, Cancun, and the original remappings.

Complete Solidity source contents are preserved from the source bundles. The simplified view removes comments and unselected declarations, retaining the original code of selected functions, modifiers, and declarations. It is not expected to reproduce deployed bytecode.

Incident references: [sheet alert](https://x.com/SlowMist_Team/status/2067424733747122259?s=20); [technical analysis](https://www.darknavy.org/web3/exploits/little-boy-plus-lp-share-hashrate-reserve-manipulation/).

攻击链路与原理说明：[阅读本 case 分析](../../../docs/cases/20260618_LittleBoyPlus.md)。
