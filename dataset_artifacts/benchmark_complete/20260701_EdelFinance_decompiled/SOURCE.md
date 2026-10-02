# Edel Finance / xStock [Decompiled] — 反编译样本 / Decompiled sample

**源码性质：Etherscan Palkeoramix/Panoramix 伪代码；不是已验证原始 Solidity。**

价格适配器 `0x4C2C9Df4559d80E0a7aa3c7F281704a7992F4CE2` 没有验证源码。本目录使用 [Etherscan Bytecode Decompiler](https://etherscan.io/bytecode-decompiler?a=0x4C2C9Df4559d80E0a7aa3c7F281704a7992F4CE2) 实际生成的完整 `.pan` 输出；没有把伪代码改写成假定的 Solidity。攻击区块 `25434062` 的 `eth_getCode`、最新 `eth_getCode` 和 Etherscan 页面输入均为同一份 3,577 字节 runtime。

runtime 一致只能证明反编译输入对应攻击时合约，不能证明变量名、类型、控制流表达式或伪代码与原始源码完全等价。`.pan` 不能交给 solc；本次没有编译，没有分叉重放，也没有证明攻击时池代理实现。池只作为调用和资金流上下文，不被声称为漏洞组件。

本视图同时保留 AaveOracle、wGOOGLx 代理和实现的完整验证源码包、完整 trace、交易、转账与固定 PoC。

- 当前视图：`complete`。
- 反编译入口：[EdelPriceAdapter.decompiled.pan](../../../dataset/benchmark_complete/20260701_EdelFinance_decompiled/EdelPriceAdapter.decompiled.pan)
- runtime 对比：[adapter-runtime-comparison.json](evidence/adapter-runtime-comparison.json)
- 机器可读来源：[SOURCE.json](SOURCE.json)
- 交易：[攻击交易](https://etherscan.io/tx/0xe2320086b2815d21b0927839bd0e306466c29a68d38d5361e99dd21ec5472612)
- 复现材料：DeFiHackLabs 固定 commit `8c520a6ed54c9a19896bfc921d98728b078ffdc2`，仅作复现证据。
- 损失边界：公开口径 USD 204,200、305,000、403,000 未统一，CSV 损失列留空。

攻击链路与原理说明：[阅读本 case 分析](../../../docs/cases/20260701_EdelFinance_decompiled.md)。
