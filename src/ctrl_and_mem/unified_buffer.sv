module unified_buffer (
    // 时钟和复位
    input  logic        clk,
    input  logic        rst,
    
    // ==================== AXI接口 ====================
    input  logic        axi_ubuf_en,
    input  logic        axi_ubuf_we,
    input  logic [15:0] axi_ubuf_addr,
    input  logic [63:0] axi_ubuf_wdata,
    output logic [63:0] axi_ubuf_rdata,
    
    // ==================== Input存储接口 ====================
    // 额外写入端口
    input  logic        ub_wr_VPU_en,                   // VPU写入使能
    input  logic [9:0]  ub_wr_VPU_addr_in,              // VPU写入地址
    input  logic [1:0]  ub_wr_VPU_size_in,              // VPU写入尺寸
    input  logic [7:0]  ub_wr_VPU_data_in [3:0][15:0],  // VPU写入数据
    
    // 读出端口
    input  logic        ub_rd_input_en,                 // 脉动阵列读出使能
    input  logic [9:0]  ub_rd_input_addr_in,            // 脉动阵列的读出地址
    output logic [7:0]  ub_rd_input_data_out [15:0],    // 脉动阵列的读出数据
    // input  logic [15:0] vpu_input_raddr,     // VPU读地址
    // output logic [31:0] input_to_vpu,        // 到VPU的读出数据
    
    // ==================== Weight存储接口 ====================
    input  logic            ub_rd_weight_en,
    input  logic [1:0]      ub_rd_weight_size_in,
    input  logic [11:0]     ub_rd_weight_addr_in,
    output logic [7:0]      ub_rd_weight_data_out [3:0][15:0],
    
    // ==================== Misc存储接口 ====================
    input  logic [3:0]  ub_rd_scale_addr_in,    // VPU scale 读地址
    output logic [31:0] ub_rd_scale_data_out,   // VPU scale 读数据
    input  logic [3:0]  ub_rd_bias_addr_in,             // VPU bias 读地址
    input  logic [1:0]  ub_rd_bias_size_in,             // VPU bias 尺寸
    output logic [31:0] ub_rd_bias_data_out[3:0][15:0]  // VPU bias 读数据
);


// ============================================================================
// 地址范围定义
// ============================================================================
localparam WMEM_BASE    = 20'h0000;
localparam WMEM_END     = 20'h1FFF;
localparam IMEM_BASE    = 20'h2000;
localparam IMEM_END     = 20'h27FF;
localparam MMEM_BASE    = 20'h2800;
localparam MMEM_END     = 20'h29FF;

// ============================================================================
// AXI 地址转为三块存储阵列内部地址
// ============================================================================
logic [10:0]    axi_imem_wr_addr;
logic [10:0]    axi_imem_rd_addr;
logic [12:0]    axi_wmem_wr_addr;
logic [12:0]    axi_wmem_rd_addr;
logic [8:0]     axi_mmem_wr_addr;
logic [8:0]     axi_mmem_rd_addr;

assign axi_imem_wr_addr = axi_ubuf_addr[10:0];
assign axi_imem_rd_addr = axi_ubuf_addr[10:0];
assign axi_wmem_wr_addr = axi_ubuf_addr[12:0];
assign axi_wmem_rd_addr = axi_ubuf_addr[12:0];
assign axi_mmem_wr_addr = axi_ubuf_addr[8:0];
assign axi_mmem_rd_addr = axi_ubuf_addr[8:0];

logic axi_imem_wr_en;
logic axi_imem_rd_en_d, axi_imem_rd_en_q;
logic axi_wmem_wr_en;
logic axi_wmem_rd_en_d, axi_wmem_rd_en_q;
logic axi_mmem_wr_en;
logic axi_mmem_rd_en_d, axi_mmem_rd_en_q;

