# 攻击链路与原理说明

这里收录已编写详细说明的 case。每篇都围绕三件事展开：**合约或协议平时负责什么、程序具体哪里出错、攻击者如何利用错误把钱拿走。** 正文先用直接的语言解释，再给出源码、交易和资料位置；没有查到的部分会明确说明。

源码、反编译代码和 `abi.json` 位于仓库根目录的 `dataset/`，配套元数据、来源记录、交易证据和校验清单位于对应的 `dataset_artifacts/`。两棵目录沿用相同的完整／精简版本和案例层级；只有字节码及证据的 JaredFromSubway 位于资料目录，仍保留在事件索引中。

## 2026-10-02 按 X=116、Y=5 向上筛选

本批重新读取 Google Sheet，按解析后的物理记录从第 116 行向上检查。扫描范围为第 106–116 行，到第 106 行时累计取得 5 条“合约代码缺陷 + 公开漏洞原始源码”记录并停止。原始导出见[只读 CSV](sources/20261002_sheet_gid0_raw.csv)，SHA-256 为 `862e92ed5b738acce956be4d560e1e5f747375a92839debc3eb7ec7cc00c5b90`；完整 11 行内容见[固定快照](sources/20261002_sheet_rows_106_116.json)，逐行源码资格与处置见[批次结果](sources/20261002_sheet_rows_106_116_results.json)。

| 源表行 | 处置 | 事件 | 结论 |
| --- | --- | --- | --- |
| 116 | 跳过 | Summer Finance | 技术复盘将根因定为离职权限未完成回收的运营失误，未确立合约代码缺陷。 |
| 115 | 跳过 | BonkDAO | 恶意治理提案利用 quorum、timelock 和押金配置，未确立合约代码错误。 |
| 114 | 跳过 | USDT 授权钓鱼 | 用户签署恶意授权，不是代币或受害合约的代码缺陷。 |
| 113 | 新增 | [BFB：零数量转账反复烧池子](20260709_BFB.md) | Sourcify creation/runtime `match`；完整 BFB 源码与回执已归档。 |
| 112 | 跳过 | CodexField | 公开信息只称 scam/rug pull，无攻击交易、已确认代码缺陷和漏洞源码。 |
| 111 | 跳过 | Solana 鲸鱼钱包 | 疑似私钥泄漏，未确立智能合约代码缺陷。 |
| 110 | 新增 | [Bonzo / Supra：BLS 零签名通过](20260711_Bonzo_Supra.md) | 有公开 Supra 原始漏洞源码和 Hedera 攻击 actions；XDC/Hedera runtime 不同，未声称部署等价。 |
| 109 | 跳过 | SpaceXAI / Starlink | 社交账号被盗后推广代币，没有受害合约代码缺陷。 |
| 108 | 新增 | [PHX：卖出路径烧 pair 并重写储备](20260713_PHX.md) | Sourcify creation/runtime `exact_match`；交易日期与源表日期差异已单列。 |
| 107 | 新增 | [Lumi / Sodium：ERC-1271 会话绕过与持久授权](20260713_Lumi_Sodium.md) | Sourcify creation/runtime `exact_match`；三组交易与回执已归档。 |
| 106 | 新增 | [VECAndETH：可操纵现货价结算奖励](20260714_VECAndETH.md) | Sourcify creation/runtime `exact_match`；毛付款、手续费、净收益与源表损失分开记录。 |

本批新增 5 个 case，无重复、无已有 case 补全，跳过 6 行。四个 Sourcify 案例保存完整原始源包与匹配状态；Bonzo/Supra 保存 XDCScan 原始 Supra 源码、Hedera 攻击时代理/实现调用和两份 runtime 对比。对攻击时 Hedera runtime 使用用户指定的 Panoramix 官方仓库（工具自报版本 Panoramix 17 Feb 2020）处理，得到 9,550 行完整反汇编和 20 个 selector（包括 `0x2818300e`），但全量及目标函数符号执行均未收敛，因此没有高层伪代码；失败的 `.pan`/`.json` 未归档。详见[运行记录](../../dataset_artifacts/benchmark_complete/20260711_Bonzo_Supra/evidence/bonzo-panoramix-run.json)和[反汇编](../../dataset_artifacts/benchmark_complete/20260711_Bonzo_Supra/evidence/bonzo-panoramix-disassembly.asm)。所有精简版都是完整版的原文行切片并补齐理解漏洞所需的关键接口、状态、常量、入口、计算和付款/验证路径；人工语义检查见[语义审查记录](sources/20261002_semantic_review.json)，机械校验见[验证输出](sources/20261002_validation.json)。本批未本地编译、未完成攻击重放；只有 Bonzo 取得 Hedera 完整 actions，其他案例以交易、回执日志和公开跟踪分析为证据。

## 2026-10-01 读取的源表第 114–118 行

