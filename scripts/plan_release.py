#!/usr/bin/env python3
"""Validate a release request and emit values for GitHub Actions."""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEMVER = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[.-][0-9A-Za-z.-]+)?$")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("version")
    parser.add_argument("--prerelease", choices=("true", "false"), default="false")
    args = parser.parse_args()
    version = args.version.removeprefix("v")
    if not SEMVER.fullmatch(version):
        print(f"invalid version: {args.version}", file=sys.stderr)
        return 2
    if args.prerelease == "false" and not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        print("stable releases require a plain major.minor.patch version", file=sys.stderr)
        return 2
    tag = f"v{version}"
    if subprocess.run(["git", "rev-parse", "--verify", f"refs/tags/{tag}"], cwd=ROOT, capture_output=True).returncode == 0:
        print(f"tag already exists: {tag}", file=sys.stderr)
        return 1
    if os.environ.get("GH_TOKEN") and os.environ.get("GITHUB_REPOSITORY"):
        release = subprocess.run(
            ["gh", "release", "view", tag, "--repo", os.environ["GITHUB_REPOSITORY"]],
            cwd=ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if release.returncode == 0:
            print(f"release already exists: {tag}", file=sys.stderr)
            return 1
    source = (ROOT / "Sources" / "ZhiziTime" / "Resources" / "VERSION").read_text(encoding="utf-8").strip()
    if source != version:
        print(f"source VERSION {source!r} does not match release {version!r}", file=sys.stderr)
        return 1
    source_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    print(json.dumps({"version": version, "tag": tag, "source_sha": source_sha}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
