#!/usr/bin/env python3
"""Drops repeated words from the continuation files of the deck (1-squire-b.txt, …): a word already in a rank's
first file, in a banner file, or in an earlier continuation file keeps its first entry. Run before check_deck.py.
    python3 content/tools/dedupe_deck.py
"""
import glob, os, re

root = os.path.join(os.path.dirname(__file__), "..", "..", "mobile", "assets", "deck")
files = sorted(glob.glob(os.path.join(root, "*.txt")))
base = [f for f in files if re.fullmatch(r"[1-5]-[a-z]+\.txt", os.path.basename(f)) or os.path.basename(f) in ("toefl.txt", "ielts.txt")]
more = [f for f in files if re.fullmatch(r"[1-5]-[a-z]+-[a-z]+\.txt", os.path.basename(f))]


def words(line, banner):
    f = line.split("|")
    return (f[1] if banner else f[0]).split("/")


seen = set()
for path in base:
    banner = not os.path.basename(path)[0].isdigit()
    for line in open(path, encoding="utf-8"):
        if line.strip() and not line.startswith("#"):
            seen.update(words(line.rstrip("\n"), banner))
dropped = 0
for path in more:
    keep = []
    for line in open(path, encoding="utf-8"):
        raw = line.rstrip("\n")
        if raw.strip() and not raw.startswith("#"):
            ws = words(raw, False)
            if any(w in seen for w in ws):
                dropped += 1
                continue
            seen.update(ws)
        keep.append(line)
    open(path, "w", encoding="utf-8").writelines(keep)
print("dropped", dropped, "words in the deck:", len(seen))
