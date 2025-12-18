module control_unit (
    input  logic            clk,
    input  logic            rst,
    
    input  logic            global_en,
    input  logic            finish_flag,
    output logic [9:0]      icache_rd_ctrl_addr,
    output logic            icache_rd_ctrl_en,
    input  logic [53:0]     icache_rd_ctrl_data,

    // To UB
    output logic            ub_wr_VPU_en,                   // VPU写入使能
    output logic  [9:0]     ub_wr_VPU_addr_in,              // VPU写入地址
    output logic  [1:0]     ub_wr_VPU_size_in,              // VPU写入尺寸
    output logic            ub_rd_input_en,
    output logic  [9:0]     ub_rd_input_addr_in,
    output logic            ub_rd_weight_en,
    output logic  [1:0]     ub_rd_weight_size_in,
    output logic  [11:0]    ub_rd_weight_addr_in,
    output logic  [3:0]     ub_rd_scale_addr_in,        // VPU scale 读地址
    output logic  [3:0]     ub_rd_bias_addr_in,             // VPU bias 读地址
    output logic  [1:0]     ub_rd_bias_size_in,             // VPU bias 读尺寸

    // To input and weight rearranger
    output logic            sa_input_shift_en,
    output logic            sa_weight_shift_en,

    // To SA
    output logic            sa_enable [3:0],
    output logic            sa_valid_in,
    output logic            sa_new_weight,
    output logic            sa_switch_weight,

    // To VPU
    output logic [1:0]      vpu_mode_select,
    output logic            vpu_psum_clear,
    output logic            vpu_bias_enable,
    output logic            vpu_relu_enable,
    output logic            vpu_dequant_enable,

    // To status reg
    output logic            ctrl_finish_in
);

// 指令缓存控制
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        icache_rd_ctrl_addr     <= 10'b0;
        icache_rd_ctrl_en       <= 1'b0;
    end else begin
        if (global_en && !ctrl_finish_in) begin
            icache_rd_ctrl_addr <= icache_rd_ctrl_addr + 10'h1;
            icache_rd_ctrl_en   <= 1'b1;
        end
    end
end

// 指令 decode
logic [53:0] tpu_instrcuction;

assign tpu_instrcuction = (finish_flag) ? 54'h20_0000_0000_0000 : icache_rd_ctrl_data;

logic [9:0]     ins_input_rd_addr;
logic [9:0]     ins_VPU_wr_addr;
logic [11:0]    ins_weight_rd_addr;
logic [3:0]     ins_bias_rd_addr;
logic [3:0]     ins_scale_rd_addr;
logic [1:0]     ins_sa_en_size;
logic           ins_sa_weight_valid;
logic           ins_sa_switch_weight;
logic           ins_sa_input_valid;
logic [1:0]     ins_vpu_mode_select;
logic           ins_vpu_psum_clear;
logic           ins_vpu_bias_en;
logic           ins_vpu_relu_en;
logic           ins_vpu_dequant_en;
logic           ins_finish;

assign ins_input_rd_addr        = tpu_instrcuction[9:0];
assign ins_VPU_wr_addr          = tpu_instrcuction[19:10];
assign ins_weight_rd_addr       = tpu_instrcuction[31:20];
assign ins_bias_rd_addr         = tpu_instrcuction[35:32];
assign ins_scale_rd_addr        = tpu_instrcuction[39:36];
assign ins_sa_en_size           = tpu_instrcuction[41:40];
assign ins_VPU_en_size          = tpu_instrcuction[43:42];
assign ins_sa_weight_valid      = tpu_instrcuction[44];
assign ins_sa_switch_weight     = tpu_instrcuction[45];
assign ins_sa_input_valid       = tpu_instrcuction[46];
assign ins_vpu_mode_select      = tpu_instrcuction[48:47];
assign ins_vpu_psum_clear       = tpu_instrcuction[49];
assign ins_vpu_bias_en          = tpu_instrcuction[50];
assign ins_vpu_relu_en          = tpu_instrcuction[51];
assign ins_vpu_dequant_en       = tpu_instrcuction[52];
assign ins_finish               = tpu_instrcuction[53];


// UB 控制
assign ub_rd_input_en       = ins_sa_input_valid;
assign ub_rd_input_addr_in  = ins_input_rd_addr;
assign ub_rd_weight_en      = ins_sa_weight_valid;
assign ub_rd_weight_size_in = (ins_sa_weight_valid ? ins_sa_en_size : 2'b0);
assign ub_rd_weight_addr_in = ins_weight_rd_addr;
assign ub_rd_scale_addr_in  = ins_scale_rd_addr;
assign ub_rd_bias_addr_in   = ins_bias_rd_addr;
assign ub_rd_bias_size_in   = ins_VPU_en_size;
assign ub_wr_VPU_en         = (ins_VPU_en_size != 2'b00);
assign ub_wr_VPU_addr_in    = ins_VPU_wr_addr;
assign ub_wr_VPU_size_in    = ins_VPU_en_size;

// SA 输入重组控制
assign sa_input_shift_en    = (ins_sa_en_size != 2'b00);
assign sa_weight_shift_en   = (ins_sa_en_size != 2'b00);

// SA 控制
always_comb begin
    case(ins_sa_en_size)
        2'b00: sa_enable = {1'b0, 1'b0, 1'b0, 1'b0};
        2'b01: sa_enable = {1'b0, 1'b0, 1'b0, 1'b1};
        2'b10: sa_enable = {1'b0, 1'b0, 1'b1, 1'b1};
        2'b11: sa_enable = {1'b1, 1'b1, 1'b1, 1'b1};
    endcase
end

assign sa_valid_in      = ins_sa_input_valid;
assign sa_new_weight    = ins_sa_weight_valid;
assign sa_switch_weight     = ins_sa_switch_weight;


// VPU 控制
assign vpu_mode_select      = ins_vpu_mode_select;
assign vpu_psum_clear       = ins_vpu_psum_clear;
assign vpu_bias_enable      = ins_vpu_bias_en;
assign vpu_relu_enable      = ins_vpu_relu_en;
assign vpu_dequant_enable   = ins_vpu_dequant_en;

// 状态寄存器控制
assign ctrl_finish_in   = ins_finish;


endmodule