assign axi_imem_wr_en = ((axi_ubuf_addr >= IMEM_BASE) && (axi_ubuf_addr <= IMEM_END)) && axi_ubuf_en && axi_ubuf_we;
assign axi_imem_rd_en_d = ((axi_ubuf_addr >= IMEM_BASE) && (axi_ubuf_addr <= IMEM_END)) && axi_ubuf_en && (!axi_ubuf_we);
assign axi_wmem_wr_en = ((axi_ubuf_addr >= WMEM_BASE) && (axi_ubuf_addr <= WMEM_END)) && axi_ubuf_en && axi_ubuf_we;
assign axi_wmem_rd_en_d = ((axi_ubuf_addr >= WMEM_BASE) && (axi_ubuf_addr <= WMEM_END)) && axi_ubuf_en && (!axi_ubuf_we);
assign axi_mmem_wr_en = ((axi_ubuf_addr >= MMEM_BASE) && (axi_ubuf_addr <= MMEM_END)) && axi_ubuf_en && axi_ubuf_we;
assign axi_mmem_rd_en_d = ((axi_ubuf_addr >= MMEM_BASE) && (axi_ubuf_addr <= MMEM_END)) && axi_ubuf_en && (!axi_ubuf_we);

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        axi_imem_rd_en_q <= 1'b0;
        axi_wmem_rd_en_q <= 1'b0;
        axi_mmem_rd_en_q <= 1'b0;
    end else begin
        axi_imem_rd_en_q <= axi_imem_rd_en_d;
        axi_wmem_rd_en_q <= axi_wmem_rd_en_d;
        axi_mmem_rd_en_q <= axi_mmem_rd_en_d;
    end
end



// ============================================================================
// Input 存储阵列 : 256 × 512bit, 2个写入端口(AXI,VPU), 2个读出端口(AXI,sa)
// ============================================================================
// AXI 总线的写入位宽: 64 bits/cycle
// VPU 的最小写入位宽: 16col × 8bit = 128 bits/cycle
// VPU 的最大写入位宽: 16col × 8bit × 4array = 512 bits/cycle
// AXI 总线的读出位宽: 64 bits/cycle
// SA 的读出位宽: 16col × 8bit = 128 bits/cycle
// 故采用每行 512 bit 存储

logic [511:0] input_memory [255:0];

// 写入逻辑
logic [7:0]     axi_imem_wr_row;        // 解析AXI写地址到input存储坐标
logic [2:0]     axi_imem_wr_inrow_offset;

assign axi_imem_wr_row          = axi_imem_wr_addr[10:3];
assign axi_imem_wr_inrow_offset = axi_imem_wr_addr[2:0];

logic [7:0]     vpu_imem_wr_row;        // 解析VPU写地址到input存储坐标
logic [2:0]     vpu_imem_wr_inrow_offset_128;
logic [2:0]     vpu_imem_wr_inrow_offset_256;

assign vpu_imem_wr_row              = ub_wr_VPU_addr_in[9:2];
assign vpu_imem_wr_inrow_offset_128 = ub_wr_VPU_addr_in[1:0];
assign vpu_imem_wr_inrow_offset_256 = ub_wr_VPU_addr_in[1];

logic [127:0]   ub_wr_VPU_data_in_128_temp; // 用于格式转换
logic [255:0]   ub_wr_VPU_data_in_256_temp;
logic [511:0]   ub_wr_VPU_data_in_512_temp;

genvar i_wr_vpu_128;
generate
    for (i_wr_vpu_128 = 0; i_wr_vpu_128 < 16; i_wr_vpu_128 = i_wr_vpu_128+1) begin
        assign ub_wr_VPU_data_in_128_temp[i_wr_vpu_128*8 +: 8] = ub_wr_VPU_data_in[0][i_wr_vpu_128];
    end
endgenerate

genvar i_wr_vpu_256;
generate
    for (i_wr_vpu_256 = 0; i_wr_vpu_256 < 16; i_wr_vpu_256 = i_wr_vpu_256+1) begin
        assign ub_wr_VPU_data_in_256_temp[i_wr_vpu_256*8+128 +: 8] = ub_wr_VPU_data_in[0][i_wr_vpu_256];
        assign ub_wr_VPU_data_in_256_temp[i_wr_vpu_256*8 +: 8] = ub_wr_VPU_data_in[1][i_wr_vpu_256];
    end
endgenerate

