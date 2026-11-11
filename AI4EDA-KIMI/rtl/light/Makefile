# ============================================================================
# 流水灯实验（E4 示例：时序逻辑电路）
#
# 常用命令：
#   make sim        Verilator 仿真（light_fast，200 周期自动比对）
#   make wave       生成 FST 波形并用 GTKWave 打开
#   make icarus     Icarus Verilog 仿真（tb_light.v，自检）
#   make lint       Verilator -Wall 静态检查
#   make nvboard    接入 NVBoard（light，CNT_MAX=5000000）
#   make clean      清理 build/
#
# 说明：
#   light.v      被测 RTL，CNT_MAX 默认 5000000，用于 NVBoard 观察
#   light_fast.v 把 CNT_MAX 改成 4 的包装，供快速仿真使用
# ============================================================================

TOP      ?= light_fast
CSRC     ?= light_main.cpp
WAVE     ?= 0

BUILD    := build
SUFFIX   := $(if $(filter 1,$(WAVE)),_wave,)
OBJ_DIR  := $(BUILD)/obj_$(TOP)$(SUFFIX)
BIN      := $(BUILD)/$(TOP)$(SUFFIX)

VERILATOR ?= verilator
VSRCS     := light.v light_fast.v
CXXFLAGS  ?= -O2

VERILATOR_FLAGS := --cc --exe --build --top-module $(TOP) \
                   -Mdir $(OBJ_DIR) -o $(abspath $(BIN)) \
                   -Wall -Wno-fatal --x-assign fast --x-initial fast \
                   $(VSRCS) $(CSRC) -CFLAGS "$(CXXFLAGS)"

ifeq ($(WAVE),1)
  VERILATOR_FLAGS += --trace-fst
endif

all: sim

sim: run

run: $(BIN)
	@./$(BIN)

$(BIN): $(VSRCS) $(CSRC) Makefile
	@mkdir -p $(BUILD)
	$(VERILATOR) $(VERILATOR_FLAGS)

# ---- 波形 ------------------------------------------------------------------
wave:
	@$(MAKE) --no-print-directory run WAVE=1
	@echo "波形文件：build/light_fast.fst（已尝试启动 gtkwave）"
	@gtkwave build/light_fast.fst >/dev/null 2>&1 &

# ---- Icarus Verilog 自检 ---------------------------------------------------
# tb_light.v 中的 $dumpfile/$dumpvars 默认注释；生成 VCD 时解注释后重新运行
$(BUILD)/tb_light: tb_light.v light.v light_fast.v
	@mkdir -p $(BUILD)
	iverilog -g2012 -Wall -o $@ $^

icarus: $(BUILD)/tb_light
	@vvp $(BUILD)/tb_light

# ---- 静态检查 --------------------------------------------------------------
lint:
	@for m in light light_fast; do \
	  echo "== Verilator lint: $$m =="; \
	  $(VERILATOR) --lint-only -Wall --top-module $$m $(VSRCS) || exit 1; \
	done

# ============================================================================
# NVBoard 接入：led[15:0] -> LD15..LD0
# ============================================================================
ifneq ($(NVBOARD_HOME),)
include $(NVBOARD_HOME)/scripts/nvboard.mk
endif

NVBOARD_BIN  := $(BUILD)/light_nvboard
NVBOARD_OBJ  := $(BUILD)/obj_nvboard_light
NVBOARD_AUTO := $(BUILD)/auto_bind_light.cpp

$(NVBOARD_AUTO): light.nxdc
	@mkdir -p $(BUILD)
	python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $< $@

$(NVBOARD_BIN): $(VSRCS) nvboard_light.cpp $(NVBOARD_AUTO) $(NVBOARD_ARCHIVE)
	@mkdir -p $(BUILD)
	$(VERILATOR) --cc --exe --build --top-module light \
	  -Mdir $(NVBOARD_OBJ) -o $(abspath $(NVBOARD_BIN)) \
	  -Wall -Wno-fatal --x-assign fast --x-initial fast \
	  $(VSRCS) nvboard_light.cpp $(NVBOARD_AUTO) $(NVBOARD_ARCHIVE) \
	  -CFLAGS "$(CXXFLAGS)" \
	  -CFLAGS "-I$(abspath $(NVBOARD_OBJ))" \
	  -CFLAGS "-I$(NVBOARD_HOME)/usr/include" \
	  -LDFLAGS "$(LDFLAGS)"

nvboard:
	@test -n "$(NVBOARD_HOME)" || { \
	  echo "错误：NVBOARD_HOME 未设置，请先运行 bash init.sh nvboard 并重新登录"; \
	  exit 1; \
	}
	@$(MAKE) --no-print-directory run-nvboard

run-nvboard: $(NVBOARD_BIN)
	@./$(NVBOARD_BIN)

clean:
	rm -rf $(BUILD)

.PHONY: all sim run wave icarus lint nvboard run-nvboard clean
