"""Extract archived original sources to short, ignored investigation paths."""
import json
from pathlib import Path
import tarfile

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]
OUT = ROOT / ".cache/latest5"


def write_under(root, name, content):
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


if __name__ == "__main__":
    manifest = []
    for group in (BASE / "screening").iterdir():
        if not group.is_dir():
            continue
        paths = [p for p in group.glob("*.json") if "source" in p.stem and ".http" not in p.name]
        paths += list((group / "sources").glob("0x*.json"))
        for p in paths:
            if ".http" in p.name:
                continue
            data = json.loads(p.read_text("utf-8"))
            if not data.get("sources"):
                continue
            label = data.get("compilation", {}).get("name", p.stem) + "_" + data.get("address", "unknown")[-6:]
            dest = OUT / group.name / label
            for name, item in data["sources"].items():
                write_under(dest, name, item["content"].encode("utf-8"))
            manifest.append({"response": p.relative_to(ROOT).as_posix(),
                             "root": dest.relative_to(ROOT).as_posix(), "files": len(data["sources"])})
    archive = BASE / "screening/premia/official-fe3b821.tar.gz"
    if archive.exists():
        with tarfile.open(archive, "r:gz") as tar:
            for member in tar.getmembers():
                if member.isfile():
                    name = Path(*Path(member.name).parts[1:])
                    write_under(OUT / "premia/upstream", name, tar.extractfile(member).read())
    (BASE / "extracted_sources.json").write_text(json.dumps(manifest, indent=2) + "\n", "utf-8")
    print(json.dumps(manifest, indent=2))
