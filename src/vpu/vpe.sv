module vpe #(
    parameter I_WIDTH=32,
    parameter PSUM_WIDTH=32,
    parameter O_WDITH=8,
    parameter WITH_PIPE_REG=1,
    parameter BATCH_SIZE=16
)(
    input  logic                        clk     ,
    input  logic                        rst     ,

    input  logic [1:0]                  mode_select         ,

    input  logic [PSUM_WIDTH-1      :0] psum_load_in        ,
    input  logic                        psum_clear          ,
    input  logic [PSUM_WIDTH-1      :0] bias_in             ,
    input  logic                        bias_enable         ,

    input  logic                        relu_enable         ,
    input  logic                        dequant_enable      ,
    input  logic [31                :0] scale_fp32_in       ,
    input  logic                        psum_enable         ,

    input  logic                        sa_in_valid         ,
    input  logic [I_WIDTH-1         :0] sa_in               ,
    output logic                        vpe_out_valid       ,
    output logic [O_WDITH-1         :0] vpe_out             ,
    output logic [$clog2(BATCH_SIZE)-1:0] psum_idx          ,
    output logic [1:0]                  mode_state          
);

    logic [PSUM_WIDTH-1:0] psum_out;
    logic cache_stream_valid;
    logic [PSUM_WIDTH-1:0] cache_stream_data;
    
    logic bias_out_valid;
    logic [PSUM_WIDTH-1:0] bias_out;
    logic relu_in_valid;
    logic [PSUM_WIDTH-1:0] relu_in;
    logic relu_out_valid;
    logic [PSUM_WIDTH-1:0] relu_out;
    
    logic dequant_in_valid;
    logic [PSUM_WIDTH-1:0] dequant_in;
    logic dequant_out_valid;
    logic [O_WDITH-1:0] dequant_out;

    vpe_psum_cache #(
        .PSUM_WIDTH(PSUM_WIDTH),
        .BATCH_SIZE(BATCH_SIZE),
        .I_WIDTH(I_WIDTH)
    ) u_vpe_psum_cache (
        .clk             (clk                 ),
        .rst             (rst                 ),
        .psum_enable     (psum_enable         ),
        .mode_select     (mode_select         ),
        .psum_clear      (psum_clear          ),
        .psum_load_in    (psum_load_in        ),
        .in_valid        (sa_in_valid         ),
        .in              (sa_in               ),
        .psum_out        (psum_out            ),
        .stream_out_valid(cache_stream_valid  ),
        .stream_out      (cache_stream_data   ),
        .psum_idx        (psum_idx            ),
        .mode_state      (mode_state          )
    );

    vpe_bias #(
        .PSUM_WIDTH(PSUM_WIDTH)
    ) u_vpe_bias (
        .clk            (clk                ),
        .rst            (rst                ),
        .bias_enable    (bias_enable        ),
        .bias_in_valid  (cache_stream_valid ),
        .bias_in        (cache_stream_data  ),
        .bias_value     (bias_in            ),
        .bias_out_valid (bias_out_valid     ),
        .bias_out       (bias_out           )
    );

    assign relu_in_valid = bias_out_valid;
    assign relu_in       = bias_out;

    vpe_relu #(
        .PSUM_WIDTH(PSUM_WIDTH)
    ) u_vpe_relu (
        .clk            (clk            ),
        .rst            (rst            ),
        .relu_enable    (relu_enable    ),
        .relu_in_valid  (relu_in_valid  ),
        .relu_in        (relu_in        ),
        .relu_out_valid (relu_out_valid ),
        .relu_out       (relu_out       )
    );

    generate
        if (WITH_PIPE_REG == 1) begin : gen_pipe_reg_relu_dequant
            pipe_register #(
                .WIDTH(PSUM_WIDTH)
            ) u_pipe_reg_relu_dequant (
                .clk    (clk                    ),
                .rst    (rst                    ),
                .in_vld (relu_out_valid         ),
                .in     (relu_out               ),
                .out_vld(dequant_in_valid       ),
                .out    (dequant_in             )
            );
        end else begin : gen_direct_relu_dequant
            assign dequant_in_valid = relu_out_valid;
            assign dequant_in       = relu_out;
        end
    endgenerate

    vpe_dequanter #(
        .PSUM_WIDTH(PSUM_WIDTH),
        .O_WIDTH(O_WDITH)
    ) u_vpe_dequanter (
        .clk                (clk                ),
        .rst                (rst                ),
        .dequant_enable     (dequant_enable     ),
        .scale_fp32_in      (scale_fp32_in      ),
        .dequant_in_valid   (dequant_in_valid   ),
        .dequant_in         (dequant_in         ),
        .dequant_out_valid  (dequant_out_valid  ),
        .dequant_out        (dequant_out        )
    );

    generate
        if (WITH_PIPE_REG == 1) begin : gen_pipe_reg_dequant_out
            pipe_register #(
                .WIDTH(O_WDITH)
            ) u_pipe_reg_dequant_out (
                .clk    (clk                    ),
                .rst    (rst                    ),
                .in_vld (dequant_out_valid      ),
                .in     (dequant_out            ),
                .out_vld(vpe_out_valid          ),
                .out    (vpe_out                )
            );
        end else begin : gen_direct_dequant_out
            assign vpe_out_valid = dequant_out_valid;
            assign vpe_out       = dequant_out;
        end
    endgenerate

endmodule
