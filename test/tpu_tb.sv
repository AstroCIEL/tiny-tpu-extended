//////////////////////////////////////////////////////////////////////////////////
// Designer:        Zhantong Zhu [Peking University] <zhu_20021122@stu.pku.edu.cn>
// Acknowledgement: GitHub Copilot
// Description:     Testbench for TPU-Lite
//////////////////////////////////////////////////////////////////////////////////

// resolution should be set to 1 ps
`timescale 1ps / 1ps

module tpu_tb;

    // ANSI Color codes
    localparam string COLOR_RED = "\033[31m";
    localparam string COLOR_GREEN = "\033[32m";
    localparam string COLOR_YELLOW = "\033[33m";
    localparam string COLOR_BLUE = "\033[34m";
    localparam string COLOR_MAGENTA = "\033[35m";
    localparam string COLOR_CYAN = "\033[36m";
    localparam string COLOR_RESET = "\033[0m";

    localparam int AXI_ADDR_WIDTH = 64;
    localparam int AXI_DATA_WIDTH = 64;

    localparam longint TPU_BASE_ADDR = 64'h4000_0000;
    
    // UBUF Address Range (from axi_interface.sv)
    localparam longint UBUF_START_OFFSET = 64'h0000 << 3;
    localparam longint UBUF_END_OFFSET   = 64'h29FF << 3;
    
    localparam longint UBUF_START_ADDR = TPU_BASE_ADDR + UBUF_START_OFFSET;
    localparam longint UBUF_END_ADDR   = TPU_BASE_ADDR + UBUF_END_OFFSET;

    // ICACHE Address Range
    localparam longint ICACHE_START_OFFSET = 64'h2A00 << 3;
    localparam longint ICACHE_END_OFFSET   = 64'h2DFF << 3;
    localparam longint ICACHE_START_ADDR   = TPU_BASE_ADDR + ICACHE_START_OFFSET;
    localparam longint ICACHE_END_ADDR     = TPU_BASE_ADDR + ICACHE_END_OFFSET;

    // STATUS REG Address Range
    localparam longint STATUS_START_OFFSET = 64'h2E00 << 3;
    localparam longint STATUS_REG_EN_ADDR  = TPU_BASE_ADDR + STATUS_START_OFFSET; // Offset 0x0000
    localparam longint STATUS_REG_FINISH_ADDR = TPU_BASE_ADDR + STATUS_START_OFFSET + 8; // Offset 0x0001

    logic                      clk, rstn_i;
    logic                      axi_req_i;
    logic                      axi_we_i;
    logic [AXI_DATA_WIDTH-1:0] axi_rdata_o;
    logic [AXI_DATA_WIDTH-1:0] axi_wdata_i;
    logic [AXI_ADDR_WIDTH-1:0] axi_addr_i;
    
    int error_count;

    tpu i_tpu (
        .clk        (clk),
        .rst        (~rstn_i),
        .axi_req    (axi_req_i),
        .axi_we     (axi_we_i),
        .axi_addr   (axi_addr_i),
        .axi_wdata  (axi_wdata_i),
        .axi_rdata  (axi_rdata_o)
    );

    always #1000 clk = ~clk;

    // Task for AXI write
    task axi_write(input logic [AXI_ADDR_WIDTH-1:0] addr, input logic [AXI_DATA_WIDTH-1:0] data);
        @(posedge clk);
        #200;
        axi_req_i = 1;
        axi_we_i = 1;
        axi_addr_i = addr;
        axi_wdata_i = data;
        @(posedge clk);
        #200;
        axi_req_i = 0;
        axi_we_i = 0;
        axi_wdata_i = '0;
    endtask

    // Task for AXI read
    task axi_read(input logic [AXI_ADDR_WIDTH-1:0] addr, output logic [AXI_DATA_WIDTH-1:0] data);
        @(posedge clk);
        #200;
        axi_req_i = 1;
        axi_we_i = 0;
        axi_addr_i = addr;
        @(posedge clk);
        #200;
        axi_req_i = 0;
        // Wait for data to be valid (1 cycle latency in axi_interface)
        data = axi_rdata_o;
    endtask


    task test_sequential_UB_access();
        $display("%s[TEST] Starting Sequential Access Test...%s", COLOR_YELLOW, COLOR_RESET);
        
        // Write First 128 words
        for (longint addr = UBUF_START_ADDR; addr < UBUF_START_ADDR + (128*8); addr += 8) begin
            logic [63:0] wdata;
            wdata = addr + 64'hA5A5_0000_0000_0000; // Unique pattern per address
            axi_write(addr, wdata);
        end

        // Write Last 128 words
        for (longint addr = UBUF_END_ADDR - (127*8); addr <= UBUF_END_ADDR; addr += 8) begin
            logic [63:0] wdata;
            wdata = addr + 64'h5A5A_0000_0000_0000; // Unique pattern per address
            axi_write(addr, wdata);
        end
        
        $display("%s[INFO] Sequential Write completed.%s", COLOR_CYAN, COLOR_RESET);

        // Verify First 128 words
        for (longint addr = UBUF_START_ADDR; addr < UBUF_START_ADDR + (128*8); addr += 8) begin
            logic [63:0] expected_data;
            logic [63:0] rdata;
            
            expected_data = addr + 64'hA5A5_0000_0000_0000;
            axi_read(addr, rdata);
            
            if (rdata !== expected_data) begin
                $display("%s[FAIL] Addr: 0x%h | Read: 0x%h | Expected: 0x%h%s", 
                         COLOR_RED, addr, rdata, expected_data, COLOR_RESET);
                error_count++;
            end
        end

        // Verify Last 128 words
        for (longint addr = UBUF_END_ADDR - (127*8); addr <= UBUF_END_ADDR; addr += 8) begin
            logic [63:0] expected_data;
            logic [63:0] rdata;
            
            expected_data = addr + 64'h5A5A_0000_0000_0000;
            axi_read(addr, rdata);
            
            if (rdata !== expected_data) begin
                $display("%s[FAIL] Addr: 0x%h | Read: 0x%h | Expected: 0x%h%s", 
                         COLOR_RED, addr, rdata, expected_data, COLOR_RESET);
                error_count++;
            end
        end
        $display("%s[INFO] Sequential Access Test completed.%s", COLOR_CYAN, COLOR_RESET);
    endtask

    task test_random_UB_access(input int count);
        logic [63:0] expected_mem [longint];
        logic [63:0] addr;
        logic [63:0] wdata;
        logic [63:0] rdata;
        
        $display("%s[TEST] Starting Random Access Test (%0d transactions)...%s", COLOR_YELLOW, count, COLOR_RESET);

        // Write phase
        for (int i = 0; i < count; i++) begin
            // Generate random address aligned to 8 bytes within UBUF range
            logic [15:0] word_idx;
            word_idx = $urandom_range(0, 16'h29FF);
            addr = TPU_BASE_ADDR + (longint'(word_idx) * 8);
            
            wdata = {$urandom, $urandom};
            
            axi_write(addr, wdata);
            
            // Store expected data in associative array (handles overwrites correctly)
            expected_mem[addr] = wdata;
        end
        
        $display("%s[INFO] Random Write completed. Verifying...%s", COLOR_CYAN, COLOR_RESET);

        // Read phase
        foreach (expected_mem[idx]) begin
            axi_read(idx, rdata);
            if (rdata !== expected_mem[idx]) begin
                 $display("%s[FAIL] Random Test - Addr: 0x%h | Read: 0x%h | Expected: 0x%h%s", 
                         COLOR_RED, idx, rdata, expected_mem[idx], COLOR_RESET);
                error_count++;
            end
        end

        // Add a few clock cycles
        repeat (10) @(posedge clk);

        $display("%s[INFO] Random Access Test completed.%s", COLOR_CYAN, COLOR_RESET);
    endtask

    task test_icache_access();
        $display("%s[TEST] Starting ICACHE Access Test...%s", COLOR_YELLOW, COLOR_RESET);
        
        // Write Pattern to ICACHE
        for (longint addr = ICACHE_START_ADDR; addr <= ICACHE_END_ADDR; addr += 8) begin
            logic [63:0] wdata;
            // Instructions are 54-bit, so we mask the upper bits to simulate realistic data
            wdata = (addr + 64'hBEEF_0000_0000_0000) & 64'h003F_FFFF_FFFF_FFFF; 
            axi_write(addr, wdata);
        end
        
        $display("%s[INFO] ICACHE Write completed.%s", COLOR_CYAN, COLOR_RESET);

        // Verify ICACHE
        for (longint addr = ICACHE_START_ADDR; addr <= ICACHE_END_ADDR; addr += 8) begin
            logic [63:0] expected_data;
            logic [63:0] rdata;
            
            expected_data = (addr + 64'hBEEF_0000_0000_0000) & 64'h003F_FFFF_FFFF_FFFF;
            axi_read(addr, rdata);
            
            if (rdata !== expected_data) begin
                $display("%s[FAIL] ICACHE - Addr: 0x%h | Read: 0x%h | Expected: 0x%h%s", 
                         COLOR_RED, addr, rdata, expected_data, COLOR_RESET);
                error_count++;
            end
        end
        $display("%s[INFO] ICACHE Access Test completed.%s", COLOR_CYAN, COLOR_RESET);
    endtask

    task test_status_reg_access();
        logic [63:0] wdata;
        logic [63:0] rdata;
        
        $display("%s[TEST] Starting Status Register Access Test...%s", COLOR_YELLOW, COLOR_RESET);

        // Test Global Enable Register (Bit 0)
        // Write 1
        wdata = 64'h1;
        axi_write(STATUS_REG_EN_ADDR, wdata);
        axi_read(STATUS_REG_EN_ADDR, rdata);
        
        if (rdata[0] !== 1'b1) begin
            $display("%s[FAIL] Status Reg EN - Write 1 Failed. Read: 0x%h%s", COLOR_RED, rdata, COLOR_RESET);
            error_count++;
        end else begin
             $display("%s[PASS] Status Reg EN - Write 1 Verified.%s", COLOR_GREEN, COLOR_RESET);
        end

        // Write 0
        wdata = 64'h0;
        axi_write(STATUS_REG_EN_ADDR, wdata);
        axi_read(STATUS_REG_EN_ADDR, rdata);
        
        if (rdata[0] !== 1'b0) begin
            $display("%s[FAIL] Status Reg EN - Write 0 Failed. Read: 0x%h%s", COLOR_RED, rdata, COLOR_RESET);
            error_count++;
        end else begin
             $display("%s[PASS] Status Reg EN - Write 0 Verified.%s", COLOR_GREEN, COLOR_RESET);
        end
        
        $display("%s[INFO] Status Register Access Test completed.%s", COLOR_CYAN, COLOR_RESET);
    endtask

    initial begin
        clk = 1'b1;
        rstn_i = 1'b0;
        axi_req_i = 0;
        axi_we_i = 0;
        axi_addr_i = 0;
        axi_wdata_i = 0;
        error_count = 0;

        #20000;
        rstn_i = 1'b1;
        #10000;

        $display("%s\n========================================", COLOR_BLUE);
        $display("       TPU Unified Buffer Test");
        $display("========================================%s", COLOR_RESET);

        test_sequential_UB_access();
        
        test_random_UB_access(50);

        test_icache_access();

        test_status_reg_access();

        if (error_count == 0) begin
            $display("%s\n[PASS] All UBUF tests passed successfully!%s", COLOR_GREEN, COLOR_RESET);
        end else begin
            $display("%s\n[FAIL] UBUF tests failed with %0d errors.%s", COLOR_RED, error_count, COLOR_RESET);
        end

        $display("\n=== Test Complete ===\n");
        $finish;
    end

    initial begin
        $fsdbDumpfile("waveform.fsdb");
        $fsdbDumpvars("+all");
        $fsdbDumpMDA();
    end

endmodule