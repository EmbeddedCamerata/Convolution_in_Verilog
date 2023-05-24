module conv #(
    parameter I_BIT_WIDTH = 8,
    parameter I_SIZE = 5,
    parameter K_CHANNELS = 3,
    parameter K_SIZE = 3
)(
    input                                   clk,
    input                                   rstn,
    input                                   conv_en,

`ifdef BRAM_MODE
    // Interface to input bram
    input       signed  [I_BIT_WIDTH-1:0]   input_bram_douta,
    output reg                              input_bram_ena,
    output reg          [14:0]              input_bram_addra,

    // Interface to weight bram
    input       signed  [I_BIT_WIDTH-1:0]   weights_bram_douta,
    output reg                              weights_bram_ena,
    output reg          [I_BIT_WIDTH-1:0]   weights_bram_addra,

    // Interface to result bram
    output reg                              result_bram_ena,
    output reg                              result_bram_wea,
    output reg          [12:0]              result_bram_addra,
    output reg  signed  [2*I_BIT_WIDTH-1:0] result_bram_dina,
`else
    input       signed  [I_BIT_WIDTH-1:0]   input_buf_dout,
    output reg                              input_buf_ren,
    output reg                              input_buf_cs,
    output reg          [15:0]              input_buf_addr,

    input       signed  [I_BIT_WIDTH-1:0]   weights_buf_dout,
    output reg                              weights_buf_ren,
    output reg                              weights_buf_cs,
    output reg          [15:0]              weights_buf_addr,

    output reg                              result_buf_wen,
    output reg                              result_buf_cs,
    output reg          [15:0]              result_buf_addr,
    output reg  signed  [2*I_BIT_WIDTH-1:0] result_buf_din,
`endif
    output reg                              conv_done
);

    localparam O_SIZE = I_SIZE - K_SIZE + 1;
    localparam O_CHANNELS = K_CHANNELS;

    integer k_ch = 0,   // 遍历权重的通道索引
            i_ch = 0,   // 遍历输入FM的通道索引
            o_ch = 0,   // 遍历输出FM的通道索引
            row = 0,    // 遍历一个通道的输出FM图，row
            column = 0, // 遍历一个通道的输出FM图，col
            count = 0;  // 遍历每次进行运算的数

    integer j;

    reg signed [I_BIT_WIDTH*K_SIZE*K_SIZE-1:0] inputs[0:K_CHANNELS-1];
    reg signed [I_BIT_WIDTH*K_SIZE*K_SIZE-1:0] weights[0:K_CHANNELS-1];
    wire signed [2*I_BIT_WIDTH-1:0] dout[0:K_CHANNELS-1];
    reg signed [2*I_BIT_WIDTH-1:0] result[0:K_CHANNELS-1];

    genvar i;
    generate
        for (i = 0; i < K_CHANNELS; i=i+1) begin: Gen_PE_array
            mult_add #(
                .I_BIT_WIDTH(I_BIT_WIDTH),
                .K_SIZE(K_SIZE),
                .O_BIT_WIDTH(2*I_BIT_WIDTH)
            ) u_mult_add (
                .in         (inputs[i]),
                .weights    (weights[i]),
                .convValue  (dout[i])
            );
        end
    endgenerate

    reg [5:0] cstate, nstate;

    integer data_begin = 0,
            circle = 0;

    localparam conv_weights_base = 0;
    localparam conv_input_base = 0;
    localparam conv_result_base = 0;

    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            cstate <= S_IDLE;
        else
            cstate <= nstate;
    end

    parameter S_IDLE          = 6'b000001,
              S_LOAD_WEIGHTS  = 6'b000010,
              S_CHECK         = 6'b000100,
              S_LOAD_DATA     = 6'b001000,
              S_CONVOLUTE     = 6'b010000,
              S_STORE_RESULT  = 6'b100000;

    always @(*) begin
        case (cstate)
            S_IDLE: nstate = S_LOAD_WEIGHTS;
            S_LOAD_WEIGHTS: if (k_ch >= K_CHANNELS) nstate = S_CHECK;

            S_CHECK: begin
                if (row == O_SIZE)
                    nstate = S_IDLE;
                else
                    nstate = S_LOAD_DATA;
            end

            S_LOAD_DATA: if (i_ch >= K_CHANNELS) nstate = S_CONVOLUTE;
            S_CONVOLUTE: nstate = S_STORE_RESULT;
            S_STORE_RESULT: if (o_ch >= O_CHANNELS) nstate = S_CHECK;

            default: nstate = S_IDLE;
        endcase
    end

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
`ifdef BRAM_MODE
            weights_bram_ena <= 1'b0;
            weights_bram_addra <= 0;

            input_bram_ena <= 1'b0;
            input_bram_addra <= 0;

            result_bram_ena <= 1'b0;
            result_bram_wea <= 1'b0;
            result_bram_addra <= 0;
            result_bram_dina <= 0;
`else
            input_buf_cs <= 1'b0;
            input_buf_ren <= 1'b1;
            input_buf_addr <= 0;

            weights_buf_cs <= 1'b0;
            weights_buf_ren <= 1'b1;
            weights_buf_addr <= 0;

            result_buf_cs <= 1'b0;
            result_buf_wen <= 1'b1;
            result_buf_addr <= 0;
            result_buf_din <= 0;
`endif

            k_ch <= 0;      // 遍历权重的通道
            i_ch <= 0;      // 遍历输入FM的通道
            o_ch <= 0;      // 遍历result的通道
            row <= 0;       // 遍历输出特征图的row
            column <= 0;    // 遍历输出特征图的col
            count <= 0;     // 遍历一个3*3内部的权重或输入数据
            circle <= 0;
            data_begin = 0;

            for (j = 0; j < K_CHANNELS; j=j+1) begin
                result[j] <= 0;
                inputs[j] <= 0;
                weights[j] <= 0;
            end

            conv_done <= 1'b0;
        end
        else if (conv_en) begin
            case (cstate)
                S_IDLE: begin
                    k_ch <= 0;
                    i_ch <= 0;
                    o_ch <= 0;
                    row <= 0;
                    column <= 0;
                    count <= 0;
                    circle <= 0;
                    data_begin = 0;

                    for (j = 0; j < K_CHANNELS; j=j+1) begin
                        result[j] <= 0;
                        inputs[j] <= 0;
                        weights[j] <= 0;
                    end
                    conv_done <= 1'b0;
                end

                S_LOAD_WEIGHTS: begin
                    if (k_ch < K_CHANNELS) begin
                        if (count < K_SIZE*K_SIZE) begin
                            if (circle == 0) begin
`ifdef BRAM_MODE
                                weights_bram_ena <= 1'b1;
                                weights_bram_addra <= conv_weights_base + k_ch * (K_SIZE*K_SIZE) + count;
`else
                                weights_buf_cs <= 1'b1;
                                weights_buf_ren <= 1'b0;
                                // Get weight channel #k_ch
                                weights_buf_addr <= conv_weights_base + k_ch * (K_SIZE*K_SIZE) + count;
`endif
                                circle <= circle + 1;
                            end
                            else if (circle == 2) begin
                                data_begin = I_BIT_WIDTH * (K_SIZE*K_SIZE - count) - 1;
`ifdef BRAM_MODE
                                weights[k_ch][data_begin-:I_BIT_WIDTH] <= weights_bram_douta;
`else
                                weights[k_ch][data_begin-:I_BIT_WIDTH] <= weights_buf_dout;
`endif
                                count <= count + 1;
                                circle <= 0;
                            end
                            else begin
                                circle <= circle + 1;
                            end
                        end
                        else begin
                            circle <= 0;
                            count <= 0;
                            k_ch <= k_ch + 1;
                        end
                    end
                    else begin
`ifdef BRAM_MODE
                        weights_bram_ena <= 1'b0;
`else
                        weights_buf_cs <= 1'b0;
                        weights_buf_ren <= 1'b1;
`endif
                        k_ch <= 1'b0;
                    end
                end

                S_CHECK: begin
                    if (row == O_SIZE) begin
`ifdef BRAM_MODE
                        weights_bram_ena <= 1'b0;
                        input_bram_ena <= 1'b0;
                        result_bram_ena <= 1'b0;
                        result_bram_wea <= 1'b0;
`else
                        input_buf_cs <= 1'b0;
                        input_buf_ren <= 1'b1;

                        weights_buf_cs <= 1'b0;
                        weights_buf_ren <= 1'b1;

                        result_buf_cs <= 1'b0;
                        result_buf_wen <= 1'b1;
`endif
                        conv_done <= 1'b1;
                    end
                    else begin
                        circle <= 0;
                        count <= 0;

                        for (j = 0; j < O_CHANNELS; j=j+1) begin
                            result[j] <= 0;
                        end
                    end
                end

                S_LOAD_DATA: begin
                    if (i_ch < K_CHANNELS) begin
                        // 根据卷积核所在位置，将其下对应数据取至PE
                        // 当前count < 卷积大小，直到count == 卷积核大小，进入下一状态
                        if (count < K_SIZE*K_SIZE) begin
                            if (circle == 0) begin
                                // 基地址 + 当前FM通道*input size**2 + (row + count / fm大小) * 卷积核宽 + col + count % fm大小
`ifdef BRAM_MODE
                                input_bram_ena <= 1'b1;
                                input_bram_addra <= conv_input_base + i_ch * (I_SIZE*I_SIZE) + (row + count / K_SIZE) * I_SIZE + column + count % K_SIZE;
`else
                                input_buf_cs <= 1'b1;
                                input_buf_ren <= 1'b0;
                                input_buf_addr <= conv_input_base + i_ch * (I_SIZE*I_SIZE) + (row + count / K_SIZE) * I_SIZE + column + count % K_SIZE;
`endif
                                circle <= circle + 1'b1;
                            end
                            else if (circle == 2) begin
                                data_begin = I_BIT_WIDTH * (K_SIZE*K_SIZE - count) - 1;
`ifdef BRAM_MODE
                                inputs[i_ch][data_begin-:I_BIT_WIDTH] <= input_bram_douta;
`else
                                inputs[i_ch][data_begin-:I_BIT_WIDTH] <= input_buf_dout;
`endif
                                count <= count + 1;
                                circle <= 0;
                            end
                            else begin
                                circle <= circle + 1;
                            end
                        end
                        else begin
                            circle <= 0;
                            count <= 0;
                            i_ch <= i_ch + 1;
                        end
                    end
                    else begin
`ifdef BRAM_MODE
                        input_bram_ena <= 1'b0;
`else
                        input_buf_cs <= 1'b0;
                        input_buf_ren <= 1'b1;
`endif
                        i_ch <= 1'b0;
                    end
                end

                S_CONVOLUTE: begin
                    for (j = 0; j < K_CHANNELS; j=j+1)
                        result[j] <= dout[j];
                end

                S_STORE_RESULT: begin
                    if (o_ch < O_CHANNELS) begin
                        if (circle == 0) begin
`ifdef BRAM_MODE
                            result_bram_ena <= 1'b1;
                            result_bram_wea <= 1'b1;
                            result_bram_addra <= conv_result_base + o_ch * (O_SIZE*O_SIZE) + row * O_SIZE + column;
                            result_bram_dina <= result[o_ch];
`else
                            result_buf_cs <= 1'b1;
                            result_buf_wen <= 1'b0;
                            result_buf_addr <= conv_result_base + o_ch * (O_SIZE*O_SIZE) + row * O_SIZE + column;
                            result_buf_din <= result[o_ch];
`endif
                            circle <= circle + 1;
                        end
                        else if (circle == 2) begin
`ifdef BRAM_MODE
                            result_bram_ena <= 1'b0;
                            result_bram_wea <= 1'b0;
`else
                            result_buf_cs <= 1'b0;
                            result_buf_wen <= 1'b1;
`endif
                            circle <= 0;
                            o_ch <= o_ch + 1;
                        end
                        else begin
                            circle <= circle + 1;
                        end
                    end
                    else begin
`ifdef BRAM_MODE
                        result_bram_ena <= 1'b0;
                        result_bram_wea <= 1'b0;
`else
                        result_buf_cs <= 1'b0;
                        result_buf_wen <= 1'b1;
`endif
                        o_ch <= 1'b0;

                        if (column == O_SIZE - 1) begin
                            row <= (row + 1);
                        end
                        column <= (column + 1) % O_SIZE;
                    end
                end

                default: begin
`ifdef BRAM_MODE
                    weights_bram_ena <= 1'b0;
                    result_bram_ena <= 1'b0;
                    result_bram_wea <= 1'b0;
                    input_bram_ena <= 1'b0;
`else
                    input_buf_cs <= 1'b0;
                    input_buf_ren <= 1'b1;

                    weights_buf_cs <= 1'b0;
                    weights_buf_ren <= 1'b1;

                    result_buf_cs <= 1'b0;
                    result_buf_wen <= 1'b1;
`endif
                    k_ch <= 0;
                    i_ch <= 0;
                    o_ch <= 0;
                    row <= 0;
                    column <= 0;

                    for (j = 0; j < K_CHANNELS; j=j+1) begin
                        result[j] <= 0;
                        inputs[j] <= 0;
                        weights[j] <= 0;
                    end

                    conv_done <= 1'b0;
                end
            endcase
        end
        else begin

        end
    end

endmodule