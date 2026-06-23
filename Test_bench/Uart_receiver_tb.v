`timescale 1ns/1ps
`default_nettype none

module dummy_tb;

// inputs
reg r_clk;
reg rx;
reg reset;


// outputs 
wire [7:0] data_out;
wire done;
wire load;


// parameters

localparam bittime = 273;


// Instantiation
UART_RECEIVER   DUT (
                        .r_clk(r_clk),
                        .rx(rx),
                        .reset(reset),
                        .data_out(data_out),
                        .done(done),
                        .load(load)
                    );


// getting Sampling tick

wire Sample_tick;

assign Sample_tick = DUT.R_S.Sample_tick;

// clocks

initial r_clk = 0;
always #2.5 r_clk <= ~r_clk; // 5ns timeperiod

// Reference scoreboard

// what ever data is sent serially it will be written in this queue
reg [7:0] ref_queue [0:1023];
integer q_head = 0;
integer q_tail = 0;
integer pass_cnt = 0;
integer fail_cnt = 0;

// initializing scoreboard
integer i;
initial 
        begin
            for(i=0;i<1024;i=i+1)
                ref_queue[i] <= 8'h00;
        end

task push_ref;
        input [7:0] data;
        begin
            ref_queue[q_tail] = data;
            q_tail = q_tail + 1;
        end
endtask

// Main tasks

// making data packet

task frame_data;
        input [7:0] data;
        output reg [10:0] framed_data;
        reg p;
        begin
             p = ~(^data);
             framed_data = {1'b1,p,data,1'b0};

        end
endtask

// making wrong data packets

// 1.wrong parity
task frame_data_p;
        input [7:0] data;
        output reg [10:0] framed_data;
        reg p;
        begin
             p = (^data);
             framed_data = {1'b1,p,data,1'b0};
        end
endtask

// 2.wrong stop bit
task frame_data_s;
        input [7:0] data;
        output reg [10:0] framed_data;
        reg p;
        begin
             p = ~(^data);
             framed_data = {1'b0,p,data,1'b0};
        end
endtask


// sending data serially

