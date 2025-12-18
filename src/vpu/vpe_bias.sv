module vpe_bias #(
    parameter PSUM_WIDTH = 32
)(
    input  logic                        clk         ,
    input  logic                        rst         ,
    input  logic                        bias_enable ,

    input  logic                        bias_in_valid   ,
    input  logic [PSUM_WIDTH-1:0]       bias_in         ,
    input  logic [PSUM_WIDTH-1:0]       bias_value      ,
    output logic                        bias_out_valid  ,
    output logic [PSUM_WIDTH-1:0]       bias_out
);

    assign bias_out_valid = bias_in_valid;
    assign bias_out = bias_enable ? add_bias(bias_in, bias_value) : bias_in;

    function automatic logic signed [PSUM_WIDTH-1:0] add_bias(
        input logic signed [PSUM_WIDTH-1:0] base,
        input logic signed [PSUM_WIDTH-1:0] operand
    );
        return base + operand;
    endfunction

endmodule
