// Random lockstep check of repro/shadow_nib.v: a vs b (renamed top_a/top_b).
// Counts phases where both buses are binary-defined and differ.
`timescale 1ns/1ps
module tb;
  reg clk=0, rst=1, push=0, pop=0; reg [11:0] target=0;
  always #5 clk=~clk;
  wire [3:0] ba, bb; wire [2:0] pa, pb;
  top_a A(.clk(clk),.rst(rst),.push(push),.pop(pop),.target(target),.bus(ba),.phase(pa));
  top_b B(.clk(clk),.rst(rst),.push(push),.pop(pop),.target(target),.bus(bb),.phase(pb));
  integer i, seed, diff, defined, first;
  initial begin
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    diff=0; defined=0; first=-1;
    repeat(3) @(posedge clk); #1 rst=0;
    for (i=0;i<200000;i=i+1) begin
      push = ($random(seed) % 8) == 0; pop = ($random(seed) % 6) == 0; target = $random(seed);
      #8;
      if (^ba !== 1'bx && ^bb !== 1'bx) begin defined=defined+1;
        if (ba !== bb) begin diff=diff+1; if (first<0) first=i; end end
      @(posedge clk); #1;
    end
    $display("RESULT seed=%0d cycles=200000 both_defined=%0d diff=%0d first=%0d", seed, defined, diff, first);
    $finish;
  end
endmodule
