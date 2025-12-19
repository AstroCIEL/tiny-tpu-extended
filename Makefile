# ================= CONFIGURATION =================
# Simulator to use
SIM ?= vcs

# Directory configurations
SIM_BUILD_DIR = sim_build
SIM_BIN = $(SIM_BUILD_DIR)/simv

# Get Cocotb variables
# 获取 cocotb 针对 VCS 的 VPI 库路径
COCOTB_VPI_LIB = $(shell cocotb-config --lib-name-path vpi vcs)

# Environment variables for Cocotb
export COCOTB_REDUCED_LOG_FMT=1
export LIBPYTHON_LOC=$(shell cocotb-config --libpython)
export PYTHONPATH := test:$(PYTHONPATH)

# ================= SOURCES =================
SOURCES = src/ctrl_and_mem/axi_interface.sv \
          src/ctrl_and_mem/control_unit.sv \
          src/ctrl_and_mem/instruction_cache.sv \
          src/ctrl_and_mem/status_reg.sv \
          src/ctrl_and_mem/systolic_data_rearranger_FIFO.sv \
          src/ctrl_and_mem/systolic_data_rearranger.sv \
          src/ctrl_and_mem/unified_buffer.sv \
          src/systolic_array/int.sv \
          src/systolic_array/pe.sv \
          src/systolic_array/systolic.sv \
          src/systolic_array/systolic_array_4x16x16.sv \
          src/vpu/vpu.sv \
          src/vpu/pipe_register.sv \
          src/vpu/vpe_adder.sv \
          src/vpu/vpe_bias.sv \
          src/vpu/vpe_dequanter.sv \
          src/vpu/vpe_psum_cache.sv \
          src/vpu/vpe_relu.sv \
          src/vpu/vpe.sv \
          src/vpu/vpu_channel.sv \
          src/tpu.sv

# ================= VCS FLAGS =================
# -full64: 64位模式
# -sverilog: 启用 SystemVerilog 支持
# -timescale: 设置时间精度（防止未定义的 timescale 警告）
# -debug_access+all: 开启调试能力（这对 dump 波形和 cocotb 访问信号至关重要）
# -load: 加载 Cocotb 的 VPI 库
VCS_FLAGS = -full64 -sverilog -timescale=1ns/1ps \
            -debug_access+all \
            -load $(COCOTB_VPI_LIB)

# ================= TARGETS =================

.PHONY: test_tpu clean

test_tpu: $(SIM_BUILD_DIR)
	# 1. Compilation Step
	vcs $(VCS_FLAGS) -o $(SIM_BIN) \
		$(SOURCES) test/dump_tpu.sv

	# 2. Execution Step
	# 直接运行生成的 simv 可执行文件，传入 MODULE 环境变量
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_tpu $(SIM_BIN)
	
	# 3. Waveform Handling (Optional)
	# 检查结果并移动波形
	! grep failure results.xml
	@if [ -f tpu.vcd ]; then mv tpu.vcd waveforms/ 2>/dev/null; echo "Waveform moved to waveforms/"; fi
	@if [ -f tpu.fsdb ]; then mv tpu.fsdb waveforms/ 2>/dev/null; echo "FSDB moved to waveforms/"; fi

$(SIM_BUILD_DIR):
	mkdir -p $(SIM_BUILD_DIR)

clean:
	rm -rf $(SIM_BUILD_DIR)
	rm -rf csrc *.daidir *.key simv* *.vpd *.fsdb results.xml __pycache__