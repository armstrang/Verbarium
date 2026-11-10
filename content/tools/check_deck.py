#!/usr/bin/env python3
"""Checks the Verbarium deck (mobile/assets/deck/*.txt): format, one gap per sentence, no word twice.

Core files: word|pos|meaning|sentence[|=form]   (the rank comes from the file name, 1-… to 5-…; a file may be
                                                 split: 1-squire.txt, 1-squire-b.txt, …)
Banner files (toefl.txt, ielts.txt): rank|word|pos|meaning|sentence[|=form]
collocations.txt: rank|phrase with [answer]|wrong,wrong,wrong|meaning[|meaning in English]
en/<same file name>: word|definition   (plain English, for learning through English; the definition may not
                                        use the word itself)
A word may be written american/british. "=form" is what the gap wants when it is not the headword (=increased). Run from the repository root:  python3 content/tools/check_deck.py
With --loose, words that have no English definition yet are counted but are not an error.
"""
import glob, os, re, sys

POS = {"n", "v", "adj", "adv", "prep", "conj"}
root = os.path.join(os.path.dirname(__file__), "..", "..", "mobile", "assets", "deck")
bad, seen, counts = [], {}, {}
words_in = {}  # file name -> headwords
for path in sorted(glob.glob(os.path.join(root, "*.txt"))):
    name = os.path.basename(path)
    if name == "collocations.txt":
        for ln, line in enumerate(open(path, encoding="utf-8"), 1):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            f = line.split("|")
            ok = len(f) in (4, 5) and f[0].isdigit()
            if ok and len(f) == 5:
                m = re.search(r"\[(.+?)\]", f[1])
                if m and re.search(rf"\b{re.escape(m.group(1))}\b", f[4].lower()): bad.append(f"{name}:{ln} the English meaning gives the answer away")
                if "--loose" not in sys.argv and len(f[4].strip()) < 3: bad.append(f"{name}:{ln} English meaning")
            elif ok and "--loose" not in sys.argv: bad.append(f"{name}:{ln} no English meaning") and re.search(r"\[[a-z]+\]", f[1]) and len(f[2].split(",")) == 3 and f[3].strip()
            if not ok: bad.append(f"{name}:{ln} collocation")
            elif re.search(r"\[([a-z]+)\]", f[1]).group(1) in f[2].split(","): bad.append(f"{name}:{ln} answer among the wrong ones")
            counts[("colloc", int(f[0]) if f[0].isdigit() else 0)] = counts.get(("colloc", int(f[0]) if f[0].isdigit() else 0), 0) + 1
        continue
    layer = "core" if name[0].isdigit() else name[:-4]
    for ln, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        f = line.split("|")
        if layer == "core":
            rank = int(name[0])
        else:
            if not f[0].isdigit():
                bad.append(f"{name}:{ln} no rank"); continue
            rank, f = int(f[0]), f[1:]
        gap = None
        if len(f) == 5 and re.fullmatch(r"=[a-z]+(/[a-z]+)?", f[4]):
            gap, f = f[4][1:].split("/"), f[:4]
        if len(f) != 4:
            bad.append(f"{name}:{ln} {len(f)} fields"); continue
        word, pos, meaning, sent = f
        if pos not in POS: bad.append(f"{name}:{ln} pos {pos}")
        if sent.count("___") != 1: bad.append(f"{name}:{ln} gaps {sent.count('___')}")
        if not meaning.strip(): bad.append(f"{name}:{ln} no meaning")
        if not re.fullmatch(r"[a-z]+(/[a-z]+)?", word): bad.append(f"{name}:{ln} word {word!r}")
        for w in (gap or []):
            if re.search(rf"\b{w}\b", sent.lower()): bad.append(f"{name}:{ln} answer in sentence: {w}")
        for w in word.split("/"):
            if re.search(rf"\b{w}\b", sent.lower()): bad.append(f"{name}:{ln} answer in sentence: {w}")
            key = (w, layer if layer != "core" else "core")
            for other in ("core", layer):
                if (w, other) in seen: bad.append(f"{name}:{ln} twice: {w} (also {seen[(w, other)]})")
            seen[key] = f"{name}:{ln}"
        if not sent.rstrip().endswith((".", "?", "!")): bad.append(f"{name}:{ln} no full stop")
        words_in.setdefault(name, {})[word.split("/")[0]] = word.split("/")
        counts[(layer, rank)] = counts.get((layer, rank), 0) + 1
# English definitions
have, total = 0, sum(len(v) for v in words_in.values())
for name, ws in sorted(words_in.items()):
    path = os.path.join(root, "en", name)
    defs = {}
    if os.path.exists(path):
        for ln, line in enumerate(open(path, encoding="utf-8"), 1):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            w, _, d = line.partition("|")
            w = w.split("/")[0]
            if w not in ws: bad.append(f"en/{name}:{ln} not a word of {name}: {w}"); continue
            if w in defs: bad.append(f"en/{name}:{ln} twice: {w}")
            if len(d.strip()) < 3 or "|" in d: bad.append(f"en/{name}:{ln} definition")
            for form in ws[w]:
                if re.search(rf"\b{form}\b", d.lower()): bad.append(f"en/{name}:{ln} the definition uses the word: {form}")
            defs[w] = d
    have += len(defs)
    missing = [w for w in ws if w not in defs]
    if missing and "--loose" not in sys.argv: bad.append(f"en/{name}: {len(missing)} words without a definition, e.g. {', '.join(missing[:5])}")
for path in glob.glob(os.path.join(root, "en", "*.txt")):
    if os.path.basename(path) not in words_in: bad.append(f"en/{os.path.basename(path)}: no deck file of that name")
print("definitions", have, "of", total)
for k in sorted(counts): print(k, counts[k])
print("core", sum(v for (l, _), v in counts.items() if l == "core"),
      "toefl", sum(v for (l, _), v in counts.items() if l == "toefl"),
      "ielts", sum(v for (l, _), v in counts.items() if l == "ielts"))
print("\n".join(bad) if bad else "deck ok")
sys.exit(1 if bad else 0)
