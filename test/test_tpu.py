import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# AXI 地址定义 (根据 axi_interface.sv 计算)
TPU_BASE_ADDR = 0x40000000
STATUS_BASE_OFFSET = 0x2E00 << 3
# 寄存器地址
REG_ENABLE_ADDR  = TPU_BASE_ADDR + STATUS_BASE_OFFSET + 0x00 # 0x40017000
REG_FINISH_ADDR  = TPU_BASE_ADDR + STATUS_BASE_OFFSET + 0x08 # 0x40017008
# 结果读回地址 (Input Memory Base)
MEM_RESULT_ADDR  = TPU_BASE_ADDR + 0x0000                    # 0x40000000

class TPUDriver:
    def __init__(self, dut):
        self.dut = dut
        self.dut.axi_req.value = 0
        self.dut.axi_we.value = 0
        self.dut.axi_addr.value = 0
        self.dut.axi_wdata.value = 0

    async def reset(self):
        """复位逻辑"""
        self.dut.rst.value = 1
        await Timer(100, units="ns")
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        self.dut._log.info("Reset complete")

    async def axi_write(self, addr, data):
        """模拟 AXI 写操作"""
        await RisingEdge(self.dut.clk)
        self.dut.axi_req.value = 1
        self.dut.axi_we.value = 1
        self.dut.axi_addr.value = addr
        self.dut.axi_wdata.value = data
        
        await RisingEdge(self.dut.clk)
        # 单周期请求，下一拍拉低
        self.dut.axi_req.value = 0
        self.dut.axi_we.value = 0
        self.dut.axi_addr.value = 0
        self.dut.axi_wdata.value = 0

    async def axi_read(self, addr):
        """模拟 AXI 读操作"""
        await RisingEdge(self.dut.clk)
        self.dut.axi_req.value = 1
        self.dut.axi_we.value = 0
        self.dut.axi_addr.value = addr
        
        await RisingEdge(self.dut.clk)
        self.dut.axi_req.value = 0
        self.dut.axi_addr.value = 0
        
        # axi_interface 中读数据有 1 cycle latency (axi_req_q)
        # 此时 axi_req_q 为高，axi_rdata 应该在当前拍或下一拍有效
        # 查看代码：axi_rdata 是组合逻辑依赖 axi_req_q (DFF输出)，所以在这个周期末尾数据应该有效
        # 或者在下一拍读取
        await RisingEdge(self.dut.clk) 
        return self.dut.axi_rdata.value.integer

@cocotb.test()
async def tpu_top_test(dut):
    """TPU 顶层验证流程"""
    
    # 1. 启动时钟 (10ns period -> 100MHz)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    driver = TPUDriver(dut)
    
    # 2. 复位
    dut._log.info("Starting Reset...")
    await driver.reset()
    
    # 3. 启动 TPU (Write Global Enable = 1)
    dut._log.info(f"Writing Enable to addr 0x{REG_ENABLE_ADDR:X}...")
    await driver.axi_write(REG_ENABLE_ADDR, 1)
    
    # 4. 轮询直到完成 (Poll Finish Flag)
    dut._log.info("Polling Finish Flag...")
    max_cycles = 5000 # 防止死循环的超时设置
    cycles = 0
    while True:
        finish_flag = await driver.axi_read(REG_FINISH_ADDR)
        if finish_flag == 1:
            dut._log.info(f"TPU Finished after approx {cycles} polling cycles!")
            break
        
        cycles += 1
        if cycles >= max_cycles:
            raise TimeoutError("TPU execution timed out! Finish flag never asserted.")
        
        # 等待几个时钟周期再查询
        for _ in range(10): 
            await RisingEdge(dut.clk)

    # 5. (可选) 读回结果进行验证
    # 假设结果被写回到了 Input Memory 的起始地址 (0x40000000)
    # 并且假设我们知道预期的结果是什么（这里仅打印读到的值）
    dut._log.info("Reading Calculation Result...")
    
    # 读取前几个地址的数据
    for i in range(4):
        addr = MEM_RESULT_ADDR + (i * 8) # 每个地址 64-bit 偏移8字节 (注意 axi_interface 寻址是对齐的)
        # 注意: 内部 addr_in_TPU = axi_addr[18:3]，所以外部地址加 8，内部地址加 1
        result = await driver.axi_read(addr)
        dut._log.info(f"Result at Address 0x{addr:X}: 0x{result:016X}")

    dut._log.info("Testbench completed successfully.")