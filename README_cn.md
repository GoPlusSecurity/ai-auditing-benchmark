# ai-auditing-benchmark

面向 **AI 智能合约审计** 的基准数据集：从历史上因合约漏洞导致的真实攻击事件中，整理并提取被攻击项目（或相关合约）中 **存在漏洞的合约源码**，用于评估与训练审计能力（例如与 `ai-auditing-engine` 等工具配合）。

## 数据集来源与目标

- **来源**：公开可得的链上/安全事件报告与仓库快照，对应各次攻击中被利用或存在缺陷的合约代码。
- **目标**：
  - 提供可复现、可对比的 **真实漏洞样本**；
  - 支持在完整漏洞上下文中评测 AI 审计效果。

## 目录结构

`dataset/` 只存放源码，ABI 和其他配套资料位于对应的 `dataset_artifacts/`，两者均按事件分目录存放。每个事件目录名建议理解为：`{事件日期YYYYMMDD}_{项目或协议标识}`（日期在前，便于按时间排序与检索）。

```
dataset/
└── {事件日期YYYYMMDD}_{项目或协议标识}/    # 被攻击合约的完整代码（含依赖、库等）

dataset_artifacts/
├── {事件日期YYYYMMDD}_{项目或协议标识}/    # 元数据、来源、交易证据、构建配置及校验清单
└── batches/                                # 批次快照与校验记录
```

`dataset/` 保存 `.sol`、`.rs`、`.cairo`、`.pan`、`.ts`、`.cpp` 和 `.h` 源码，包括既有反编译代码、项目测试源码和必要的源链上下文；ABI 文件统一放在 `dataset_artifacts/` 对应路径。其他原来位于 `dataset/{案例}/{路径}` 的配套文件，现位于 `dataset_artifacts/{案例}/{路径}`；源码路径和文件字节保持原样。构建配置、锁文件、恢复工具及编译器输入位于资料目录，编译需要原工程布局时，应在临时目录中合并对应的两棵目录。

元数据中的案例相对路径，包括 `complete_case_root`，以对应的资料案例目录为基准；源码引用使用 `../../dataset/{案例}/...`，原有仓库根目录路径继续沿用。资料目录中的每份 `SHA256SUMS` 同时覆盖该案例的资料文件和源码文件。

源码目录收录 **被攻击合约的完整源码树**（含接口、库、第三方依赖等），便于：
  - 跨合约、跨模块的交互分析；
  - 需要完整调用图与状态流的审计流程。

## 事件索引（CSV）

仓库根目录下的 CSV 列举了 **全部已索引事件**，包含只有配套证据、没有源码的案例，建议作为元数据的权威来源。2026-10-16 批次完成后，两份 CSV 各有 57 条事件记录，源码目录有 56 个案例。最新批次见[案例说明索引](docs/cases/README.md)和[逐行处理结果](dataset_artifacts/batches/20261016_x123_y5/results.json)。JaredFromSubway 只有 runtime 字节码和证据，全部存放在 `dataset_artifacts/` 中。

- 中文版：[`ai-auditing-benchmark_cn.csv`](ai-auditing-benchmark_cn.csv)
- 英文版：[`ai-auditing-benchmark_en.csv`](ai-auditing-benchmark_en.csv)

两份 CSV 记录相同事件，字段语言和损失金额单位不同：中文为万美元，英文为千美元。各列含义如下：

- **攻击时间**：事件发生日期（`YYYY.MM.DD`）。
- **项目**：被攻击项目或协议（展示名可能与目录中的标识略有差异，如带 `@` 或括号说明）。
- **漏洞**：漏洞类型概括。
- **漏洞详情**：攻击手法与缺陷说明。
- **攻击交易**：代表性链上交易哈希。
- **漏洞合约地址**：相关合约地址（同一单元格内可能为多行）。
- **损失金额/万美元**：公开报道或估算的损失规模。

**与目录名的对应关系**：`dataset/` 下的事件文件夹名为 `{事件日期YYYYMMDD}_{项目或协议标识}`，其中日期由「攻击时间」换算为八位数字（例如 `2025.05.28` → `20250528`）；`{项目或协议标识}` 与表格中的「项目」列对应，一般为小写/驼峰等形式的目录安全命名（如表格中的 `@Corkprotocol` 对应目录 `20250528_Corkprotocol`）。若「项目」列含额外说明（如合约地址括号），目录名通常仍采用简短协议标识，以仓库内实际文件夹为准。

源码树路径因事件而异，请在上述目录下按子项目/合约名继续浏览。

## 快速开始（按事件定位代码）

1. 在 CSV 中找到目标行（按「攻击时间 / 项目」）。
2. 将「攻击时间」转换为 `YYYYMMDD`，与项目标识拼接成目录名：`{YYYYMMDD}_{ProjectSlug}`。
3. 打开 `dataset/{目录名}/...`，阅读完整审计上下文。
4. 在有对应记录的案例中，阅读 `dataset_artifacts/{目录名}/SOURCE.md` 和 `case_metadata.json`，确认来源及源码证据范围。

示例：`2025.05.28` + `@Corkprotocol` → `dataset/20250528_Corkprotocol/`

已编写的[攻击链路与原理说明](docs/cases/README.md)用通俗语言说明合约或协议负责什么、漏洞在哪里、攻击者怎样利用，并附代码和资料来源。对应资料目录 `dataset_artifacts/{案例}/SOURCE.md` 也提供同一文档入口。