genvar i_wr_vpu_512;
generate
    for (i_wr_vpu_512 = 0; i_wr_vpu_512 < 16; i_wr_vpu_512 = i_wr_vpu_512+1) begin
        assign ub_wr_VPU_data_in_512_temp[i_wr_vpu_512*8+384 +: 8] = ub_wr_VPU_data_in[0][i_wr_vpu_512];
        assign ub_wr_VPU_data_in_512_temp[i_wr_vpu_512*8+256 +: 8] = ub_wr_VPU_data_in[1][i_wr_vpu_512];
        assign ub_wr_VPU_data_in_512_temp[i_wr_vpu_512*8+128 +: 8] = ub_wr_VPU_data_in[2][i_wr_vpu_512];
        assign ub_wr_VPU_data_in_512_temp[i_wr_vpu_512*8 +: 8] = ub_wr_VPU_data_in[3][i_wr_vpu_512];
    end
endgenerate

            
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        for (int i= 0; i < 256; i=i+1) begin
            input_memory[i] <= 512'b0;
        end
    end else begin
        if (axi_imem_wr_en) begin       // AXI 写入逻辑
            input_memory[axi_imem_wr_row][axi_imem_wr_inrow_offset*64 +: 64] <= axi_ubuf_wdata;
        end else if(ub_wr_VPU_en) begin      // VPU 写入逻辑
            case (ub_wr_VPU_size_in)
                2'b01: begin
                    input_memory[vpu_imem_wr_row][vpu_imem_wr_inrow_offset_128*128 +: 128] <= ub_wr_VPU_data_in_128_temp;
                end

                2'b10: begin
                    input_memory[vpu_imem_wr_row][vpu_imem_wr_inrow_offset_256*256 +: 256] <= ub_wr_VPU_data_in_256_temp;
                end

                2'b11: begin
                    input_memory[vpu_imem_wr_row] <= ub_wr_VPU_data_in_512_temp;
                end
            endcase
        end
    end
end

// SA 读出逻辑
// 解析读出地址到input存储坐标
logic [7:0]     sa_imem_rd_row;
logic [1:0]     sa_imem_rd_inrow_offset;

assign sa_imem_rd_row           = ub_rd_input_addr_in[9:2];
assign sa_imem_rd_inrow_offset  = ub_rd_input_addr_in[1:0];

logic [127:0]   ub_rd_input_data_out_temp;   // 用于格式转换

always_comb begin
    if (ub_rd_input_en) begin
        ub_rd_input_data_out_temp = input_memory[sa_imem_rd_row][sa_imem_rd_inrow_offset*128 +: 128];
    end else begin
        ub_rd_input_data_out_temp = 128'b0;
    end
end

genvar i_rd_input;
generate
    for (i_rd_input = 0; i_rd_input < 4; i_rd_input = i_rd_input+1) begin
        assign ub_rd_input_data_out[15-i_rd_input] = ub_rd_input_data_out_temp[i_rd_input*8 +: 8];
    end
endgenerate

// AXI 读出逻辑
logic [7:0]    axi_imem_rd_row_d, axi_imem_rd_row_q;        // 解析AXI地址到input存储坐标
logic [2:0]    axi_imem_rd_inrow_offset_d, axi_imem_rd_inrow_offset_q;

assign axi_imem_rd_row_d          = axi_imem_rd_addr[10:3];
assign axi_imem_rd_inrow_offset_d = axi_imem_rd_addr[2:0];

// AXI 读出逻辑 (Weight)
logic [9:0]     axi_wmem_rd_row_d, axi_wmem_rd_row_q;
logic [2:0]     axi_wmem_rd_inrow_offset_d, axi_wmem_rd_inrow_offset_q;

assign axi_wmem_rd_row_d          = axi_wmem_rd_addr[12:3];
assign axi_wmem_rd_inrow_offset_d = axi_wmem_rd_addr[2:0];

// AXI 读出逻辑 (Misc)
logic [3:0]     axi_mmem_rd_row_d, axi_mmem_rd_row_q;
logic [4:0]     axi_mmem_rd_inrow_offset_d, axi_mmem_rd_inrow_offset_q;

assign axi_mmem_rd_row_d          = axi_mmem_rd_addr[8:5];
assign axi_mmem_rd_inrow_offset_d = axi_mmem_rd_addr[4:0];

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        axi_imem_rd_row_q <= '0;
        axi_imem_rd_inrow_offset_q <= '0;
        axi_wmem_rd_row_q <= '0;
        axi_wmem_rd_inrow_offset_q <= '0;
        axi_mmem_rd_row_q <= '0;
        axi_mmem_rd_inrow_offset_q <= '0;
    end else begin
        axi_imem_rd_row_q <= axi_imem_rd_row_d;
        axi_imem_rd_inrow_offset_q <= axi_imem_rd_inrow_offset_d;
        axi_wmem_rd_row_q <= axi_wmem_rd_row_d;
        axi_wmem_rd_inrow_offset_q <= axi_wmem_rd_inrow_offset_d;
        axi_mmem_rd_row_q <= axi_mmem_rd_row_d;
        axi_mmem_rd_inrow_offset_q <= axi_mmem_rd_inrow_offset_d;
    end
