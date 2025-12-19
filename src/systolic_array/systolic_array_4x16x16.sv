`timescale 1ns/1ps

// 4x16x16 systolic array
module systolic_array
(
    input logic clk,
    input logic rst,
    input logic sa_enable [3:0],        // SA选通信号，与后续单个array的控制信号结合处理

    // input signals from left side of systolic array
    input logic [7:0] sa_input [15:0],
    input logic sa_valid_in,            // 单个array的左上角接收input，其余pe的接收valid信号由左上角传递

    // input signals from top of systolic array
    input logic [7:0] sa_weight [3:0][15:0], 
    input logic sa_new_weight,          // 单个array接收新一组weight的信号，由左侧开始，向右传递
    input logic sa_switch_in,           // 单个array的左上角权重switch信号，其余pe的由左上角传递

    // output signals to the bottom of systolic array
    output logic [31:0] sa_output [3:0][15:0],
    output logic sa_valid_out [3:0][15:0]    // 单个array对应16列的输出valid信号 // Changed!!!
);

    // logic valid_out [3:0][15:0]; // Changed!!!
    // assign sa_valid_out = valid_out[0]; // Changed!!!

    generate
        for (genvar i = 0; i < 4; i++) begin
            logic sys_rst;
            assign sys_rst = rst || !sa_enable[i];
            systolic systolic_inst (
                .clk(clk),
                .rst(sys_rst),

                .sys_input(sa_input),
                .sys_valid_in(sa_valid_in),

                .sys_weight(sa_weight[i]),
                .sys_new_weight(sa_new_weight),
                .sys_switch_in(sa_switch_in),

                .sys_output(sa_output[i]),
                .sys_valid_out(sa_valid_out[i]) // Changed!!!
            );
        end
    endgenerate

endmodule