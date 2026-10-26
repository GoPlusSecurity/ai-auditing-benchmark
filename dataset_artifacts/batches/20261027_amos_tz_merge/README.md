# amos 合并到 tz：2026-10-27

本次以 `14920dcd252a0f9dee40453f4b6e885708979f78` 为旧内容基线；先将本地四例和 Allbridge 更新提交为 `abee605182854ba42b846f5674903f89a386d8f1`，再执行正式合并。只创建本地提交，不推送。

当前目录是 `dataset/<case_id>/` 和 `dataset_artifacts/<case_id>/`，批次材料仍在 `dataset_artifacts/batches/`。目标为 65 个源码案例、58 个资料案例、中英文 CSV 各 66 条事件。九例 776 个源码文件按字节迁移（含标明性质的在线反编译输出与 Term Labs 的 Vyper 源码）；源码取得、历史绑定和实际损益的证据边界沿用原记录。

- [合并前完整字节备份](premerge-backup.zip)：含两批全部资料、九例完整与历史精简版本、当前改动、文档和索引；ZIP 成员路径是迁移前的历史路径。
- [原文件哈希清单](premerge-inventory.json)及[分支和改动状态](premerge-state.json)。
- [合并前暂存区逐字节核对](checkpoint-index-verification-fast.json)。
- [远端引用核对](post-fetch-refs.json)：使用系统 OpenSSH fetch，amos 与指定提交一致。
- [迁移验收测试](test_migration.py)：核对 amos 原案例、776 个新增源码字节、目录数量、CSV 原始前缀和单版本元数据。
- [执行记录](progress.md)。

原始导出、快照、抓取响应、ABI、失败记录、当时的验证报告和 Allbridge 补充记录保持原字节。两批历史记录中的旧路径、旧数量、旧验证结果只描述当时状态。当前案例文档、来源清单、元数据、README 和维护工具使用平铺路径；旧精简文件仅留在历史备份及父提交中。

本次只运行维护者编写的离线数据核对工具。不重新抓取，不执行上游脚本或 PoC，不编译合约，不部署、发送交易或重放。

## 本次核对结果

- [迁移清单](migration-manifest.json)：逐文件列出旧路径、新路径、前后 SHA-256 和处置方式；2,715 个原文件全部有去向。
- [原貌保留核对](preservation-verification.json)：旧 56 个源码案例及 49 个资料案例共 2,572 个文件等于 amos；新增 776 个源码文件与备份相同。移除的九例精简文件共 252 个（源码 216、资料 36），仍可从备份或合并父提交恢复。
- [旧案例 Git 对象清单](old-amos-cases.json)与[CSV 拼接清单](csv-merge-manifest.json)：amos 的 57 条记录原字节保留，新增 9 条，各 66 条。
- [第一批当前核对](batch21-current.json)、[第二批当前核对](batch26-current.json)：原响应、源码、来源路径、文档链接和行号。
- [39 项离线测试输出](offline-suite.txt)、[重建工具回归测试](flat-tools-test.txt)、[独立复核及修正](review.md)。
- [Git 字节和父提交验证工具](verify_git_tree.py)：提交前用 `--ref INDEX`，提交后用 `--ref HEAD`。直接核对 blob 内容，排除换行转换与忽略规则遗漏。

离线验证检查保存的材料与目录结构，不扩大原案例对历史状态、部署绑定和最终损益的结论。

[全目录校验](final-layout.json)检查 839 个本地 Markdown 链接、2,023 个 JSON 文件引用，且没有历史源码哈希差异。[首次暂存区字节核对](index-verification.json)检查 5,225 个 Git blob，与工作区一致，未发现冲突或未跟踪任务文件。此报告记录写入审计记录前的暂存快照；审计记录加入后、正式提交前及提交后再次直接核对实际 Git 树。
