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

Kepler-Formal main `3f1648b`, PDR engine, 3 reset cycles on `rst`. Earlier
tool versions and engines are in the git history and in the other `results/`
directories.

| Check | Result | Log |
|---|---|---|
| Inventory | Same ports in all 10 trials. RTL 07–10 byte-identical to 06 | `results/inventory.txt` |
| RTL 05 vs 04, 06 vs 05 | **proved equal**, ≤ 1 s each | `results/rtl_04vs05_*_kf3f1648b`, `rtl_05vs06_*_kf3f1648b` |
| RTL 02 vs 01 | **proved equal**, all 12 outputs, 147 s (157 s with step 8) | `results/rtl_01vs02_*_kf3f1648b` |
| RTL 03 vs 01, `--signal-correspondence-step 8` | **proved equal**, all 12 outputs, 155 s | `results/rtl_01vs03_pdr_k400_budx50_step8_kf3f1648b` |
| RTL 04 vs 01, `--signal-correspondence-step 8` | **proved equal**, all 12 outputs, 157 s | `results/rtl_01vs04_pdr_k400_budx50_step8_kf3f1648b` |
| **Netlist vs RTL**, all 10 trials | **proved equal**, all 23 outputs, ≤ 1 s each | `results/gate_*_pdr_k400_budx50_kf3f1648b` |
| **raw_syn vs syn**, all 10 trials | **proved equal**, all 23 outputs, ≤ 1 s each | `results/edit_*_pdr_k400_budx50_kf3f1648b` |
| Sanity: RTL with a bug (upstream `rtl_02_bug.v`, `rtl_03_bug.v`) | counterexample found, k = 33 and k = 8 | `results/rtl_01vs0[23]bug_*_kf3f1648b` |
| Sanity: trial 10 netlist with one NAND2 replaced by a NOR2 (3 cells) | counterexample found in all 3, k = 5, 18, 30 | `results/mutant_gate_10_nand2_*/kf3f1648b` |
| Lockstep random simulation, RTL 02/03/04 vs 01 | **0 mismatches** in 10 × 10⁶ cycles each | `results/random_sim_rtl_*.log` |
| Lockstep random simulation, netlist vs RTL, all 10 trials | **0 mismatches** in 10 × 10⁶ cycles each, pins and SRAM interface | `results/random_sim_gate_*.log` |

**How to read the table:**
- "Proved" means proved for every reachable state.
- Random simulation is evidence, not proof.
- The trials do not clear the SRAM after reset. Words never written are unknown (X), and SEC compares only binary-defined outputs.

## Why RTL 03 and 04 need step 8

Trial 02 keeps a copy of the program counter in registers beside the SRAM.
Trial 03 also reads the index register one cycle early and writes the stack one
cycle late for register instructions, so its memories agree with trial 01's at
the end of every instruction (8 clock cycles), not in every cycle. With `--signal-correspondence-step 8` one induction step spans one
instruction; any step is sound, a wrong one only proves less. With the default
step 1, RTL 03 vs 01 stops at 8 of 12 outputs (`bus_d[0..3]` open, 51 min) and
RTL 04 vs 01 is not concluded at the 1 h cap (`results/rtl_01vs0[34]_pdr_k400_budx50_kf3f1648b`).

The reproducer `repro/shadow_nib.v` (12-bit PC as three nibbles, equivalent by
construction) is proved in 10 s (array) and 13 s (SRAM), and its `-DBUG`
variant is found at k = 18 (`results/repro_*_kf3f1648b`).

Reported upstream in [kepler-formal#317](https://github.com/keplertech/kepler-formal/issues/317);
RTL 01–04 are now in Kepler-Formal's regression (`regress/c4004_rtl/`).

## Still to do

- Netlist of trial N vs RTL 01, now that all RTL versions are proved equal.
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
| `repro/` | reproducers `shadow.v`, `shadow_nib.v` (`run.sh`, `tb_nib.v`) |

Example, RTL 03 vs 01:

```sh
KEPLER_SEC_DIAG=1 CAP=3600 SC_STEP=8 REF=01 ./run_sec.sh rtl 03 pdr 400 budx50_step8_kf3f1648b
```

The runs also set the `KEPLER_SEC_PDR_DUAL_RAIL_SINGLETON_*_BUDGET` variables
recorded in each `status.txt`.

**Tools:** Kepler-Formal `3f1648b` (main), Release build in `tools/`, which is
not committed; Icarus Verilog.

**Compressed logs:** large `run.log` files are stored as `run.log.xz`.
