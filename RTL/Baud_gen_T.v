//baudrate of transmitter = 9600 bits/s

module baud_gen_T (
    input t_clk,
    input reset,
    output baud_tick_T
);

integer count = 1;
reg baud_tick_T_reg;
initial baud_tick_T_reg = 1'b0;
always @(posedge t_clk,posedge reset) 
begin
    if(reset)
    begin 
        count <= 1;
        baud_tick_T_reg <= 1'b1;
    end
    else if(count==20)     // count = 40 since // time period of clock = 2.604167  // one baud tick of transmitter occurs for every 0.1041667ms
    begin
        count <= 1;
        baud_tick_T_reg <= 1'b1;
    end
    else 
    begin
        count <= count + 1;
        baud_tick_T_reg <= 1'b0;
    end        
end

assign baud_tick_T = baud_tick_T_reg;

endmodule