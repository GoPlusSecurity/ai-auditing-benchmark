# 2026-10-16：X=123、Y=5 执行归档

从固定导出的第 123 条 CSV 解析记录开始，按行号递减处理，到第 106 行累计取得 5 条“合约代码缺陷且关键漏洞有公开原始源码”的记录并停止。扫描 18 行，新增 5 例，跳过 13 行，无重复合并或已有案例补全。

## 本批入口

- [源表原始 CSV](sheet_gid0_raw.csv)：1050 条解析记录，第一条说明，第二条 14 列表头；原始 SHA-256 为 `d62e6e56755ab3c678bb9645eb0e0fa3a5aae6bf378f0b582a49814cab480c30`。
- [固定快照](snapshot.json)：X/Y、读取时间与时区、原始地址、实际扫描顺序、18 行全部字段和入选原行号。
- [逐行处理结果](results.json)：18 行资格、处置、理由和来源入口；跳过不计入 Y。
- [本批参数及索引字段](selected_cases.json)：5 个 case 的中英文写入字段、来源和金额口径。
- [验证报告](validation.json)、[离线复算脚本](recompute_evidence.py)、[转账参数核对脚本](verify_transfer_parameters.py)、[因果路径审查](semantic_review.json)、[基线](baseline.json)、[CSV 字节保留记录](csv_append_manifest.json)、[ABI 迁移清单](abi_relocations.json)、[校验清单更新范围](checksum_updates.json)。
- [跳过行的筛选证据清单](screening_manifest.json)：原始公开页面、API 响应、固定版本资料及查询失败记录；它们作为配套材料保留，不是正式收录案例。失败查询只说明本次没有取得结果，不能证明公开资料永久不存在。
- [最终 33 项测试结果](test_results.json)、[执行决策和复核修复记录](execution_notes.md)。

## 正式案例

| 源表行 | Case | 说明 |
| --- | --- | --- |
| 123 | 20260715_Drips | [有符号转换反转付款方向](../../../docs/cases/20260715_Drips.md) |
| 121 | 20260715_Ostium | [未来时间戳报价进入结算](../../../docs/cases/20260715_Ostium.md) |
| 117 | 20260717_CrowdRingCircle | [先烧 pair 并 sync，再入账本金](../../../docs/cases/20260717_CrowdRingCircle.md) |
| 107 | 20260723_Verus | [重复根在两端解释不同](../../../docs/cases/20260723_Verus.md) |
| 106 | 20260724_LienFinance | [例外债券计数无法保证逐项匹配](../../../docs/cases/20260724_LienFinance.md) |

`dataset/<case>` 仅有完整原始源码和明确标注的必要参考源码。ABI、原始来源响应、编译输入/配置、交易和跟踪位于对应的 `dataset_artifacts`，中文解释在 `docs/cases`。`SOURCE.md` 链接同一篇案例说明。

## 按补充要求跳过的部分

RWT 有原始代币源码，但关键卖币合约没有取得原始源码，公开浏览器点击反编译后没有返回可用高层结果。42DAO 有 Vat 等原始源码和上游 Spotter；只在筛选阶段用官方 solc 0.5.12 对 Spotter 做了**当前**执行代码比较（去除 CBOR 元数据相等，完整 runtime 不同），关键 Median/OSM 漏洞版本源码及浏览器反编译没有取得。两例按用户补充跳过，且没有安装反编译依赖。Spotter 比较不证明攻击时状态，也不属于本批 5 个正式案例的编译验收。

Drips/Lien 的未验证攻击合约用于编排已有调用，核心缺陷有原始源码，实际参数与付款有完整内部跟踪支持；没有用猜测出来的攻击合约源码替代受害逻辑。Ostium 和 CRC 缺完整内部跟踪，分别明确把可独立核查的 calldata/回执与公开分析支持的步骤区分开。

## 离线核查方法

在仓库根目录运行：

```powershell
python -X utf8 -B docs/cases/sources/validate_20261016_batch.py --output dataset_artifacts/batches/20261016_x123_y5/validation.json
python -X utf8 -B dataset_artifacts/batches/20261016_x123_y5/recompute_evidence.py
python -X utf8 -B dataset_artifacts/batches/20261016_x123_y5/verify_transfer_parameters.py
```

在 `docs/cases/sources` 目录运行：

```powershell
python -X utf8 -B -m unittest test_20261002_batch test_20261016_batch -v
```

这些是本地数据检查和整数/十进制复算，不运行归档合约、下载的攻击代码或链上交易。验证数量和目标来自当前快照及逐行结果。旧批次选择函数的测试覆盖 Y=1、不合格起点、连续跳过、上下边界、非整数和布尔值、表头/越界、扫描量不足、合格量不足及单元格内换行。新增测试覆盖旧 CSV 被重新格式化、ABI 内容改变或旧位置仍留副本时的拒绝行为。

当前批次逐一核对 24 个源包的 407 个原始文件、160 份连续切片、23 份案例证据哈希及五例离线金额/参数复算。另从历史 ABI 输入、返回值核对 Verus 实际转账解析器和 8 项付款参数。37 个旧 ABI 迁移前后字节相同，1911 个旧源码文件与执行前基线一致。中英文 CSV 旧 52 条记录的全部字节保留，分别追加 5 条后各有 57 条事件；两套源码目录各有 56 个案例。

Sourcify/浏览器验证、历史调用目标、攻击前存储和独立重放是不同层级。正式 5 例均未本地编译、未分叉重放；Drips、Verus、Lien 有完整内部跟踪，Ostium 有 calldata 和回执，CRC 有原始交易回执。Verus 源链公证未从 RPC 独立全量重读。Ostium、Verus 的整体美元损失留空，逐笔币量另记。全库检查仍列出旧 JB 资料中的三条历史哈希差异，其对应源码本次与基线字节一致，没有修改范围外证据。
