#!/bin/sh
# prep.sh <NN>: copy cfg/rtl_01.v and cfg/rtl_<NN>.v into sim/build/ with every
# module name suffixed (_A = trial 01, _B = trial NN) so both fit in one simulation.
set -e
cd "$(dirname "$0")/.."
n=$1; mkdir -p sim/build
re='[[:<:]](cpu_top|env_filter|c4004_core|SRAM128)[[:>:]]'
sed -E "s/$re/\\1_A/g" cfg/rtl_01.v    > sim/build/rtl_01_A_for$n.v
sed -E "s/$re/\\1_B/g" cfg/rtl_$n.v    > sim/build/rtl_${n}_B.v
