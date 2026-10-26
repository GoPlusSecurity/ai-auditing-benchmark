"""Read escaped standard-JSON input in saved Etherscan pages without executing JS."""
import re,json,hashlib
from pathlib import Path
BASE=Path(__file__).resolve().parent
for kind in ['vault','delay']:
    path=BASE/f'{kind}-code-page.html'
    html=path.read_text('utf-8')
    token=re.search(r"var editor_contractJsonData = '((?:\\.|[^'\\])*)'",html).group(1)
    js_string=json.loads('"'+token.replace("\\'", "'").replace('\\`','`')+'"')
    data=json.loads(js_string)
    dest=BASE/'extracted'/kind
    for name,source in data['sources'].items():
        target=dest/name
        if not target.resolve().is_relative_to(dest.resolve()):raise ValueError(name)
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(source['content'].encode())
    (BASE/f'{kind}-etherscan-input.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(kind, list(data),list(data['sources']))