本批参数为 `X=118`、`Y=5`，按解析后的 CSV 记录逆序处理 `118、117、116、115、114`，没有因跳过或重复而补选其他行。原始 `gid=0` 导出见[只读快照](sources/20261001_sheet_gid0_raw.csv)，SHA-256 为 `b52633e537c2a66e8e90e43783686c91308184d18c43237b5a1569723ecc459f`；五行固定内容见[选行快照](sources/20261001_sheet_rows_114_118.json)，逐行处置、源码资格和证据边界见[批次结果](sources/20261001_sheet_rows_114_118_results.json)。

| 源表行 | 处置 | 事件 | 源码资格与原因 |
| --- | --- | --- | --- |
| 118 | 跳过 | Polymarket 用户钓鱼 | 钓鱼事件，不是合约代码漏洞；无攻击交易和公开原始漏洞源码。不补选。 |
| 117 | 收录（反编译） | [Edel Finance / xStock [Decompiled]](20260701_EdelFinance_decompiled.md) | 使用 Etherscan Palkeoramix/Panoramix 完整反编译价格适配器；页面输入与攻击区块 25434062 的 3,577 字节 runtime 完全一致。AaveOracle 和 wGOOGLx 使用验证源码补足上下文。明确不是已验证原始 Solidity，未编译或分叉重放。 |
| 116 | 合并重复 | Edel Finance / Backed xStocks | 与第 117 行是同一攻击交易，保留本行 30.5 万美元及包装股票口径；合并到 `20260701_EdelFinance_decompiled`，不重复建立 case。 |
| 115 | 跳过 | corezcat / GameStopfun Rugpull | 披露称为 Rugpull，未给攻击交易、确认的合约代码缺陷或公开原始漏洞源码。不补选。 |
| 114 | 跳过 | Hinkal | Hinkal、helper、in-logic 有验证 Solidity，但根因所在的攻击时 Circom / 生成 verifier 原始源码未公开匹配；后来公开的仓库已含子群检查修复，不能代替漏洞版本。转账第二页仍有下一页游标，也不能用当前归档声称完整损失总额。 |

本批结果是 1 个正式收录 case、1 个重复行合并、3 个跳过，共覆盖 5 行。Edel 是用户明确批准的单例反编译源码例外：两套 dataset 都保留 Etherscan `.pan` 全文和攻击区块 runtime 绑定证据，并用 `[Decompiled]`、`source_kind=decompiled`、`verified_original_source=false` 标出性质。公开的 204,200、305,000、403,000 美元口径没有统一，所以中英文 CSV 损失列留空。Hinkal 仍因攻击时电路/verifier 原始源码未匹配而跳过；钓鱼和 Rugpull 行也没有转成合约漏洞 case。

## 2026-09-14 读取的源表第 98–102 行

本批按[固定五行快照](sources/20260914_sheet_rows_98_102.json)整理以下五篇说明。dataset 和中英文 CSV 现保留 DLMC、Royalties、Taiko 三条；ATM 与非合约的 SecondFi 钱包事件均已移出数据集，仅保留文档及引用资料。日期和损失保留源表口径，中文金额单位为万美元，英文为千美元。

| 源表行 | Case / 数据集日期 | 详细说明 | 源码与事件证据状态 |
| --- | --- | --- | --- |
| 98 | DLMC / 2026.06.25 | [入金抬价和推荐奖励如何合在一起取走资金](20260625_DLMC.md) | 已取得并验证原始 Solidity；两套源码本地编译通过，交易回执和金额已核对，未分叉重放。 |
| 99 | Royalties / 2026.06.24 | [没有转入 NFT，却被记成拥有 100 份分红权](20260624_Royalties.md) | 两份实现共 45 个 Solidity 文件及代理源码已归档；17 份原文切片。历史代理槽及状态未独立读取。 |
| 100 | SecondFi / 2026.06.23 | [签名里的秘密变成公开值，钱包为何失守](20260623_SecondFi.md) | 非合约事件；已从两套 dataset 目录和 CSV 移除，仅保留文档与事件证据。 |
| 101 | ATM / 2026.06.22 | [先把 LP 转进池子，为何别人能取走资产](20260622_ATM.md) | 仅保留文档及引用资料，已从两套 dataset 目录和中英文 CSV 移除；说明 LP 分步操作的风险。 |
| 102 | Taiko / 2026.06.22 | [假证明如何让跨链桥释放真实资产](20260622_Taiko.md) | 实际 SGX verifier 源包与官方固定版本核对；其他组件为上游源码上下文，46 份原文切片。 |

数据集中的 `source_status` 区分已验证原始源码、SGX 源码与上游上下文。SecondFi 与 ATM 只保留文档证据，不计入数据集或中英文 CSV；Taiko 也不能仅审计付款 Vault 而忽略上游证明链。目录数量不代表已完成编译或重放的样本数量，具体限制以每篇说明和 SOURCE.md 为准。

## 2026-09-10 读取的源表第 99–103 行

