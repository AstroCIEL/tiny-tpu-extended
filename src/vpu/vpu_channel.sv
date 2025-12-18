module vpu_channel #(
    parameter I_WIDTH       = 32,
    parameter PSUM_WIDTH    = 32,
    parameter O_WDITH       = 8,
    parameter WITH_PIPE_REG = 1,
    parameter CHANNEL_WIDTH = 16,
    parameter BATCH_SIZE    = 16
)(
    input  logic                            clk,
    input  logic                            rst,

    input  logic [1:0]                      mode_select                         ,
    input  logic [PSUM_WIDTH-1:0]           psum_load_in   [CHANNEL_WIDTH-1:0]  ,
    input  logic                            psum_clear                          ,
    input  logic [PSUM_WIDTH-1:0]           bias_in        [CHANNEL_WIDTH-1:0]  ,
    input  logic                            bias_enable                         ,
    input  logic                            psum_enable                         ,

    input  logic                            relu_enable                         ,
    input  logic                            dequant_enable                      ,
    input  logic [31:0]                     scale_fp32_in                       ,

    input  logic                            sa_in_valid    [CHANNEL_WIDTH-1:0]  ,
    input  logic [I_WIDTH-1:0]              sa_in          [CHANNEL_WIDTH-1:0]  ,
    output logic                            vpu_out_valid  [CHANNEL_WIDTH-1:0]  ,
    output logic [O_WDITH-1:0]              vpu_out        [CHANNEL_WIDTH-1:0]  ,

    output logic [$clog2(BATCH_SIZE)-1  :0] psum_idx       [CHANNEL_WIDTH-1:0]  ,
    output logic [1:0]                      mode_state     [CHANNEL_WIDTH-1:0]
);

    generate
        genvar i;
        for (i = 0; i < CHANNEL_WIDTH; i = i + 1) begin : gen_vpe
            vpe #(
                .I_WIDTH(I_WIDTH),
                .PSUM_WIDTH(PSUM_WIDTH),
                .O_WDITH(O_WDITH),
                .WITH_PIPE_REG(WITH_PIPE_REG),
                .BATCH_SIZE(BATCH_SIZE)
            ) u_vpe (
                .clk                (clk                ),
                .rst                (rst                ),
                .mode_select        (mode_select     ),
                .psum_load_in       (psum_load_in[i] ),
                .psum_clear         (psum_clear      ),
                .bias_in            (bias_in[i]      ),
                .bias_enable        (bias_enable     ),
                .relu_enable        (relu_enable     ),
                .dequant_enable     (dequant_enable  ),
                .scale_fp32_in      (scale_fp32_in   ),
                .psum_enable        (psum_enable     ),
                .sa_in_valid        (sa_in_valid[i]  ),
                .sa_in              (sa_in[i]        ),
                .vpe_out_valid      (vpu_out_valid[i]),
                .vpe_out            (vpu_out[i]      ),
                .psum_idx           (psum_idx[i]     ),
                .mode_state         (mode_state[i]   )
            );
        end
    endgenerate

endmodule
