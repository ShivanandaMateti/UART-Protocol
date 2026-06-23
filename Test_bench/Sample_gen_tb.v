`timescale 1ns/1ps
`default_nettype none

module Sample_gen_tb;

// inputs 
reg r_clk;
reg reset;
reg restart;

// outputs
wire Sample_tick;

// instantiation

Sample_gen   DUT (
                    .r_clk(r_clk),
                    .reset(reset),
                    .restart(restart),
                    .Sample_tick(Sample_tick)
                );

// clock

initial r_clk = 0;
always #2.5 r_clk  <= ~r_clk;

// tasks
task wait_N;
        input integer n;
        integer count;
        begin
            while(count < n)
            begin
                @(posedge r_clk);
                count <= count + 1;
            end
        end
endtask

task apply_reset;
    begin
        reset = 1;
        wait_N(160);
        reset = 0;
    end
endtask

task assert_restart;
    begin
        restart = 1;
        wait_N(160);
        restart = 0;
    end
endtask

task check_Sample_tick;
    input exp;
    output result;
    reg actual;
    begin
        if(Sample_tick)
            actual <= 1;
        else
            actual <= 0;
        if(exp == actual)
            result <= 1;
        else
            result <= 0;
    end
endtask

// Main test sequence
reg result; // to check the status of sample tick

initial begin

    // initialization
    apply_reset;
    
    $display("\ntest - 1 fair sample_tick check");
    wait_N(4);
    check_Sample_tick(1'b1,result);
    if(result)
        $display("test 1 passed");
    else
        $display("test 1 failed");
    
    $display("\ntest - 2 reset in between");
    fork
        begin
            wait_N(4);
            check_Sample_tick(1'b1,result);
        end
        begin
            wait_N(3);
            apply_reset;
        end
    join
    check_Sample_tick(1'b1,result);
            if(result)
                $display("test 2 failed");
            else
                $display("test 2 passed");

    $display("\ntest - 3 restart in between");
    fork
        begin
            wait_N(4);
            check_Sample_tick(1'b1,result);
        end
        begin
            wait_N(3);
            assert_restart;
        end
    join
    check_Sample_tick(1'b1,result);
            if(result)
                $display("test 2 failed");
            else
                $display("test 2 passed");

    #5000;
    $finish;

end

endmodule



    









