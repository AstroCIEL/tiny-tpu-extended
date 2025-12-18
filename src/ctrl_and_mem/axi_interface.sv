// =============================================
// AXI - ubuf_memory
//         - data_memory
//         - weight_memory
//         - misc_memory
//     - icache_memory
//     - status_register
// =============================================

module axi_interface (
    // 时钟及复位
    input  logic       clk,
    input  logic       rst,

    // AXI Interface
    input  logic        axi_req,        // AXI请求信号
    input  logic        axi_we,         // 写使能 (1=写, 0=读)
    input  logic [63:0] axi_addr,       // 地址
    input  logic [63:0] axi_wdata,      // 写数据
    output logic [63:0] axi_rdata,      // 读数据
    
    // 内部接口
    output logic        ubuf_en,
    output logic        ubuf_we,
    output logic [15:0] ubuf_addr,
    output logic [63:0] ubuf_wdata,
    input  logic [63:0] ubuf_rdata,

    output logic        icache_en,
    output logic        icache_we,
    output logic [15:0] icache_addr,
    output logic [63:0] icache_wdata,
    input  logic [63:0] icache_rdata,
    
    output logic        status_en,
    output logic        status_we,
    output logic [15:0] status_addr,
    output logic [63:0] status_wdata,
    input  logic [63:0] status_rdata
);

    // 地址映射定义
    localparam UBUF_BASE    = 16'h0000;
    localparam UBUF_END     = 16'h29FF;
    localparam ICACHE_BASE  = 16'h2A00;
    localparam ICACHE_END   = 16'h2DFF;
    localparam STATUS_BASE  = 16'h2E00;
    localparam STATUS_END   = 16'h2E01;

    localparam TPU_BASE     = 64'h4000_0000;
    localparam TPU_END      = 64'h8000_0000;

    logic [15:0] addr_in_TPU; // 内部地址
    logic [15:0] addr_in_TPU_q, addr_in_TPU_d;
    logic axi_req_q, axi_req_d, axi_we_d, axi_we_q;

    // Generate internal address
    always_comb begin
        addr_in_TPU = 16'hFFFF;
        if (axi_addr >= TPU_BASE && axi_addr < TPU_END) begin
            addr_in_TPU = axi_addr[18:3];
        end
    end

    // 写控制
    always_comb begin  // UBUF
        ubuf_en     = 1'b0;
        ubuf_we     = 1'b0;
        ubuf_addr   = 16'b0;
        ubuf_wdata  = 64'b0;
        if (axi_req && (addr_in_TPU >= UBUF_BASE) && (addr_in_TPU <= UBUF_END)) begin
            ubuf_en = 1'b1;
            ubuf_addr = addr_in_TPU - UBUF_BASE;
            if (axi_we) begin
                ubuf_we = axi_we;
                ubuf_wdata = axi_wdata;
            end
        end
    end

    always_comb begin  // ICACHE
        icache_en       = 1'b0;
        icache_we       = 1'b0;
        icache_addr     = 16'b0;
        icache_wdata    = 64'b0;
        if (axi_req && (addr_in_TPU >= ICACHE_BASE) && (addr_in_TPU <= ICACHE_END)) begin
            icache_en = 1'b1;
            icache_addr = addr_in_TPU - ICACHE_BASE;
            if (axi_we) begin
                icache_we = axi_we;
                icache_wdata = axi_wdata;
            end
        end
    end

    always_comb begin  // STATUS
        status_en       = 1'b0;
        status_we       = 1'b0;
        status_addr     = 16'b0;
        status_wdata    = 64'b0;

        if (axi_req && (addr_in_TPU >= STATUS_BASE) && (addr_in_TPU <= STATUS_END)) begin
            status_en = 1'b1;
            status_addr = addr_in_TPU - STATUS_BASE;
            if (axi_we) begin
                status_we = axi_we;
                status_wdata = axi_wdata;
            end
        end
    end

    // Buffer read request for a single cycle
    always_ff @(posedge clk) begin
            axi_req_q <= axi_req_d;
            axi_we_q <= axi_we_d;
            addr_in_TPU_q <= addr_in_TPU_d;
    end

    always_comb begin
        axi_req_d = axi_req;
        axi_we_d = axi_we;
        addr_in_TPU_d = addr_in_TPU;
    end

    // 读数据多路选择
    always_comb begin
        axi_rdata = 64'hCA11AB1EBADCAB1E;
        if (axi_req_q && !axi_we_q) begin
            if ((addr_in_TPU_q >= UBUF_BASE) && (addr_in_TPU_q <= UBUF_END)) begin
                axi_rdata = ubuf_rdata;
            end
            else if ((addr_in_TPU_q >= STATUS_BASE) && (addr_in_TPU_q <= STATUS_END)) begin
                axi_rdata = status_rdata;
            end
            else if ((addr_in_TPU_q >= ICACHE_BASE) && (addr_in_TPU_q <= ICACHE_END)) begin
                axi_rdata = icache_rdata;
            end
        end
    end

endmodule