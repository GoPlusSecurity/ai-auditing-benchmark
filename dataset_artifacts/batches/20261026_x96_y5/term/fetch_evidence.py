"""Read public research evidence; never submits or signs transactions."""
import concurrent.futures
import datetime as dt
import hashlib
import json
from pathlib import Path
import sys
import urllib.request

BASE = Path(__file__).resolve().parent

def fetch(item):
    target = (BASE / item['path']).resolve()
    if not target.is_relative_to(BASE):
        raise ValueError('destination outside batch')
    payload = json.dumps(item['payload']).encode() if 'payload' in item else None
    req = urllib.request.Request(item['url'], data=payload, headers={
        'User-Agent': 'PublicIncidentResearch/1.0',
        **({'Content-Type': 'application/json'} if payload else {})})
    try:
        with urllib.request.urlopen(req, timeout=35) as response:
            raw = response.read()
            status = response.status
            content_type = response.headers.get('content-type')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
        result = {**item, 'http_status': status, 'bytes': len(raw),
                  'sha256': hashlib.sha256(raw).hexdigest(), 'content_type': content_type}
    except Exception as error:
        result = {**item, 'error': str(error)}
    result['retrieved_at'] = dt.datetime.now(dt.timezone(dt.timedelta(hours=8))).isoformat()
    return result

if __name__ == '__main__':
    job_path = BASE / sys.argv[1]
    jobs = json.loads(job_path.read_text('utf-8'))
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(fetch, jobs))
    (BASE / (job_path.stem + '-fetch-results.json')).write_text(
        json.dumps(results, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for result in results:
        print(json.dumps({k: v for k, v in result.items() if k != 'payload'}, ensure_ascii=False))
