#!/usr/bin/env python3
"""Extract the post-reset input trace from a Kepler-Formal SEC log.

Parses lines of the form
    cycle N: rst[0]=0, test[0]=1, d_in[0]=0, d_in[1]=1, ...
and writes a $readmemh file with one line per cycle: {rst, test, d_in[3:0]}
as two hex digits. An input that the trace omits for a cycle is a don't-care
for the counterexample and is written as 0 (reported on stderr).

usage: cex2memh.py <kepler run.log> <out.memh>
prints: number of cycles and the reported bad frame
"""
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
cyc_re = re.compile(r"^\s*cycle (\d+):\s*(.*)$")
bit_re = re.compile(r"(\w+)\[(\d+)\]=([01])")
bad_re = re.compile(r"first bad frame at cycle (\d+)")

rows, bad, missing = {}, None, set()
with open(src) as f:
    for line in f:
        m = bad_re.search(line)
        if m:
            bad = int(m.group(1))
        m = cyc_re.match(line)
        if not m:
            continue
        n = int(m.group(1))
        vals = {"rst": 0, "test": 0, "d_in": 0}
        seen = set()
        for name, idx, v in bit_re.findall(m.group(2)):
            seen.add(name)
            if name in vals:
                vals[name] |= int(v) << int(idx)
        missing |= {k for k in vals if k not in seen}
        rows[n] = (vals["rst"] << 5) | (vals["test"] << 4) | vals["d_in"]

if not rows:
    sys.exit(f"no 'cycle N:' trace found in {src}")
n = max(rows) + 1
with open(dst, "w") as f:
    for i in range(n):
        f.write(f"{rows.get(i, 0):02x}\n")
if missing:
    print(f"note: inputs not in trace (don't-care, written as 0): {sorted(missing)}", file=sys.stderr)
print(f"{n} {bad if bad is not None else -1}")
