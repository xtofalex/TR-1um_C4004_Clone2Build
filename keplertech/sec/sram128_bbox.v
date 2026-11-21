// Black-box SRAM128 (ports only) for RTL-vs-gate SEC with --set-as-boundary
// u_sram u_sram: the SRAM's inputs become observed outputs and DO[3:0] becomes a
// shared free input on both sides, so SEC proves the surrounding logic only.
module SRAM128 (input CE, input WR, input A0, input A1, input A2, input A3, input A4,
                input [3:0] DIN, output [3:0] DO);
endmodule
