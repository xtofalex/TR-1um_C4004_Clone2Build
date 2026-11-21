#!/bin/sh
# gen_cfg.sh: preprocess the SEC inputs into cfg/ (one flat file per design).
#   cfg/rtl_<NN>.v    sec/ wrapper + env_filter + SRAM model (no initial
#                     contents) + TR-1um_C4004_<NN>/rtl/c4004_core.v, for each
#                     distinct RTL version (results/inventory.txt): 01..06
#                     (07..10 are byte-identical to 06).
#   cfg/rtlbb_<NN>.v  TR-1um_C4004_<NN>/rtl/c4004_core.v + black-box SRAM128,
#                     for RTL-vs-netlist checks with --set-as-boundary u_sram u_sram.
# `timescale lines are removed (slang rejects a mix of files with and without one).
# The Gemini files are read, never modified.
set -e
cd "$(dirname "$0")"
mkdir -p cfg
for n in 01 02 03 04 05 06; do
  rtl=../TR-1um_C4004_$n/rtl/c4004_core.v
  iverilog -E -Isec -o /dev/stdout sec/wrap_c4004.v sec/env_filter.v sec/sram128_sec.v "$rtl" \
    | sed '/^[[:space:]]*`timescale/d' > cfg/rtl_$n.v
  iverilog -E -o /dev/stdout "$rtl" sec/sram128_bbox.v \
    | sed '/^[[:space:]]*`timescale/d' > cfg/rtlbb_$n.v
  echo "cfg/rtl_$n.v cfg/rtlbb_$n.v <- $rtl"
done