task send_data;
        input [10:0] framed_data;
        reg [10:0] temp;
        begin
            temp = framed_data;
            repeat(11)
            begin
                rx      <= temp[0];
                temp    <= {1'b1,temp[10:1]};
                #320;
            end

        end
endtask

// applying reset

task apply_reset;
        begin
            reset  = 1 ;
            repeat(10) @(posedge r_clk);
            reset = 0;
            repeat(5) @(posedge r_clk);
        end
endtask

// Evaluating tasks 

task check_data;
        input [7:0] data_received;
        input [31:0] test_id;
        begin
            if(data_received == ref_queue[q_head])begin
                $display("\nT-%0d PASS! data_received : %0h ,data_sent : %0h",test_id,data_received,ref_queue[q_head]);
                pass_cnt = pass_cnt + 1;
            end
            else begin
                $display("\nT-%0d FAIL! data_received : %0h ,data_sent : %0h",test_id,data_received,ref_queue[q_head]);
                fail_cnt = fail_cnt + 1;
            end
            q_head = q_head + 1;
        end
endtask

// for done signal

reg done_latched;
always @(posedge done or posedge reset) begin
    if (reset) done_latched <= 1'b0;
    else       done_latched <= 1'b1;
end

task check_done;
        input exp;
        input [31:0] test_id;
        input [511:0] msg;
        begin
            $display("T-%0d expected done to be : %0h , Actual status : %0h \n %0s",test_id,exp,done_latched,msg);
            if(exp == done_latched)
                pass_cnt = pass_cnt + 1;
            else
                fail_cnt = fail_cnt + 1;
        end
endtask

// waitng task

task wait_N;
        input integer N;
        integer count;
        begin
            count=0;
            while(count<N)
            begin
                @(posedge r_clk);
                    count = count + 1;
            end
        end
endtask

// main test sequence
reg [10:0] framed_data;
reg [10:0] temp;

initial 
    begin
        rx = 1'b1;
        reset = 0;
        
        $dumpfile("dummy.vcd");
        $dumpvars(0,dummy_tb);

        //reset before starting 
        apply_reset;

        // test - 1 everything correct
        $display("\n test - 1 everything correct !");
        frame_data(8'h12,framed_data);
        push_ref(8'h12);
        done_latched = 1'b0;
        send_data(framed_data);
        #(2*bittime);
        check_data(data_out,1);
        check_done(1'b1,1,"data read correctly");

        // test - 2 data sent correctly but reset in between
        $display("\n test - 2 everything correct but reset in between!");
        frame_data(8'h96,framed_data);
        temp = framed_data;
        done_latched = 1'b0;
        fork
            begin
                done_latched = 0;
                frame_data(8'h22,framed_data);
                send_data(framed_data);
                #(2*bittime);
                check_done(1'b0,2,"data not read correctly due to reset");
            end
            begin
                wait_N(128);
                apply_reset;
            end
        join

        #(2*bittime);
        $display("\n After deasserting reset we send data again");
        frame_data(8'h55,framed_data);
        push_ref(8'h55);
        done_latched = 1'b0;
        send_data(framed_data);
        #(2*bittime);
        check_data(data_out,2);
        check_done(1'b1,2,"data read correctly");


        // test - 3 wrong parity
        $display("\n test - 3 wrong parity bit ");
        frame_data_p(8'h07,framed_data);
        done_latched = 1'b0;
        send_data(framed_data);
        #(2*bittime);
        check_done(1'b0,3,"data not read due to wrong parity");

        //test - 4 - long idle state
        $display("\n test -4 long idle state");
        rx = 1'b1;
        done_latched = 1'b0;
        wait_N(1280);
        check_done(1'b0,7,"No data read during idle");

        // test - 5 data sent with no gap
        $display("\n test - 5 continuous data send");
        //d1
        frame_data(8'h01,framed_data);
        push_ref(8'h01);
        done_latched = 1'b0;
        send_data(framed_data);
        #(2*bittime);
        check_data(data_out,5);
        check_done(1'b1,51,"data read correctly");
        //d2
        frame_data(8'h10,framed_data);
        push_ref(8'h10);
        done_latched = 1'b0;
        send_data(framed_data);
        #(2*bittime);
        check_data(data_out,5);
        check_done(1'b1,52,"data read correctly");
        //d3
        frame_data(8'h00,framed_data);
        push_ref(8'h00);
        done_latched = 1'b0;
        send_data(framed_data);
        #(2*bittime);
        check_data(data_out,5);
        check_done(1'b1,53,"data read correctly");
        //d4
        frame_data(8'hff,framed_data);
        push_ref(8'hff);
        done_latched = 1'b0;
        send_data(framed_data);
        #(2*bittime);
        check_data(data_out,5);
        check_done(1'b1,54,"data read correctly");

        // test-6 no stop bit
        $display("\n Test - 6 Data sent without a stop bit ");
        frame_data_s(8'h21,framed_data);
        done_latched = 1'b0;
        send_data(framed_data);
        #(2*bittime);
        check_done(1'b0,6,"wrong stop bit given");

        // test-7 data patterns
        rx = 1'b1;
        wait_N(640);
        $display("\n Test-7 data sent in serial patterns");
        //d1
        frame_data(8'h55,framed_data);
        push_ref(8'h55);
        done_latched = 1'b0;
        send_data(framed_data);
        #(2*bittime);
        check_data(data_out,7);
        check_done(1'b1,71,"data read correctly");
        //d2
        frame_data(8'haa,framed_data);
        push_ref(8'haa);
        done_latched = 1'b0;
        send_data(framed_data);
        #(2*bittime);
        check_data(data_out,7);
        check_done(1'b1,72,"data read correctly");
        //d3
        frame_data(8'h0f,framed_data);
        push_ref(8'h0f);
        done_latched = 1'b0;
        send_data(framed_data);
        #(2*bittime);
        check_data(data_out,7);
        check_done(1'b1,73,"data read correctly");
        //d4
        frame_data(8'hf0,framed_data);
        push_ref(8'hf0);
        done_latched = 1'b0;
        send_data(framed_data);
        #(2*bittime);
        check_data(data_out,7);
        check_done(1'b1,74,"7->4 data read correctly");

         // test - 8 adding a little buffer to the baudrate 

        $display("\n Test-8 Little buffer in the baudrate ");
        #(300);
        frame_data(8'h07,framed_data);
        push_ref(8'h07);
        done_latched = 1'b0;
        temp = framed_data;
        repeat(11)
        begin
            rx      = temp[0];
            temp
              = {1'b1,temp[10:1]};
            #(324);
        end
        check_data(data_out,8);
        check_done(1'b1,8," data read correctly during buffer also");

        

        // scoreboard display
        $display("\n RESULTS !!!");
        $display("\n Total pass count = %0d , Total fail count = %0d ",pass_cnt,fail_cnt);

        $finish;
    end

// simulation exceed runtime

initial 
    begin
        #50000000000 $display("\n Runtime error !!!");
        $finish;
    end



endmodule

























                    


            
            



