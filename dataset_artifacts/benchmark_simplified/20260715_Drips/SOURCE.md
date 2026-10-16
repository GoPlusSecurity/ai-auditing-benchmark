# 20260715_Drips

公开原始源码与来源记录。源码位于[对应代码目录](../../../dataset/benchmark_simplified/20260715_Drips)，本目录存放 ABI、编译配置、来源和证据。

- [共同案例说明](../../../docs/cases/20260715_Drips.md)
- [固定批次快照](../../batches/20261016_x123_y5/snapshot.json)
- [逐行处理结果](../../batches/20261016_x123_y5/results.json)
- [完整来源清单](../../benchmark_complete/20260715_Drips/provenance.json)

原始源码已取得并逐文件计算 SHA-256。浏览器验证/Sourcify 匹配状态、历史调用目标、历史状态和复现是不同的核查层级。编译输入中其他同名模块只是该源包的上下文，不自动代表攻击时部署版本。

本例未本地编译、未分叉重放；完整内部跟踪取得状态为 `True`。详细的已核查内容、推断和缺口以共同案例说明为准。

精简代码为完整版的连续原文行切片，见 `slice_manifest.json`。切片保留漏洞因果路径，但不是独立编译单元。没有补写或改写 Solidity 逻辑。
