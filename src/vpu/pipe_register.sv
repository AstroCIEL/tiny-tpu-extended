module pipe_register #(
    parameter WIDTH=32
)(
    input  logic                        clk     ,
    input  logic                        rst     ,
    input  logic                        in_vld  ,
    input  logic [WIDTH-1           :0] in      ,
    output logic                        out_vld ,
    output logic [WIDTH-1           :0] out
);
    logic [WIDTH-1:0] data_reg;
    logic vld_reg;

    always@(posedge clk or posedge rst) begin
        if(rst) begin
            data_reg <= 'b0;
            vld_reg  <= 1'b0;
        end
        else begin
            if(in_vld) begin
                data_reg <= in;
                vld_reg  <= 1'b1;
            end
            else begin
                data_reg <= 'b0;
                vld_reg  <= 1'b0;
            end
        end
    end

    assign out_vld = vld_reg;
    assign out = data_reg;
endmodule

