#!/bin/sh
# run_sec.sh <check> <NN> <engine> <k> [tag]
#   check = rtl    cfg/rtl_01.v           vs cfg/rtl_<NN>.v          (RTL sign-off, -sv)
#           gate   cfg/rtlbb_<RTL of NN>  vs TR-1um_C4004_<NN>/openroad/c4004_core_syn.v
#           edit   TR-1um_C4004_<NN>/openroad/c4004_core_raw_syn.v vs .../c4004_core_syn.v
#           cross  cfg/rtlbb_01.v         vs TR-1um_C4004_<NN>/openroad/c4004_core_syn.v
#   gate/edit/cross: SRAM128 cut as a black box (--set-as-boundary u_sram u_sram),
#   Liberty = TR-1um_C4004_<NN>/module/STDCELL/tr1um_typ_5v0_25c.lib + .../module/SRAM128/SRAM128.lib.
#   All checks: reset bootstrap of 3 cycles with rst=1, then rst=0.
# Environment: CAP=<seconds> stops kepler-formal after that wall time (SIGALRM,
#   recorded in status.txt); REF=<NN> sets the reference RTL of `rtl` (default 01);
#   KEPLER_* variables (e.g. KEPLER_SEC_DIAG=1) are passed through and recorded;
#   SC_STEP=<n> adds --signal-correspondence-step <n> (clock cycles per induction
#   step of signal correspondence; 8 = one C4004 instruction).
# Output: results/<check>_<NN>_<engine>_k<k>[_tag]/ with run.log (kepler-formal
# stdout+stderr followed by /usr/bin/time -l) and status.txt (command, KEPLER_*
# environment, exit code, wall time, user/sys CPU, peak RSS). Kepler writes its
# miter_log_*.txt and skipped_*.txt to that directory (it is the cwd).
# Paths in status.txt are relative to keplertech/.
set -e
here=$(cd "$(dirname "$0")" && pwd)
KF=${KF:-$here/tools/kepler-formal/build/src/bin/kepler-formal}
check=$1; n=$2; engine=$3; k=$4; tag=${5:-}
rtl_of() { case $1 in 07|08|09|10) echo 06;; *) echo $1;; esac; }   # inventory.txt
T=../TR-1um_C4004_$n
L1=$T/module/STDCELL/tr1um_typ_5v0_25c.lib; L2=$T/module/SRAM128/SRAM128.lib   # identical in all trials
case $check in
  rtl)   fmt=-sv;     d1=cfg/rtl_${REF:-01}.v;      d2=cfg/rtl_$n.v; extra="";;
  gate)  fmt=-sv2v;   d1=cfg/rtlbb_$(rtl_of $n).v;  d2=$T/openroad/c4004_core_syn.v
         extra="--set-as-boundary u_sram u_sram --liberty ../../$L1 ../../$L2";;
  edit)  # raw_syn has escaped scalar ports: compared through sec/raw_syn_top.v
         fmt=-verilog; d1="sec/raw_syn_top.v ../../$T/openroad/c4004_core_raw_syn.v"
         d2=$T/openroad/c4004_core_syn.v
         extra="--verilog_design1_top raw_syn_top --set-as-boundary u_raw/u_sram u_sram --liberty ../../$L1 ../../$L2";;
  cross) fmt=-sv2v;   d1=cfg/rtlbb_01.v;            d2=$T/openroad/c4004_core_syn.v
         extra="--set-as-boundary u_sram u_sram --liberty ../../$L1 ../../$L2";;
  *) echo "unknown check $check" >&2; exit 2;;
esac
name=${check}_${REF:+${REF}vs}${n}_${engine}_k${k}${tag:+_$tag}
out=$here/results/$name
mkdir -p "$out"
# Paths are relative to keplertech/; kepler-formal runs in results/<name>/.
args="$fmt -v sec --sec-engine $engine -k $k --sec-reset-cycles 3 --sec-reset-port rst=1 --report-skipped-pos${SC_STEP:+ --signal-correspondence-step $SC_STEP}"
cmd="$KF $args --design1 ../../$d1 --design2 ../../$d2 $extra"
cd "$out"
{
  echo "cmd (cwd = results/$name): kepler-formal $args --design1 ../../$d1 --design2 ../../$d2 $extra"
  echo "kepler-formal: $("$KF" --version 2>&1 | grep -E 'version|hash' | tr '\n' ' ')"
  env | grep '^KEPLER_' || true
  if [ -n "$CAP" ]; then echo "wall-clock cap: $CAP s"; fi
} > status.txt
start=$(date +%s)
set +e
if [ -n "$CAP" ]; then
  /usr/bin/time -l perl -e 'alarm shift; exec @ARGV' "$CAP" $cmd > run.log 2>&1
else
  /usr/bin/time -l $cmd > run.log 2>&1
fi
rc=$?
set -e
end=$(date +%s)
cpu=$(grep -E '^ *[0-9.,]+ real' run.log | tail -1 | sed 's/,/./g' | awk '{print "user " $3 " s, sys " $5 " s"}')
rss=$(grep 'maximum resident set size' run.log | tail -1 | awk '{printf "%.0f MB", $1/1048576}')
verdict=$(grep -E 'SEC (proved|partially|found|verification|disproved)|counterexample|first bad frame|not equivalent|EQUIVALENT' run.log | grep -v '^\[.*debug' | tail -3 | sed 's/^\[[^]]*\] \[[^]]*\] \[[^]]*\] \[[^]]*\] //')
{
  if [ -n "$CAP" ] && [ $((end-start)) -ge "$CAP" ]; then
    echo "STOPPED by wall-clock cap ($CAP s): result is the depth reached, not a verdict"; fi
  # deepest k-induction base case completed (needs KEPLER_SEC_DIAG=1)
  b=$(grep -o 'k-induction base coi k=[0-9]* first_bad_frame=[0-9]*' run.log | tail -1)
  if [ -n "$b" ]; then echo "deepest base-case query started: $b"; fi
  echo "exit: $rc  wall: $((end-start)) s  cpu: $cpu  peak RSS: $rss"
  echo "$verdict"
  grep -E 'SEC summary: signal_correspondence|^  - .*(inconclusive|skipped)' run.log || true
} >> status.txt
cat status.txt
