# Axelar / Secret：接收铸币与赎回路径的源码切片

攻击链路与原理见[案例文档](../../../docs/cases/20260619_Axelar_Secret.md)。对应[完整源码与来源](../../benchmark_complete/20260619_Axelar_Secret/SOURCE.md)。

本目录直接摘取官方提交 `b2061822376a772da0e55bbf9436797b9d0356b7` 的 Rust 代码，保留：

- IBC 通道的建立检查与注册。
- `ibc_packet_receive()` → `do_ibc_packet_receive()` → 允许列表查询 → `mint_amount()`。
- 允许列表的初始化与管理员限制。
- 代币回调 → `execute_transfer()` → 销毁凭证并发送 IBC 赎回消息。
- 所需消息、状态、错误类型。

`source_manifest.json` 记录每段在完整版中的行号与切片哈希。没有把 Rust 改写成 Solidity，也没有加入漏洞修复。裁掉了迁移、查询、无关确认路径和测试；所需外部类型仍可在完整版及原依赖清单查阅。

这是用于静态审计的片段集合，**不是独立 Cargo 工程**，未声称能够单独编译。历史交易、Code ID 关联和金额口径沿用完整版的证据范围；本轮没有运行链上攻击。
