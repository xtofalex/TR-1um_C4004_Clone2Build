# C4004 Clone2Build — formal check of the 10 trials (status: in progress)

This folder holds an independent check of the ten C4004 trials
(`TR-1um_C4004_01` … `_10`), done without modifying any trial file. It uses
open-source tools from KeplerTech:

* [**Kepler-Formal**](https://github.com/keplertech/kepler-formal): sequential
  equivalence (SEC), output by output, cycle by cycle, for every input sequence.
* Icarus Verilog: replay and lockstep random simulation.

Two questions:

1. Do the RTL versions of the trials behave the same as trial 01?
2. Is each trial's netlist the same machine as its RTL?
   - `openroad/c4004_core_syn.v` vs the RTL;
   - `raw_syn` (Yosys) vs `syn` (after `scripts/insert_high_fo_buffers.py`).

## Status

| Check | Result | Log |
|---|---|---|
| Inventory | Same ports in all 10 trials. RTL 07–10 byte-identical to 06 | `results/inventory.txt` |
| RTL 05 vs 04, 06 vs 05 | **proved equal**, 2 s each, so the distinct behaviours to check are 01–04 | `results/rtl_04vs05_*`, `rtl_05vs06_*` |
| RTL 02 vs 01, PDR | **7 of 12 outputs proved**; `bus_d[0..3]`, `cm_ram[1]` not concluded. No counterexample | `results/rtl_01vs02_pdr_k400_budx50` |
| … same, Kepler-Formal branch `issue-317-signal-correspondence` (8491fc0) | **8 of 12 proved**; `bus_d[0..3]` not concluded. No counterexample | `results/rtl_01vs02_pdr_k400_budx50_kf8491fc0` |
| … same, branch head befed14 (signal correspondence over 1, 2, 4 frames) | **8 of 12 proved**, unchanged; `bus_d[0..3]` not concluded. 1 and 2 frames prove no open output, 4 frames gives up. No counterexample | `results/rtl_01vs02_pdr_k400_budx50_kfbefed14` |
| … same, branch head ed98c57 (signal correspondence on binary functions, up to 16 frames) | **all 12 outputs proved**, 115 s. 4 frames prove 4 of the 8 open outputs, 16 frames the last 4 | `results/rtl_01vs02_pdr_k400_budx50_kfed98c57` |
| RTL 03, 04 vs 01, k-induction (20 min cap) | no counterexample; not concluded | `results/rtl_01vs0[34]_k_induction_k80` |
| RTL 03 vs 01, PDR, ed98c57 (1 h cap) | 8 of 12 outputs proved; 4 not concluded at the cap. No counterexample | `results/rtl_01vs03_pdr_k400_budx50_kfed98c57` |
| RTL 04 vs 01, PDR, ed98c57 | PDR reports a difference at k = 28 but Kepler-Formal finds no input trace for it. **Treated as a spurious PDR result:** the bounded check (k-induction base case) finds no difference up to depth 37 with both fd24770 and ed98c57, and lockstep random simulation shows none | `results/rtl_01vs04_pdr_k400_budx50_kfed98c57`, `rtl_01vs04_k_induction_k40_kfed98c57` |
| Netlist vs RTL, all 10 trials, k-induction k = 20 | no counterexample; 1–2 of 23 outputs proved | `results/gate_*_k_induction_k20` |
| raw_syn vs syn, all 10 trials, k-induction k = 20 | no counterexample; 1–2 of 23 outputs proved | `results/edit_*_k_induction_k20` |
| **Netlist vs RTL, all 10 trials, PDR, ed98c57** | **all 23 outputs proved**, 2–9 s each | `results/gate_*_pdr_k400_budx50_kfed98c57` |
| **raw_syn vs syn, all 10 trials, PDR, ed98c57** | **all 23 outputs proved**, 1–2 s each | `results/edit_*_pdr_k400_budx50_kfed98c57` |
| Sanity check of the netlist proofs: trial 10 netlist with one NAND2 replaced by a NOR2 (3 different cells) | counterexample found in all 3, at k = 5, 18, 30 (ed98c57 and 3ac09e2) | `results/mutant_gate_10_nand2_*` |
| Netlist vs RTL, trial 10, PDR (10 min probe) | 17 of 23 outputs proved; `d_out[2,3]`, SRAM `DIN[0..3]` not concluded | `results/gate_10_pdr_k400_probe` |
| **Global re-run, branch head 3ac09e2** (includes the fix 716eba4: binary-round register pairs constrained on the rails instead of merged) | **same verdicts as ed98c57 everywhere**: RTL 02 vs 01, 05 vs 04, 06 vs 05, netlist vs RTL and raw_syn vs syn for all 10 trials proved (≤ 191 s); RTL 03 vs 01 8 of 12, `bus_d[0..3]` not concluded (finished on its own, 49 min); RTL 04 vs 01 same untraced PDR difference at k = 28; reproducer proved, `-DBUG` and the 3 netlist mutants still found. The binary round finds no pair here (`binary_pairs=0`), so the fix does not touch these proofs | `results/*_kf3ac09e2` |
| **Global re-run, Kepler-Formal main 3f1648b** (issue-317 branch merged, new option `signal_correspondence_step`) | **RTL 01–06 all proved equal.** With `--signal-correspondence-step 8` (one instruction = 8 clock cycles): RTL 03 vs 01 and 04 vs 01 proved, all 12 outputs, 155 s and 157 s; 02 vs 01 proved, 157 s. With the default step 1: 02 vs 01 proved (147 s); 03 vs 01 8 of 12, `bus_d[0..3]` not concluded (51 min); 04 vs 01 not concluded at the 1 h cap, and the untraced difference at k = 28 is no longer reported. 05 vs 04, 06 vs 05, netlist vs RTL and raw_syn vs syn for all 10 trials proved (≤ 1 s) | `results/*_kf3f1648b`, `results/*_step8_kf3f1648b` |
| Sanity checks, 3f1648b | all found: upstream `rtl_02_bug.v` (k = 33, step 1 and 8), `rtl_03_bug.v` (k = 8, step 8), the 3 netlist mutants (k = 30, 5, 18), `shadow_nib -DBUG` (k = 18). `shadow_nib` proved, 10 s (array) and 13 s (SRAM) | `results/rtl_01vs0[23]bug_*`, `results/mutant_gate_10_nand2_*/kf3f1648b`, `results/repro_*_kf3f1648b` |
| Lockstep random simulation, RTL 02/03/04 vs 01 | **0 mismatches** in 10 × 10⁶ cycles each | `results/random_sim_rtl_*.log` |
| Lockstep random simulation, netlist vs RTL, all 10 trials | **0 mismatches** in 10 × 10⁶ cycles each, pins and SRAM interface | `results/random_sim_gate_*.log` |

**How to read the table:**
- "Proved" means proved for every reachable state.
- "Not concluded" means the solver stopped on its budget or on our wall-clock cap. It is not evidence of a difference.
- Random simulation is evidence, not proof.
- The trials do not clear the SRAM after reset. Words never written are unknown (X), and SEC compares only binary-defined outputs.

## Why `bus_d` was not concluded for RTL 01 vs 02

Trial 02 keeps a copy of PC+1 in `buf_l/m/h` and reads the PC from these
registers instead of the SRAM while `pc_init_n` = 0. Trial 01 always reads it
from the SRAM. The PC nibbles appear on `bus_d` in phases A1–A3.

Two small designs, equivalent by construction and not derived from trial code (`repro/`), reproduce the inconclusive result:

| Reproducer | Kepler-Formal fd24770 | Kepler-Formal 8491fc0 | Kepler-Formal befed14 | Kepler-Formal ed98c57 |
|---|---|---|---|---|
| `shadow.v`: register copy of one memory word, 32 words × 4–12 bits | 1–2 of 4–12 outputs proved | **all proved**, 8–31 s | not rerun | not rerun |
| `shadow_nib.v`: 12-bit PC as three nibbles, read and written in separate phases | `bus[0..3]` not concluded | `bus[0..3]` not concluded | **all proved**, 48 s (array), 53 s (SRAM) | **all proved**, 14 s (array), 14 s (SRAM) |

- **Sanity check:** in both reproducers a deliberately inserted bug (`-DBUG`) is found (cycle 2, and cycles 18–25; befed14 and ed98c57: cycle 18).
- **befed14 on the trials:** the reproducer is fixed, RTL 01 vs 02 is not: on the full design the 4-frame induction stops on its limits.
- **ed98c57 on the trials:** RTL 01 vs 02 is **proved equal** on all 12 outputs in 115 s (befed14: 8 of 12 after 50 min CPU).
- **Reset warning (ed98c57):** Kepler-Formal now reports that after the 3 reset cycles 132 of 179 state bits per design can still be X: the SRAM cells and its read register. This is the uncleared SRAM noted above, not a wrapper problem.
- **Upstream:** reported in [kepler-formal#317](https://github.com/keplertech/kepler-formal/issues/317).

## Still to do

- Netlist of trial N vs RTL 01, only where the RTL is proved equal.
- Part 2: how the trials were explored, edited and checked, and where the tools would have helped.
- `DETAILS.md` with methods and exact commands.

## Layout and reproduction

| Path | Content |
|---|---|
| `inventory.py` | hashes, groups and port check of the 10 trials |
| `gen_cfg.sh`, `cfg/` | preprocessed SEC inputs (common wrapper `sec/wrap_c4004.v`) |
| `run_sec.sh <rtl\|gate\|edit\|cross> <NN> <engine> <k> [tag]` | one Kepler-Formal run (`SC_STEP=<n>` adds `--signal-correspondence-step <n>`); writes `results/<name>/run.log` and `status.txt` (command, tool version, exit code, wall and CPU time, peak memory) |
| `replay.sh`, `sim/` | counterexample replay and lockstep simulation benches |
| `random_sim.sh` | lockstep random simulation, 5 seeds × 10⁶ cycles × 2 stimulus edges |
| `sim_provenance.sh` | which sources the stored simulation logs and binaries of each trial came from |
| `repro/` | the two reproducers above (`run.sh`, `tb_nib.v`) |

**Tools:**
- Kepler-Formal `fd24770` and `3f1648b` (main), `8491fc0`, `befed14`, `ed98c57` and `3ac09e2` (branch `issue-317-signal-correspondence`), Release builds in `tools/`, which is not committed;
- Icarus Verilog.

**Compressed logs:** `run.log` of `results/rtl_01vs02_pdr_k400_budx50_kf8491fc0` and `_kfbefed14` are stored as `run.log.xz` (266 MB uncompressed each), and `results/rtl_01vs03_pdr_k400_budx50_kfed98c57` and `_kf3ac09e2` too (169 and 176 MB), and `results/rtl_01vs03_pdr_k400_budx50_kf3f1648b` and `rtl_01vs04_pdr_k400_budx50_kf3f1648b` (192 and 256 MB).
