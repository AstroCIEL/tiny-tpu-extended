`timescale 1ns/1ps

module pe
(
    input logic clk,
    input logic rst,

    // West wires of PE
    input logic signed [7:0] pe_input_in, 
    input logic pe_valid_in, 
    input logic pe_switch_in, 

    // North wires of PE
    input logic signed [31:0] pe_psum_in,
    input logic signed [7:0] pe_weight_in,
    input logic pe_valid_w_in,

    // South wires of the PE
    output logic signed [31:0] pe_psum_out,
    output logic signed [7:0] pe_weight_out,

    // East wires of the PE
    output logic signed [7:0] pe_input_out,
    output logic pe_valid_out,
    output logic pe_switch_out,
    output logic pe_valid_w_out
);

    logic signed [31:0] mult_out;
    logic signed [31:0] mac_out;
    logic signed [7:0] weight_reg_active; // foreground register
    logic signed [7:0] weight_reg_inactive; // background register

    int8_mul_int32 mult (
        .ina(pe_input_in),
        .inb(weight_reg_active),
        .out(mult_out)
    );

    int32_add_int32 adder (
        .ina(mult_out),
        .inb(pe_psum_in),
        .out(mac_out),
        .overflow()
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pe_input_out <= 8'b0;
            pe_weight_out <= 8'b0;
            weight_reg_active <= 8'b0;
            weight_reg_inactive <= 8'b0;
            pe_psum_out <= 32'b0;
            pe_valid_out <= 0;
            pe_switch_out <= 0;
            pe_valid_w_out <= 0;
        end 
        else begin
            pe_valid_out <= pe_valid_in;
            pe_switch_out <= pe_switch_in;
            pe_valid_w_out <= pe_valid_w_in;
            
            if (pe_valid_w_in) begin
                weight_reg_inactive <= pe_weight_in;
                pe_weight_out <= pe_weight_in;
            end

            if (pe_valid_in) begin
                pe_input_out <= pe_input_in;
                pe_psum_out <= mac_out;
            end
            else begin
                pe_input_out <= 8'b0;
                pe_psum_out <= 32'b0;
            end

            if (pe_switch_in) begin
                weight_reg_active <= weight_reg_inactive;
            end
        end
    end

endmodule