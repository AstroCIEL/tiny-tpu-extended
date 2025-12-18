module systolic_data_rearranger_FIFO #(
    parameter FIFO_LEN = 16         // FIFO 长度
) (
    // 时钟和复位
    input  logic        clk,
    input  logic        rst,
    
    // Unified Buffer接口
    input  logic [7:0]  ubuf_data_in,
    
    // 脉动阵列接口
    output logic [7:0]  SA_data_out,
    
    // 控制接口
    input  logic        load_en,    // 使能数据加载
    input  logic        shift_en    // 使能数据打拍
);


    // 存储器定义
    logic [7:0] fifo_reg [FIFO_LEN-1:0];    // 高位进，低位出，FIFO深度及延迟由 FIFO_LEN 参数指定

    // 写入逻辑
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            fifo_reg[FIFO_LEN-1]    <= 8'b0;
        end else begin
            if (load_en) begin
                fifo_reg[FIFO_LEN-1]    <= ubuf_data_in;
            end
        end
    end

    // 移位逻辑
    genvar i_tap;
    generate
        for (i_tap = 0; i_tap < FIFO_LEN-1; i_tap = i_tap + 1) begin : gen_FIFO_taps
            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                    fifo_reg[i_tap]    <= 8'b0;
                end else begin
                    if (shift_en) begin
                        fifo_reg[i_tap] <= fifo_reg[i_tap+1];
                    end
                end
            end
        end
    endgenerate

    // 输出逻辑
    assign SA_data_out = fifo_reg[0];

endmodule