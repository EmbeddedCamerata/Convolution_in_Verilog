module mult_add #(
    parameter I_BIT_WIDTH   = 8,
    parameter O_BIT_WIDTH   = 32,
    parameter K_SIZE        = 3
)(
    input       signed [I_BIT_WIDTH*K_SIZE*K_SIZE-1:0]  in,
    input       signed [I_BIT_WIDTH*K_SIZE*K_SIZE-1:0]  weights,
    output wire signed [O_BIT_WIDTH-1:0]                convValue
);

    wire signed [O_BIT_WIDTH-1:0] mul[0:K_SIZE*K_SIZE-1];

    // Multiplication
    genvar x, y;
    generate
        for (x = 0; x < K_SIZE; x = x+1) begin: sum_rows        // each row
            for (y = 0; y < K_SIZE; y = y+1) begin: sum_columns // each item in a row
                assign mul[K_SIZE*x+y] = in[I_BIT_WIDTH*(K_SIZE*x+y+1)-1 : I_BIT_WIDTH*(K_SIZE*x+y)] * weights[I_BIT_WIDTH*(K_SIZE*x+y+1)-1 : I_BIT_WIDTH*(K_SIZE*x+y)];
            end
        end
    endgenerate

    // Adder tree
    wire signed [O_BIT_WIDTH-1:0] sums[0:6];

    generate
        // sums[0] to sums[3]
        for (x = 0; x < 4; x = x+1) begin: addertree_nodes0
            assign sums[x] = mul[x*2] + mul[x*2+1];
        end
        // sums[4] to sums[5]
        for (x = 0; x < 2; x = x+1) begin: addertree_nodes1
            assign sums[x+4] = sums[x*2] + sums[x*2+1];
        end
    endgenerate

    assign sums[6] = sums[4] + sums[5];
    assign convValue = sums[6] + mul[8];

endmodule