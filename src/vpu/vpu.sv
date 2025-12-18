module vpu #(
    parameter I_WIDTH       = 32,
    parameter PSUM_WIDTH    = 32,
    parameter O_WDITH       = 8,
    parameter WITH_PIPE_REG = 1,
    parameter CHANNEL_WIDTH = 16,
    parameter BATCH_SIZE    = 16,
    parameter CHANNEL_NUM   = 4
)(
    input  logic                    clk             ,
    input  logic                    rst             ,

    input  logic [1:0]              mode_select     ,
    input  logic                    psum_clear      ,
    input  logic                    psum_enable     ,
    input  logic                    bias_enable     ,
    input  logic                    relu_enable     ,
    input  logic                    dequant_enable  ,
    input  logic [31:0]             scale_fp32_in   ,

    input  logic [PSUM_WIDTH-1:0]   psum_load_in [CHANNEL_NUM-1:0][CHANNEL_WIDTH-1:0],
    input  logic [PSUM_WIDTH-1:0]   bias_in      [CHANNEL_NUM-1:0][CHANNEL_WIDTH-1:0],

    input  logic                    sa_in_valid  [CHANNEL_NUM-1:0][CHANNEL_WIDTH-1:0],
    input  logic [I_WIDTH-1:0]      sa_in        [CHANNEL_NUM-1:0][CHANNEL_WIDTH-1:0],

    output logic                    vpu_out_valid[CHANNEL_NUM-1:0][CHANNEL_WIDTH-1:0],
    output logic [O_WDITH-1:0]      vpu_out      [CHANNEL_NUM-1:0][CHANNEL_WIDTH-1:0]
);

    logic [$clog2(BATCH_SIZE)-1:0] psum_idx_int [CHANNEL_NUM-1:0][CHANNEL_WIDTH-1:0];
    logic [1:0]                   mode_state_int [CHANNEL_NUM-1:0][CHANNEL_WIDTH-1:0];

    genvar chan;
    generate
        for (chan = 0; chan < CHANNEL_NUM; chan = chan + 1) begin : gen_vpu_channel
            vpu_channel #(
                .I_WIDTH(I_WIDTH),
                .PSUM_WIDTH(PSUM_WIDTH),
                .O_WDITH(O_WDITH),
                .WITH_PIPE_REG(WITH_PIPE_REG),
                .CHANNEL_WIDTH(CHANNEL_WIDTH),
                .BATCH_SIZE(BATCH_SIZE)
            ) u_vpu_channel (
                .clk            (clk                          ),
                .rst            (rst                          ),
                .mode_select    (mode_select                  ),
                .psum_load_in   (psum_load_in[chan]           ),
                .psum_clear     (psum_clear                   ),
                .bias_enable    (bias_enable                  ),
                .psum_enable    (psum_enable                  ),
                .bias_in        (bias_in[chan]                ),
                .relu_enable    (relu_enable                  ),
                .dequant_enable (dequant_enable               ),
                .scale_fp32_in  (scale_fp32_in                ),
                .sa_in_valid    (sa_in_valid[chan]            ),
                .sa_in          (sa_in[chan]                  ),
                .vpu_out_valid  (vpu_out_valid[chan]          ),
                .vpu_out        (vpu_out[chan]                ),
                .psum_idx       (psum_idx_int[chan]           ),
                .mode_state     (mode_state_int[chan]         )
            );
        end
    endgenerate

endmodule