2026-09-14 按源表第 98–102 行整理 DLMC、Royalties、SecondFi、ATM、Taiko，保留[五行快照](docs/cases/sources/20260914_sheet_rows_98_102.json)及[五篇详细说明](docs/cases/README.md)。ATM 以及非合约的 SecondFi 钱包事件均已从 dataset 目录和中英文 CSV 移除，仅保留文档与引用资料；本批数据集现包含 DLMC、Royalties、Taiko 三条。Taiko 区分实际 SGX 验证源码与其他上游上下文。各案例对应资料目录中的 case_metadata.json 和 SOURCE.md 标明证据范围。

2026-10-02 按 `X=116、Y=5` 执行向上筛选，实际扫描解析后的源表第 116–106 行，收录第 113、110、108、107、106 行，分别是 [`20260709_BFB`](docs/cases/20260709_BFB.md)、[`20260711_Bonzo_Supra`](docs/cases/20260711_Bonzo_Supra.md)、[`20260713_PHX`](docs/cases/20260713_PHX.md)、[`20260713_Lumi_Sodium`](docs/cases/20260713_Lumi_Sodium.md) 和 [`20260714_VECAndETH`](docs/cases/20260714_VECAndETH.md)。[固定 11 行快照](docs/cases/sources/20261002_sheet_rows_106_116.json)绑定原始导出 SHA-256 `862e92ed5b738acce956be4d560e1e5f747375a92839debc3eb7ec7cc00c5b90`，[逐行结果](docs/cases/sources/20261002_sheet_rows_106_116_results.json)说明其余 6 行的跳过原因。五个案例均取得与缺陷相关的公开原始源码：BFB 为 Sourcify match，PHX、Lumi/Sodium、VECAndETH 为 exact match；Bonzo/Supra 保存同一漏洞路径的 Supra 原始源码和 Hedera 攻击 actions，同时明确 XDC/Hedera runtime 不同、攻击时源码等价尚未证实。本批已核对交易和回执/actions，未本地编译或分叉重放。

2026-10-01 的源表第 114–118 行新增一个 [`20260701_EdelFinance_decompiled`](dataset_artifacts/20260701_EdelFinance_decompiled/SOURCE.md) 样本。价格适配器由 Etherscan Palkeoramix/Panoramix 生成的 74 个逻辑行全文完整保留；其 3,577 字节输入与攻击区块 25434062 的 `eth_getCode` 完全一致，周边 AaveOracle 和 wGOOGLx 使用验证源码。该样本明确是反编译伪代码，不是已验证原始 Solidity；没有编译、源码等价证明或分叉重放。公开美元损失口径冲突，因此中英文 CSV 损失列均留空。

2026-09-10 按源表第 99–103 行补充 JaredFromSubway、BnbLabubu、Namada、Axelar / Secret、mySwap，并保留[原始行快照](docs/cases/sources/20260910_sheet_rows_99_103.json)。这批包含 Rust 协议代码和源码尚未取得的事件材料。对应资料目录的 `case_metadata.json` 用 `source_status` 标出源码缺失或历史交易对应不完整的情况；这类目录不能直接算作已验证的漏洞源码样本。缺失的交易或地址留空，限制写入 CSV 详情。中英文金额分别按万美元、千美元换算。

mySwap CL 的目录现已保存攻击时执行的链上 Sierra 类，并通过类哈希校验。状态 `decompiled_sierra` 表示已恢复保留指令编号的伪 Cairo 代码：归档保留 425 个函数，覆盖攻击相关入口及其依赖。[Case 文档](docs/cases/20260619_mySwap.md)将具体检查与原始 RPC 跟踪对应；原始 Cairo 工程仍未恢复，未声称完成本地编译或攻击重放。

JaredFromSubway 的资料目录已保存受害机器人完整的 13,835 字节 EVM runtime，提供 `.hex` 和 `.bin`。按攻击区块 25360696 及前一区块 25360695 的区块哈希查询，返回结果相同。状态 `runtime_bytecode_only` 表示已取得机器码，原始 Solidity 和反编译仍未取得；[字节码来源记录](dataset_artifacts/20260621_JaredFromSubway/bytecode.json)保留地址、区块哈希、原始 RPC 证据和校验值。

## 与 AI 审计引擎的配合方式（建议）

1. **回归评测**：对每个事件，在 `dataset/{案例}` 上跑审计 prompt/流水线，记录检出率、误报与成本。
2. **发布检查**：发布前使用同一套完整上下文做抽检。

## 使用与声明

- 本仓库代码片段来自各项目的公开源码或事件相关公开材料，**版权归原作者所有**；仅用于安全研究与基准评测。
- 漏洞代码具有 **破坏性**，请勿用于非法用途；引用本数据集发表论文或产品时，请注明数据集名称与版本/提交信息。

## 贡献与更新

欢迎通过 Issue / PR 补充新事件或修正路径；新增条目请同时放入 `dataset/` 和 `dataset_artifacts/`，**并同步更新** CSV 元数据（[`ai-auditing-benchmark_cn.csv`](ai-auditing-benchmark_cn.csv)、[`ai-auditing-benchmark_en.csv`](ai-auditing-benchmark_en.csv)），在 PR 中简要说明事件出处与漏洞类型。
