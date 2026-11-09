# 必要代码的来源覆盖

用户在最终复核后确认：“**只要求漏洞、权限和付款因果链的必要代码完整**”。[范围记录](scope-confirmation.json)保留原话及适用边界。本页区分必要的代码、纯编排/收款地址和历史绑定缺口，不把最后两类写成已取得原码。

每个包的完整文件、原始下载地址、取得时间、提供方匹配、编译输入和逐文件 SHA-256 均保存在对应 `provenance.json`、`source-files.json` 和 `source-bundles/`。表中地址是来源包所对应的实例，不自动表示已经完成攻击区块绑定。

## CoreVault / InsurancePool（100 文件）

| 来源包与实例 | 必要作用及覆盖 |
| --- | --- |
| corevault — `0x302f5084ba0e4a2d4de5e6bc5dd5247028f5d674` | 原始 CoreVaultFarming、OracleLib、YieldMath、存储和接口；保留首单/锁定期/收益上限、现货采样、均价、美元权益与 BNB 计算 |
| treasury — `0xfc1b8abb7414b68daf2b64604f0ac3b8ef159ef5` | `onlyFarmVault`、余额与保险池补款、最终原生 BNB 转账 |
| insurance — `0xf40e0d525003fb6c6a9a7d79734a87a465053df1` | 储备与授权提款代码，调用者检查和实际付款实现 |
| bnix — `0x81215684ef11f6e8050bc6b34448e71de264dc74` | 订单收益路径涉及的协议代币及相关依赖，防止只保留本金片段 |
| fist — `0xc9882def23bc42d53895b8361d0b1edc7570bc6a` | 相关代币完整原始文件 |
| pancake-pair — `0x16b9a82891338f9ba80e2d6970fdda79d1eb0dae` | 储备读取、兑换、更新和普通池权限/余额检查 |

直接入口：[原始包与逐文件清单](../../../../dataset_artifacts/20261104_CoreVault_InsurancePool/provenance.json)、[检查至付款的源码说明](../../20261104_CoreVault_InsurancePool.md)。

未补原码的 `0xd9c2e4f19746b4617ad658152adaa306c47ef86b` 是旧订单用户及付款收款地址；其控制过程与内部转款不用于证明赎回公式。借款、攻击编排及还款只按回执观察表述。关键代码没有独立攻击区块运行码绑定；样本窗口、人工覆盖和旧订单历史槽仍未核实。

## Premia V3（426 文件）

| 来源包与实例 | 必要作用及覆盖 |
| --- | --- |
| vault-proxy — `0x45df5ea836a15b561937ae8373ab9ee984aea531` | 金库代理、实现选择与依赖；当前解析与历史解析分开 |
| vault-impl — `0xb539ff8563974d407fd6d717ff2f930e99093d21` | 金库交易、权利金、抵押品写入和角色检查 |
| pool-proxy — `0x1b25f69cfc2b3a9fcc0a7c0944a81723d5dcd77d` | 池代理及路由接口 |
| pool-deposit — `0x386dd942d3b058543f0dfa19034a0284a49ba5fd` | 存取、延迟检查、头寸状态、tick 计数增减、删除和重建、数学与费用归属 |
| pool-core — `0xa1a1ea8b5a6045b6bfa51afb9b1c8c44f3f296bc` | 头寸转移/拆分、买卖、费用计算和 `_claim` 最终实际资产付款；完整公共基类和依赖 |

直接入口：[原始包与逐文件清单](../../../../dataset_artifacts/20261101_PremiaV3/provenance.json)、[计数错误至付款的源码说明](../../20261101_PremiaV3.md)。

未取得攻击主编排合约 `0x577168c8c6fa937495c3d6961f1d7d734b2d785f` 及辅助持有人的内部源码；头寸拆分、退出、tick 更新及付款只按池子自身的事件和已取得原始实现解释。当前路由不能证明历史路由，历史读取失败已归档；全案所有池的历史状态没有完整重建。

## X100 Senate（56 文件）

| 来源包与实例 | 必要作用及覆盖 |
| --- | --- |
| freezer — `0x79f35a33fe2813414851c4ae8daeacd14d822a46` | Freezer、Senate、DexTreasury、DexBase、权限和存储；冻结/实时排名、提案/投票、合法自调用、执行后余额保护和兑换入口 |
| dex-module — `0xcd5762ac6013fa762782ac1797ab09152c1028e8` | 固定委托模块、池/路由选择、参数和最低输出检查以及资产支付 |
| x-token — `0x100a2c7f45fd48e217fdce72e658dc78fd43a100` | X 代币、冻结凭证与转账等依赖 |

