module mult_add_tb;

    logic signed [8*3*3-1:0] in;
	logic signed [8*3*3-1:0] weights;
	logic signed [16-1:0] convValue;

    mult_add u_mult_add(.*);

    integer x, y;

    initial begin
        in <= {
            8'd1, 8'd2, 8'd3, 8'd4, 8'd5, 8'd6, 8'd7, 8'd8, 8'd9
        };
        weights <= {
            8'd9, 8'd8, 8'd7, 8'd6, 8'd5, 8'd4, 8'd3, 8'd2, 8'd1
        };

        #10
        for (x = 0; x < 3; x = x+1) begin
            for (y = 0; y < 3; y = y+1) begin
                $display("0x%x", u_mult_add.mul33[3*x+y]);
            end
        end
        
        $display("0x%x", convValue);
        $finish;
    end

    initial begin
        $dumpfile("wave_mult_add.fst");
        $dumpvars(0, mult_add_tb);
    end

endmodule