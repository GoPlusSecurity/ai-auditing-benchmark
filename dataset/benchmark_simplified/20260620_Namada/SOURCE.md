# Namada MASP：证明返回值和调用链的原始源码切片

攻击链路与原理见[案例文档](../../../docs/cases/20260620_Namada.md)；版本与历史关联限制见[完整版来源说明](../../benchmark_complete/20260620_Namada/SOURCE.md)。

本目录沿着“底层返回真假 → MASP 读取结果 → Namada 决定是否接受交易”保留真实 Rust 代码：

- `nam-bellperson/src/groth16/verifier.rs`：验证计算及 `Result<bool, ...>` 返回语义。
- `masp/masp_proofs/src/sapling/verifier/batch.rs`：证明入队、签名检查及三处 `.is_err()` 判断。
- `masp/masp_proofs/src/sapling/verifier.rs`：承诺、公开输入和共识检查上下文。
- `masp/masp_primitives/src/transaction/components/sapling.rs`：交易证明和授权数据类型。
- `namada_context/crates/shielded_token/src/validation.rs`：实际调用入口、签名哈希与 gas 处理。

所有片段从完整版直接提取；`source_manifest.json` 记录原始行段和哈希。未替换函数体、未添加漏洞修复，保留的许可证按对应上游适用。

这是静态阅读用的代码切片，不是独立 Cargo 工程。编译所需的其他模块应回到完整版及其依赖清单查阅。源码错误已经核对，但没有攻击交易可用于完成本次事件的逐笔关联，状态仍为 `upstream_source_incident_correlation_incomplete`。不应把该条当成已经重放验证的攻击样本。
