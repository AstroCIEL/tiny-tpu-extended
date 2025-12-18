module instruction_cache #(
    INS_LEN   = 54
) (
    // AXI 端口
    input  logic        clk,
    input  logic        rst,
    input  logic        axi_icache_en,      // AXI使能信号
    input  logic        axi_icache_we,      // AXI写使能
    input  logic [15:0] axi_icache_addr,    // AXI地址
    input  logic [63:0] axi_icache_wdata,   // AXI写数据
    output logic [63:0] axi_icache_rdata,   // AXI读数据
    
    // 控制模块读出端口
    input  logic                icache_rd_ctrl_en,     // 控制模块使能
    input  logic [9:0]          icache_rd_ctrl_addr,   // 控制模块地址
    output logic [INS_LEN-1:0]  icache_rd_ctrl_data    // 控制模块读数据
);


// ============================================================================
// Instruction存储阵列 : 1024 × 54bit, 1个写入端口(AXI), 1个读出端口(ctrl)
// ============================================================================
// AXI 总线的写入位宽: 64 bits/cycle
// Ctrl 读出位宽: 54bit(暂定)
// 故采用每行 54 bit 存储
logic [INS_LEN-1:0] ins_memory [1023:0];

    
// AXI 写入逻辑
// 解析AXI地址到 icache 存储坐标
logic [9:0]    axi_insmem_wr_row;

assign axi_insmem_wr_row = axi_icache_addr[9:0];
            
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        for (int i= 0; i < 1024; i=i+1) begin
            ins_memory[i] <= 'b0;
        end
        // $readmemb("/home/rjbao/workspace/xrun_workspace/src/tb/ins_binary.txt", ins_memory);
    end else begin
        if (axi_icache_en && axi_icache_we) begin
            ins_memory[axi_insmem_wr_row] <= axi_icache_wdata[INS_LEN-1:0];
        end
    end
end

// AXI 读出逻辑 (1 cycle latency)
logic        axi_icache_rd_en_d, axi_icache_rd_en_q;
logic [9:0]  axi_icache_rd_addr_d, axi_icache_rd_addr_q;

assign axi_icache_rd_en_d   = axi_icache_en && !axi_icache_we;
assign axi_icache_rd_addr_d = axi_icache_addr[9:0];

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        axi_icache_rd_en_q   <= 1'b0;
        axi_icache_rd_addr_q <= '0;
    end else begin
        axi_icache_rd_en_q   <= axi_icache_rd_en_d;
        axi_icache_rd_addr_q <= axi_icache_rd_addr_d;
    end
end

always_comb begin
    if (axi_icache_rd_en_q) begin
        axi_icache_rdata = {{(64-INS_LEN){1'b0}}, ins_memory[axi_icache_rd_addr_q]};
    end else begin
        axi_icache_rdata = 64'b0;
    end
end

// Ctrl 读出逻辑
always_comb begin
    if(rst) begin
        icache_rd_ctrl_data = 'b0;
    end else if(icache_rd_ctrl_en) begin
        icache_rd_ctrl_data = ins_memory[icache_rd_ctrl_addr];
    end else begin
        icache_rd_ctrl_data = 'b0;
    end
end

endmodule