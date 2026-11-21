// Environment model shared by both SEC wrappers (instantiated identically in
// wrap_c4004.v and wrap_ref.v). It sits between the top-level d_in/test pins
// and the CPU core, and recovers the 4004 state phase from the design's OWN
// sync output (sync is high in X3, so the next clock is A1).
//
// Always on:
//   d_in and test are registered on the rising edge before reaching the core.
//   Kepler-Formal SEC evaluates negedge state with the same input vector as the
//   preceding posedge, while the C4004 routes d_in combinationally into its
//   negedge-clocked SRAM address (SRC pre-read in M2). Registering the inputs
//   removes that mixed-edge combinational input path; it is a pure 1-clock
//   delay applied identically to both designs.
//
// `STACK_ENV`: restrict programs to stack-legal ones. Tracks subroutine depth
//   (0..3). In M1/M2 of an instruction's FIRST word, a JMS at depth 3 or a BBL
//   at depth 0 is replaced by NOP (00). Two-word instructions: JCN(1), FIM(2,
//   OPA[0]=0), FIN(3, OPA[0]=0), JUN(4), JMS(5), ISZ(7).
//
// `TEST_CONST`: TEST is captured while rst is high and then held, so it is a
//   free but constant value per run.
module env_filter (
    input  wire       clk,
    input  wire       rst,
    input  wire [3:0] d_in,
    input  wire       test,
    input  wire       sync,      // this design's own SYNC (high in X3)
    output wire [3:0] d_core,
    output wire       test_core,
    output reg  [2:0] ph,        // recovered phase: 0=A1 ... 3=M1 4=M2 5=X1 ... 7=X3
    output reg        ph_valid   // 1 once the first SYNC has been seen
);
    // ---- input registers (always) ----
    reg [3:0] d_q;
    reg       t_q;
    always @(posedge clk) begin
        if (rst) begin
            d_q <= 4'd0;
            t_q <= test;
        end else begin
            d_q <= d_in;
`ifdef TEST_CONST
            t_q <= t_q;          // hold the value captured during reset
`else
            t_q <= test;
`endif
        end
    end
`ifdef NO_INPUT_REG
    // EXPERIMENT ONLY (cfg x1_noreg): pass d_in/test straight to the core to
    // demonstrate why the input register above is needed. Not used for results.
    assign test_core = test;
`else
    assign test_core = t_q;
`endif

    // ---- phase recovery from the design's own sync ----
    always @(posedge clk) begin
        if (rst) begin
            ph       <= 3'd0;
            ph_valid <= 1'b0;
        end else if (sync) begin
            ph       <= 3'd0;
            ph_valid <= 1'b1;
        end else begin
            ph       <= ph + 3'd1;
        end
    end

`ifdef STACK_ENV
    wire in_m1 = ph_valid & (ph == 3'd3);
    wire in_m2 = ph_valid & (ph == 3'd4);
    wire in_x3 = ph_valid & (ph == 3'd7);

    reg  [1:0] depth;      // subroutine nesting depth seen by the core
    reg        second;     // current instruction cycle is the 2nd word
    reg        blocked;    // first word of this cycle was replaced by NOP
    reg  [3:0] opr_q;      // OPR as delivered to the core
    reg  [3:0] opa_q;      // OPA as delivered to the core

    wire block_now = in_m1 & ~second &
                     (((d_q == 4'h5) & (depth == 2'd3)) |   // JMS would overflow
                      ((d_q == 4'hC) & (depth == 2'd0)));   // BBL would underflow

    wire two_word = (opr_q == 4'h1) | (opr_q == 4'h4) | (opr_q == 4'h5) |
                    (opr_q == 4'h7) |
                    (((opr_q == 4'h2) | (opr_q == 4'h3)) & ~opa_q[0]);

    always @(posedge clk) begin
        if (rst) begin
            depth   <= 2'd0;
            second  <= 1'b0;
            blocked <= 1'b0;
            opr_q   <= 4'd0;
            opa_q   <= 4'd0;
        end else begin
            if (in_m1 & ~second) begin
                opr_q   <= block_now ? 4'h0 : d_q;
                blocked <= block_now;
            end
            if (in_m2 & ~second)
                opa_q <= blocked ? 4'h0 : d_q;
            if (in_x3) begin
                if (second) begin
                    second <= 1'b0;
                end else begin
                    second <= two_word;
                    if (opr_q == 4'h5) depth <= depth + 2'd1;   // JMS (never at 3)
                    if (opr_q == 4'hC) depth <= depth - 2'd1;   // BBL (never at 0)
                end
            end
        end
    end

    assign d_core = (block_now | (in_m2 & ~second & blocked)) ? 4'h0 : d_q;
`elsif NO_INPUT_REG
    assign d_core = d_in;
`else
    assign d_core = d_q;
`endif
endmodule
