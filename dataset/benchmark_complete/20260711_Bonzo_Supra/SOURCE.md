# 20260711_Bonzo_Supra source record

- Case explanation: [../../../docs/cases/20260711_Bonzo_Supra.md](../../../docs/cases/20260711_Bonzo_Supra.md)
- Source-sheet row: 110; [fixed batch snapshot](../../../docs/cases/sources/20261002_sheet_rows_106_116.json) and [row decisions](../../../docs/cases/sources/20261002_sheet_rows_106_116_results.json).
- Chain: Hedera Mainnet
- Vulnerable component: [0x2fa6dbfe4291136cf272e1a3294362b6651e8517](https://hashscan.io/mainnet/contract/0.0.4323006)
- Representative transaction: [0xd50c55e24eb8483ec55bf74e84fc9853d0f0fe36f64abdb812a2d9afa2a10a60](https://hashscan.io/mainnet/transaction/1783731093.686041919)
- Public source: [https://xdcscan.com/address/0xbb37c65aab92c41ec696c18600cabb4fc6309549#code](https://xdcscan.com/address/0xbb37c65aab92c41ec696c18600cabb4fc6309549#code)
- Technical/official analysis: [https://bonzo.finance/blog/bonzo-lend-incident-report-oracle-provider-exploit](https://bonzo.finance/blog/bonzo-lend-incident-report-oracle-provider-exploit)

`provenance.json` fixes the public source entry and per-file hashes. `evidence/` retains the fetched transaction records, receipt/actions, address roles and actual verification status. This archive does not claim a local compilation, complete historical-state reconstruction or exploit replay. The XDC source and Hedera attack implementation are expressly not byte-identical; read `evidence/runtime-comparison.json` before treating the source as an exact deployment reconstruction. Panoramix produced a full disassembly and selector inventory, but high-level pseudocode for `0x2818300e` did not converge; see `evidence/bonzo-panoramix-run.json` and do not treat the tool output as verified Solidity.
