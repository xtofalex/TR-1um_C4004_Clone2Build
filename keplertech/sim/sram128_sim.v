// SRAM128 model for lockstep simulation only: same behaviour as
// sec/sram128_sec.v, but mem[] and DO start at 0 so that Icarus does not
// propagate X from never-written registers (both sides get the same model, so
// this cannot hide a difference between them; SEC uses the X version).
module SRAM128 (
    input  wire       CE,
    input  wire       WR,
    input  wire       A0, A1, A2, A3, A4,
    input  wire [3:0] DIN,
    output reg  [3:0] DO
);
    reg [3:0] mem [0:31];
    wire [4:0] addr = {A4, A3, A2, A1, A0};
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) mem[i] = 4'd0;
        DO = 4'd0;
    end
    always @(posedge CE) begin
        if (WR) mem[addr] <= DIN;
        else    DO <= mem[addr];
    end
endmodule
