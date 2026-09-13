# ai-auditing-benchmark

面向 **AI 智能合约审计** 的基准数据集：从历史上因合约漏洞导致的真实攻击事件中，整理并提取被攻击项目（或相关合约）中 **存在漏洞的合约源码**，用于评估与训练审计能力（例如与 `ai-auditing-engine` 等工具配合）。

## 数据集来源与目标

- **来源**：公开可得的链上/安全事件报告与仓库快照，对应各次攻击中被利用或存在缺陷的合约代码。
- **目标**：
  - 提供可复现、可对比的 **真实漏洞样本**；
  - 支持在「完整上下文」与「精简攻击面」两种粒度下评测 AI 审计效果。

## 目录结构

数据位于 `dataset/` 下，按事件分目录存放。每个事件目录名建议理解为：`{事件日期YYYYMMDD}_{项目或协议标识}`（日期在前，便于按时间排序与检索）。

```
dataset/
├── benchmark_complete/    # 被攻击合约的完整代码（含依赖、库等，尽量贴近当时可编译/可审计的上下文）
└── benchmark_simplified/  # 仅保留与漏洞相关的函数及必要依赖，剔除明显无关逻辑
```

### `benchmark_complete`

- 收录 **被攻击合约的完整源码树**（含接口、库、第三方依赖等），便于：
  - 跨合约、跨模块的交互分析；
  - 需要完整调用图与状态流的审计流程。

### `benchmark_simplified`

- 在 **同一攻击事件** 对应代码基础上，**只保留存在漏洞的函数**（及支撑其编译、语义理解所必需的最小依赖），**排除与漏洞无关的函数**，用于：
  - 与 **ai-auditing-engine** 等引擎集成时，**缩小输入范围**，更利于 **精确定位漏洞**；
  - **降低 token 与算力成本**，加快迭代评测。

> 说明：`benchmark_simplified` 中仍可能包含部分库文件或接口，是因为漏洞函数在类型、常量或数学库层面存在耦合；其原则是「最小必要」，而非「仅单个 .sol 单文件」。

## 事件索引（CSV）

仓库根目录下的 CSV 列举了当前 `dataset` 中收录的 **全部事件**，建议作为元数据的权威来源：

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

**与目录名的对应关系**：`dataset/benchmark_complete` 与 `benchmark_simplified` 下的事件文件夹名为 `{事件日期YYYYMMDD}_{项目或协议标识}`，其中日期由「攻击时间」换算为八位数字（例如 `2025.05.28` → `20250528`）；`{项目或协议标识}` 与表格中的「项目」列对应，一般为小写/驼峰等形式的目录安全命名（如表格中的 `@Corkprotocol` 对应目录 `20250528_Corkprotocol`）。若「项目」列含额外说明（如合约地址括号），目录名通常仍采用简短协议标识，以仓库内实际文件夹为准。

源码树路径因事件而异，请在上述目录下按子项目/合约名继续浏览。

## 快速开始（按事件定位代码）

1. 在 CSV 中找到目标行（按「攻击时间 / 项目」）。
2. 将「攻击时间」转换为 `YYYYMMDD`，与项目标识拼接成目录名：`{YYYYMMDD}_{ProjectSlug}`。
3. 选择粒度：
   - `dataset/benchmark_complete/{目录名}/...`：完整上下文（更贴近真实审计输入）。
   - `dataset/benchmark_simplified/{目录名}/...`：最小必要切片（更省 token，便于快速回归）。

示例：`2025.05.28` + `@Corkprotocol` → `dataset/benchmark_simplified/20250528_Corkprotocol/`

已编写的[攻击链路与原理说明](docs/cases/README.md)用通俗语言说明合约或协议负责什么、漏洞在哪里、攻击者怎样利用，并附代码和资料来源。对应事件目录的 `SOURCE.md` 也提供同一文档入口。

2026-09-10 按源表第 99–103 行补充 JaredFromSubway、BnbLabubu、Namada、Axelar / Secret、mySwap，并保留[原始行快照](docs/cases/sources/20260910_sheet_rows_99_103.json)。这批包含 Rust 协议代码和源码尚未取得的事件材料。新增目录的 `case_metadata.json` 用 `source_status` 标出源码缺失或历史交易对应不完整的情况；这类目录不能直接算作已验证的漏洞源码样本。缺失的交易或地址留空，限制写入 CSV 详情。中英文金额分别按万美元、千美元换算。

mySwap CL 的两套目录现已保存攻击时执行的链上 Sierra 类，并通过类哈希校验。状态 `decompiled_sierra` 表示已恢复保留指令编号的伪 Cairo 代码：完整版保留 425 个函数，精简版保留攻击相关 5 个入口及其依赖，共 276 个函数。[Case 文档](docs/cases/20260619_mySwap.md)将具体检查与原始 RPC 跟踪对应；原始 Cairo 工程仍未恢复，未声称完成本地编译或攻击重放。

JaredFromSubway 的两套目录已保存受害机器人完整的 13,835 字节 EVM runtime，提供 `.hex` 和 `.bin`。按攻击区块 25360696 及前一区块 25360695 的区块哈希查询，返回结果相同。状态 `runtime_bytecode_only` 表示已取得机器码，原始 Solidity 和反编译仍未取得；[字节码来源记录](dataset/benchmark_complete/20260621_JaredFromSubway/bytecode.json)保留地址、区块哈希、原始 RPC 证据和校验值。

## 与 AI 审计引擎的配合方式（建议）

1. **回归与对比评测**：对同一事件，分别在 `benchmark_complete` 与 `benchmark_simplified` 上跑同一套审计 prompt/流水线，对比检出率、误报与成本。
2. **日常迭代**：开发阶段优先用 `benchmark_simplified` 做快速验证；发布前再用 `benchmark_complete` 做更接近生产上下文的抽检。

## 使用与声明

- 本仓库代码片段来自各项目的公开源码或事件相关公开材料，**版权归原作者所有**；仅用于安全研究与基准评测。
- 漏洞代码具有 **破坏性**，请勿用于非法用途；引用本数据集发表论文或产品时，请注明数据集名称与版本/提交信息。

## 贡献与更新

欢迎通过 Issue / PR 补充新事件、修正路径或完善「漏洞函数」裁剪规则；新增条目请同时维护 `benchmark_complete` 与 `benchmark_simplified` 的对应关系，**并同步更新** CSV 元数据（[`ai-auditing-benchmark_cn.csv`](ai-auditing-benchmark_cn.csv)、[`ai-auditing-benchmark_en.csv`](ai-auditing-benchmark_en.csv)），在 PR 中简要说明事件出处与漏洞类型。
