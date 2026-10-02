# Royalties / Royal1155LDA：完整视图来源

状态为 `verified_original_source`。已从 PolygonScan 两份实现源码页提取完整 Solidity 原文，并将页面内标准 JSON 与独立 data-csource 属性逐文件交叉核对。45 份 Solidity 文件、编译设置与两份代理源码均已保存。当前代理页面关联已归档，攻击时历史代理槽尚未独立读取。

- LDA 代理：`0x7c885c4bfd179fb59f1056fbea319d579a278075`；[实现源码页](https://polygonscan.com/address/0xd5b297c08d890376b6cbdba6023a39ffbdf65c78#code)，24 份 Solidity。
- Royalties 代理：`0xfe16ee78828672e86cf8e42d8a5119ab79877ec7`；[实现源码页](https://polygonscan.com/address/0x1e0598614d9168a657cb57bd038dfd71812c9074#code)，21 份 Solidity。
- 源表恶意地址 `0x11ca9155aedfeb6772df5ea42ff714db7fba6adb` 是攻击辅助地址，没有列为漏洞合约。

完整版 `../../../dataset/benchmark_complete/20260624_Royalties/source-bundles/` 保存两份源包、原始标准输入、Solidity 编译输入及设置；`../../../dataset/benchmark_complete/20260624_Royalties/proxies/` 保存浏览器代理源码；`provenance.json` 保存来源与逐文件哈希。源码页记录编译器 `v0.8.4+commit.c7e474f2`、optimizer runs 200。本次未独立编译或匹配部署字节码。

精简版保存 17 份原文函数切片，覆盖 ERC1155 转账、权益钩子与查询、分红存入、结算、领取及比例公式。`slice_manifest.json` 记录完整版路径、原始行号和 SHA-256。切片不是可独立编译的完整合约；完整状态声明与依赖保留在完整版。

[攻击交易](https://polygonscan.com/tx/0x7a92106f145045b7a2bdce60a22109739f9b0cd0185bf16ff83fd1fac98cb42e)位于区块 89018051，状态成功，时间为 2026-06-23 16:27:52 UTC。源表第 99 行采用 2026.06.24 和 261200 美元，均保留。两者日期可由北京时间换算对应。

原始交易 HTML 在完整版 `evidence/polygonscan/transaction.html`。两套目录的 `evidence/decoded-events.json` 保存原始事件字段及解码结果，核对了 100 个重复 ID、全零数量和存款/领取/转账事件。这是浏览器事件数据，不是 RPC 回执或完整内部 trace。`evidence/transaction-summary.json` 精确重算：Royalties 净流出 261170.864361 USDC.e，辅助地址本笔净流入 261162.926278 USDC.e，未扣 gas。

源码中的必要前提是回填未完成且发送方档位余额为零时跳过扣减；该分支与接收方无视数量加一共同产生错误权益。攻击前回填标志、余额和供应量未独立读取。付款与存款的 100 倍比例已经事件核对，不能据此声称已验证全部历史状态。未运行主网分叉或攻击重放。

SHA256SUMS 校验本视图所有已归档文件，原始源码另有逐文件来源校验。完整说明：[20260624_Royalties.md](../../../docs/cases/20260624_Royalties.md)；源表：[本批五行快照](../../../docs/cases/sources/20260914_sheet_rows_98_102.json)。
