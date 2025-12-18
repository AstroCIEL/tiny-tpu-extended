module systolic_data_rearranger (
    // 时钟和复位
    input  logic        clk,
    input  logic        rst,
    
    // Unified Buffer接口
    input  logic [7:0]  ubuf_data_in [15:0],
    
    // 脉动阵列接口
    output logic [7:0]  SA_data_out [15:0],
    
    // 控制接口
    input  logic        load_en,    // 使能数据加载
    input  logic        shift_en    // 使能数据打拍
);

    // 将输入延迟 0~15 个周期输出
    assign SA_data_out[0] = (load_en) ? ubuf_data_in[0] : 8'b0;

    genvar i_rows;
    generate
        for (i_rows = 1; i_rows < 16; i_rows = i_rows + 1) begin : gen_FIFO_rows
            systolic_data_rearranger_FIFO #(
                .FIFO_LEN(i_rows)
            ) u_rearranger_FIFO (
                    .clk            (clk        ),
                    .rst            (rst        ),
                    .ubuf_data_in   (ubuf_data_in[i_rows]   ),
                    .SA_data_out    (SA_data_out[i_rows]    ),
                    .load_en        (load_en    ),
                    .shift_en       (shift_en   )
            );
        end
    endgenerate


endmodule