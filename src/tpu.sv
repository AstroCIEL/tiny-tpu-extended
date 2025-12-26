module tpu (
    // 时钟和复位
    input  logic        clk,
    input  logic        rst,
    
    // ==================== AXI接口 ====================
    input  logic        axi_req,
    input  logic        axi_we,
    input  logic [63:0] axi_addr,
    input  logic [63:0] axi_wdata,
    output logic [63:0] axi_rdata
);

logic        axi_icache_en;
logic        axi_icache_we;
logic [15:0] axi_icache_addr;
logic [63:0] axi_icache_wdata;
logic [63:0] axi_icache_rdata;

logic        axi_ubuf_en;
logic        axi_ubuf_we;
logic [15:0] axi_ubuf_addr;
logic [63:0] axi_ubuf_wdata;
logic [63:0] axi_ubuf_rdata;

logic        axi_status_en;
logic        axi_status_we;
logic [15:0] axi_status_addr;
logic [63:0] axi_status_wdata;
logic [63:0] axi_status_rdata;

axi_interface u_axi_interface (
    .clk    (clk),
    .rst    (rst),

    // AXI Interface
    .axi_req    (axi_req  ),
    .axi_we     (axi_we   ),
    .axi_addr   (axi_addr ),
    .axi_wdata  (axi_wdata),
    .axi_rdata  (axi_rdata),
    
    // 内部接口
    .icache_en      (axi_icache_en   ),
    .icache_we      (axi_icache_we   ),
    .icache_addr    (axi_icache_addr ),
    .icache_wdata   (axi_icache_wdata),
    .icache_rdata   (axi_icache_rdata),
    
    .ubuf_en        (axi_ubuf_en     ),
    .ubuf_we        (axi_ubuf_we     ),
    .ubuf_addr      (axi_ubuf_addr   ),
    .ubuf_wdata     (axi_ubuf_wdata  ),
    .ubuf_rdata     (axi_ubuf_rdata  ),
    
    .status_en      (axi_status_en   ),
    .status_we      (axi_status_we   ),
    .status_addr    (axi_status_addr ),
    .status_wdata   (axi_status_wdata),
    .status_rdata   (axi_status_rdata)
);

logic global_en;
logic ctrl_finish_in;
logic finish_flag;

status_reg u_status_reg (
    .clk    (clk),
    .rst    (rst),
    
    // ==================== AXI接口 ====================
    .axi_status_en      (axi_status_en   ),
    .axi_status_we      (axi_status_we   ),
    .axi_status_addr    (axi_status_addr ),
    .axi_status_wdata   (axi_status_wdata),
    .axi_status_rdata   (axi_status_rdata),

	// ==================== 控制接口 ====================
	.ctrl_finish_in     (ctrl_finish_in),

	// ==================== 输出接口 ====================
    .global_en          (global_en),
    .finish_flag        (finish_flag)
);

logic               icache_rd_ctrl_en;
logic [9:0]         icache_rd_ctrl_addr;
logic [53:0]        icache_rd_ctrl_data;

instruction_cache #(
    .INS_LEN    (54)
) u_instruction_cache (
    .clk    (clk),
    .rst    (rst),

    // ==================== AXI 存储接口 ====================
    .axi_icache_en      (axi_icache_en   ),
    .axi_icache_we      (axi_icache_we   ),
    .axi_icache_addr    (axi_icache_addr ),
    .axi_icache_wdata   (axi_icache_wdata),
    .axi_icache_rdata   (axi_icache_rdata),
    
    // ==================== 控制模块读出接口 ====================
    .icache_rd_ctrl_en      (icache_rd_ctrl_en  ),
    .icache_rd_ctrl_addr    (icache_rd_ctrl_addr),
    .icache_rd_ctrl_data    (icache_rd_ctrl_data)
);

// CTRL unit
logic           ub_wr_VPU_en;
logic [9:0]     ub_wr_VPU_addr_in;
logic [1:0]     ub_wr_VPU_size_in;
logic           ub_rd_input_en;
logic [9:0]     ub_rd_input_addr_in;
logic           ub_rd_weight_en;
logic [1:0]     ub_rd_weight_size_in;
logic [11:0]    ub_rd_weight_addr_in;
logic [3:0]     ub_rd_scale_addr_in;
logic [3:0]     ub_rd_bias_addr_in;
logic [1:0]     ub_rd_bias_size_in;

logic           sa_input_shift_en;
logic           sa_weight_shift_en;

