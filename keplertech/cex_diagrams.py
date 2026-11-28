#!/usr/bin/env python3
"""Draw the SEC counterexamples of results/ as schematics with naja-schematic.

Usage (from keplertech/, with najaeda and naja-schematic installed):
    tools/naja-venv/bin/python cex_diagrams.py [out_dir]   # default docs/cex

For each counterexample listed in CASES, reads the first difference that
Kepler-Formal reports in run.log (cycle and output) and
writes <name>.svg and <name>.png (the per-design values are not shown:
see kepler-formal#312):
  - RTL: the fan-in cone of the differing output in the faulty design, every
    register named on its output net, the edited register drawn red;
  - netlist mutant: the changed cell, its fan-in back to the flops and the
    net it drives, filled and drawn red.
The differing output and its values go in the caption.
"""
import re
import sys
from pathlib import Path

import naja_schematic
from najaeda import netlist

HERE = Path(__file__).resolve().parent
TRIAL10 = HERE.parent / "TR-1um_C4004_10"
LIBS = [TRIAL10 / "module/STDCELL/tr1um_typ_5v0_25c.lib",
        TRIAL10 / "module/SRAM128/SRAM128.lib"]
REGRESS = HERE / "tools/kepler-formal/regress/c4004_rtl"
RED, BLUE = "#d62728", "#1f77b4"

CASES = [
    dict(name="rtl_03_bug", kind="rtl", ref="RTL 01", dut="RTL 03 with a bug",
         result="results/rtl_01vs03bug_pdr_k400_budx50_step8_kf3f1648b",
         design=REGRESS / "rtl_03_bug.v", reg="pc_init_n",
         edit="where pc_init_n <= 1'b1 was removed (the PC copy stays marked valid)"),
    dict(name="rtl_02_bug", kind="rtl", ref="RTL 01", dut="RTL 02 with a bug",
         result="results/rtl_01vs02bug_pdr_k400_budx50_kf3f1648b",
         design=REGRESS / "rtl_02_bug.v", reg="pc_init_n",
         edit="where pc_init_n <= 1'b1 was removed (the PC copy stays marked valid after INC)"),
] + [
    dict(name=f"mutant_nand2_{n}", kind="mutant", ref="RTL 06", dut=f"trial 10 netlist, mutant {n}",
         result=f"results/mutant_gate_10_nand2_{n}/kf3f1648b", nth=n)
    for n in (1, 40, 80)
]


def first_difference(run_log):
    """(cycle, [(signal, ref value, dut value)]) of the reported counterexample."""
    text = Path(run_log).read_text(errors="replace")
    cycle = int(re.search(r"first bad frame at cycle (\d+)", text).group(1))
    block = text.split(f"Observed output mismatches at cycle {cycle}:", 1)[1]
    diffs = re.findall(r"^\s+(\S+): design0=(\S+), design1=(\S+)$", block.split("Traceback", 1)[0], re.M)
    return cycle, diffs


def describe(signal):
    if signal.startswith("__kepler_boundary"):
        return "an SRAM128 input"
    return signal.replace("[0]", "") if signal.endswith("[0]") and "[" in signal[:-3] else signal


def mutant_netlist(nth, out):
    """Trial 10 netlist with its nth NAND2 replaced by a NOR2 (as in results/mutant_*/README.txt)."""
    count, cell, lines = 0, None, []
    for line in (TRIAL10 / "openroad/c4004_core_syn.v").read_text().splitlines():
        if re.match(r"^\s*NAND2 ", line):
            count += 1
            if count == nth:
                line = line.replace("NAND2", "NOR2", 1)
                cell = line.split()[1]
        lines.append(line)
    out.write_text("\n".join(lines) + "\n")
    return cell


def rtl_job(case, cycle, diffs):
    netlist.reset()
    top = netlist.load_system_verilog([str(case["design"])])
    out_sig, ref_v, dut_v = diffs[0]
    port = out_sig.split("[")[0]
    bit = int(out_sig.split("[")[1].rstrip("]")) if "[" in out_sig else None
    pin = ([], port, bit) if bit is not None else ([], port)
    style = [{"kind": "net", "target": pin, "color": RED, "width": 3,
              "label": f"{out_sig}: differs at cycle {cycle}"}]
    found = False
    for inst in top.get_child_instance("u_core").get_child_instances():
        if not any(t.is_sequential() for t in inst.get_terms()):
            continue
        q = [t for t in inst.get_terms() if t.is_output() and t.get_upper_net()]
        if not q:
            continue
        # elaborated registers are unnamed instances: name them on their output net
        reg, width = q[0].get_upper_net().get_name(), q[0].get_width()
        out = (inst, q[0].get_name(), 0) if width > 1 else (inst, q[0].get_name())
        if reg == case["reg"]:
            found = True
            style.append({"kind": "instance", "target": inst, "fill": RED + "66"})
            style.append({"kind": "net", "target": out, "color": RED, "width": 3,
                          "label": f"{reg} (edited)"})
        else:
            style.append({"kind": "net", "target": out, "label": reg + ("[0]" if width > 1 else "")})
    if not found:
        raise SystemExit(f"{case['name']}: register {case['reg']} not found")
    return dict(traces=[pin], style=style,
                caption=f"First difference at cycle {cycle}, on {describe(out_sig)}. Green: its fan-in back to the registers; "
                        f"red: the edited register, {case['edit']}.")


def mutant_job(case, cycle, diffs, work):
    netlist.reset()
    for lib in LIBS:
        netlist.load_liberty([str(lib)])
    mutant = work / f"{case['name']}.v"
    cell = mutant_netlist(case["nth"], mutant)
    top = netlist.load_gate_level_verilog([str(mutant)])
    inst = top.get_child_instance(cell)
    out_sig, ref_v, dut_v = diffs[0]
    style = [{"kind": "instance", "target": inst, "fill": RED + "66", "label": f"{cell}: NAND2 -> NOR2"},
             {"kind": "net", "target": (inst, "Y"), "color": RED, "width": 3}]
    return dict(traces=[(inst, "Y")], nets=[(inst, "Y")], style=style,
                caption=f"First difference at cycle {cycle}, on {describe(out_sig)}. Red: the changed cell and the net it drives; "
                        f"magenta: its fan-in back to the flip-flops.")


def main():
    out_dir = HERE / (sys.argv[1] if len(sys.argv) > 1 else "docs/cex")
    out_dir.mkdir(parents=True, exist_ok=True)
    for case in CASES:
        cycle, diffs = first_difference(HERE / case["result"] / "run.log")
        job = rtl_job(case, cycle, diffs) if case["kind"] == "rtl" else mutant_job(case, cycle, diffs, out_dir)
        title = f"{case['dut']} vs {case['ref']}: counterexample"
        svg = out_dir / f"{case['name']}.svg"
        naja_schematic.export_svg(path=str(svg), traces=job.get("traces"), nets=job.get("nets"),
                                  style=job["style"], title=title, caption=job["caption"],
                                  hide_ui_glyphs=True)
        naja_schematic.export_png(path=str(out_dir / f"{case['name']}.png"), traces=job.get("traces"),
                                  nets=job.get("nets"), style=job["style"], title=title,
                                  caption=job["caption"], hide_ui_glyphs=True, scale=2)
        (out_dir / f"{case['name']}.v").unlink(missing_ok=True)
        print(f"{svg.relative_to(HERE)}: {job['caption']}")


if __name__ == "__main__":
    main()
