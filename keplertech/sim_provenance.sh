#!/bin/sh
# sim_provenance.sh: which design files the simulation logs and compiled
# simulations stored in the trial folders were built from (read-only).
#   1. stored rtl_sim.log / gate_sim.log: sha1 and the testbench path they print
#   2. every compiled Icarus simulation (*.vvp, sim_rtl, sim_gate, sim_c4004):
#      sha1, the source paths recorded in it, and instance-name fingerprints
#      that exist in only some trials' openroad/c4004_core_syn.v:
#        _1005_         deleted by insert_high_fo_buffers.py from trial 05 on
#        u_clk_buf_r9   trials 01..08     u_clk_buf_r10  trials 02..07
#        u_buf_dhiz     trials 06..10     u_inv_sram_ce  trial 07 only
#   3. the same fingerprints counted in each trial's c4004_core_syn.v
# usage: ./sim_provenance.sh > results/sim_provenance.txt   (from keplertech/)
cd "$(dirname "$0")/.."
fp() { for i in _1005_ u_clk_buf_r9 u_clk_buf_r10 u_buf_dhiz u_inv_sram_ce; do
         printf ' %s=%s' $i $(grep -a -c "$2$i$3" "$1"); done; }
echo "# 1. stored simulation logs"
for f in $(find TR-1um_C4004_* -name 'rtl_sim.log' -o -name 'gate_sim.log' | sort); do
  echo "$f sha1=$(shasum "$f" | cut -c1-10) prints: $(grep -o 'TR-1um_C4004_[0-9]*/[^:]*' "$f" | head -1) | $(grep -E '^(PASS|FAIL)' "$f" | head -1)"
done
echo
echo "# 2. compiled simulations: sources and fingerprints (count of instance names)"
for v in $(find TR-1um_C4004_* \( -name '*.vvp' -o -name sim_rtl -o -name sim_gate -o -name sim_c4004 \) | sort); do
  echo "$v sha1=$(shasum "$v" | cut -c1-10)"
  echo "   sources: $(grep -a -o -E '"[^" ]*\.v"' "$v" | sort -u | tr '\n' ' ')"
  echo "   fingerprints:$(fp "$v" '"' '"')"
done
echo
echo "# 3. fingerprints in each trial's openroad/c4004_core_syn.v"
for t in 01 02 03 04 05 06 07 08 09 10; do
  echo "TR-1um_C4004_$t/openroad/c4004_core_syn.v:$(fp TR-1um_C4004_$t/openroad/c4004_core_syn.v ' ' ' ')"
done
