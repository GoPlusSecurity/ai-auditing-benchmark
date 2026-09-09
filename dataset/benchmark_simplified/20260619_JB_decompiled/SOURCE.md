# $JB [Decompiled] — 反编译样本 / Decompiled sample

**源码性质：agent_native_recovery；不是已验证原始源码。**

采用 DarkNavy 发布的反编译恢复代码，主代币置信度为 medium，路由器及控制器为 low。原作者对关键选择器进行选择性恢复：元数据中的 coverage=1.0 只表示请求的选择器均有恢复结果，不代表恢复全部部署代码。完整目录保存全部已取得的恢复材料及运行时字节码；精简目录只保留代币销毁入口及其依赖，并保留路由器上下文。

这些恢复文件不是已验证的原始 Solidity。函数名、类型、存储布局和非核心路径可能有还原误差；未做字节码等价证明。路由器文件存在未恢复算术、抽象占位声明及语法问题，作为 `.sol.txt` 上下文原样保存，不纳入可编译 Solidity 文件。具体限制见原始 `provenance/*.decompile_meta.json`。不得以恢复文件能编译推断其行为等价于链上合约。

入口：[代币恢复代码](JBToken.recovered.sol)；[路由器上下文](context/TradeRouter.recovered.sol.txt)。

- 当前视图：`simplified`。
- 原始表格：[第 99 行](https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0#gid=0)。目录及 CSV 日期均按表格保留为 `2026.06.19`。
- 损失金额采用表格 `lost_u`：USD 50,000；中文 CSV 单位为万美元，英文 CSV 单位为千美元。
- 反编译来源：[公开材料](https://github.com/DarkNavySecurity/web3-exploit-analysis/tree/main/artifacts/analysis_0x54e120b8d62a9d7cef94bf51f1f5b8aa13565d76d8797a79afeeb25ed0e1dc25)。
- 事件来源：[表格原始告警](https://x.com/audit_911/status/2067943961327763788)；[技术分析](https://www.darknavy.org/web3/exploits/jb-token-pair-burn-reserve-manipulation/)。
- 机器可读的来源及限制见 [SOURCE.json](SOURCE.json)。

攻击链路与原理说明：[阅读本 case 分析](../../../docs/cases/20260619_JB_decompiled.md)。