logic           sa_enable [3:0];
logic           sa_valid_in;
logic           sa_new_weight;
logic           sa_switch_weight;

logic [1:0]     vpu_mode_select;
logic           vpu_psum_clear;
logic           vpu_bias_enable;
logic           vpu_relu_enable;
logic           vpu_dequant_enable;
logic           load_en;

control_unit u_control_unit(
    .clk    (clk),
    .rst    (rst),
    
    .global_en              (global_en),
    .finish_flag            (finish_flag),
    .icache_rd_ctrl_addr    (icache_rd_ctrl_addr),
    .icache_rd_ctrl_en      (icache_rd_ctrl_en),
    .icache_rd_ctrl_data    (icache_rd_ctrl_data),

    // To UB
    .ub_wr_VPU_en           (ub_wr_VPU_en           ),
    .ub_wr_VPU_addr_in      (ub_wr_VPU_addr_in      ),
    .ub_wr_VPU_size_in      (ub_wr_VPU_size_in      ),
    .ub_rd_input_en         (ub_rd_input_en         ),
    .ub_rd_input_addr_in    (ub_rd_input_addr_in    ),
    .ub_rd_weight_en        (ub_rd_weight_en        ),
    .ub_rd_weight_size_in   (ub_rd_weight_size_in   ),
    .ub_rd_weight_addr_in   (ub_rd_weight_addr_in   ),
    .ub_rd_scale_addr_in    (ub_rd_scale_addr_in    ),
    .ub_rd_bias_addr_in     (ub_rd_bias_addr_in     ),
    .ub_rd_bias_size_in     (ub_rd_bias_size_in     ),

    // To input and weight rearranger
    .sa_input_shift_en      (sa_input_shift_en      ),
    .sa_weight_shift_en     (sa_weight_shift_en     ),

    // To SA
    .sa_enable              (sa_enable              ),
    .sa_valid_in            (sa_valid_in            ),
    .sa_new_weight          (load_en          ),
    .sa_switch_weight       (sa_new_weight       ),

    // To VPU
    .vpu_mode_select        (vpu_mode_select        ),
    .vpu_psum_clear         (vpu_psum_clear         ),
    .vpu_bias_enable        (vpu_bias_enable        ),
    .vpu_relu_enable        (vpu_relu_enable        ),
    .vpu_dequant_enable     (vpu_dequant_enable     ),

    // To status reg
    .ctrl_finish_in         (ctrl_finish_in)
);


logic [7:0]  ub_wr_VPU_data_in [3:0][15:0];
logic [7:0]  ub_rd_input_data_out [15:0];
logic [7:0]  ub_rd_weight_data_out [3:0][15:0];
logic [31:0] ub_rd_scale_data_out;
logic [31:0] ub_rd_bias_data_out [3:0][15:0];

unified_buffer u_unified_buffer (
    .clk    (clk),
    .rst    (rst),
    
    // ==================== AXI接口 ====================
    .axi_ubuf_en    (axi_ubuf_en   ),
    .axi_ubuf_we    (axi_ubuf_we   ),
    .axi_ubuf_addr  (axi_ubuf_addr ),
    .axi_ubuf_wdata (axi_ubuf_wdata),
    .axi_ubuf_rdata (axi_ubuf_rdata),
    
    // ==================== Input存储接口 ====================
    // 额外写入端口
    .ub_wr_VPU_en           (ub_wr_VPU_en     ),
    .ub_wr_VPU_addr_in      (ub_wr_VPU_addr_in),
    .ub_wr_VPU_size_in      (ub_wr_VPU_size_in),
    .ub_wr_VPU_data_in      (ub_wr_VPU_data_in),
    
    // 读出端口
    .ub_rd_input_en         (ub_rd_input_en      ),
    .ub_rd_input_addr_in    (ub_rd_input_addr_in ),
    .ub_rd_input_data_out   (ub_rd_input_data_out),
    
    // ==================== Weight存储接口 ====================
    .ub_rd_weight_en        (ub_rd_weight_en      ),
    .ub_rd_weight_size_in   (ub_rd_weight_size_in ),
    .ub_rd_weight_addr_in   (ub_rd_weight_addr_in ),
    .ub_rd_weight_data_out  (ub_rd_weight_data_out),
    
    // ==================== Misc存储接口 ====================
    .ub_rd_scale_addr_in    (ub_rd_scale_addr_in ),
    .ub_rd_scale_data_out   (ub_rd_scale_data_out),
    .ub_rd_bias_addr_in     (ub_rd_bias_addr_in  ),
    .ub_rd_bias_size_in     (ub_rd_bias_size_in  ),
    .ub_rd_bias_data_out    (ub_rd_bias_data_out )
);

