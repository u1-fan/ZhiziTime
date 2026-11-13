#!/usr/bin/env python3
"""Prepare the next ZhiziTime version without rewriting release history."""

import argparse
import datetime as dt
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION_FILE = ROOT / "Sources" / "ZhiziTime" / "Resources" / "VERSION"
README_FILE = ROOT / "README.md"
CHANGELOG_FILE = ROOT / "CHANGELOG.md"
SEMVER = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[.-][0-9A-Za-z.-]+)?$")


def command(*args: str) -> str:
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else ""


def latest_tag() -> str:
    return command("git", "describe", "--tags", "--abbrev=0") or f"v{VERSION_FILE.read_text().strip()}"


def commits_since(tag: str) -> list[str]:
    output = command("git", "log", f"{tag}..HEAD", "--pretty=format:%s")
    return [line for line in output.splitlines() if line and not line.startswith("chore: prepare v")]


def suggested_version(current: str, commits: list[str]) -> str:
    major, minor, patch = (int(part) for part in current.split(".")[:3])
    if any(re.match(r"^feat(?:\([^)]*\))?:", item, re.I) for item in commits):
        return f"{major}.{minor + 1}.0"
    return f"{major}.{minor}.{patch + 1}"


def write(path: Path, old: str, new: str, dry_run: bool) -> None:
    if old == new:
        return
    print(f"  -> {path.relative_to(ROOT)}")
    if not dry_run:
        path.write_text(new, encoding="utf-8")


def update_readme(content: str, version: str) -> str:
    content = re.sub(r"ZhiziTime-v[0-9A-Za-z.-]+-macOS-", f"ZhiziTime-v{version}-macOS-", content)
    content = re.sub(r"ZhiziTime-v[0-9A-Za-z.-]+-macos-", f"ZhiziTime-v{version}-macOS-", content)
    content = re.sub(r"releases/download/v[0-9A-Za-z.-]+/", f"releases/download/v{version}/", content)
    return content


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", nargs="?", help="target version, for example 1.1.0")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    current = VERSION_FILE.read_text(encoding="utf-8").strip()
    previous_tag = latest_tag()
    target = (args.version or suggested_version(current, commits_since(previous_tag))).lstrip("v")
    if not SEMVER.fullmatch(target):
        print(f"invalid version: {target}", file=sys.stderr)
        return 2

    print(f"==> ZhiziTime release v{target} (previous {previous_tag})")
    write(VERSION_FILE, VERSION_FILE.read_text(encoding="utf-8"), f"{target}\n", args.dry_run)

    if README_FILE.is_file():
        old = README_FILE.read_text(encoding="utf-8")
        write(README_FILE, old, update_readme(old, target), args.dry_run)

    old_changelog = CHANGELOG_FILE.read_text(encoding="utf-8") if CHANGELOG_FILE.exists() else "# Changelog\n\n"
    if f"## [{target}]" not in old_changelog:
        subjects = commits_since(previous_tag)
        body = "\n".join(f"- {subject}" for subject in subjects) or "- 日常维护与性能改进。"
        entry = f"## [{target}] - {dt.date.today().isoformat()}\n\n{body}\n\n"
        write(CHANGELOG_FILE, old_changelog, old_changelog.replace("# Changelog\n\n", "# Changelog\n\n" + entry, 1), args.dry_run)

    print("下一步：审查 diff，运行 task macos:test && task release-check，提交后触发 release-dmg.yml。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
