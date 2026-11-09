# 最终只读复核范围

路径说明：此复核之后，用户更正为源码直接放在dataset一级；下列源码路径已同步为当前位置，源码内容通过迁移前后哈希核对。

目标是执行同目录 plan.txt，固定最新快照，取得 5 个新的、源码合格的合约漏洞事件，完整归档及解释因果链，追加中英文七列 CSV。

基线与当前 HEAD 均为 tz 的 d7f203a614359d5a7908ade9c35e69f734be638f；所有本批修改尚未提交。必须同时检查 git diff 与未跟踪的新文件，不能只检查 HEAD diff。

入口：

- plan.txt：原始任务全文。
- progress.md：已采取的工作区、路径和证据解释决定，特别是 Ruling 行。
- snapshot.json、sheet_gid0_raw.csv、existing_events.json、results.json：完整行字段、排序、去重和裁决。
- cases.json：本批五例、来源包、金额及中英文 CSV 文本。
- README.md：逐行结果与证据范围。
- validation.json、pre-append-validation.json、test-results.txt：已运行的验收和 14 项回归测试。
- batch.py、build.py、validate.py、analyze.py：筛选、写入和离线解码逻辑。
- docs/cases/<case_id>.md、dataset/<case_id>/、dataset_artifacts/<case_id>/：五例正式文档、完整源码与来源证据。

本批名单：20261104_CoreVault_InsurancePool、20261101_PremiaV3、20261024_X100、20261022_NEM、20261019_AlpsCon。

追加约束：用户只允许区块浏览器或厂商官方线上反编译，拒绝本地反编译；Dedaub 登录受限时选择继续跳过。本批没有反编译输出。缺失关键漏洞/权限/付款代码的候选均跳过；未取得原码的纯编排和收款地址没有作为代码证据，步骤只能依照直接事件/跟踪或标明推断。请特别评估此来源边界是否符合 plan.txt。

重点人工判断：

1. 按 date 降序、同日原始记录号升序裁决直到第五例，是否遗漏更早在顺序中的合格记录；去重清单是否覆盖旧批次，日期差异是否明示。
2. 五例各自是否具有公开漏洞原始源码及完整必要的权限、检查、状态、计算、付款代码，当前代理/来源验证是否被错误当成历史部署证据。
3. CoreVault 三采样窗口/逆价格；Premia 拆分 counter 到边界重建再到 ClaimFees 的机制；X100 即时治理与一年锁仓；NEM 未成交累计与 skim/flush；AlpsCon 跨版本奖励起点与付款，是否被原码及事件支持。
4. 金额是否区分周转资金、总付款、受害净流出、收益和美元报道；中英文表达与单位、地址角色是否一致。
5. 源码位置与公式、文档的普通语言、Mermaid、本地链接、CSV 幂等/旧字节保留、改动范围与未知事项是否明确。

复核只读，不编辑文件、Git 状态、索引或分支，不发送链上交易，不运行上游代码/PoC，不使用本地反编译，不分派其他代理。可以用 Python stdlib 或现有工具独立检查数据；避免输出整个大响应。

请给出 Strengths、Critical/Important/Minor（每项须有文件行号、问题和影响、具体修正）、Declined to judge（逐条说明设为范围外的行为与理由）、明确 verdict。仅报告实际阅读和核对过的问题，并说明核对范围。没有提交或合并请求，本次 verdict 针对工作区交付。
