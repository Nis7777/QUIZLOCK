#!/usr/bin/env python3
"""
Generates Shared/Localizable.xcstrings. The app is English only: keys are the English strings exactly as
they appear in code (Xcode extracts them automatically). This script only adds the plural variants.

    python3 Scripts/build_strings.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Shared", "Localizable.xcstrings")

# Plurals: key → (one, other)
PLURALS = {
    "%lld hours": ("%lld hour", "%lld hours"),
    "%lld minutes": ("%lld minute", "%lld minutes"),
    "%lld apps selected": ("%lld app selected", "%lld apps selected"),
    "%lld puzzles": ("%lld puzzle", "%lld puzzles"),
    "%lld tries left": ("%lld try left", "%lld tries left"),
    "Not quite. %lld tries left": ("Not quite. %lld try left", "Not quite. %lld tries left"),
    "%lld-day streak": ("%lld-day streak", "%lld-day streak"),
    "%lld-day streak!": ("%lld-day streak!", "%lld-day streak!"),
    "Keep your %lld-day streak 🔥": ("Keep your %lld-day streak 🔥", "Keep your %lld-day streak 🔥"),
    "Solve %lld puzzles to unlock %@": ("Solve %1$lld puzzle to unlock %2$@", "Solve %1$lld puzzles to unlock %2$@"),
}


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def main():
    strings = {}
    for key, (one, other) in PLURALS.items():
        strings[key] = {"localizations": {
            "en": {"variations": {"plural": {"one": unit(one), "other": unit(other)}}},
        }}
    catalog = {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2, sort_keys=False)
        f.write("\n")
    print(f"Wrote {len(strings)} strings to {os.path.relpath(OUT, ROOT)}")


if __name__ == "__main__":
    main()
