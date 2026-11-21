// Lockstep random simulation: trial 01 RTL (A) vs trial NN RTL (B), both in
// sec/wrap_c4004.v (module names suffixed by sim/prep.sh), same random d_in/test.
// Outputs compared 1 ns BEFORE every rising edge, i.e. the value present when
// the phase ends; this is when the trials' own ROM model samples the bus
// (TR-1um_C4004_NN/rtl/tb_c4004.v:190, always @(posedge clk)).
// Plusargs: +seed= +ncyc= +edge=pos|neg (stimulus 1 ns after the rising or the
//           falling edge) +stop=<n mismatches printed>
`timescale 1ns/1ps
module tb_lockstep;
    reg clk = 0, rst = 1, test = 0;
    reg [3:0] d_in = 0;
    always #5 clk = ~clk;
    wire       oeA, oeB, hzA, hzB, syA, syB, crA, crB;
    wire [3:0] dA, dB, cmA, cmB;
    cpu_top_A A (.clk(clk), .rst(rst), .test(test), .d_in(d_in), .bus_oe(oeA), .bus_hiz(hzA),
                 .bus_d(dA), .sync(syA), .cm_rom(crA), .cm_ram(cmA));
    cpu_top_B B (.clk(clk), .rst(rst), .test(test), .d_in(d_in), .bus_oe(oeB), .bus_hiz(hzB),
                 .bus_d(dB), .sync(syB), .cm_rom(crB), .cm_ram(cmB));
    wire [11:0] vA = {oeA, hzA, dA, syA, crA, cmA};
    wire [11:0] vB = {oeB, hzB, dB, syB, crB, cmB};
    integer seed, seed0, ncyc, stopn, cyc, mism, first;
    reg [8*8-1:0] edge_s;
    initial begin
        if (!$value$plusargs("seed=%d", seed)) seed = 1; seed0 = seed;
        if (!$value$plusargs("ncyc=%d", ncyc)) ncyc = 100000;
        if (!$value$plusargs("stop=%d", stopn)) stopn = 3;
        if (!$value$plusargs("edge=%s", edge_s)) edge_s = "pos";
        mism = 0; first = -1;
        repeat (3) @(posedge clk); #1 rst = 0;
        for (cyc = 1; cyc <= ncyc; cyc = cyc + 1) begin
            // loop entered 1 ns after a rising edge
            if (edge_s == "neg") #4;                 // -> 1 ns after the falling edge
            d_in = $random(seed); test = $random(seed);
            if (edge_s == "neg") #3; else #8;         // -> 1 ns before the rising edge
            if (vA !== vB) begin
                mism = mism + 1; if (first < 0) first = cyc;
                if (mism <= stopn)
                    $display("DIFF cyc=%0d phase=%0d opr=%h opa=%h | 01 %b | NN %b",
                             cyc, A.u_core.phase, A.u_core.opr, A.u_core.opa, vA, vB);
            end
            @(posedge clk); #1;
        end
        $display("RESULT seed=%0d edge=%0s cycles=%0d mismatch_cycles=%0d first=%0d", seed0, edge_s, ncyc, mism, first);
        $finish;
    end
endmodule
