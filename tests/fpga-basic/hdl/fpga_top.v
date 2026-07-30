`resetall
`timescale 1 ns / 1 ps
`default_nettype none

module fpga_top #(
    parameter EXAMPLE_GENERIC0 = "FALSE",
    parameter EXAMPLE_GENERIC1 = "TRUE"
) (
    input wire [3 : 0] GPIO_DIP_SW,
    output wire [3 : 0] GPIO_LED_LS
);

assign GPIO_LED_LS = GPIO_DIP_SW;

bd_top top ();

endmodule

`resetall
