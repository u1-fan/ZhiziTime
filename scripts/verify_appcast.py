#!/usr/bin/env python3
"""Validate the current Sparkle appcast entry."""

import argparse
import sys
import urllib.parse
import xml.etree.ElementTree as ET

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def verify_document(document: bytes, version: str, artifact: str) -> None:
    root = ET.fromstring(document)
    entries = root.findall(".//item")
    for item in entries:
        enclosure = item.find("enclosure")
        if enclosure is None:
            continue
        if enclosure.get(f"{{{SPARKLE}}}version") != version:
            continue
        url = enclosure.get("url", "")
        if not url or "/latest/" in url or not url.endswith(urllib.parse.quote(artifact)):
            raise ValueError("appcast enclosure URL is not versioned or does not match the artifact")
        if not enclosure.get(f"{{{SPARKLE}}}edSignature"):
            raise ValueError("appcast enclosure has no EdDSA signature")
        return
    raise ValueError(f"appcast has no signed entry for version {version}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("appcast")
    parser.add_argument("version")
    parser.add_argument("artifact")
    args = parser.parse_args()
    try:
        with open(args.appcast, "rb") as stream:
            verify_document(stream.read(), args.version, args.artifact)
    except (OSError, ValueError, ET.ParseError) as error:
        print(f"appcast: {error}", file=sys.stderr)
        return 1
    print(f"appcast: verified {args.version} {args.artifact}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
