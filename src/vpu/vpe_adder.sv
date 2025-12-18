module vpe_adder #(
    parameter I_WIDTH=32,
    parameter PSUM_WIDTH=32
)(
    input  logic                        clk     ,
    input  logic                        rst     ,
    input  logic                        adder_enbale    ,
    input  logic                        adder_sel_psum_bias, // 0:psum， 1: bias
    input  logic [PSUM_WIDTH-1 :0]      bias_in         ,
    input  logic [PSUM_WIDTH-1 :0]      selected_psum_in,

    input  logic                        in_valid        ,
    input  logic [I_WIDTH-1    :0]      in              ,
    output logic                        adder_out_valid ,
    output logic [PSUM_WIDTH-1 :0]      adder_out       
);

    logic [PSUM_WIDTH-1:0]  adder_base;
    assign adder_base = (adder_sel_psum_bias) ? (bias_in) : (selected_psum_in);

    assign adder_out = (adder_enbale) ?
                        add_s32(in, adder_base)
                        : {{(PSUM_WIDTH-I_WIDTH){in[I_WIDTH-1]}}, in};
    assign adder_out_valid = in_valid;

    function automatic logic signed [PSUM_WIDTH-1:0] add_s32(
        input logic signed [I_WIDTH-1:0] in_val,
        input logic signed [PSUM_WIDTH-1:0] base
    );
        return base + in_val;
    endfunction

endmodule

