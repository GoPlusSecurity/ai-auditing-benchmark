from pathlib import Path
import csv,json
b=Path('dataset_artifacts/batches/20261026_x96_y5')
r=list(csv.reader((b/'sheet_gid0_raw.csv').open(encoding='utf-8-sig',newline='')))
x={'physical_csv_reader_row':91,'header_row':2,'headers':r[1],'values':r[90],'fields':dict(zip(r[1],r[90]))}
(b/'term'/'sheet-row.json').write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(x,ensure_ascii=False,indent=2))
p=b/'term'/'extracted'/'voting'/'src/plugins/governance/majority-voting/MajorityVotingBase.sol'
for n,l in enumerate(p.read_text().splitlines(),1):
 if 456<=n<=509: print(f'{n}: {l}')
