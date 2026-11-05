#!/usr/bin/env python3
"""Every string of the LauncherHistory table exists in all eight languages, and nothing more."""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LANGS = {"de", "es", "fr", "ja", "ko", "pt", "ru", "zh-Hans"}
catalog = json.loads((ROOT / "Tinycast/Resources/PersonalEdition.xcstrings").read_text())["strings"]
problems = []
for key, entry in catalog.items():
    have = {lang for lang, value in entry.get("localizations", {}).items()
            if value.get("stringUnit", {}).get("value")}
    if have != LANGS:
        problems.append(f"{key!r}: languages {sorted(have)}")
    if key.count("%@") != 0:
        for lang in have:
            if entry["localizations"][lang]["stringUnit"]["value"].count("%@") != key.count("%@"):
                problems.append(f"{key!r}: {lang} loses its %@")
used = set()
for path in list((ROOT / "Tinycast").rglob("*.swift")):
    text = path.read_text()
    if 'table: "PersonalEdition"' not in text:
        continue
    for match in re.finditer(r'(?:localized: |text\(|LocalizedStringResource\()\s*"((?:[^"\\]|\\.)*)"', text):
        key = re.sub(r"\\\((?:[^()]|\([^()]*\))*\)", "%@", match.group(1))
        used.add(key)
missing = sorted(used - set(catalog))
problems += [f"{key!r} is used but not in the catalog" for key in missing]
unused = sorted(set(catalog) - used)
problems += [f"{key!r} is in the catalog but unused" for key in unused]
print("\n".join(problems))
sys.exit(1 if problems else 0)
