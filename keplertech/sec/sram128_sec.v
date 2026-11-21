// SEC copy of rtl/sram128_model.v (SRAM128, 32 x 4-bit macro model).
// Identical behaviour, but WITHOUT the `initial` block that zeroes mem[] and DO:
// contents start unknown, as in silicon. The Gemini trials (01-10) do not clear
// the SRAM after reset, so words never written stay unknown (X) in SEC.
//   - posedge CE with WR = 0: DO <= mem[addr]
//   - posedge CE with WR = 1: mem[addr] <= DIN (DO holds)
module SRAM128 (
    input  wire       CE,
    input  wire       WR,
    input  wire       A0,
    input  wire       A1,
    input  wire       A2,
    input  wire       A3,
    input  wire       A4,
    input  wire [3:0] DIN,
    output reg  [3:0] DO
);
    reg [3:0] mem [0:31];
    wire [4:0] addr = {A4, A3, A2, A1, A0};

    always @(posedge CE) begin
        if (WR) begin
            mem[addr] <= DIN;
        end else begin
            DO <= mem[addr];
        end
    end
endmodule
