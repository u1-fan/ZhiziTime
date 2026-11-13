#!/usr/bin/env python3
"""Poll a published Sparkle appcast until the current release is visible."""

import argparse
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from verify_appcast import verify_document  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url")
    parser.add_argument("version")
    parser.add_argument("artifact")
    parser.add_argument("--attempts", type=int, default=12)
    parser.add_argument("--delay", type=int, default=10)
    args = parser.parse_args()
    if args.attempts < 1 or args.delay < 0:
        parser.error("--attempts must be positive and --delay cannot be negative")

    for attempt in range(1, args.attempts + 1):
        try:
            with urllib.request.urlopen(args.url, timeout=30) as response:
                if response.status != 200:
                    raise urllib.error.HTTPError(args.url, response.status, "unexpected HTTP status", response.headers, None)
                document = response.read()
            verify_document(document, args.version, args.artifact)
            print(f"published appcast verified: {args.url}")
            return 0
        except (OSError, ValueError, urllib.error.URLError, ET.ParseError) as error:
            if attempt == args.attempts:
                print(f"published appcast was not ready after {args.attempts} attempts: {error}", file=sys.stderr)
                return 1
            print(f"appcast check {attempt}/{args.attempts} not ready: {error}")
            time.sleep(args.delay)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
