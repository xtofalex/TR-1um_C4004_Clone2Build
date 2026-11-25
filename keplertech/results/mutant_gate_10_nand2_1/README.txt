Mutant of ../TR-1um_C4004_10/openroad/c4004_core_syn.v: the 1th NAND2 instance replaced by a NOR2 (same pins).
Rebuild: awk -v n=1 '/^ *NAND2 /{c++; if(c==n) sub(/NAND2/,"NOR2")} {print}' c4004_core_syn.v > m1.v
Command: kepler-formal -sv2v -v sec --sec-engine pdr -k 400 --sec-reset-cycles 3 --sec-reset-port rst=1 --design1 cfg/rtlbb_06.v --design2 m1.v --set-as-boundary u_sram u_sram --liberty <trial 10 STDCELL and SRAM128 .lib> (as run_sec.sh gate 10, without --report-skipped-pos and KEPLER_* variables). Expected: a counterexample.
714c714
<   NAND2 _0615_ ( .A(_0103_), .B(_0104_), .Y(_0107_) );
---
>   NOR2 _0615_ ( .A(_0103_), .B(_0104_), .Y(_0107_) );
