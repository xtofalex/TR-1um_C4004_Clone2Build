#!/bin/sh
# run.sh <AW> <W> <engine> <k> [cap_s]
#   Preprocesses repro/shadow.v into a/b variants (b = with shadow register) for
#   AW address bits and W data bits, runs kepler-formal SEC (same options as the
#   RTL checks: dual_rail_steady default, 3 reset cycles on rst) and writes
#   results/repro_aw<AW>_w<W>_<engine>_k<k>/{run.log,status.txt}.
#   BUG=1 builds b with the shadow register not invalidated on pop (must fail).
#   KEPLER_* environment variables are passed through and recorded.
#   SRC=<file> (default repro/shadow.v) and DEFS="-DX ..." select the reproducer;
#   -DSRAM adds sec/sram128_sec.v. KF=<binary> selects another kepler-formal build; TAG=<t> suffixes the result name.
set -e
cd "$(dirname "$0")/.."
BUGDEF=${BUG:+-DBUG}; aw=$1; w=$2; engine=$3; k=$4; cap=${5:-600}
name=repro_aw${aw}_w${w}${BUG:+_bug}_${engine}_k${k}${TAG:+_$TAG}
out=results/$name; mkdir -p "$out"   # sources written straight into $out (no shared build files)
SRC=${SRC:-repro/shadow.v}; LIBS=""
case " $DEFS " in *" -DSRAM "*) LIBS=sec/sram128_sec.v;; esac
iverilog -E -DAW=$aw -DW=$w $DEFS                  -o "$out/a_aw${aw}_w${w}.v" $SRC $LIBS
iverilog -E -DAW=$aw -DW=$w $DEFS -DSHADOW $BUGDEF -o "$out/b_aw${aw}_w${w}.v" $SRC $LIBS
KF=${KF:-$PWD/tools/kepler-formal/build/src/bin/kepler-formal}
cmd="$KF -sv -v sec --sec-engine $engine -k $k --sec-reset-cycles 3 --sec-reset-port rst=1 --report-skipped-pos --design1 a_aw${aw}_w${w}.v --design2 b_aw${aw}_w${w}.v"
cd "$out"
start=$(date +%s)
if /usr/bin/time -l perl -e 'alarm shift; exec @ARGV' "$cap" $cmd > run.log 2>&1; then rc=0; else rc=$?; fi
end=$(date +%s)
{
  echo "cmd (cwd = results/$name): ${cmd#$KF }" | sed 's|^|kepler-formal |'
  echo "source: $SRC $LIBS defines: $DEFS ${BUGDEF}"
  echo "kepler-formal: $("$KF" --version 2>&1 | grep -E 'version|hash' | tr '\n' ' ')"
  env | grep '^KEPLER_' || true
  echo "wall-clock cap: $cap s"
  if [ $((end-start)) -ge "$cap" ]; then echo "STOPPED by wall-clock cap ($cap s)"; fi
  awk '/real/ && /user/ {printf "exit: %s  wall: %s s  cpu: user %s s, sys %s s\n", rc, $1, $3, $5}' rc=$rc run.log
  awk '/maximum resident/ {printf "peak RSS: %d MB\n", $1/1048576}' run.log
  grep -E "SEC (partially )?proved|SEC verification|counterexample|not equivalent|NOT EQUIVALENT|dual-rail PDR steady-state proof was inconclusive" run.log || true
  grep "steady-state check end" run.log || true
  grep "signal_correspondence" run.log | grep "SEC summary" || true
} > status.txt
cat status.txt
