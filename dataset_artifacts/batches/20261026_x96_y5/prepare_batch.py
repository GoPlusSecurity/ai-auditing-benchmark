"""Capture the fixed input and baseline without touching formal dataset files."""
import csv
import datetime as dt
import hashlib
import json
import subprocess
from pathlib import Path

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p, value): p.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
raw = BASE/'sheet_gid0_raw.csv'
with raw.open(encoding='utf-8-sig', newline='') as f: records = list(csv.reader(f))
assert len(records[0]) == 14 and all(not x for x in records[0][1:])
assert records[1] == ['timestamp','target (社媒 or Addr)','description','data_source','original_link','date','lost','lost_u','malicious_tx','malicious_address','malicious_url','malicious_social_account','attack_category','attack_analysis']
assert 3 <= 96 <= len(records) and 1 <= 5 <= 94
snapshot = {'parameters':{'x':96,'y':5},'source_url':'https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/edit?gid=0#gid=0','export_url':'https://docs.google.com/spreadsheets/d/1ENyVv94OaHW2BesbrSaiIluwjHMjuYrSR1aFk_LxS3Y/export?format=csv&gid=0','retrieved_at':dt.datetime.fromtimestamp(raw.stat().st_mtime,dt.timezone(dt.timedelta(hours=8))).isoformat(),'timezone':'Asia/Shanghai','raw_export_sha256':sha(raw),'parsed_record_count':len(records),'header':records[1],'structure':{'row_1':'explanation','row_2':'header','first_event_row':3},'candidate_rows':[{'row':i,'cells':records[i-1],'fields':dict(zip(records[1],records[i-1]))} for i in range(96,2,-1)]}
if not (BASE/'input_snapshot.json').exists(): dump(BASE/'input_snapshot.json',snapshot)
if not (BASE/'baseline.json').exists():
    tracked=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0')
    files={name:sha(ROOT/name) for name in tracked if name and (ROOT/name).is_file()}
    dump(BASE/'baseline.json',{'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'branch':'tz','initial_status':'clean (recorded before batch download)','files':files})
print(json.dumps({'records':len(records),'sha256':sha(raw),'baseline_files':len(json.loads((BASE/'baseline.json').read_text('utf-8'))['files'])}))