end

// VPU 读出逻辑
// TODO



// ============================================================================
// Weight存储阵列 : 1024 × 512bit, 1个写入端口(AXI), 1个读出端口(sa)
// ============================================================================
// AXI 总线的写入位宽: 64 bits/cycle
// Weight 读出的最小位宽: 16col × 8bit =  128 bits/cycle
// Weight 读出的最大位宽: 16col × 8bit × 4array = 512 bits/cycle
// 故采用每行 512 bit 存储

logic [511:0] weight_memory [1023:0];

// AXI 写入逻辑
// 解析AXI地址到weight存储坐标
logic [9:0]     axi_wmem_wr_row;
logic [2:0]     axi_wmem_inrow_offset;

assign axi_wmem_wr_row          = axi_wmem_wr_addr[12:3];
assign axi_wmem_inrow_offset    = axi_wmem_wr_addr[2:0];
            
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        // for (int i= 0; i < 1024; i=i+1) begin
        //     weight_memory[i] <= 512'b0;
        // end
        $readmemh("/home/rjbao/workspace/xrun_workspace/src/tb/weight_hex.txt", weight_memory);
    end else begin
        if (axi_ubuf_en && axi_ubuf_we && axi_wmem_wr_en) begin
            weight_memory[axi_wmem_wr_row][axi_wmem_inrow_offset*64 +: 64] <= axi_ubuf_wdata;
        end
    end
end

// Weight 读出逻辑
// 解析读出地址到weight存储坐标
logic [9:0]     sa_wmem_rd_row;
logic [1:0]     sa_wmem_inrow_offset_128;
logic           sa_wmem_inrow_offset_256;

assign sa_wmem_rd_row           = ub_rd_weight_addr_in[11:2];
assign sa_wmem_inrow_offset_128 = ub_rd_weight_addr_in[1:0];
assign sa_wmem_inrow_offset_256 = ub_rd_weight_addr_in[1];

logic [127:0]   ub_rd_weight_data_out_temp [3:0];   // 用于格式转换

always_comb begin
    for (int i = 0; i < 4; i++) begin
        ub_rd_weight_data_out_temp[i] = 128'b0;
    end

    if(ub_rd_weight_en) begin
        case(ub_rd_weight_size_in)
            2'b01: begin
                ub_rd_weight_data_out_temp[0] = weight_memory[sa_wmem_rd_row][sa_wmem_inrow_offset_128*128 +: 128];
            end

            2'b10: begin
                ub_rd_weight_data_out_temp[0] = weight_memory[sa_wmem_rd_row][sa_wmem_inrow_offset_256*256+128 +: 128];
                ub_rd_weight_data_out_temp[1] = weight_memory[sa_wmem_rd_row][sa_wmem_inrow_offset_256*256 +: 128];
            end

            2'b11: begin
                ub_rd_weight_data_out_temp[0] = weight_memory[sa_wmem_rd_row][511:384];
                ub_rd_weight_data_out_temp[1] = weight_memory[sa_wmem_rd_row][383:256];
                ub_rd_weight_data_out_temp[2] = weight_memory[sa_wmem_rd_row][255:128];
                ub_rd_weight_data_out_temp[3] = weight_memory[sa_wmem_rd_row][127:0];
            end
        endcase
    end
end

genvar i_rd_weight, j_rd_weight;
generate
    for (i_rd_weight = 0; i_rd_weight < 4; i_rd_weight = i_rd_weight+1) begin
        for (j_rd_weight=0; j_rd_weight < 16; j_rd_weight = j_rd_weight+1) begin
            assign ub_rd_weight_data_out[i_rd_weight][15-j_rd_weight] = ub_rd_weight_data_out_temp[i_rd_weight][j_rd_weight*8 +: 8];
        end
    end
endgenerate

