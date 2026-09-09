# @ThetanutsFi [Decompiled] — 反编译样本 / Decompiled sample

**源码性质：panoramix_pseudocode；不是已验证原始源码。**

采用 Etherscan 的 Palkeoramix/Panoramix 反编译页面实际生成的全文，通过编辑器全选复制导出，保留原始输出。完整目录包含所有输出函数和运行时字节码；精简目录保留存储布局、claim、mint、费用铸币及 ERC-20 记账相关函数。DarkNavy 的该合约 recovered.sol 只有空函数占位，未将它用作本样本。

`.pan` 是反编译器的伪代码语法，不是 Solidity，不能交给 solc 编译。变量别名、表达式、事件参数和 payable 标记仍需结合字节码核对；输出中的原始乱码也保留，未把伪代码改写成假定的原始源码。未进行字节码等价证明或攻击交易重放。

入口：[Panoramix 反编译代码](ThetanutsIndex.decompiled.pan)。

- 当前视图：`simplified`。
- 原始表格：[第 104 行](https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0#gid=0)。目录及 CSV 日期均按表格保留为 `2026.06.15`。
- 损失金额采用表格 `lost_u`：USD 105,000；中文 CSV 单位为万美元，英文 CSV 单位为千美元。
- 反编译来源：[公开材料](https://etherscan.io/bytecode-decompiler?a=0xC2C3AE0a7b405058558C9b4a63b373486CB86Ac7)。
- 事件来源：[表格原始告警](https://x.com/blockaid_/status/2066524884583215322?s=46)；[技术分析](https://www.darknavy.org/web3/exploits/thetanuts-legacy-index-vault-zero-cost-remint/)。
- 机器可读的来源及限制见 [SOURCE.json](SOURCE.json)。

攻击链路与原理说明：[阅读本 case 分析](../../../docs/cases/20260615_ThetanutsFi_decompiled.md)。
