module vpe_psum_cache #(
    parameter PSUM_WIDTH=32,
    parameter BATCH_SIZE=16,
    parameter I_WIDTH=32
)(
    input  logic                        clk             ,
    input  logic                        rst             ,
    input  logic [1:0]                  mode_select     ,
    input  logic                        psum_enable     ,
    input  logic                        psum_clear      ,
    input  logic [PSUM_WIDTH-1      :0] psum_load_in    ,
    input  logic                        in_valid        ,
    input  logic [I_WIDTH-1         :0] in              ,
    output logic [PSUM_WIDTH-1      :0] psum_out        ,
    output logic                        stream_out_valid,
    output logic [PSUM_WIDTH-1      :0] stream_out      ,
    output logic [$clog2(BATCH_SIZE)-1  :0] psum_idx,
    output logic [1:0]                  mode_state
);
    localparam int IDX_WIDTH = (BATCH_SIZE <= 1) ? 1 : $clog2(BATCH_SIZE);
    localparam logic [IDX_WIDTH-1:0] LAST_INDEX = IDX_WIDTH'(BATCH_SIZE - 1);

    typedef enum logic [1:0] {
        MODE_INVALID = 2'b00,
        MODE_ACCU    = 2'b01,
        MODE_LOAD    = 2'b10,
        MODE_OUTPUT  = 2'b11
    } mode_e;

    mode_e mode_q, mode_d;
    logic [IDX_WIDTH-1:0] idx_q, idx_d;

    logic [PSUM_WIDTH-1:0] psum_cache [0:BATCH_SIZE-1];
    logic [PSUM_WIDTH-1:0] mem_read_data;
    assign mem_read_data = psum_cache[idx_q];

    logic write_en;
    logic [PSUM_WIDTH-1:0] write_data;
    logic [IDX_WIDTH-1:0] write_idx;
    logic [PSUM_WIDTH-1:0] in_ext;

    assign psum_idx = idx_q;
    assign mode_state = mode_q;
    assign psum_out = mem_read_data;
    assign in_ext = {{(PSUM_WIDTH-I_WIDTH){in[I_WIDTH-1]}}, in};

    function automatic logic signed [PSUM_WIDTH-1:0] add_values(
        input logic signed [PSUM_WIDTH-1:0] base,
        input logic signed [PSUM_WIDTH-1:0] operand
    );
        return base + operand;
    endfunction

    function automatic logic [IDX_WIDTH-1:0] bump_index(
        input logic [IDX_WIDTH-1:0] value
    );
        if (value == LAST_INDEX) begin
            return '0;
        end else begin
            return value + 1'b1;
        end
    endfunction

    always_comb begin
        mode_d = mode_q;
        idx_d = idx_q;
        write_en = 1'b0;
        write_data = '0;
        write_idx = idx_q;
        stream_out_valid = 1'b0;
        stream_out = '0;

        if (psum_clear) begin
            mode_d = MODE_ACCU;
            idx_d = '0;
        end else if (!psum_enable) begin
            stream_out_valid = in_valid;
            stream_out = in_ext;
        end else begin
            unique case (mode_q)
                MODE_ACCU: begin
                    if (mode_select == MODE_LOAD) begin
                        mode_d = MODE_LOAD;
                        idx_d = '0;
                    end else if (mode_select == MODE_OUTPUT) begin
                        mode_d = MODE_OUTPUT;
                        idx_d = '0;
                    end else if (mode_select == MODE_INVALID) begin
                        // hold, no operation
                    end else if (in_valid) begin
                        write_en = 1'b1;
                        write_data = add_values(mem_read_data, in_ext);
                        write_idx = idx_q;
                        idx_d = bump_index(idx_q);
                    end
                end
                MODE_LOAD: begin
                    if (mode_select == MODE_INVALID) begin
                        // hold
                    end else begin
                        write_en = 1'b1;
                        write_data = psum_load_in;
                        write_idx = idx_q;
                        if (idx_q == LAST_INDEX) begin
                            idx_d = '0;
                            mode_d = MODE_ACCU;
                        end else begin
                            idx_d = bump_index(idx_q);
                        end
                    end
                end
                MODE_OUTPUT: begin
                    if (mode_select == MODE_INVALID) begin
                        // hold
                    end else begin
                        stream_out_valid = 1'b1;
                        stream_out = mem_read_data;
                        if (idx_q == LAST_INDEX) begin
                            idx_d = '0;
                            mode_d = MODE_ACCU;
                        end else begin
                            idx_d = bump_index(idx_q);
                        end
                    end
                end
                default: begin
                    mode_d = MODE_ACCU;
                    idx_d = '0;
                end
            endcase
        end
    end

    integer i;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mode_q <= MODE_ACCU;
            idx_q <= '0;
            for (i = 0; i < BATCH_SIZE; i = i + 1) begin
                psum_cache[i] <= '0;
            end
        end else begin
            if (psum_clear) begin
                mode_q <= MODE_ACCU;
                idx_q <= '0;
                for (i = 0; i < BATCH_SIZE; i = i + 1) begin
                    psum_cache[i] <= '0;
                end
            end else begin
            mode_q <= mode_d;
            idx_q <= idx_d;
            if (write_en) begin
                psum_cache[write_idx] <= write_data;
            end
            end
        end
    end
endmodule
