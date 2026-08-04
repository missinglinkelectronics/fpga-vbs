`resetall
`timescale 1 ns / 1 ps
`default_nettype none

`ifndef CLOCK_PERIOD_PS
    `define CLOCK_PERIOD_PS 10
`endif

module tb_top ();

parameter CLOCK_PERIOD_PS = `CLOCK_PERIOD_PS;

reg clk = 0;

initial forever begin
    #(CLOCK_PERIOD_PS / 2.0) clk = ~clk;
end

initial begin
    #1000;

    $display("----------------------------------------");
    $display("INFO: SIMULATION PASSED");
    $display("----------------------------------------");

    $finish;
end

dut dut_inst();

endmodule

`resetall
