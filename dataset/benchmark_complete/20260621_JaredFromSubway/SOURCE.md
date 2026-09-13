# JaredFromSubway — 链上运行时字节码 / On-chain runtime bytecode

**代码状态：`runtime_bytecode_only`。已保存受害机器人在攻击区块及前一区块的完整运行时字节码；原始 Solidity 与反编译代码尚未取得。**

2026-09-14 通过 Ethereum 主网 RPC 取得受害机器人 `0x1f2f10d1c40777ae1da742455c65828ff36df387` 的运行时字节码，共 **13,835 字节**。保存为 [十六进制文本](onchain/JaredFromSubway.runtime.hex) 和 [原始二进制](onchain/JaredFromSubway.runtime.bin)。这是受害地址已部署的 EVM 代码，不是创建交易的初始化代码，也不是攻击者的 wrapper。

当前视图是 `complete`。完整版保留字节码、原始 RPC 响应、角色和报告事实；精简版保留同一完整字节码及最小攻击路径。直接删除字节码指令会改变跳转目标和语义，因此两份 runtime 逐字节相同，不进行猜测性裁剪。

## 字节码取证与校验

| 项目 | 结果 |
| --- | --- |
| 网络 | Ethereum Mainnet，`eth_chainId = 0x1` |
| 攻击区块 | `25360696`，哈希 `0x01518baaea1ec7aafe01e63b6c7e5b3bb198cca03cd6ff1d0f6843415a153f8c` |
| 前一区块 | `25360695`，哈希 `0xf7ab6aebce06dc50692139c9dc7e4add9d3ba154fb7abf39fb51d00405e84392` |
| 读取方式 | `eth_getCode(address, {blockHash, requireCanonical: true})`，另用明确区块号交叉核对 |
| 历史节点 | `https://eth.drpc.org` |
| 独立交叉读取 | PublicNode 的 `latest` runtime 与历史结果相同；历史版本以固定区块哈希请求为准 |
| 长度 | `13,835` 字节 |
| Runtime SHA-256 | `204a4fde84952e40b97a2841629b35e0abf6d7a3070a6fa7b87d4df6ae044708` |
| Runtime Keccak-256 | `0x14a86b6d239e89ae47d307fa4a7fb6843e4356f5d13ac751a053711a88b36658` |

上面的两个哈希针对解码后的原始字节。`.hex` 文件是小写、带 `0x` 前缀并以 LF 结尾的一行文本，文件本身的 SHA-256 会不同；[bytecode.json](bytecode.json) 分别记录字节哈希和文件哈希。

固定区块哈希和区块号的四次历史查询均返回相同代码。区块查询得到的代码代表该区块结束时的状态；这里没有把它说成逐交易执行 trace。攻击交易的原始 receipt 也已取得：交易成功，区块号、区块哈希和区块时间一致，其中有 50 条真实代币 Transfer 事件的转出地址是本条受害机器人。这项核对用于确认地址和事件关联，未据此重算 423 次授权、66 个诱饵调用或完整事件损失。

原始取证文件：[固定区块请求](evidence/rpc/hash-pinned-request.json)、[固定区块响应](evidence/rpc/hash-pinned-response-drpc.json)、[区块号请求](evidence/rpc/archive-code-request.json)、[区块号响应](evidence/rpc/archive-code-response-drpc.json)、[攻击交易 receipt](evidence/rpc/receipt-response-drpc.json)、[独立 latest 读取](evidence/rpc/latest-response-publicnode.json)。所有文件由只读 RPC 请求取得。

## 事件、角色和金额

- [源表当前第 99 行](https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0#range=A99:N99)：日期 `2026.06.21`，`lost_u = 7,500,000`。表格会更新，行号仅对应本次抓取。
- Ethereum 受害机器人：[MEV bot](https://etherscan.io/address/0x1f2f10d1c40777ae1da742455c65828ff36df387)。它是本条“漏洞合约地址”所指对象，地址归属由 BlockSec 与 CertiK 报告支持。
- 源表中的 `0x4ee0b6e9f9c4886beeef2ebd7fc27223169531ce` 是恶意 wrapper / 获授权 spender，`0x3e37f4a10d771ba9de44b6d301410b1bedea65d0` 是攻击者地址；这两个地址不填入受害合约字段。详见[角色表](evidence/address_roles.json)。
- [代表性扣款交易](https://etherscan.io/tx/0x2be8704f5a59b69e0b71f64aefdb99eb0e8ae9fb3926147c581910d71bcf3e65)。Blockaid 报告的时间是 `2026-06-20 18:49:11 UTC`，对应北京时间 `2026-06-21 02:49:11`，目录沿用源表日期。
- 本条金额是源表及 Blockaid 的约 USD 7.5M。BlockSec 的约 USD 15M 是另一个未逐笔对齐的报道口径，不相加、不替换本条数字。

## 证据能说明什么

BlockSec 与 CertiK 的分析支持：受害 bot 向不可信 wrapper 授权真实代币，wrapper 在部分操作中不消耗授权，操作结束后授权也未撤销，攻击者随后借助 `transferFrom` 转走资产。这个结论在本目录属于**报告支持的根因**，没有本地受害源码行号证明。

入口：[报告事实索引](evidence/claims.json)；[检索过程及尚缺材料](evidence/source_search.json)；[机器可读来源](SOURCE.json)；[详细中文说明](../../../docs/cases/20260621_JaredFromSubway.md)。

## 来源与验证边界

主要报告：[Blockaid](https://blockaid.io/blog/the-predator-becomes-the-prey-how-a-counter-mev-honeypot-drained-75m-from-jaredfromsubway)、[BlockSec](https://blocksec.com/blog/web3-security-jaredfromsubway-aztec-more)、[CertiK](https://www.certik.com/blog/jaredfromsubway-mev-bot-incident-analysis)。接口语义参考 [ERC-20](https://eips.ethereum.org/EIPS/eip-20)。

本次读取公开 GitHub 仓库版本元数据的网络请求未获授权，已停止该下载。随后只检索了本地已有的 DarkNavy 仓库目录索引（固定版本 `0dedb932869fff89899d75a3e6e2315cd87768bd`），未找到本事件匹配路径。该版本只是**已查阅的本地索引版本**，不是本事件源码版本。受害源码的 upstream commit 和 SHA-256 因而为 `null`。

`SOURCE.json` 与 `SHA256SUMS` 固定本地字节码、取证材料和说明文件。已验证链上 runtime 的历史一致性，但尚未验证任何 Solidity／反编译实现与它等价。本次没有编译或重放攻击，前序授权交易的完整调用轨迹、源码函数位置和不同损失报道的逐笔核对仍未完成。
