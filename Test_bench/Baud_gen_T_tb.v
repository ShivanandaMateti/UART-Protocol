`timescale 1ms/1ps

module baud_gen_T_test;

reg clk;
reg reset;

wire baud_tick;

baud_gen_T Baudgenarator(
                         .clk(clk),
                         .reset(reset),
                         .baud_tick_T(baud_tick)
);


    // Clock
    initial clk = 0;
    always #0.001302083 clk = ~clk;   // time period of clock = 2.604167us
    #100 $finish;
  
endmodule
