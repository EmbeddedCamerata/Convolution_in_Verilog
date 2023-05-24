module conv_with_buffer_tb;

    localparam I_SIZE = `INPUT_SIZE;    // Define the macro in Makefile
    localparam K_SIZE = `KERNEL_SIZE;   // Define the macro in Makefile
    localparam O_SIZE = I_SIZE - K_SIZE + 1;
    localparam K_CHANNELS = `KERNEL_CH; // Define the macro in Makefile
    localparam O_CHANNELS = K_CHANNELS;
    localparam I_BIT_WIDTH = 8;

    localparam I_NUM = I_SIZE*I_SIZE*K_CHANNELS;
    localparam K_NUM = K_SIZE*K_SIZE*K_CHANNELS;
    localparam O_NUM = O_SIZE*O_SIZE*O_CHANNELS;

    bit clk, rstn;
    logic conv_en;
    logic conv_done;

    conv_with_buffer #(
        .I_BIT_WIDTH    (I_BIT_WIDTH),
        .I_SIZE         (I_SIZE),
        .K_CHANNELS     (K_CHANNELS),
        .K_SIZE         (K_SIZE)
    ) u_conv_with_buffer(.*);

    initial begin
        rstn <= 1'b1;
        conv_en <= 1'b1;

        sys_reset();

        $readmemh("./data/fmap.mem", u_conv_with_buffer.i_gbuffer.mem, 0, I_NUM-1);
        $readmemh("./data/weights.mem", u_conv_with_buffer.w_gbuffer.mem, 0, K_NUM-1);
    end

    initial begin
        wait(conv_done == 1'b1);
        conv_en <= 1'b0;
        #100
        $writememh("./data/results.mem", u_conv_with_buffer.r_gbuffer.mem, 0, O_NUM-1);
        $finish;
    end

    task sys_reset;
        #3 rstn <= 1'b0;
        #7 rstn <= 1'b1;
    endtask

    always #5 clk = ~clk;

    initial begin
        $dumpfile("wave_conv_with_buffer.fst");
        $dumpvars(0, u_conv_with_buffer);
    end

endmodule