logic [7:0]  sa_input [15:0];

systolic_data_rearranger u_input_rearranger (
    .clk    (clk),
    .rst    (rst),
    
    // ==================== UBUF 接口 ====================
    .ubuf_data_in   (ub_rd_input_data_out),
    
    // ==================== 脉动阵列接口 ====================
    .SA_data_out    (sa_input),
    
    // ==================== 控制接口 ====================
    .load_en        (sa_valid_in),
    .shift_en       (sa_input_shift_en)
);

logic [7:0] sa_weight [3:0][15:0];

genvar i_weight_rearranger;
generate
    for (i_weight_rearranger = 0; i_weight_rearranger < 4; i_weight_rearranger = i_weight_rearranger + 1) begin : gen_weight_rearranger
            systolic_data_rearranger u_weight_rearranger (
                    .clk    (clk),
                    .rst    (rst),
                    
                    // ==================== UBUF 接口 ====================
                    .ubuf_data_in   (ub_rd_weight_data_out[i_weight_rearranger]),
    
                    // ==================== 脉动阵列接口 ====================
                    .SA_data_out    (sa_weight[i_weight_rearranger]),

                    // ==================== 控制接口 ====================
                    .load_en    (load_en),
                    .shift_en   (sa_weight_shift_en)
            );
    end
endgenerate


logic [31:0] sa_output [3:0][15:0];
logic  sa_valid_out [3:0][15:0];

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        sa_switch_weight <= 0;
    end
    else begin
        sa_switch_weight <= sa_new_weight;
    end
end


systolic_array u_systolic_array (
    .clk    (clk),
    .rst    (rst),

    .sa_enable      (sa_enable),

    // input signals from left side of systolic array
    .sa_input       (sa_input),
    .sa_valid_in    (sa_valid_in),

    // input signals from top of systolic array
    .sa_weight      (sa_weight), 
    .sa_new_weight  (sa_new_weight),
    .sa_switch_in   (sa_switch_weight),

    // output signals to the bottom of systolic array
    .sa_output      (sa_output),
    .sa_valid_out   (sa_valid_out)
);

// logic VPU_sa_in_valid [3:0][15:0];

// genvar i_VPU_sa_in_valid;
// generate
//     for(i_VPU_sa_in_valid = 0; i_VPU_sa_in_valid < 4; i_VPU_sa_in_valid = i_VPU_sa_in_valid + 1) begin : sa_in_valid_format_transfer
//         assign VPU_sa_in_valid[i_VPU_sa_in_valid] = sa_valid_out;
//     end

// endgenerate
logic  sa_valid_out_reg [3:0][15:0];
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        for (int i =0; i<4;i=i+1) begin
            for (int j=0;j<16;j=j+1) begin
                sa_valid_out_reg[i][j] <= 0;
            end
        end
    end
    else begin
        for (int i =0; i<4;i=i+1) begin
            for (int j=0;j<16;j=j+1) begin
                sa_valid_out_reg[i][j] <= sa_valid_out[i][j];
            end
        end
    end
end


vpu #(
    .I_WIDTH       (32),
    .PSUM_WIDTH    (32),
    .O_WDITH       (8),
    .WITH_PIPE_REG (1),
    .CHANNEL_WIDTH (16),
    .BATCH_SIZE    (16),
    .CHANNEL_NUM   (4)
) u_vpu (
    .clk    (clk),
    .rst    (rst),

    .mode_select        (vpu_mode_select),
    .psum_clear         (vpu_psum_clear),
    .psum_enable        (1'b1),         // TODO：暂时不支持 psum load
    .bias_enable        (vpu_bias_enable),
    .relu_enable        (vpu_relu_enable),
    .dequant_enable     (vpu_dequant_enable),
    .scale_fp32_in      (ub_rd_scale_data_out),

    .psum_load_in       ('{4{ '{16{ 31'b0 }} }}), // TODO：暂时不支持 psum load
    .bias_in            (ub_rd_bias_data_out),

    .sa_in_valid        (sa_valid_out),
    .sa_in              (sa_output),

    .vpu_out_valid      (),
    .vpu_out            (ub_wr_VPU_data_in)
);


endmodule
