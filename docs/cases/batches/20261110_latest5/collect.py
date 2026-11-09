"""Archive public read-only HTTP/RPC responses and collection failures.

Usage: collect.py jobs.json. Each job is {id,url,path,body?}; all paths must
stay below this batch directory. No blockchain transaction is submitted.
"""
import concurrent.futures
import datetime as dt
import hashlib
import json
from pathlib import Path
import sys
import urllib.error
import urllib.request

BASE = Path(__file__).resolve().parent


def fetch(job):
    destination = (BASE / job["path"]).resolve()
    if not destination.is_relative_to(BASE):
        raise ValueError(f"Archive path escapes batch: id={job['id']}; root={BASE!s}; target={destination!s}; input={job['path']!s}")
    if not job["url"].startswith("https://"):
        raise ValueError("Only public HTTPS endpoints are allowed")
    meta_path = destination.with_name(destination.name + ".http.json")
    if destination.exists() and meta_path.exists():
        old = json.loads(meta_path.read_text("utf-8"))
        if old.get("url") == job["url"] and old.get("request_body") == job.get("body"):
            return {"id": job["id"], "status": "cached", "bytes": destination.stat().st_size}
        raise ValueError("Refusing to overwrite a different archived request")
    if meta_path.exists():
        previous = meta_path.read_bytes()
        attempt = hashlib.sha256(previous).hexdigest()[:12]
        meta_path.with_name(meta_path.name + ".attempt-" + attempt).write_bytes(previous)
    payload = json.dumps(job["body"]).encode() if "body" in job else None
    if payload:
        method = job["body"].get("method", "")
        if not (method.startswith(("eth_get", "debug_trace", "trace_", "eth_call"))):
            raise ValueError("Only historical read-only RPC methods are permitted")
    request = urllib.request.Request(job["url"], data=payload,
        headers={"User-Agent": "Mozilla/5.0 public-security-research archive",
                 "Content-Type": "application/json"} if payload else
                {"User-Agent": "Mozilla/5.0 public-security-research archive"})
    meta = {"id": job["id"], "url": job["url"], "request_body": job.get("body"),
            "retrieved_at": dt.datetime.now(dt.timezone(dt.timedelta(hours=8))).isoformat(),
            "timezone": "Asia/Shanghai"}
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(request, timeout=35) as response:
            data = response.read()
            meta.update(status=response.status, final_url=response.url,
                        content_type=response.headers.get("Content-Type"),
                        etag=response.headers.get("ETag"),
                        last_modified=response.headers.get("Last-Modified"))
        destination.write_bytes(data)
        meta.update(sha256=hashlib.sha256(data).hexdigest(), bytes=len(data))
    except Exception as exc:
        meta.update(error=str(exc), exception=type(exc).__name__)
        if isinstance(exc, urllib.error.HTTPError):
            data = exc.read()
            failure = destination.with_name(destination.name + ".error-body")
            failure.write_bytes(data)
            meta.update(status=exc.code, error_body_sha256=hashlib.sha256(data).hexdigest())
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", "utf-8")
    return {k: meta.get(k) for k in ("id", "status", "bytes", "error")}


if __name__ == "__main__":
    jobs = json.loads(Path(sys.argv[1]).read_text("utf-8-sig"))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for result in pool.map(fetch, jobs):
            print(json.dumps(result, ensure_ascii=False), flush=True)
