module vpe_relu #(
    parameter PSUM_WIDTH=32
)(
    input  logic                        clk     ,
    input  logic                        rst     ,
    input  logic                        relu_enable     ,

    input  logic                        relu_in_valid   ,
    input  logic [PSUM_WIDTH-1      :0] relu_in         ,
    output logic                        relu_out_valid  ,
    output logic [PSUM_WIDTH-1      :0] relu_out
);
    assign relu_out = (relu_enable) ? relu(relu_in): relu_in;
    assign relu_out_valid = relu_in_valid;

    function automatic logic signed [PSUM_WIDTH-1:0] relu(
        input logic signed [PSUM_WIDTH-1:0] val
    );
        logic [PSUM_WIDTH-1:0] sign_extended;
        logic [PSUM_WIDTH-1:0] mask;
        sign_extended = {32{val[31]}}; 
        mask = ~sign_extended;
        return val & mask;
    endfunction
endmodule

