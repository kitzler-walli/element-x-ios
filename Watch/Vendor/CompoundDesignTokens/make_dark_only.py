#!/usr/bin/env python3
#
# Copyright 2026 Element Creations Ltd.
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
# Please see LICENSE files in the repository root for full details.
#

"""Makes every colour set in Colors.xcassets use its dark variant as the only value.

watchOS is always dark and ignores the luminosity appearances in asset catalogs, so without
this the tokens resolve to their light values. Run it after updating the vendored tokens.
"""

import json
import pathlib
import sys


def dark_variant(colors):
    for entry in colors:
        appearances = entry.get("appearances", [])
        if appearances == [{"appearance": "luminosity", "value": "dark"}]:
            return entry
    return None


def main():
    catalog = pathlib.Path(__file__).resolve().parent / "Colors.xcassets"
    updated = 0

    for contents in sorted(catalog.glob("*.colorset/Contents.json")):
        data = json.loads(contents.read_text())
        dark = dark_variant(data.get("colors", []))
        if dark is None:
            continue  # Already dark only, or a colour without a dark variant.

        data["colors"] = [{"idiom": "universal", "color": dark["color"]}]
        contents.write_text(json.dumps(data, indent=2) + "\n")
        updated += 1

    print(f"Updated {updated} colour sets.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
