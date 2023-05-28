module conv_with_bram #(
    parameter I_BIT_WIDTH   = 8,
    parameter I_SIZE        = 24,
    parameter K_CHANNELS    = 16,
    parameter K_SIZE        = 3
)(
    input       clk,
    input       rstn,
    input       conv_en,
    output wire conv_done
);

    wire signed [I_BIT_WIDTH-1:0] input_bram_douta;
    wire input_bram_ena;
    wire [15:0] input_bram_addra;

    wire signed [I_BIT_WIDTH-1:0] weights_bram_douta;
    wire weights_bram_ena;
    wire [15:0] weights_bram_addra;

    wire signed [2*I_BIT_WIDTH-1:0] result_bram_dina;
    wire result_bram_ena;
    wire result_bram_wea;
    wire [15:0] result_bram_addra;

    conv #(
        .I_BIT_WIDTH        (I_BIT_WIDTH),
        .O_BIT_WIDTH        (4*I_BIT_WIDTH),
        .I_SIZE             (I_SIZE),
        .K_CHANNELS         (K_CHANNELS),
        .K_SIZE             (K_SIZE)
    ) u_conv(
        .clk                (clk),
        .rstn               (rstn),
        .conv_en            (conv_en),
        .conv_done          (conv_done),

        .input_bram_douta   (input_bram_douta),
        .input_bram_ena     (input_bram_ena),
        .input_bram_addra   (input_bram_addra),

        .weights_bram_douta (weights_bram_douta),
        .weights_bram_ena   (weights_bram_ena),
        .weights_bram_addra (weights_bram_addra),

        .result_bram_dina   (result_bram_dina),
        .result_bram_ena    (result_bram_ena),
        .result_bram_wea    (result_bram_wea),
        .result_bram_addra  (result_bram_addra)
    );

    weights_blk_mem w_blk_mem (
        .clka   (clk),                  // input wire clka
        .ena    (weights_bram_ena),     // input wire ena
        .wea    (1'b0),                 // input wire [0 : 0] wea
        .addra  (weights_bram_addra),   // input wire [15 : 0] addra
        .dina   (),                     // input wire [15 : 0] dina
        .douta  (weights_bram_douta)    // output wire [15 : 0] douta
    );

    input_blk_mem i_blk_mem (
        .clka   (clk),              // input wire clka
        .ena    (input_bram_ena),   // input wire ena
        .wea    (1'b0),             // input wire [0 : 0] wea
        .addra  (input_bram_addra), // input wire [15 : 0] addra
        .dina   (),                 // input wire [15 : 0] dina
        .douta  (input_bram_douta)  // output wire [15 : 0] douta
    );

    result_blk_mem r_blk_mem (
        .clka   (clk),              // input wire clka
        .ena    (result_bram_ena),  // input wire ena
        .wea    (result_bram_wea),  // input wire [0 : 0] wea
        .addra  (result_bram_addra),// input wire [15 : 0] addra
        .dina   (result_bram_dina), // input wire [15 : 0] dina
        .douta  ()                  // output wire [15 : 0] douta
    );

endmodule