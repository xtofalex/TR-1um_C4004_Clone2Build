// Second reproducer: shadow register vs memory word, closer to RTL 01 vs 02.
// Not derived from Gemini code. Compared with repro/shadow.v it adds:
//   - a 12-bit PC stored as 3 nibbles in 3 memory words {sp, k}, k = 0..2,
//     read one nibble per phase (phases 0..2, like A1..A3) and written back
//     one nibble per phase (phases 3..5); 6 phases per instruction;
//   - with -DSRAM: the memory is SRAM128 (sec/sram128_sec.v): single port,
//     read latch DO and write both on the rising edge of CE = ~clk & en,
//     i.e. on the falling clock edge, as in the trials. Without -DSRAM the
//     memory is an array read combinationally and written on the rising edge.
//   SHADOW undefined (like trial 01): bus nibble k = memory word {sp, k}.
//   SHADOW defined   (like trial 02): bus nibble k = buf[k] while valid = 1,
//     and the memory is not read (CE off) in phases 0..2 while valid = 1.
//   BUG: valid is not cleared on pop.
// Stack: 8 levels (sp 3 bits) x 4 words = 32 words x 4 bits.
module top (
    input  wire       clk,
    input  wire       rst,
    input  wire       push,       // sampled in phase 2: call, new PC = target
    input  wire       pop,        // sampled in phase 2: return to mem[sp-1]
    input  wire [11:0] target,
    output wire [3:0] bus,        // PC nibble in phases 0..2, 0 otherwise
    output wire [2:0] phase
);
    reg [2:0]  ph;
    reg [2:0]  sp;
    reg        init;              // first instruction after reset: PC = 0
    reg [11:0] pc_lat;            // PC collected during phases 0..2
    reg        op_push, op_pop;
    reg [11:0] op_target;
    assign phase = ph;

    wire        rd_ph = (ph <= 3'd2);
    wire        wr_ph = (ph >= 3'd3) && (ph <= 3'd5);
    wire [1:0]  k     = rd_ph ? ph[1:0] : (ph - 3'd3);
    wire [11:0] nxt   = pc_lat + 12'd1;
    // write in phases 3..5: seq -> pc+1 into {sp,k}; push -> target into {sp+1,k}; pop -> none
    wire        wr_en   = wr_ph && !op_pop;
    wire [2:0]  wr_sp   = op_push ? sp + 3'd1 : sp;
    wire [11:0] wr_word = op_push ? op_target : nxt;
    // nibble select written as a mux (an earlier version used w[k*4 +: 4])
    function [3:0] nib(input [11:0] w, input [1:0] i);
        nib = (i == 2'd0) ? w[3:0] : (i == 2'd1) ? w[7:4] : w[11:8];
    endfunction
    wire [3:0]  wr_nib  = nib(wr_word, k);

    reg [11:0] buf_pc;
    reg        valid;
    wire       rd_en = rd_ph && !valid && !init;



    wire [4:0] addr = rd_ph ? {sp, k} : {wr_sp, k};
    wire [3:0] rd_data;


    wire ce = ~clk & (rd_en | wr_en);
    SRAM128 u_sram (.CE(ce), .WR(wr_en), .A0(addr[0]), .A1(addr[1]), .A2(addr[2]),
                    .A3(addr[3]), .A4(addr[4]), .DIN(wr_nib), .DO(rd_data));







    wire [3:0] pc_nib = init ? 4'd0 : (valid ? nib(buf_pc, k) : rd_data);



    assign bus = rd_ph ? pc_nib : 4'd0;

    always @(posedge clk) begin
        if (rst) begin
            ph <= 3'd0; sp <= 3'd0; init <= 1'b1;
            op_push <= 1'b0; op_pop <= 1'b0;
            // reset values for op_target/pc_lat/buf_pc: only matter inside the reset
            // window, but without them kepler-formal (fd24770 and 8491fc0) skips the
            // bus outputs ("structured memory dependency ... WDATA ... no drivers")
            op_target <= 12'd0; pc_lat <= 12'd0;

            valid <= 1'b0; buf_pc <= 12'd0;

        end else begin
            ph <= (ph == 3'd5) ? 3'd0 : ph + 3'd1;
            if (rd_ph) case (k)
                2'd0: pc_lat[3:0]  <= pc_nib;
                2'd1: pc_lat[7:4]  <= pc_nib;
                default: pc_lat[11:8] <= pc_nib;
            endcase
            if (ph == 3'd2) begin
                op_push <= push; op_pop <= pop & ~push; op_target <= target;
            end
            if (ph == 3'd5) begin
                init <= 1'b0;
                if (op_push)     sp <= sp + 3'd1;
                else if (op_pop) sp <= sp - 3'd1;

                if (op_push)     begin buf_pc <= op_target; valid <= 1'b1; end



                else             begin buf_pc <= nxt; valid <= 1'b1; end

            end
        end
    end
endmodule
// SEC copy of rtl/sram128_model.v (SRAM128, 32 x 4-bit macro model).
// Identical behaviour, but WITHOUT the `initial` block that zeroes mem[] and DO:
// contents start unknown, as in silicon. The C4004 clears all 32 words itself
// during its post-reset init sequence, so nothing may rely on initial zeros.
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
