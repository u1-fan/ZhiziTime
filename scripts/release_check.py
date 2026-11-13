#!/usr/bin/env python3
"""Validate version, Sparkle configuration, and release naming invariants."""

import argparse
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION_FILE = ROOT / "Sources" / "ZhiziTime" / "Resources" / "VERSION"
SEMVER = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[.-][0-9A-Za-z.-]+)?$")


def validate(tag: str | None) -> list[str]:
    errors: list[str] = []
    version = VERSION_FILE.read_text(encoding="utf-8").strip()
    if not SEMVER.fullmatch(version):
        errors.append(f"source version is not semantic: {version!r}")
    if tag and tag != f"v{version}":
        errors.append(f"tag {tag!r} does not match source version {version!r}")

    with (ROOT / "Resources" / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    if info.get("CFBundleIdentifier") != "com.brian.zhizitime":
        errors.append("Info.plist Bundle ID changed unexpectedly")
    if not info.get("SUFeedURL", "").startswith("https://"):
        errors.append("Info.plist must contain an HTTPS SUFeedURL")

    package = (ROOT / "Package.swift").read_text(encoding="utf-8")
    for required in ("sparkle-project/Sparkle", "product(name: \"Sparkle\"", "ZHIZI_ENABLE_SPARKLE"):
        if required not in package:
            errors.append(f"Package.swift is missing {required}")

    workflow = ROOT / ".github" / "workflows" / "release-dmg.yml"
    if not workflow.is_file():
        errors.append("Release workflow is missing")
    else:
        workflow_text = workflow.read_text(encoding="utf-8")
        for required in ("notarytool submit", "generate_appcast", "SPARKLE_EDDSA_PRIVATE_KEY", "hdiutil verify", "verify_published_appcast.py"):
            if required not in workflow_text:
                errors.append(f"release workflow is missing {required}")

    ci = ROOT / ".github" / "workflows" / "ci.yml"
    if not ci.is_file():
        errors.append("CI workflow is missing")
    else:
        ci_text = ci.read_text(encoding="utf-8")
        for required in ("actionlint", "py_compile", "shellcheck"):
            if required not in ci_text:
                errors.append(f"CI workflow is missing {required}")

    for relative_path in ("scripts/configure_sparkle_keys.sh", "scripts/verify_published_appcast.py"):
        if not (ROOT / relative_path).is_file():
            errors.append(f"required release helper is missing: {relative_path}")

    public_key = ROOT / "config" / "sparkle-public-key.txt"
    if not public_key.is_file() or not public_key.read_text(encoding="utf-8").strip():
        errors.append("config/sparkle-public-key.txt is missing or empty")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag", nargs="?")
    args = parser.parse_args()
    errors = validate(args.tag)
    if errors:
        for error in errors:
            print(f"release-check: {error}", file=sys.stderr)
        return 1
    print("release-check: metadata is consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
