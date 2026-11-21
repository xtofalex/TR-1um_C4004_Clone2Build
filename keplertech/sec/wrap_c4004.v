// SEC wrapper for one Gemini trial's rtl/c4004_core.v (instantiated unchanged).
// The same wrapper is used for every trial, so both SEC sides have the top
//   cpu_top(clk, rst, test, d_in[3:0] -> bus_oe, bus_hiz, bus_d[3:0], sync,
//           cm_rom, cm_ram[3:0]).
// All ten trials have the same c4004_core ports (results/inventory.txt), and
// all reset to phase A1 with the PC taken from buf_l/m/h = 0, so no startup
// alignment is needed (unlike keplertech_demo/sec/wrap_ref.v).
// SRAM128 is sec/sram128_sec.v: no initial contents (X under dual_rail_steady).
module cpu_top (
    input  wire       clk,
    input  wire       rst,
    input  wire       test,
    input  wire [3:0] d_in,
    output wire       bus_oe,
    output wire       bus_hiz,
    output wire [3:0] bus_d,
    output wire       sync,
    output wire       cm_rom,
    output wire [3:0] cm_ram
);
    wire [3:0] d_core;
    wire       test_core;
    wire [2:0] env_ph;
    wire       env_ph_valid;
    wire [3:0] d_out;
    wire       d_oe, d_hiz, sync_raw;

    env_filter u_env (
        .clk(clk), .rst(rst), .d_in(d_in), .test(test), .sync(sync_raw),
        .d_core(d_core), .test_core(test_core), .ph(env_ph), .ph_valid(env_ph_valid)
    );

    c4004_core u_core (
        .clk(clk), .rst(rst), .test(test_core), .d_in(d_core),
        .d_out(d_out), .d_oe(d_oe), .d_hiz(d_hiz),
        .sync(sync_raw), .cm_rom(cm_rom), .cm_ram(cm_ram)
    );

    wire       oe_raw   = d_oe;
    wire       hiz_raw  = d_hiz;
    wire [3:0] dout_raw = d_out;
    assign sync = sync_raw;
`include "observe.vh"
endmodule
