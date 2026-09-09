# @aztecnetwork source provenance

- Dataset view: `complete`.
- Source sheet: [GoPlus incident sheet, row 100](https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0#gid=0).
- Dataset date: `2026.06.18`. The sheet's `date` is intentionally preserved; it is not converted from the transaction's UTC timestamp.
- Chain: Ethereum (chain ID 1).
- Reported loss: USD 2,170,000, copied from the sheet's `lost_u` value. Chinese CSV units are USD 10,000; English CSV units are USD 1,000.
- Solidity compiler: `0.6.10+commit.00c0fcaf`. Original optimizer/remapping settings are in `compiler-settings.*.json`.

Entry source files:

- [contracts/RollupProcessor.sol](contracts/RollupProcessor.sol)
- [contracts/verifier/TurboVerifier.sol](contracts/verifier/TurboVerifier.sol)

Source retrieval:

- [Source bundle 1](https://etherscan.io/address/0x737901bea3eeb88459df9ef1be8ff3ae1b42a2ba#code)
- [Source bundle 2](https://etherscan.io/address/0x48cb7ba00d087541dc8e2b3738f80fdd1fee8ce8#code)

Both source bundles were extracted from the verified Solidity standard-JSON source displayed by Etherscan. Shared source files are byte-for-byte identical across the two bundles.

The complete view contains the L1 processor, verifier, cryptographic libraries, and verification keys. The simplified view retains the escape-hatch proof-to-settlement path and its dependencies. The original off-chain claim-circuit source is not part of the verified L1 bundles; these Solidity files alone do not reproduce the circuit-level defect. This is a separate deployment from the existing 20260614_aztecnetwork sample.

Complete Solidity source contents are preserved from the source bundles. The simplified view removes comments and unselected declarations, retaining the original code of selected functions, modifiers, and declarations. It is not expected to reproduce deployed bytecode.

Incident references: [sheet alert](https://x.com/evilcos/status/2067488848788262957); [technical analysis](https://www.darknavy.org/web3/exploits/aztec-private-rollup-bridge-escape-hatch-claim-proof-drain/).

攻击链路与原理说明：[阅读本 case 分析](../../../docs/cases/20260618_aztecnetwork.md)。
