// Lockstep random simulation: trial NN rtl/c4004_core.v (R) vs trial NN
// openroad/c4004_core_syn.v (G), cell models from the trial's rtl/stdcells_sim.v,
// one SRAM128 model per side (sim/sram128_sim.v). Same random d_in/test.
// Compares the 11 core pins 1 ns before every rising edge (end of the phase,
// when tb_c4004.v samples the bus) and the 11 SRAM input
// pins (CE, WR, A4..A0, DIN) 1 ns after every falling edge (CE is high then).
// Plusargs: +seed= +ncyc= +edge=pos|neg +stop=
`timescale 1ns/1ps
module tb_rtl_vs_gate;
    reg clk = 0, rst = 1, test = 0;
    reg [3:0] d_in = 0;
    always #25 clk = ~clk;
    wire [3:0] dR, dG, cmR, cmG;
    wire oeR, oeG, hzR, hzG, syR, syG, crR, crG;
    c4004_core_R R (.clk(clk), .rst(rst), .test(test), .d_in(d_in), .d_out(dR), .d_oe(oeR), .d_hiz(hzR), .sync(syR), .cm_rom(crR), .cm_ram(cmR));
    c4004_core_G G (.clk(clk), .rst(rst), .test(test), .d_in(d_in), .d_out(dG), .d_oe(oeG), .d_hiz(hzG), .sync(syG), .cm_rom(crG), .cm_ram(cmG));
    // d_out is compared only while d_oe = 1 (c4004_top drives D only then)
    wire [11:0] pR = {oeR, hzR, oeR ? dR : 4'd0, syR, crR, cmR};
    wire [11:0] pG = {oeG, hzG, oeG ? dG : 4'd0, syG, crG, cmG};
    wire [10:0] sR = {R.u_sram.CE, R.u_sram.WR, R.u_sram.A4, R.u_sram.A3, R.u_sram.A2, R.u_sram.A1, R.u_sram.A0, R.u_sram.DIN};
    wire [10:0] sG = {G.u_sram.CE, G.u_sram.WR, G.u_sram.A4, G.u_sram.A3, G.u_sram.A2, G.u_sram.A1, G.u_sram.A0, G.u_sram.DIN};
    integer seed, seed0, ncyc, stopn, cyc, pm, sm, nprint;
    reg [8*8-1:0] edge_s;
    initial begin
        if (!$value$plusargs("seed=%d", seed)) seed = 1; seed0 = seed;
        if (!$value$plusargs("ncyc=%d", ncyc)) ncyc = 100000;
        if (!$value$plusargs("stop=%d", stopn)) stopn = 5;
        if (!$value$plusargs("edge=%s", edge_s)) edge_s = "pos";
        pm = 0; sm = 0; nprint = 0;
        repeat (3) @(posedge clk); #1 rst = 0;
        for (cyc = 1; cyc <= ncyc; cyc = cyc + 1) begin
            // loop entered 1 ns after a rising edge
            if (edge_s == "neg") #24;                // -> 1 ns after the falling edge
            d_in = $random(seed); test = $random(seed);
            if (edge_s == "pos") #24;                // -> 1 ns after the falling edge
            // SRAM interface: compared only when either side enables the SRAM
            if ((sR[10] | sG[10]) && sR !== sG) begin sm = sm + 1; if (nprint < stopn) begin nprint = nprint + 1;
                $display("SRAM-DIFF cyc=%0d phase=%0d | RTL ce/wr/a/din=%b | GATE=%b", cyc, R.phase, sR, sG); end end
            #23;                                     // -> 1 ns before the rising edge
            if (pR !== pG) begin pm = pm + 1; if (nprint < stopn) begin nprint = nprint + 1;
                $display("PIN-DIFF  cyc=%0d phase=%0d opr=%h opa=%h | RTL %b | GATE %b", cyc, R.phase, R.opr, R.opa, pR, pG); end end
            @(posedge clk); #1;
        end
        $display("RESULT seed=%0d edge=%0s cycles=%0d pin_mismatch_cycles=%0d sram_if_mismatch_cycles=%0d", seed0, edge_s, ncyc, pm, sm);
        $finish;
    end
endmodule
