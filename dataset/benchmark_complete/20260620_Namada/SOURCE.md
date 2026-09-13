# Namada MASP：真实源码缺陷，历史交易对应待补

攻击链路与原理见[案例文档](../../../docs/cases/20260620_Namada.md)。源表为 2026-09-10 读取的第 101 行，见[行快照](../../../docs/cases/sources/20260910_sheet_rows_99_103.json)。日期和金额沿用 2026.06.20、约 60 万美元。

**源码中的证明验证错误已核对；尚未完成它与本次资金流出的交易级对应。** `case_metadata.json` 的 `source_status` 明确为 `upstream_source_incident_correlation_incomplete`。用于要求链上利用已完全确认的评测集合时，应先按这个状态过滤。

## 文件与版本

| 目录 | 内容及固定来源 |
| --- | --- |
| `masp/` | MASP 三个库的完整源码、库内依赖、Cargo 清单与锁文件；固定到 [`7fcae1072d692221a0620469da7815e6d388ba54`](https://github.com/namada-net/masp/tree/7fcae1072d692221a0620469da7815e6d388ba54) |
| `namada_context/` | 事发前 Namada 的完整 `shielded_token` crate、根依赖清单以及 IBC 调用上下文；固定到 [`6714f3a363d7a2eb23fec00209ac1604acb5f205`](https://github.com/namada-net/namada/tree/6714f3a363d7a2eb23fec00209ac1604acb5f205) |
| `nam-bellperson/` | `nam-bellperson 0.26.6-nam.1` 的完整 `src` 与包清单，提供返回 `Result<bool, ...>` 的底层验证实现 |

本数据集不收录 `masp/masp_proofs/params/` 下的 `masp-convert.vk`、`masp-spend.vk`、`masp-output.vk` 三个参数文件。

`namada_context` 是完整受影响库的调用上下文，没有收录整条链的所有模块。外部依赖保留原 Cargo 清单，未全部供应到仓库。本目录不是开箱可启动的主网节点。

## 如何确认拿到的是原始版本

Namada 事发前提交的 `Cargo.toml` 与 `Cargo.lock` 指向 `masp_proofs 3.0.9`。该发布包的 `.cargo_vcs_info.json` 指向上述 MASP 提交，关键 `batch.rs` 与提交源码逐字节相同。

- `masp_proofs 3.0.9` 包 SHA-256：`328364c1a31969cf20f6297b1fbee34f1b0852bae499aaf17112cb2b7dd2e9c2`。
- `nam-bellperson 0.26.6-nam.1` 包 SHA-256：`b2db0fa5a3cc38b4b835b7d20f032d1f1266d4db7932d63d20b667dc9fb20416`。

两者都与原 Namada 锁文件相符。`source_manifest.json` 保存每个收录文件的哈希及来源。库、调用上下文的原始许可证分别保留在相应目录。

## 缺陷与事件的证据边界

真实缺陷：`BatchValidator::validate()` 对花费、转换和输出证明只检查 `.is_err()`。底层无效证明返回 `Ok(false)` 时不会被拒绝。官方 [MASP PR #114](https://github.com/namada-net/masp/pull/114)修正为仅接受 `Ok(true)`；[Namada PR #5026](https://github.com/namada-net/namada/pull/5026)的分支名为 `tiago/masp-drain-fix`，并升级了相应依赖、增加假证明回归测试。

上述证据支持收录这个源码缺陷，但本次未核实历史攻击交易输入、主网二进制版本及具体提款顺序。源表交易和地址原本为空；CSV 也留空，而不是补一个未经确认的哈希或 EVM 地址。Namada 的 MASP 是协议内置组件。

核验完成的是源码、发布包哈希、调用链、官方修复与测试内容。本轮未运行 Rust 测试、下载大型证明参数、重建节点或重放攻击；IBC 转出只作为事件记录中的资金路径，不被直接写成已确认根因。
