/*
 * Top module only in Vivado.
 */
module conv_with_bram_top(
    input       clk_in1_p,
    input       clk_in1_n,
    input       rstn,
    output wire conv_done
);

    wire clk_out1;

    conv_with_bram u_conv_with_bram(
        .clk        (clk_out1),
        .rstn       (rstn),
        .conv_en    (1'b1),
        .conv_done  (conv_done)
    );

    clk_wiz_0 sys_clk (
        // Clock out ports
        .clk_out1(clk_out1),    // output clk_out1
        // Status and control signals
        .locked(),              // output locked
        // Clock in ports
        .clk_in1_p(clk_in1_p),  // input clk_in1_p
        .clk_in1_n(clk_in1_n)   // input clk_in1_n
    );

endmodule