# ============================================================================
# 双控开关实验（E4 示例：组合逻辑电路）
#
# 目录结构与 npc 框架一致：
#   vsrc/    RTL 源文件
#   csrc/    C++ 仿真驱动
#   constr/  NVBoard 引脚约束
#   build/   生成物
#
# 常用命令：
#   make sim        Verilator 仿真（100 组随机输入 + assert）
#   make wave       生成 FST 波形并用 GTKWave 打开
#   make icarus     Icarus Verilog 仿真（tb_top.v，穷举 4 种输入）
#   make lint       Verilator -Wall 静态检查
#   make nvboard    接入 NVBoard（SW0/SW1 -> LD0）
#   make clean      清理 build/
# ============================================================================

TOP      ?= top
CSRC     ?= csrc/main.cpp
WAVE     ?= 0
NXDC     ?= constr/top.nxdc

BUILD    := build
SUFFIX   := $(if $(filter 1,$(WAVE)),_wave,)
OBJ_DIR  := $(BUILD)/obj_$(TOP)$(SUFFIX)
BIN      := $(BUILD)/$(TOP)$(SUFFIX)

VERILATOR ?= verilator
VSRCS     := $(wildcard vsrc/*.v)
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
	@echo "波形文件：build/top.fst（已尝试启动 gtkwave）"
	@gtkwave build/top.fst >/dev/null 2>&1 &

# ---- Icarus Verilog 穷举检查 -----------------------------------------------
# tb_top.v 中的 $dumpfile/$dumpvars 默认注释；生成 VCD 时解注释后重新运行
$(BUILD)/tb_top: tb_top.v $(VSRCS)
	@mkdir -p $(BUILD)
	iverilog -g2012 -Wall -o $@ $^

icarus: $(BUILD)/tb_top
	@vvp $(BUILD)/tb_top

# ---- 静态检查 --------------------------------------------------------------
lint:
	@echo "== Verilator lint: top =="
	@$(VERILATOR) --lint-only -Wall --top-module top $(VSRCS)

# ============================================================================
# NVBoard 接入：a -> SW0, b -> SW1, f -> LD0
# ============================================================================
ifneq ($(NVBOARD_HOME),)
include $(NVBOARD_HOME)/scripts/nvboard.mk
endif

NVBOARD_CSRC ?= csrc/nvboard_top.cpp
NVBOARD_BIN  := $(BUILD)/top_nvboard
NVBOARD_OBJ  := $(BUILD)/obj_nvboard_top
NVBOARD_AUTO := $(BUILD)/auto_bind_top.cpp

$(NVBOARD_AUTO): $(NXDC)
	@mkdir -p $(BUILD)
	python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $< $@

$(NVBOARD_BIN): $(VSRCS) $(NVBOARD_CSRC) $(NVBOARD_AUTO) $(NVBOARD_ARCHIVE)
	@mkdir -p $(BUILD)
	$(VERILATOR) --cc --exe --build --top-module $(TOP) \
	  -Mdir $(NVBOARD_OBJ) -o $(abspath $(NVBOARD_BIN)) \
	  -Wall -Wno-fatal --x-assign fast --x-initial fast \
	  $(VSRCS) $(NVBOARD_CSRC) $(NVBOARD_AUTO) $(NVBOARD_ARCHIVE) \
	  -CFLAGS "$(CXXFLAGS)" \
	  -CFLAGS "-I$(abspath $(NVBOARD_OBJ))" \
	  -CFLAGS "-I$(NVBOARD_HOME)/usr/include" \
	  -LDFLAGS "$(LDFLAGS)"

nvboard:
	@test -n "$(NVBOARD_HOME)" || { \
	  echo "错误：NVBOARD_HOME 未设置，请先运行 bash init.sh nvboard 并重新登录"; \
	  exit 1; \
	}
	@test -f "$(NVBOARD_CSRC)" || { \
	  echo "错误：找不到 NVBoard 驱动 $(NVBOARD_CSRC)"; exit 1; \
	}
	@$(MAKE) --no-print-directory run-nvboard

run-nvboard: $(NVBOARD_BIN)
	@./$(NVBOARD_BIN)

clean:
	rm -rf $(BUILD)

.PHONY: all sim run wave icarus lint nvboard run-nvboard clean
