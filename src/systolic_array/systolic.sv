`timescale 1ns/1ps

// 16x16 systolic array
module systolic
(
    input logic clk,
    input logic rst,

    // input signals from left side of systolic array
    input logic [7:0] sys_input [15:0],
    input logic sys_valid_in,        // 只给左上角pe

    // input signals from top of systolic array
    input logic [7:0] sys_weight [15:0],
    input logic sys_new_weight,      // 控制最左列，向右侧传递
    input logic sys_switch_in,       // 只给左上角pe

    output logic [31:0] sys_output [15:0],
    output logic sys_valid_out [15:0]
);

    logic [31:0] pe_psum_out [15:0][15:0];
    logic [7:0] pe_weight_out [15:0][15:0];
    logic [7:0] pe_input_out [15:0][15:0];
    logic pe_valid_out [15:0][15:0];
    logic pe_switch_out [15:0][15:0];
    logic pe_valid_w_out [15:0][15:0];
    logic col_new_weight [15:0];

    // 生成16x16 PE阵列
    generate
        for (genvar j = 0; j < 16; j++) begin
            if (j == 0) begin
                assign col_new_weight[j] = sys_new_weight;
            end
            else begin
                assign col_new_weight[j] = col_new_weight[j-1];
            end
            for (genvar i = 0; i < 16; i++) begin
                // 确定每个PE的连接
                logic [7:0] local_input;
                logic local_valid_in;
                logic local_switch_in;
                logic [31:0] local_psum;
                logic [7:0] local_weight;
                logic local_valid_w_in;

                if (i == 0) begin
                    assign local_valid_in = (j == 0) ? sys_valid_in : pe_valid_out[i][j-1];
                    assign local_psum = 32'b0;
                    assign local_weight = sys_weight[j];
                    assign local_valid_w_in = 1'b1;
                    assign local_switch_in = (j == 0) ? sys_switch_in : pe_switch_out[i][j-1];
                end else begin
                    assign local_valid_in = pe_valid_out[i-1][j];
                    assign local_psum = pe_psum_out[i-1][j];
                    assign local_weight = pe_weight_out[i-1][j];
                    assign local_valid_w_in = (col_new_weight[j]) ? 0 : pe_valid_w_out[i-1][j];
                    assign local_switch_in = pe_switch_out[i-1][j];
                end
                
                if (j == 0) begin
                    assign local_input = sys_input[i];
                end else begin
                    assign local_input = pe_input_out[i][j-1];
                end
                
                // PE实例化
                pe pe_inst (
                    .clk(clk),
                    .rst(rst),
                    
                    .pe_input_in(local_input),
                    .pe_valid_in(local_valid_in),
                    .pe_switch_in(local_switch_in),

                    .pe_psum_in(local_psum),
                    .pe_weight_in(local_weight),
                    .pe_valid_w_in(local_valid_w_in),

                    .pe_psum_out(pe_psum_out[i][j]),
                    .pe_weight_out(pe_weight_out[i][j]),

                    .pe_input_out(pe_input_out[i][j]),

                    .pe_valid_out(pe_valid_out[i][j]),
                    .pe_switch_out(pe_switch_out[i][j]),
                    .pe_valid_w_out(pe_valid_w_out[i][j])
                );
                
                // 最后一行的输出连接
                if (i == 15) begin
                    assign sys_output[j] = pe_psum_out[i][j];
                    assign sys_valid_out[j] = pe_valid_out[i][j];
                end
            end
        end
    endgenerate

endmodule