// ============================================================================
// MISC存储阵列 : 16 × 2048bit, 1个写入端口(AXI), 2个读出端口(vpu.scale, vpu.bias)
// ============================================================================
// AXI 总线的写入位宽: 64 bits/cycle
// VPU 读出 scale 的位宽: 32bit
// VPU 读出 bias 的最小位宽: 16col × 32bit =  512 bits/cycle
// VPU 读出 bias 的最大位宽: 4channel × 16col × 32bit =  2048 bits/cycle
// 故采用每行 2048 bit 存储，每行从低比特开始存储有效数据，高比特可空置，从而简化设计

logic [2047:0] misc_memory [15:0];

// AXI 写入逻辑
// 解析AXI地址到weight存储坐标
logic [3:0]     axi_mmem_wr_row;
logic [4:0]     axi_mmem_inrow_offset;

assign axi_mmem_wr_row          = axi_mmem_wr_addr[8:5];
assign axi_mmem_inrow_offset    = axi_mmem_wr_addr[4:0];
            
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        for (int i= 0; i < 16; i=i+1) begin
            misc_memory[i] <= 2048'b0;
        end
    end else begin
        if (axi_mmem_wr_en) begin
            misc_memory[axi_mmem_wr_row][axi_mmem_inrow_offset*64 +: 64] <= axi_ubuf_wdata;
        end
    end
end

// scale 读出逻辑
// 解析读出地址到misc存储坐标
logic [3:0]     vpu_mmem_rd_scale_row;

assign vpu_mmem_rd_scale_row    = ub_rd_scale_addr_in;

assign ub_rd_scale_data_out = misc_memory[vpu_mmem_rd_scale_row][31:0];

// bias 读出逻辑
// 解析读出地址到misc存储坐标
logic [3:0]     vpu_mmem_rd_bias_row;

assign vpu_mmem_rd_bias_row     = ub_rd_bias_addr_in;

logic [511:0]   ub_rd_bias_data_out_temp [3:0];   // 用于格式转换

always_comb begin
    for (int i = 0; i < 4; i = i+1) begin
        ub_rd_bias_data_out_temp[i] = 512'b0;
    end

    case(ub_rd_weight_size_in)
        2'b01: begin
            ub_rd_bias_data_out_temp[0] = misc_memory[vpu_mmem_rd_bias_row][511:0];
        end

        2'b10: begin
            ub_rd_bias_data_out_temp[0] = misc_memory[vpu_mmem_rd_bias_row][1024:512];
            ub_rd_bias_data_out_temp[1] = misc_memory[vpu_mmem_rd_bias_row][511:0];
        end

        2'b11: begin
            ub_rd_bias_data_out_temp[0] = misc_memory[vpu_mmem_rd_bias_row][2047:1536];
            ub_rd_bias_data_out_temp[1] = misc_memory[vpu_mmem_rd_bias_row][1535:1024];
            ub_rd_bias_data_out_temp[2] = misc_memory[vpu_mmem_rd_bias_row][1023:512];
            ub_rd_bias_data_out_temp[3] = misc_memory[vpu_mmem_rd_bias_row][511:0];
        end
    endcase
end

genvar i_rd_bias, j_rd_bias;
generate
    for (i_rd_bias = 0; i_rd_bias < 4; i_rd_bias = i_rd_bias+1) begin
        for (j_rd_bias=0; j_rd_bias < 16; j_rd_bias = j_rd_bias+1) begin
            assign ub_rd_bias_data_out[i_rd_bias][j_rd_bias] = ub_rd_bias_data_out_temp[i_rd_bias][j_rd_bias*32 +: 32];
        end
    end
endgenerate

always_comb begin
    if (axi_imem_rd_en_q) begin
        axi_ubuf_rdata = input_memory[axi_imem_rd_row_q][axi_imem_rd_inrow_offset_q*64 +: 64];
    end else if (axi_wmem_rd_en_q) begin
        axi_ubuf_rdata = weight_memory[axi_wmem_rd_row_q][axi_wmem_rd_inrow_offset_q*64 +: 64];
    end else if (axi_mmem_rd_en_q) begin
        axi_ubuf_rdata = misc_memory[axi_mmem_rd_row_q][axi_mmem_rd_inrow_offset_q*64 +: 64];
    end else begin
        axi_ubuf_rdata = 64'b0;
    end
end

endmodule