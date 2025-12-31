# ==============================================================================
# 工具定义
# ==============================================================================
VCS     = vcs
VERDI   = verdi
SIMV    = ./simv

# ==============================================================================
# 编译与仿真选项
# ==============================================================================
# -full64          : 64位模式
# -sverilog        : 支持 SystemVerilog 语法
# -debug_access+all: 开启所有调试权限 (Verdi 需要)
# -kdb             : 生成 Knowledge Database (Verdi 需要)
# -timescale       : 设置默认时间精度
# -l <log>         : 指定日志文件
VCS_FLAGS = -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps -l comp.log +define+LOAD_TXT

# 仿真运行时的选项
SIM_FLAGS = -l sim.log

# ==============================================================================
# 文件列表
# ==============================================================================
# 假设你的新 SV Testbench 放在 test 目录下，名为 tb_tpu.sv
DUT = tpu
TB_SOURCE = ../test/$(DUT)_tb.sv

# RTL 源文件 (保持原本的目录结构)
RTL_SOURCES = ../src/ctrl_and_mem/axi_interface.sv \
              ../src/ctrl_and_mem/control_unit.sv \
              ../src/ctrl_and_mem/instruction_cache.sv \
              ../src/ctrl_and_mem/status_reg.sv \
              ../src/ctrl_and_mem/systolic_data_rearranger_FIFO.sv \
              ../src/ctrl_and_mem/systolic_data_rearranger.sv \
              ../src/ctrl_and_mem/unified_buffer.sv \
              ../src/systolic_array/int.sv \
              ../src/systolic_array/pe.sv \
              ../src/systolic_array/systolic.sv \
              ../src/systolic_array/systolic_array_4x16x16.sv \
              ../src/vpu/vpu.sv \
              ../src/vpu/pipe_register.sv \
              ../src/vpu/vpe_adder.sv \
              ../src/vpu/vpe_bias.sv \
              ../src/vpu/vpe_dequanter.sv \
              ../src/vpu/vpe_psum_cache.sv \
              ../src/vpu/vpe_relu.sv \
              ../src/vpu/vpe.sv \
              ../src/vpu/vpu_channel.sv \
              ../src/tpu.sv

# ==============================================================================
# 伪目标 (Phony Targets)
# ==============================================================================
.PHONY: all comp run wave clean help

# 默认目标：编译并仿真
all: comp run wave

# 编译目标
comp:
	@echo "--- Compiling with VCS ---"
	$(VCS) $(VCS_FLAGS) $(RTL_SOURCES) $(TB_SOURCE) -o $(SIMV)

# 仿真目标
run:
	@echo "--- Running Simulation ---"
	$(SIMV) $(SIM_FLAGS)

# 查看波形目标 (前提是 TB 中生成了 tpu_wave.fsdb)
wave:
	@echo "--- Opening Verdi ---"
	$(VERDI) -ssf $(DUT)_wave.fsdb -nologo &

# 清理目标
clean:
	@echo "--- Cleaning up ---"
	rm -rf csrc simv simv.daidir *.log *.fsdb ucli.key vc_hdrs.h verdiLog novas.*

help:
	@echo "Available targets:"
	@echo "  make comp   - Compile the design"
	@echo "  make run    - Run the simulation"
	@echo "  make wave   - Open waveform in Verdi"
	@echo "  make clean  - Remove generated files"
	@echo "  make all    - Compile and Run (Default)"
