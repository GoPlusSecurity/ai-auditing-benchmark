# DIP source provenance

- Dataset view: `simplified`.
- Source sheet: [GoPlus incident sheet, row 102](https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0#gid=0).
- Dataset date: `2026.06.17`. The sheet's `date` is intentionally preserved; it is not converted from the transaction's UTC timestamp.
- Chain: BNB Smart Chain (chain ID 56).
- Reported loss: USD 111,100, copied from the sheet's `lost_u` value. Chinese CSV units are USD 10,000; English CSV units are USD 1,000.
- Solidity compiler: `0.8.18+commit.87f61d96`. Original optimizer/remapping settings are in `compiler-settings.*.json`.

Entry source files:

- [contracts/flatten/nexus_dip.sol](contracts/flatten/nexus_dip.sol)

Source retrieval:

- [Source bundle 1](https://sourcify.dev/server/v2/contract/56/0x6c60bf5db0670ae94489d3dde2c60f271625db50?fields=all)

Sourcify creationMatch and runtimeMatch are both `match`; metadata-exact matching is not claimed.

The complete view preserves the verified flattened source. The simplified view retains the token transfer path, ERC-20 balance/supply queries, router/pair configuration, and the declarations they require.

Complete Solidity source contents are preserved from the source bundles. The simplified view removes comments and unselected declarations, retaining the original code of selected functions, modifiers, and declarations. It is not expected to reproduce deployed bytecode.

Incident references: [sheet alert](https://x.com/TenArmorAlert/status/2067059314519417163); [technical analysis](https://www.darknavy.org/web3/exploits/dip-token-double-transfer-reserve-manipulation/).

攻击链路与原理说明：[阅读本 case 分析](../../../docs/cases/20260617_DIP.md)。
