module int8_mul_int32 (
    input  wire signed [7:0]  ina,      // signed int8
    input  wire signed [7:0]  inb,      // signed int8  
    output wire signed [31:0] out      // signed int32 result
);
    // 有符号乘法：直接使用 * 运算符，Verilog 会自动进行符号扩展
    wire signed [15:0] product_16bit = ina * inb;
    // 将 16 位结果符号扩展到 32 位
    assign out = { {16{product_16bit[15]}}, product_16bit };
endmodule

module int32_add_int32 (
    input  wire signed [31:0] ina,      // signed int32
    input  wire signed [31:0] inb,      // signed int32
    output wire signed [31:0] out,      // signed int32 result
    output wire               overflow  // overflow flag
);
    // 有符号加法
    wire signed [31:0] sum = ina + inb;
    wire overflow_detect = 
        (~ina[31] & ~inb[31] &  sum[31]) |  // 正 + 正 = 负（上溢）
        ( ina[31] &  inb[31] & ~sum[31]);   // 负 + 负 = 正（下溢）
    assign out = sum;
    assign overflow = overflow_detect;
endmodule