直接入口：[原始包与逐文件清单](../../../../dataset_artifacts/20261024_X100/provenance.json)、[治理至付款的源码说明](../../20261024_X100.md)。

三份核心包已做攻击区块运行码与提供方归档运行码比对，全部一致；这不是本地重编译。主编排合约 `0x37541fc4a6f1ec86889ba506f51dc39f2bedd10a` 与两个协同地址仅按三份完整调用树和回执描述，不把跟踪转写成其内部源码。正常池/路由处理收到的参数，不作为额外漏洞归属。未重放、未穷尽攻击前所有排名与最终残余 X 处置。

## NEM / NemTokenV2（2 文件）

| 来源包与实例 | 必要作用及覆盖 |
| --- | --- |
| token — `0x9cf0e3ad4efa7ab602d7b5a38c55795cfa777777` | 完整代币原码：权限、开关、税费、方向判断、pending 累计、公开 flush、上限、从池扣币与 sync |
| pancake-pair — 来源实例 `0x16b9a82891338f9ba80e2d6970fdda79d1eb0dae` | 完整普通 PancakePair 原码，含 skim、sync 和 swap；受影响实例 `0x840e19dcca541ee0b55a3c67e900a39d523b12b8` 的当前运行码与来源运行码逐字节相同 |

直接入口：[原始包与逐文件清单](../../../../dataset_artifacts/20261022_NEM/provenance.json)、[pending 至烧池和兑换的源码说明](../../20261022_NEM.md)。

池子源码采用同运行码的已验证普通实例作参考，当前绑定范围明确，不能改写成历史绑定。攻击编排合约 `0x5e6d1f40be466dd2facc94a26818948ecd3b1ca2` 的内部程序未取得；42 次销毁与 flush 是事件直接证据，skim 的具体内部调用属于原码及转账模式支持的解释。历史权限和初始状态没有全部读取。

## AlpsCon（91 文件）

| 来源包与实例 | 必要作用及覆盖 |
| --- | --- |
| v6 — `0x74f091a719fdd47a95f378c7fb5c3d18a4582405` | 旧版本购买、锁仓、迁移、退出、费用与 onlyVerified 权限入口 |
| v7 — `0x047284b1e752e39ae7a721d361ec0b0a554ef014` | 旧版本余额和收益读取、独立付款及其检查 |
| v8 — `0xa58fbe390210460b7b07e52a29d4eb84308472e1` | 新旧余额衔接、锁仓与付款 |
| v9 — `0x9b210da482217afc24074e57f6f8337fe07f0124` | 继承基类、onlyVerified、旧余额读取、奖励起点、分别取整的 gross/claimed、记账更新和 `_claimServiceResults` |
| vault — `0x7e84f721d8082639d8dba7ed357b34523ffffa0b` | 资产保管、模块角色、付款限制、实际转账和多签/时间锁依赖 |
| swap — `0x7227d229be754fa49f416d48e8eaa121184b1721` | 白名单读取/维护、owner 权限、代币兑换与依赖；Hub 的 `_isVerified` 查询 Swap 的 `isInWhiteList` |
| token — `0x5870357dfa6a11d3fe45d775c21ed9ae60ac4bef` | 业务代币原始转账与权限代码 |

直接入口：[原始包与逐文件清单](../../../../dataset_artifacts/20261019_AlpsCon/provenance.json)、[跨版本公式至付款的源码说明](../../20261019_AlpsCon.md)。

默认测试账户 `0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266` 的委托执行代码未取得，不用于证明上述 Hub/Swap/Vault 的计算和付款实现；EIP-7702 授权列表及成功行为有归档，签名未独立恢复。历史白名单归属由原始研究及成功行为支持，未独立读取历史配置、指数槽或各版历史运行码；V7/V8 的独立付款不被擅自改写成 V9 的内部子调用。

## 资格与验证的分别结论

按用户确认后的范围，五例必要代码均有公开原始源码，没有靠反编译、运行码或报道替代整例原码。必要逻辑缺失的 TENDRIL、b14g、TranchePool、Slice 以及未取得漏洞原码的 WAX 仍保持跳过。来源取得不等于所有历史绑定已核实，上述缺口在各例元数据和正文中保留。
