# Taiko：完整审计上下文

攻击链路见[假证明如何让桥释放真实资产](../../../docs/cases/20260622_Taiko.md)。源表使用[2026-09-14 第 102 行快照](../../../docs/cases/sources/20260914_sheet_rows_98_102.json)，保留2026.06.22与170万美元口径。

源码固定到 Taiko 官方仓库事发前提交 [`ff002a4516b489c7146675f7036d699b07a7f785`](https://github.com/taikoxyz/taiko-mono/tree/ff002a4516b489c7146675f7036d699b07a7f785)。`source_manifest.json`记录原始文件或切片的来源、行号与SHA-256。完整版保存协议完整contracts树、包配置、许可证和根锁文件；外部依赖没有全部安装，本地完整工程未编译。

两份实际出现于准备交易的SGX verifier的Etherscan源包已保存在完整版 `verified-sgx/`。两者的 `SgxVerifier.sol` 均与官方快照逐字节一致。其余源码是对应机制的上游审计上下文；没有把整个快照声称为已匹配攻击时部署的源码。源状态为 `verified_sgx_source_with_upstream_context`。

精简版按原行号直接摘取注册、认证、白名单判定、检查点写入、消息验证和提款函数，并保存状态/类型上下文。它是静态审计切片集合，不是可独立编译的完整合约工程；函数体没有重写或修复。

交易证据来自Etherscan原始HTML，包含准备交易的两个注册事件、假检查点和10个RETRIABLE状态，以及USDC消息后续变为DONE并转出649761.236201 USDC。原始页面在完整版 `evidence/etherscan/`，解码字段在 `evidence/decoded-events.json`。公共RPC回执查询返回null，因此不冒充RPC回执；没有运行完整trace、SGX硬件证明、历史代理槽校验或主网分叉重放。

源表恶意地址 `0x7506DeA0c38ca0B55364B22424374c5A1ae1B76a` 是攻击者，不是漏洞合约。Bridge和ERC20Vault是付款组件，根因需连同上游证明路径分析。
