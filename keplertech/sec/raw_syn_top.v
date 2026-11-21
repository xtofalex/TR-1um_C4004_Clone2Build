// Bus-port wrapper around a Yosys netlist (openroad/c4004_core_raw_syn.v),
// which declares its ports as escaped scalars (\d_in[0] ...). kepler-formal
// does not align those with the bus bits d_in[0] of c4004_core_syn.v, so the
// raw netlist is compared through this wrapper (pure wiring, no logic).
// The SRAM boundary on this side is then u_raw/u_sram.
module raw_syn_top (clk, rst, test, d_in, d_out, d_oe, d_hiz, sync, cm_rom, cm_ram);
  input clk;
  input rst;
  input test;
  input [3:0] d_in;
  output [3:0] d_out;
  output d_oe;
  output d_hiz;
  output sync;
  output cm_rom;
  output [3:0] cm_ram;
  c4004_core u_raw (
    .clk(clk), .rst(rst), .test(test),
    .\d_in[0] (d_in[0]), .\d_in[1] (d_in[1]), .\d_in[2] (d_in[2]), .\d_in[3] (d_in[3]),
    .\d_out[0] (d_out[0]), .\d_out[1] (d_out[1]), .\d_out[2] (d_out[2]), .\d_out[3] (d_out[3]),
    .d_oe(d_oe), .d_hiz(d_hiz), .sync(sync), .cm_rom(cm_rom),
    .\cm_ram[0] (cm_ram[0]), .\cm_ram[1] (cm_ram[1]), .\cm_ram[2] (cm_ram[2]), .\cm_ram[3] (cm_ram[3])
  );
endmodule