源表会增删记录，行号会移动。本批使用[固定的五行快照](sources/20260910_sheet_rows_99_103.json)，没有把旧批次的行号套到当前表格。

| 源表行 | Case / 数据集日期 | 详细说明 | 源码与事件证据状态 |
| --- | --- | --- | --- |
| 99 | JaredFromSubway / 2026.06.21 | [交易赚了小钱，却留下了以后扣款的权限](20260621_JaredFromSubway.md) | 两套目录已保存受害机器人的 13,835 字节 runtime，固定攻击区块及前一区块的查询一致；原始源码和反编译未取得。 |
| 100 | BnbLabubu / 2026.06.20 | [代币转账为何会异常减少交易池储备](20260620_BnbLabubu.md) | OLPCToken 原始 Solidity 源码与链上字节码匹配；详见案例的参数和资金流核查范围。 |
| 101 | Namada / 2026.06.20 | [证明不成立，却被上层当成通过](20260620_Namada.md) | 有事发前 Rust 源码、官方修复与假证明测试；缺少历史攻击交易的逐笔对应。 |
| 102 | Axelar / Secret / 2026.06.19 | [不认消息来源，拿空头凭证换走真钱](20260619_Axelar_Secret.md) | 有官方指认版本的 Rust 源码；未重建主网 Wasm 或重放跨链攻击。 |
| 103 | mySwap CL / 2026.06.19 | [先建立头寸再初始化价格，如何领出真实资产](20260619_mySwap.md) | 已取得历史执行类的链上 Sierra 并校验类哈希；完整／精简反编译分别保留 425／276 个函数，原始跟踪核对全部 12 轮。 |

这五条保留源表的 `date` 和 `lost_u` 口径。中文 CSV 的金额单位为万美元，英文 CSV 为千美元。Namada 的原表未给攻击交易和合约地址，CSV 留空并在项目名、详情中标明证据限制。

每个新增事件目录的 `case_metadata.json` 提供 `source_status`。`missing_victim_source` 表示尚无受害源码，目录中的文件是事件证据；`runtime_bytecode_only` 表示已取得受害地址的链上机器码，原始源码和反编译未取得；`upstream_source_incident_correlation_incomplete` 表示代码缺陷有证据，但仍缺与历史交易的完整对应；`decompiled_sierra` 表示已保存链上 Sierra 及反编译结果，原始 Cairo 未恢复。目录数量不等于可直接编译或已完成重放的样本数量。评测应按所需的源码、语言和复现条件筛选。

## 2026-09-09 已整理的案例

| Case / 数据集日期 | 详细说明 | 核心问题 |
| --- | --- | --- |
| Thetanuts / 2026.06.15 | [先凭份额领走资产，再不交资产补出份额还债](20260615_ThetanutsFi_decompiled.md) | 新份额该付的底层资产被算成零，但份额仍然发了出来。 |
| DIP / 2026.06.17 | [池子只想转一笔币，程序却转了两遍](20260617_DIP.md) | 重复扣款拿走了池子原有的币，随后影响兑换价格。 |
| Aztec 旧版桥 / 2026.06.18 | [提款证明通过了，钱却付给了错误的人](20260618_aztecnetwork.md) | 据披露，证明规则没有完整限制最终资产归属；桥随后按错误结果付款。 |
| LittleBoyPlus / 2026.06.18 | [把奖励分数算大，再借交易池账户领出奖励](20260618_LittleBoyPlus.md) | 临时改变的池内余额影响记分，再通过交易池账户和推荐关系取得奖励。 |
| JB / 2026.06.19 | [每次卖币拿到 USDT 后，程序又烧掉池子里的 JB](20260619_JB_decompiled.md) | 官方交易程序在每轮卖出之后额外减少池子资产，攻击者反复利用。 |

每个 case 只有一份说明，完整版和精简版通过各自的 `SOURCE.md` 指向同一文档。上表五条来自 **2026-09-09 当时**的源表第 99–104 行；当时第 103 行的钱包钓鱼事件未纳入。这些旧行号仅对应各批快照；2026-09-10 快照中的第 103 行是 mySwap。

文中的数字例子会明确标注为示意，不会与实际交易金额混在一起。原表日期与 CSV 金额保持原来的记录方式；借款本金、最后赚到的钱和还没有卖出的资产也分别说明。

2026-09-09 这一批的资料核对使用本地源码和公开历史调用记录，取证记录固定到提交 `0dedb932869fff89899d75a3e6e2315cd87768bd`。JB、Thetanuts 使用反编译得到的近似代码；Aztec 没有收录原始 claim 电路，也就是相应证明规则的源代码。这些限制会在各篇中说明。该取证版本不代表其他批次的源码版本；各案例以自己的 `SOURCE.md` 为准。

这些文档包含漏洞解释和结论。拿数据集评测模型能否独立发现问题时，应单独设置待审计代码的输入范围。
