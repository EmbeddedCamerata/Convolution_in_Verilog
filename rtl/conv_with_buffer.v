module conv_with_buffer #(
    parameter I_BIT_WIDTH   = 8,
    parameter O_BIT_WIDTH   = 4*I_BIT_WIDTH,
    parameter I_SIZE        = 5,
    parameter K_CHANNELS    = 3,
    parameter K_SIZE        = 3
)(
    input       clk,
    input       rstn,
    input       conv_en,
    output wire conv_done
);

    wire signed [I_BIT_WIDTH-1:0] input_buf_dout;
    wire input_buf_ren;
    wire input_buf_cs;
    wire [15:0] input_buf_addr;

    wire signed [I_BIT_WIDTH-1:0] weights_buf_dout;
    wire weights_buf_ren;
    wire weights_buf_cs;
    wire [15:0] weights_buf_addr;

    wire signed [4*I_BIT_WIDTH-1:0] result_buf_din;
    wire result_buf_wen;
    wire result_buf_cs;
    wire [15:0] result_buf_addr;

    conv #(
        .I_BIT_WIDTH        (I_BIT_WIDTH),
        .O_BIT_WIDTH        (O_BIT_WIDTH),
        .I_SIZE             (I_SIZE),
        .K_CHANNELS         (K_CHANNELS),
        .K_SIZE             (K_SIZE)
    ) u_conv(
        .clk                (clk),
        .rstn               (rstn),
        .conv_en            (conv_en),
        .conv_done          (conv_done),

        .input_buf_dout     (input_buf_dout),
        .input_buf_ren      (input_buf_ren),
        .input_buf_cs       (input_buf_cs),
        .input_buf_addr     (input_buf_addr),

        .weights_buf_dout   (weights_buf_dout),
        .weights_buf_ren    (weights_buf_ren),
        .weights_buf_cs     (weights_buf_cs),
        .weights_buf_addr   (weights_buf_addr),

        .result_buf_din     (result_buf_din),
        .result_buf_wen     (result_buf_wen),
        .result_buf_cs      (result_buf_cs),
        .result_buf_addr    (result_buf_addr)
    );

    gbuffer #(
        .DATA_WIDTH(I_BIT_WIDTH),
        .ADDR_WIDTH(16)
    ) w_gbuffer(
        .clk    (clk),
        .rstn   (rstn),
        .A      (weights_buf_addr),
        .D      (8'hz),
        .ren    (weights_buf_ren),
        .wen    (1'b1),
        .cs     (weights_buf_cs),
        .Q      (weights_buf_dout)
    );

    gbuffer #(
        .DATA_WIDTH(I_BIT_WIDTH),
        .ADDR_WIDTH(16)
    ) i_gbuffer(
        .clk    (clk),
        .rstn   (rstn),
        .A      (input_buf_addr),
        .D      (8'hz),
        .ren    (input_buf_ren),
        .wen    (1'b1),
        .cs     (input_buf_cs),
        .Q      (input_buf_dout)
    );

    gbuffer #(
        .DATA_WIDTH(O_BIT_WIDTH),
        .ADDR_WIDTH(16)
    ) r_gbuffer(
        .clk    (clk),
        .rstn   (rstn),
        .A      (result_buf_addr),
        .D      (result_buf_din),
        .ren    (1'b1),
        .wen    (result_buf_wen),
        .cs     (result_buf_cs),
        .Q      ()
    );

endmodule