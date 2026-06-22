module Sample_gen (
                    input r_clk,
                    input reset,
                    input restart,
                    output Sample_tick
                  );

reg [2:0] count;
reg Sample_tick_reg;
always@(posedge r_clk,posedge reset)begin
    if(reset || restart)begin
        Sample_tick_reg <= 0;
        count           <= 1;
    end
    else begin
        count       <= count + 3'd1;
        if(count == 3'd4)begin
            Sample_tick_reg <= 1;
            count           <= 1;
        end
        else
            Sample_tick_reg <= 0;
    end
end
assign Sample_tick  = Sample_tick_reg; 


endmodule
