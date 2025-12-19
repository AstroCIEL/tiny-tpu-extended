module vpe_dequanter #(
    parameter PSUM_WIDTH=32,
    parameter O_WIDTH=8
)(
    input  logic                        clk     ,
    input  logic                        rst     ,
    input  logic                        dequant_enable  ,
    input  logic [31                :0] scale_fp32_in   ,
    
    input  logic                        dequant_in_valid,
    input  logic [PSUM_WIDTH-1      :0] dequant_in      ,
    output logic                        dequant_out_valid,
    output logic [O_WIDTH-1         :0] dequant_out
);

    assign dequant_out = (dequant_enable) ? 
                            (mult(dequant_in, scale_fp32_in)) : 
                            (clip(dequant_in));
    assign dequant_out_valid = dequant_in_valid;


    localparam logic signed [O_WIDTH-1:0] MAX_POS_NARROW = (1 <<< (O_WIDTH - 1)) - 1;
    localparam logic signed [O_WIDTH-1:0] MIN_NEG_NARROW = -(1 <<< (O_WIDTH - 1));

    localparam logic signed [PSUM_WIDTH-1:0] MAX_POS =
        {{(PSUM_WIDTH-O_WIDTH){MAX_POS_NARROW[O_WIDTH-1]}}, MAX_POS_NARROW};
    localparam logic signed [PSUM_WIDTH-1:0] MIN_NEG =
        {{(PSUM_WIDTH-O_WIDTH){MIN_NEG_NARROW[O_WIDTH-1]}}, MIN_NEG_NARROW};

    function automatic logic signed [O_WIDTH-1:0] clip(
        input logic signed [PSUM_WIDTH-1:0] in_val
    );
        if (in_val > MAX_POS) begin
            return MAX_POS[O_WIDTH-1:0];
        end
        else if (in_val < MIN_NEG) begin
            return MIN_NEG[O_WIDTH-1:0];
        end
        else begin
            return in_val[O_WIDTH-1:0];
        end
    endfunction

    function automatic logic signed [O_WIDTH-1:0] mult(
        input logic signed [PSUM_WIDTH-1:0] int_val,
        input logic [31:0]                  fp32_bits
    );
        localparam int PROD_WIDTH = PSUM_WIDTH + 24;

        logic fp_sign;
        logic [7:0]  fp_exp;
        logic [23:0] fp_mant;
        
        logic int_sign;
        logic [PSUM_WIDTH-1:0] int_abs; 
        
        logic final_sign;
        logic [PROD_WIDTH-1:0] product; 
        
        logic signed [9:0] shift_amount;
        logic [PROD_WIDTH-1:0] result_abs_large;
        logic rounding_bit;

        fp_sign = fp32_bits[31];
        fp_exp  = fp32_bits[30:23];
        fp_mant = (fp_exp == 0) ? 24'd0 : {1'b1, fp32_bits[22:0]};

        int_sign = int_val[PSUM_WIDTH-1]; 
        int_abs  = int_sign ? -int_val : int_val;

        final_sign = fp_sign ^ int_sign;

        product = int_abs * fp_mant;
        
        shift_amount = 10'd150 - {2'b0, fp_exp};

        if (int_val == 0 || fp_exp == 0) begin
            return '0;
        end
        else if (shift_amount < 0) begin
            result_abs_large = '1; 
        end
        else if (shift_amount >= PROD_WIDTH) begin
            result_abs_large = '0;
        end
        else begin
            if (shift_amount > 0)
                rounding_bit = product[shift_amount - 1];
            else
                rounding_bit = 0;
                
            result_abs_large = (product >> shift_amount) + rounding_bit;
        end

        if (final_sign) begin
            if (result_abs_large > (1'b1 << (O_WIDTH-1))) 
                return MIN_NEG[O_WIDTH-1:0];
            else
                return -$signed(result_abs_large[O_WIDTH-1:0]);
        end 
        else begin
            if (result_abs_large > MAX_POS)
                return MAX_POS[O_WIDTH-1:0];
            else
                return $signed(result_abs_large[O_WIDTH-1:0]);
        end
        
    endfunction

endmodule

