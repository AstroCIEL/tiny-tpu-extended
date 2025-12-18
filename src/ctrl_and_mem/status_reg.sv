module status_reg (
    // 时钟和复位
    input  logic        clk,
    input  logic        rst,
    
    // ==================== AXI接口 ====================
    input  logic        axi_status_en,
    input  logic        axi_status_we,
    input  logic [15:0] axi_status_addr,
    input  logic [63:0] axi_status_wdata,
    output logic [63:0] axi_status_rdata,

	// ==================== 控制接口 ====================
	input  logic		ctrl_finish_in,

	// ==================== 输出接口 ====================
    output logic 		global_en,
	output logic 		finish_flag
);

localparam ADDR_REG_EN    	= 16'h0000;
localparam ADDR_REG_FINISH	= 16'h0001;

logic reg_global_en;	// AXI 只写寄存器
logic reg_finish;		// AXI 只读寄存器

always_ff @(posedge clk or posedge rst) begin
	if (rst) begin
		reg_global_en	<= 1'b0;
		reg_finish		<= 1'b0;
	end else begin
		if(axi_status_en && axi_status_we && (axi_status_addr == ADDR_REG_EN)) begin
			reg_global_en	<= axi_status_wdata[0];
		end

		reg_finish		<= ctrl_finish_in;
	end
end

assign global_en = reg_global_en;

// Read Logic with 1 cycle latency to match Unified Buffer
logic axi_status_rd_en_d, axi_status_rd_en_q;
logic [15:0] axi_status_addr_d, axi_status_addr_q;

assign axi_status_rd_en_d = axi_status_en && !axi_status_we;
assign axi_status_addr_d = axi_status_addr;

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        axi_status_rd_en_q <= 1'b0;
        axi_status_addr_q <= 16'b0;
    end else begin
        axi_status_rd_en_q <= axi_status_rd_en_d;
        axi_status_addr_q <= axi_status_addr_d;
    end
end

always_comb begin
    if (axi_status_rd_en_q) begin
        case (axi_status_addr_q)
            ADDR_REG_EN:     axi_status_rdata = {63'b0, reg_global_en};
            ADDR_REG_FINISH: axi_status_rdata = {63'b0, reg_finish};
            default:         axi_status_rdata = 64'b0;
        endcase
    end else begin
        axi_status_rdata = 64'b0;
    end
end

assign finish_flag = reg_finish;

endmodule