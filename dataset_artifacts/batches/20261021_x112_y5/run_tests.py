"""Run offline curation regressions and save the actual unittest result."""
import datetime as dt
import io
import json
from pathlib import Path
import sys
import time
import unittest

BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
sys.path.insert(0,str(ROOT/'docs/cases/sources'))
names=['test_20261002_batch.SelectionRuleTests','test_20261021_batch']
suite=unittest.defaultTestLoader.loadTestsFromNames(names)
stream=io.StringIO()
started=time.monotonic()
result=unittest.TextTestRunner(stream=stream,verbosity=2).run(suite)
elapsed=time.monotonic()-started
report={'status':'passed' if result.wasSuccessful() else 'failed','run_at':dt.datetime.now(dt.timezone(dt.timedelta(hours=8))).isoformat(),'command':'python -X utf8 -B dataset_artifacts/batches/20261021_x112_y5/run_tests.py','test_modules':names,'tests_run':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'seconds':elapsed,'contract_execution':'not_run','local_decompilation':'prohibited_not_run'}
(BASE/'test_results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(BASE/'unittest_output.txt').write_text(stream.getvalue(),encoding='utf-8')
print(stream.getvalue(),end='')
print(json.dumps(report,ensure_ascii=False))
raise SystemExit(0 if result.wasSuccessful() else 1)
