# Axelar / Secret 侧 ICS-20 桥接合约

- 攻击链路与原理：[只认代币名字，不认消息来源](../../../docs/cases/20260619_Axelar_Secret.md)。
- 本目录保存 Rust 原始源码、合约的本地依赖、Cargo 清单与许可证；主入口为 `ics20-for-axelar/contracts/cw20-ics20/src/ibc.rs`。
- 源表：2026-09-10 读取的第 102 行；[固定行快照](../../../docs/cases/sources/20260910_sheet_rows_99_103.json)。索引日期使用源表的 2026.06.19；实际攻击日期据官方为 2026-06-10。
- 受影响合约：`secret1yxjmepvyl2c25vnt53cr2dpn8amknwausxee83`；不是源表 `malicious_address` 中的攻击者。

## 源码来源

[Secret 官方复盘](https://forum.scrt.network/t/security-incident-axelar-secret-ibc-bridge-exploit-june-10-2026/7995)明确将受影响部署 Code ID 2446 对应到 `add-migration-message` 分支的 `b206182`。

本地保存的固定提交为 [`b2061822376a772da0e55bbf9436797b9d0356b7`](https://github.com/scrtlabs/ics20-for-axelar/tree/b2061822376a772da0e55bbf9436797b9d0356b7)。`ics20-for-axelar/` 下的文件直接从这一提交提取，未重写业务逻辑。未收录 CI、辅助发布脚本和上游编译产物。

`source_manifest.json` 列出逐文件来源 URL 与 SHA-256；`case_metadata.json` 保存事件字段、源码状态、代表性交易和源表原交易链接。原三条 Axelar 交易未独立确认其阶段，CSV 改用官方复盘明确给出角色的首次铸币、赎回交易。

## 核查范围

本地源码确认接收路径只按 `denom` 查询允许列表，未把来源通道绑定到真正的 Axelar，随后调用真实 saToken 的 `Mint`。管理员配置检查与正常赎回的 burn/send 路径均保留在原始源码里。

部署关联采用官方披露。本轮没有重建 Wasm、核对链上 Code ID 字节码、运行 Rust/Secret 测试或复现跨链交易。外部 crates/git 依赖保留原清单与锁文件，未全部下载进仓库。

上游许可证见 `ics20-for-axelar/LICENSE-APACHE`、`LICENSE-AGPL.md` 和 `NOTICE`，按具体文件及包声明适用。
