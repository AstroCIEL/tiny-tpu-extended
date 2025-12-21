`timescale 1ns/1ps

module tb_tpu;

    // =========================================================================
    // 信号定义
    // =========================================================================
    logic        clk;
    logic        rst;
    
    // AXI 接口信号
    logic        axi_req;
    logic        axi_we;
    logic [63:0] axi_addr;
    logic [63:0] axi_wdata;
    logic [63:0] axi_rdata;

    // =========================================================================
    // 参数与地址映射 (基于 axi_interface.sv 分析)
    // =========================================================================
    // TPU Base: 0x4000_0000 [cite: 190]
    // Status Base (Internal): 0x2E00 -> AXI Offset: 0x2E00 << 3 = 0x17000
    localparam bit [63:0] TPU_BASE_ADDR   = 64'h4000_0000;
    
    // 寄存器地址计算：(Base + Internal_Offset) << 3
    // Reg Enable (Internal 0x0) -> 0x4001_7000
    localparam bit [63:0] ADDR_REG_ENABLE = TPU_BASE_ADDR + (64'h2E00 << 3); 
    
    // Reg Finish (Internal 0x1) -> 0x4001_7008
    localparam bit [63:0] ADDR_REG_FINISH = TPU_BASE_ADDR + ((64'h2E00 + 1) << 3); 
    
    // Result/Input Memory Base -> 0x4000_0000
    localparam bit [63:0] ADDR_MEM_RESULT = TPU_BASE_ADDR; 

    // =========================================================================
    // DUT 实例化
    // =========================================================================
    tpu u_tpu (
        .clk        (clk),
        .rst        (rst),
        .axi_req    (axi_req),
        .axi_we     (axi_we),
        .axi_addr   (axi_addr),
        .axi_wdata  (axi_wdata),
        .axi_rdata  (axi_rdata)
    );

    // =========================================================================
    // 时钟生成 (100MHz)
    // =========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =========================================================================
    // AXI 总线任务 (Bus Functional Model)
    // =========================================================================
    
    // AXI 写任务
    task axi_write(input [63:0] addr, input [63:0] data);
        begin
            @(posedge clk);
            axi_req   <= 1'b1;
            axi_we    <= 1'b1;
            axi_addr  <= addr;
            axi_wdata <= data;
            
            @(posedge clk);
            // 单周期请求，下一拍拉低 [cite: 208]
            axi_req   <= 1'b0;
            axi_we    <= 1'b0;
            axi_addr  <= '0;
            axi_wdata <= '0;
        end
    endtask

    // AXI 读任务
    task axi_read(input [63:0] addr, output [63:0] data);
        begin
            @(posedge clk);
            axi_req   <= 1'b1;
            axi_we    <= 1'b0; // 读模式
            axi_addr  <= addr;
            
            @(posedge clk);
            axi_req   <= 1'b0;
            axi_addr  <= '0;

            // 等待读取延迟。设计中 axi_req_q 延迟一拍，读取逻辑基于 _q 信号 [cite: 210]
            // 数据应该在 req 拉低后的当拍或者下一拍有效，这里简单等待一拍
            @(posedge clk); 
            data = axi_rdata;
        end
    endtask

    // =========================================================================
    // 主测试流程
    // =========================================================================
    logic [63:0] read_val;
    integer timeout_counter;

    initial begin
        // 0. 初始化信号
        axi_req   = 0;
        axi_we    = 0;
        axi_addr  = 0;
        axi_wdata = 0;
        
        // 1. 复位
        $display("[TB] System Reset...");
        rst = 1;
        repeat(20) @(posedge clk);
        rst = 0;
        repeat(10) @(posedge clk);

        // 2. 启动 TPU
        $display("[TB] Writing Global Enable (Addr: %h)...", ADDR_REG_ENABLE);
        axi_write(ADDR_REG_ENABLE, 64'h1);

        // 3. 轮询 Finish 标志
        $display("[TB] Polling Finish Flag (Addr: %h)...", ADDR_REG_FINISH);
        timeout_counter = 0;
        
        forever begin
            axi_read(ADDR_REG_FINISH, read_val);
            
            if (read_val[0] == 1'b1) begin
                $display("[TB] TPU Process Finished! (Flag detected at cycle %0t)", $time);
                break;
            end
            
            timeout_counter++;
            if (timeout_counter > 100000) begin // 超时保护
                $error("[TB] Error: Timeout waiting for finish flag!");
                $finish;
            end
            
            repeat(10) @(posedge clk); // 每隔 10 个周期查询一次
        end

        // 4. (可选) 读回部分结果
        // 假设结果写回到了 Input Memory 的起始位置
        $display("[TB] Reading Result Memory...");
        axi_read(ADDR_MEM_RESULT, read_val);
        $display("[TB] Result at 0x00: %h", read_val);
        
        axi_read(ADDR_MEM_RESULT + 8, read_val); // +8 bytes
        $display("[TB] Result at 0x08: %h", read_val);

        repeat(20) @(posedge clk);
        $display("[TB] Simulation Completed Successfully.");
        $finish;
    end

    // =========================================================================
    // Verdi 波形 Dump (FSDB)
    // =========================================================================
    initial begin
        // 指定输出波形文件名
        $fsdbDumpfile("tpu_wave.fsdb");
        // 0 表示 dump 所有层次，tb_top 是顶层模块名
        $fsdbDumpvars("+all");
        // 如果想 dump 数组（Unified Buffer需要），需要加上这个
        $fsdbDumpMDA(); 
    end

endmodule