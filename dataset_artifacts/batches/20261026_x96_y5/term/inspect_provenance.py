from pathlib import Path
import json
b=Path('dataset_artifacts/batches/20261026_x96_y5/term')
for stem in ['delay-implementation','delay-owner','vault-implementation']:
 d=json.loads((b/'sources'/f'{stem}-source.json').read_text())
 print(stem,type(d.get('signatures')).__name__)
 s=d.get('signatures'); print(str(s)[:1200])
recorded={r['path'].removeprefix('term/')for r in json.loads((b/'retrievals.json').read_text())if r.get('file_present')}
raw=[p.relative_to(b).as_posix()for p in b.glob('*.json')if p.name.startswith(('blockscout','execution','proposal','tx-','receipt-'))]
print('raw data without retrieval record',set(raw)-recorded)
