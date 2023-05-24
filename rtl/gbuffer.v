module gbuffer #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 16
)(
    input                           clk,
    input                           rstn,
    input       [ADDR_WIDTH-1:0]    A,
    input       [DATA_WIDTH-1:0]    D,
    input                           ren,
    input                           wen,
    input                           cs,
    output reg  [DATA_WIDTH-1:0]    Q
);

    localparam DEPTH = 2**ADDR_WIDTH;
    integer i;

    reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];

    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            Q <= 0;
            for (i = 0; i < DEPTH; i = i+1)
                mem[i] <= 0;
        end
        else if (~wen & cs) begin
            Q <= 0;
            mem[A] <= D;
        end
        else if (~ren & cs)
            Q <= mem[A];
        else
            Q <= 0;
    end

endmodule