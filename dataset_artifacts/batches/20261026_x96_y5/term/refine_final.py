from pathlib import Path
p=Path('dataset_artifacts/batches/20261026_x96_y5/term/build_case.py')
s=p.read_text('utf-8-sig').replace("'term-permissions':{'contracts/Permissions.sol':[[1,293]]}","'term-permissions':{'contracts/Permissions.sol':[[1,290]]}")
s=s.replace("GAPS=[\n", "GAPS=[\n '完整 JSON-RPC receipt 查询未得到可用结果；使用 Blockscout 原始 topics/data 日志、交易成功状态和完整 rawtrace 交叉核对，不把 null 或错误响应称为成功回执。',\n")
p.write_text(s,encoding='utf-8')
p=Path('dataset_artifacts/batches/20261026_x96_y5/term/draft.md')
s=p.read_text('utf-8-sig').replace('Modifier.sol#L79-L96','Modifier.sol#L82-L94').replace('Module.sol#L43-L76','Module.sol#L43-L77').replace('Permissions.sol#L247-L293','Permissions.sol#L247-L290')
p.write_text(s,encoding='utf-8')
