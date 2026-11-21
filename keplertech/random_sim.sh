#!/bin/sh
# random_sim.sh rtl  <NN> [ncyc] [seeds...]  trial 01 RTL vs trial NN RTL (SEC wrappers)
# random_sim.sh gate <NN> [ncyc] [seeds...]  trial NN RTL vs trial NN syn netlist
# Each seed is run twice: stimulus changing 1 ns after the rising edge, and
# 1 ns after the falling edge. Defaults: 1000000 cycles, seeds 1..5.
# SRAM: sim/sram128_sim.v (zero-initialized, same model on both sides).
set -e
cd "$(dirname "$0")"
mode=$1; n=$2; ncyc=${3:-1000000}; shift 3 2>/dev/null || shift $#
seeds=${*:-"1 2 3 4 5"}
mkdir -p sim/build
rtl_of() { case $1 in 07|08|09|10) echo 06;; *) echo $1;; esac; }
case $mode in
  rtl)
    sim/prep.sh "$n"
    # replace the SEC SRAM model (X contents) by the zero-initialized one, per side
    for s in A B; do
      if [ $s = A ]; then f=sim/build/rtl_01_A_for$n.v; else f=sim/build/rtl_${n}_B.v; fi
      awk '/^module SRAM128_/{skip=1} !skip{print} /^endmodule/{if(skip){skip=0}}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
      sed "s/module SRAM128/module SRAM128_$s/" sim/sram128_sim.v >> "$f"
    done
    iverilog -g2012 -o sim/build/lockstep_$n.vvp sim/tb_lockstep.v sim/build/rtl_01_A_for$n.v sim/build/rtl_${n}_B.v
    vvp_file=sim/build/lockstep_$n.vvp;;
  gate)
    T=../TR-1um_C4004_$n
    sed '/^[[:space:]]*`timescale/d; s/^module c4004_core /module c4004_core_R /' \
        ../TR-1um_C4004_$(rtl_of $n)/rtl/c4004_core.v > sim/build/rtl_R_$n.v
    sed 's/^module c4004_core /module c4004_core_G /' \
        $T/openroad/c4004_core_syn.v > sim/build/syn_G_$n.v
    iverilog -g2012 -o sim/build/rvg_$n.vvp sim/tb_rtl_vs_gate.v sim/sram128_sim.v \
        sim/build/rtl_R_$n.v sim/build/syn_G_$n.v $T/rtl/stdcells_sim.v
    vvp_file=sim/build/rvg_$n.vvp;;
  *) echo "usage: random_sim.sh rtl|gate <NN> [ncyc] [seeds]" >&2; exit 2;;
esac
for s in $seeds; do
  for e in pos neg; do
    vvp -n $vvp_file +seed=$s +ncyc=$ncyc +edge=$e +stop=3 | grep -v '\$finish'
  done
done
