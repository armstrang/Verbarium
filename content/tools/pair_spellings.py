#!/usr/bin/env python3
"""Adds the British spelling to deck words that have one: organize -> organize/organise.

Only known patterns, each with a list or with exceptions, so nothing is guessed: -ize/-ise (and -ization,
-ized, -izing), -yze/-yse, -or/-our for a list of stems, -er/-re for a list of words, -og/-ogue, -ense/-ence,
a doubled l, and single words (gray/grey, mold/mould, …). Words in ielts.txt are written British only; for those
the American form is put first. Also pairs the "=form" a gap wants. Run from the repository root:
    python3 content/tools/pair_spellings.py        (then check_deck.py)
"""
import glob, os, re

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "mobile", "assets", "deck")
NOT_IZE = {"size", "prize", "seize", "capsize", "downsize", "oversize", "resize", "outsize", "baize", "maize", "assize"}
OUR = ["color", "honor", "humor", "labor", "neighbor", "favor", "flavor", "harbor", "behavior", "rumor", "vapor",
       "savior", "odor", "valor", "vigor", "armor", "endeavor", "parlor", "clamor", "splendor", "tumor", "candor",
       "ardor", "rigor", "fervor", "saviour"]
RE = {"center": "centre", "theater": "theatre", "meter": "metre", "liter": "litre", "fiber": "fibre",
      "caliber": "calibre", "somber": "sombre", "saber": "sabre", "specter": "spectre", "luster": "lustre",
      "centimeter": "centimetre", "kilometer": "kilometre", "millimeter": "millimetre", "meager": "meagre",
      "centered": "centred", "theaters": "theatres", "fibers": "fibres", "meters": "metres", "kilometers": "kilometres"}
SINGLE = {"gray": "grey", "mold": "mould", "molding": "moulding", "plow": "plough", "skeptic": "sceptic",
          "skeptical": "sceptical", "skepticism": "scepticism", "aluminum": "aluminium", "maneuver": "manoeuvre",
          "pediatric": "paediatric", "anemia": "anaemia", "anesthesia": "anaesthesia", "hemoglobin": "haemoglobin",
          "diarrhea": "diarrhoea", "fetus": "foetus", "mollusk": "mollusc", "sulfur": "sulphur", "ocher": "ochre",
          "cozy": "cosy", "pajamas": "pyjamas", "catalog": "catalogue", "analog": "analogue", "dialog": "dialogue",
          "defense": "defence", "offense": "offence", "pretense": "pretence", "jewelry": "jewellery",
          "counselor": "counsellor", "marvelous": "marvellous", "enrollment": "enrolment", "enroll": "enrol",
          "fulfill": "fulfil", "skillful": "skilful", "installment": "instalment", "willful": "wilful",
          "traveler": "traveller", "traveling": "travelling", "traveled": "travelled", "canceled": "cancelled",
          "canceling": "cancelling", "labeled": "labelled", "labeling": "labelling", "modeling": "modelling",
          "fueled": "fuelled", "leveled": "levelled", "signaled": "signalled", "quarreled": "quarrelled",
          "esthetic": "aesthetic", "archeology": "archaeology", "orthopedic": "orthopaedic", "estrogen": "oestrogen",
          "check": None, "program": None, "draft": None, "tire": None, "curb": None}
# British-only words in ielts.txt whose American form is a plain -ise -> -ize change
IELTS_ISE = re.compile(r"(ise|ised|ises|ising|isation|isations)$")
IELTS_KEEP_ISE = {"exercise", "advertise", "surprise", "compromise", "advise", "expertise", "franchise",
                  "enterprise", "merchandise", "otherwise", "premise", "promise", "rise", "wise", "noise", "supervise",
                  "televise", "devise", "revise", "comprise", "despise", "chastise", "improvise", "disguise", "precise",
                  "concise", "paradise", "raise", "praise", "cruise", "bruise", "anise", "demise", "excise"}


NOT_OUR = {"honorary", "honorarium", "laborious", "laboratory", "laboratories", "humorous", "vaporize", "coloration",
           "odorless", "vigorous", "rigorous", "clamorous", "valorous", "armory"}


def british(w):
    if w in NOT_OUR:
        return None
    if w in SINGLE:
        return SINGLE[w]
    if w in RE:
        return RE[w]
    for stem in OUR:
        if w.startswith(stem) and len(w) - len(stem) <= 6 and not w.startswith(stem + "ou"):
            return stem[:-2] + "our" + w[len(stem):]
    m = re.search(r"(i)(z)(e|ed|es|ing|ation|ations|er|ers)$", w)
    if m and len(w) > 5 and not any(w.endswith(x) for x in NOT_IZE):
        return w[:m.start(2)] + "s" + w[m.end(2):]
    m = re.search(r"yz(e|ed|es|ing)$", w)
    if m:
        return w[:m.start()] + "ys" + w[m.start() + 2:]
    return None


def american(w):
    """for a British-only word in ielts.txt"""
    for a, b in SINGLE.items():
        if b == w:
            return a
    for a, b in RE.items():
        if b == w:
            return a
    for stem in OUR:
        uk = stem[:-2] + "our"
        if w.startswith(uk) and not w.startswith(stem):
            return stem + w[len(uk):]
    if w.endswith(("raising", "raise", "rise", "rising")):
        return None
    if IELTS_ISE.search(w) and len(w) > 6 and not any(w.startswith(k[:-1]) or w == k for k in IELTS_KEEP_ISE):
        return IELTS_ISE.sub(lambda m: m.group(1).replace("is", "iz"), w)
    return None


def pair(field, ielts):
    if "/" in field:
        return field
    if ielts:
        a = american(field)
        return f"{a}/{field}" if a and a != field else field
    b = british(field)
    return f"{field}/{b}" if b and b != field else field


changed = 0
for path in sorted(glob.glob(os.path.join(ROOT, "*.txt"))):
    name = os.path.basename(path)
    if name == "collocations.txt":
        continue
    ielts = name == "ielts.txt"
    head = 0 if name[0].isdigit() else 1
    out, renames = [], {}
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            out.append(line); continue
        f = line.split("|")
        new = pair(f[head], ielts)
        if new != f[head]:
            renames[f[head]] = new; f[head] = new; changed += 1
        if len(f) > head + 4 and f[head + 4].startswith("=") and "/" not in f[head + 4]:
            g = pair(f[head + 4][1:], ielts)
            f[head + 4] = "=" + g
        out.append("|".join(f))
    open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
    # the definitions are filed under the first spelling
    en = os.path.join(ROOT, "en", name)
    if renames and os.path.exists(en):
        lines = []
        for line in open(en, encoding="utf-8"):
            w, sep, d = line.rstrip("\n").partition("|")
            lines.append((renames.get(w, w) if sep else w) + sep + d)
        open(en, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("paired", changed)
