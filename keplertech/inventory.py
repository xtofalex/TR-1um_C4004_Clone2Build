#!/usr/bin/env python3
"""Inventory of the Gemini trial files (read-only).

For rtl/c4004_core.v, rtl/c4004_top.v, openroad/c4004_core_raw_syn.v,
openroad/c4004_core_syn.v and the two Liberty files of TR-1um_C4004_01..10:
SHA-256, groups of identical files, and the c4004_core port list of each
distinct version compared with trial 01.

usage: python3 inventory.py > results/inventory.txt   (run from keplertech/)
"""
import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TRIALS = [f"{i:02d}" for i in range(1, 11)]
FILES = ["rtl/c4004_core.v", "rtl/c4004_top.v",
         "openroad/c4004_core_raw_syn.v", "openroad/c4004_core_syn.v",
         "module/STDCELL/tr1um_typ_5v0_25c.lib", "module/SRAM128/SRAM128.lib"]


def ports(path):
    """(direction, name, width) of module c4004_core, from ANSI or non-ANSI
    declarations; escaped scalar bits like \\d_in[0] are merged into buses."""
    txt = Path(path).read_text()
    m = re.search(r"module\s+c4004_core\b(.*?)endmodule", txt, re.S)
    body = m.group(1)
    bits = {}
    for d, rng, n in re.findall(
            r"\b(input|output|inout)\s+(?:wire\s+|reg\s+)?(\[\d+:\d+\])?\s*(\\\S+|\w+)", body):
        n = n.lstrip("\\")
        mb = re.match(r"(\w+)\[(\d+)\]$", n)
        if mb:
            bits.setdefault((d, mb.group(1)), set()).add(int(mb.group(2)))
        elif rng:
            hi, lo = map(int, rng[1:-1].split(":"))
            bits.setdefault((d, n), set()).update(range(lo, hi + 1))
        else:
            bits.setdefault((d, n), set()).add(0)
    return sorted((d, n, len(b)) for (d, n), b in bits.items())


print("# Inventory of Gemini trial files (sha256, first 12 hex digits)\n")
groups = {}
for f in FILES:
    print(f"## {f}")
    seen = {}
    for t in TRIALS:
        p = ROOT / f"TR-1um_C4004_{t}" / f
        h = hashlib.sha256(p.read_bytes()).hexdigest()[:12]
        seen.setdefault(h, []).append(t)
        print(f"  {t}  {h}  {sum(1 for _ in p.open())} lines")
    print("  distinct versions: " + "; ".join(
        f"{v[0]}" + (f" (= {', '.join(v[1:])})" if len(v) > 1 else "") for v in seen.values()))
    groups[f] = seen
    print()

print("## c4004_core ports vs trial 01 (direction, name, width)")
ref = ports(ROOT / "TR-1um_C4004_01/rtl/c4004_core.v")
print("  trial 01 rtl: " + ", ".join(f"{d} {n}[{w}]" for d, n, w in ref))
for f in ["rtl/c4004_core.v", "openroad/c4004_core_raw_syn.v", "openroad/c4004_core_syn.v"]:
    for h, ts in groups[f].items():
        p = ports(ROOT / f"TR-1um_C4004_{ts[0]}" / f)
        print(f"  {f} {ts[0]}: {'same as trial 01 rtl' if p == ref else 'DIFFERENT: ' + str(p)}")
