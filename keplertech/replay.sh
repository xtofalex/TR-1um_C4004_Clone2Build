#!/bin/sh
# replay.sh <NN> <kepler run.log> [from_frame] [pos|neg]
#   Converts the counterexample in the log of an `rtl` check (trial 01 vs NN) to
#   sim/build/<run>.memh and replays it in Icarus on both wrapped designs,
#   printing frames >= from_frame with phase/opr/opa, acc/cy/sp and DIFF flags.
set -e
cd "$(dirname "$0")"
n=$1; log=$2; from=${3:-0}; edge=${4:-pos}
sim/prep.sh "$n"
name=$(basename "$(dirname "$log")")
read cyc bad <<EOF
$(python3 sim/cex2memh.py "$log" "sim/build/$name.memh")
EOF
echo "trace: $cyc frames, Kepler reports first bad frame at cycle $bad"
iverilog -g2012 -o "sim/build/replay_$n.vvp" sim/replay.v sim/build/rtl_01_A_for$n.v "sim/build/rtl_${n}_B.v"
vvp -n "sim/build/replay_$n.vvp" +memh="sim/build/$name.memh" +n="$cyc" +from="$from" +edge="$edge" | grep -v '\$finish'
