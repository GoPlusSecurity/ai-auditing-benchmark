"""Extract downloaded Sourcify text for static reading only; never runs Solidity."""
import hashlib
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent
out = []
for path in sorted((BASE / 'sources').glob('*.json')):
    response = json.loads(path.read_text('utf-8-sig'))
    if not isinstance(response.get('sources'), dict):
        out.append({'response':path.name,'error_or_other_response':response})
        continue
    bundle = path.stem.removesuffix('-source')
    root = BASE / 'extracted' / bundle
    files = []
    for name, item in response['sources'].items():
        dest = root / name.replace('\\', '/')
        if not dest.resolve().is_relative_to(root.resolve()):
            raise ValueError(f'unsafe source path: {name}')
        raw = item['content'].encode('utf-8')
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(raw)
        files.append({'path':name,'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'lines':len(raw.splitlines())})
    out.append({'bundle':bundle,'response':str(path.relative_to(BASE)),'response_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'address':response.get('address'),'verified_at':response.get('verifiedAt'),'runtime_match':response.get('runtimeMatch'),'creation_match':response.get('creationMatch'),'compilation':response.get('compilation'),'deployment':response.get('deployment'),'proxyResolution':response.get('proxyResolution'),'files':files})
(BASE / 'source_inventory.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for item in out:
    print(json.dumps({k:v for k,v in item.items() if k not in ['files','compilation']},ensure_ascii=False))
    if 'files' in item:
        print('contract',item['compilation'].get('fullyQualifiedName'),'sources',len(item['files']))
