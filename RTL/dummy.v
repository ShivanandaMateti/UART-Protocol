/* RECEIVER */

module UART_RECEIVER(
    input r_clk,
    input rx,
    input reset,
    output [7:0]data_out,
    output done,
    output load
);


receiver     R(
               .rx(rx),
               .reset(reset),
               .r_clk(r_clk),
               .baud_tick_T(baud_tick_T) ,
               .data_out(data_out),
               .done(done),
               .load(load),
               .restart(restart)
);
endmodule

// baudrate = 3906250bps i.e 3.9 MHz
// rx clk period = 5ns
// Sampling rate = 62500000sps i.e 62.5 MHz == 20ns
// so we used a clock divider of 4 to reach 20ns

module Sample_gen (
                    input r_clk,
                    input reset,
                    input restart,
                    output Sample_tick
                  );

reg [2:0] count;
reg Sample_tick_reg;
always@(posedge clk,posedge reset)begin
    if(reset || restart)begin
        Sample_tick <= 0;
        count       <= 0;
    end
    else begin
        count       <= count + 3'd1;
        if(count == 3'd4)begin
            Sample_tick_reg <= 1;
            count           <= 0;
        end
        else
            Sample_tick_reg <= 0;
    end

    assign Sample_tick  = Sample_tick_reg; 
end

endmodule





module receiver(
    input rx,
    input Sample_tick,
    input reset,
    input r_clk,
    output [7:0] data_out,
    output restart,
    output done,
    output load
);
localparam start = 0,
           data = 1,
           parity = 2,
           stop = 3,
           correct = 4,
           error = 5,
           idle = 6,
           SamplingWidth = 16,
           DataWidth = 8;

reg [2:0] present_state;
reg load_reg;
reg p; // flag for detecting parity,start and stop bits at midpoint
reg [7:0] data_temp;
reg [7:0] data_correct;
reg [2:0] count_s = 0; // sampling counter
reg [2:0] data_bit_count = 0;         // data bit counter
initial load_reg = 1'b0;

// state transition logic
// assigning state
always @(posedge r_clk , posedge reset) begin
    if(reset) begin
        present_state <= idle;
        data_correct  <= 8'h00;
        data_temp     <= 8'h00;
        count_s       <= 0;
        data_bit_count<= 0;
    end
    else if(rx==0 && (present_state == idle)) begin
        present_state <= start;
        restart       <= 1'b1;
    end
    else begin
        if(Sample_tick) begin
            case(present_state)

            start : begin
                    load_reg <= 0;
                    if(count_s == SamplingWidth/2)
                    begin
                        count_s      <= count_s + 1;
                        if(in==0)
                            p <= 1;
                        else
                            p <= 0;
                    end
                    else if(count_s < SamplingWidth-1)
                        count_s        <= count_s + 1;
                    else
                        begin
                            count_s        <= 0;
                            if(p)begin
                                present_state  <= data;
                                data_bit_count   <= 0;
                            end
                            else 
                                present_state  <= idle;    
                        end
                    end

            data  : if(count_s == SamplingWidth/2)
                        begin
                            count_s                    <= count_s + 1;
                            data_temp[data_bit_count]  <= in;
                        end
                    else if(count_s < SamplingWidth-1 )
                            count_s        <= count_s +1;
                    else 
                        begin
                            count_s <= 0; 
                            if(data_bit_count == DataWidth-1) 
                                  present_state <= parity;
                            else
                                 data_bit_count <= data_bit_count + 1;
                        end
            parity  :if(count_s == SamplingWidth/2)
                        begin
                            count_s                 <= count_s + 1;
                            if(in == ~(^data_temp))
                                p <= 1;
                            else
                                p <= 0;
                        end
                    else if(count_s<SamplingWidth-1)
                                count_s          <= count_s + 1; 
                    else
                        begin
                                count_s          <= 0;
                                if(p)
                                    present_state    <= stop;
                                else
                                    present_state    <= error;
                        end

            stop    :if(count_s == SamplingWidth/2)
                        begin
                            count_s      <= count_s + 1;
                            if(in)begin
                                p <= 1;
                                data_correct <= data_temp;
                            end
                            else
                                p <= 0;
                        end
                    else if(count_s < SamplingWidth-1)
                                count_s          <= count_s +1; 
                    else
                        begin
                                count_s          <= 0;
                                if(p)
                                    present_state    <= correct;
                                else
                                    present_state    <= error;
                        end

            correct  :if(count_s == SamplingWidth/2)
                        begin
                            count_s       <= count_s + 1;
                            if(in==0)
                                p <= 1;
                            else
                                p <= 0; 
                        end
                        else if(count_s < SamplingWidth-1)
                                count_s        <= count_s +1;
                        else
                            begin
                                count_s        <= 0;
                                if(p)begin
                                    present_state  <= data;
                                    data_bit_count   <= 0;
                                end
                                else
                                    present_state  <= start;
                            end                   

            error : begin
                    load_reg <= 1'b1;
                    if(count_s == SamplingWidth/2)
                    begin
                        count_s     <= count_s + 1;
                        if(in)
                            p <= 1;
                        else
                            p <= 0;
                    end
                    else if(count_s < SamplingWidth-1)
                            count_s          <= count_s +1;
                    else
                        begin
                            count_s          <= 0;
                            if(p)
                                present_state    <= start;
                             else
                                present_state    <= error;
                        end
                    end
                  
            endcase
        end
    end
end


// assigning output

assign done = (present_state == correct);
assign data_out =  data_correct;
assign load =  load_reg;

endmodule


