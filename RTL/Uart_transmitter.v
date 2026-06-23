/* TRANSMITTER */

module UART_TRANSMITTER(
    input clk,
    input reset,
    input send,
    input load,
    input [7:0] data_in,
    output Transmitter,
    output busy
);
wire baud_tick_T;
wire [10:0] packet;
baud_gen_T B_T(
                .clk(clk),
                .reset(reset),
                .baud_tick_T(baud_tick_T)
);

packetMaker P_T(
                .data_in(data_in),
                .packet(packet)
);

transmitter T(
            .clk(clk),
            .baud_tick_T(baud_tick_T),
            .reset(reset),
            .send(send),
            .load(load),
            .packet(packet),
            .Transmitter(Transmitter),
            .busy(busy)
);
endmodule

//baudrate of transmitter = 9600 bits/s

module baud_gen_T (
    input clk,
    input reset,
    output baud_tick_T
);

integer count = 1;
reg baud_tick_T_reg;
initial baud_tick_T_reg = 1'b0;
always @(posedge clk,posedge reset) 
begin
    if(reset)
    begin 
        count <= 1;
        baud_tick_T_reg <= 1'b1;
    end
    else if(count==40)     // count = 40 since // time period of clock = 2.604167  // one baud tick of transmitter occurs for every 0.1041667ms
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

module packetMaker(
            
            input [7:0]   data_in,
            output [10:0] packet
);

wire p ;
assign p = ~(^data_in);
// packet making 
assign packet = {1'b1,p,data_in[7:0],1'b0};

endmodule

module transmitter
(

input clk,
input baud_tick_T,
input send,
input reset,
input load,
input [10:0] packet,
output Transmitter,
output busy

);



reg tx; // shows the output of transmitter
reg [10:0] packet_temp;        // to shift data and transmit
reg [10:0] packet_load_ready ; // for storing data to resend if data sent isn't correct 
reg [3:0] b ;         // for counting no of bits transmitted
reg transmitting;  // can be used to check if transmitting

initial 
begin 
    b =4'd0 ; 
    transmitting = 1'b0;     // initializing them to start transmission 
    tx = 1'b1;                // initially transmitter is in idle state 
end  
       
 
always @(posedge clk,posedge reset)
begin
    if(reset)
    begin
        tx           <= 1'b1;
        b            <= 0;
        packet_temp  <= 11'h7ff;
        transmitting <= 1'b0;
    end
    else if(load)
    begin
        packet_temp   <=  packet_load_ready;
        transmitting  <=  1'b1;
    end
    else if (send && ~transmitting)
    begin
            packet_temp       <= packet;
            packet_load_ready <= packet;
            transmitting      <= 1'b1;
    end
    else 
    begin
        if(baud_tick_T && transmitting )
            begin
                tx                 <=  packet_temp[0];
                packet_temp        <=  {1'b1,packet_temp[10:1]};
                if(b==4'd10)
                begin
                    b              <=    4'd0;
                    transmitting   <=    1'b0;
                end
                else
                b                  <=  b + 4'd1;   
            end
    end
end


assign Transmitter = tx;
assign busy = ((send && ~transmitting) || transmitting);


endmodule