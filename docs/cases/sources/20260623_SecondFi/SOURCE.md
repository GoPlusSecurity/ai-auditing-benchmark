# SecondFi：文档事件资料

攻击链路见[一次正常签名为何可能暴露转账权限](../../20260623_SecondFi.md)。

这是一个**非合约事件**。按用户最新要求，本案例已从 `dataset/benchmark_complete`、`dataset/benchmark_simplified` 和中英文 CSV 移除；本目录仅保留文档引用所需的事件证据。这里没有受害智能合约源码，也没有把通用签名示例当成受害程序。

源表来自[2026-09-14 第 100 行快照](../20260914_sheet_rows_98_102.json)。日期与 200 万美元口径保留在归档元数据中；后续官方统计单列。原表未给交易或漏洞合约地址，因此相关字段留空。

已阅读官方 FAQ、外部取证方的公开研究说明和 RFC 8032。原始来源及核实范围见[evidence/sources.json](evidence/sources.json)，样本使用边界见[evidence/scope.json](evidence/scope.json)。源码、发布二进制和逐笔攻击关联未独立验证；未运行编译、攻击重放或任何真实私钥恢复。

本目录不是数据集样本，不能用于智能合约源码评测。
