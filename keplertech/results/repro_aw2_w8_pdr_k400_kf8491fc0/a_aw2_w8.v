// Minimal reproducer for the inconclusive bus_d outputs of RTL 01 vs 02
// (results/rtl_01vs02_pdr_k400_budx50). Not derived from Gemini code; it only
// mimics the structural change between the two trials:
//   SHADOW undefined (like trial 01): the PC is always read from a memory word
//     mem[sp] (a stack of DEPTH words, uninitialized).
//   SHADOW defined (like trial 02): a register `buf` holds a copy of PC+1 and is
//     read instead of the memory while `valid` = 1; it is invalidated by `pop`
//     (return), after which the PC is read from memory again.
// Both write the same values to the same memory words, so `pc` is equal in
// both designs only because of the invariant valid -> buf == mem[sp].
// Parameters (set by run.sh with -D): AW = address bits (DEPTH = 2^AW words),
// W = data bits of the PC.
// BUG variant: valid is not cleared on pop (when -DBUG)
module top (
    input  wire          clk,
    input  wire          rst,
    input  wire          push,       // call: save PC+1, jump to `target`
    input  wire          pop,        // return: resume at the saved PC
    input  wire [8-1:0] target,
    output wire [8-1:0] pc
);
    reg [2-1:0] sp;
    reg [8-1:0]  mem [0:(1<<2)-1];
    reg           init;               // first cycle after reset: PC = 0





    assign pc = init ? {8{1'b0}} : mem[sp];

    wire [2-1:0] sp_up = sp + 1'b1;
    wire [2-1:0] sp_dn = sp - 1'b1;

    always @(posedge clk) begin
        if (rst) begin
            sp   <= 0;
            init <= 1'b1;



        end else begin
            init <= 1'b0;
            if (push) begin
                mem[sp]    <= pc + 1'b1;   // return address in the current slot
                mem[sp_up] <= target;      // new PC in the next slot
                sp         <= sp_up;



            end else if (pop) begin
                sp <= sp_dn;               // resume at mem[sp-1]





            end else begin
                mem[sp] <= pc + 1'b1;      // sequential fetch



            end
        end
    end
endmodule
