# ============================================================================
# NPC 仿真框架（E4）
#
# 本目录只提供 Verilator 仿真框架，不包含任何具体实验的 RTL / C++ 代码。
# 具体实验按相同目录结构放在 AI4EDA-KIMI/rtl/ 下：
#   rtl/switch/  双控开关（组合逻辑）
#   rtl/light/   流水灯（时序逻辑）
#
# 使用方式：把自己的 RTL 放进 vsrc/、C++ 驱动放进 csrc/，然后
#   make sim [TOP=<顶层模块>] [CSRC=<C++ 驱动>]
#
# 其他命令：
#   make help       查看本说明
#   make wave       生成 FST 波形并用 GTKWave 打开
#   make lint       Verilator -Wall 静态检查
#   make nvboard    接入 NVBoard
#   make clean      清理 build/
# ============================================================================

TOP      ?= NPC
CSRC     ?= csrc/main.cpp csrc/pmem.cpp csrc/minirv_emu.cpp csrc/difftest.cpp
WAVE     ?= 0
NXDC     ?= constr/top.nxdc

BUILD    := build
SUFFIX   := $(if $(filter 1,$(WAVE)),_wave,)
OBJ_DIR  := $(BUILD)/obj_$(TOP)$(SUFFIX)
BIN      := $(BUILD)/$(TOP)$(SUFFIX)
WAVE_FILE := $(BUILD)/$(TOP).fst

VERILATOR ?= verilator
VSRCS     := $(wildcard vsrc/*.v vsrc/*.sv)
CXXFLAGS  ?= -O2

VERILATOR_FLAGS := --cc --exe --build --top-module $(TOP) \
                   -Mdir $(OBJ_DIR) -o $(abspath $(BIN)) \
                   -Wall -Wno-fatal --x-assign fast --x-initial fast \
                   $(VSRCS) $(CSRC) -CFLAGS "$(CXXFLAGS)"

ifeq ($(WAVE),1)
  VERILATOR_FLAGS += --trace-fst
endif

all: help

help:
	@echo "NPC 仿真框架（只含框架，不含具体实验）"
	@echo ""
	@echo "把 RTL 放入 vsrc/、C++ 驱动放入 csrc/ 后："
	@echo "  make sim [TOP=<顶层模块>] [CSRC=<C++ 驱动>]"
	@echo "  make wave | make lint | make nvboard | make clean"
	@echo ""
	@echo "参考实验（目录结构与本框架一致）："
	@echo "  ../../rtl/switch  双控开关"
	@echo "  ../../rtl/light   流水灯"

# 缺少源文件时给出明确提示，而不是让 Verilator 报晦涩错误
check-src:
	@test -n "$(strip $(CSRC))" || { \
	  echo "错误：请用 CSRC=<C++ 驱动> 指定仿真入口"; exit 1; \
	}
	@for src in $(strip $(CSRC)); do \
	  test -f "$$src" || { echo "错误：找不到 C++ 驱动 $$src"; exit 1; }; \
	done
	@test -n "$(VSRCS)" || { \
	  echo "错误：vsrc/ 下没有 RTL 文件"; exit 1; \
	}

# ---- 一键仿真 --------------------------------------------------------------
sim:
	@$(MAKE) --no-print-directory check-src
	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!
	@$(MAKE) --no-print-directory run TOP=$(TOP) CSRC="$(CSRC)"

run: $(BIN)
	@./$(BIN)

$(BIN): $(VSRCS) $(CSRC) Makefile | check-src
	@mkdir -p $(BUILD)
	$(VERILATOR) $(VERILATOR_FLAGS)

# ---- 波形 ------------------------------------------------------------------
wave:
	@$(MAKE) --no-print-directory run WAVE=1
	@echo "波形文件：$(WAVE_FILE)（已尝试启动 gtkwave）"
	@gtkwave $(WAVE_FILE) >/dev/null 2>&1 &

# ---- 静态检查 --------------------------------------------------------------
lint:
	@echo "== Verilator lint: $(TOP) =="
	@$(VERILATOR) --lint-only -Wall -Wno-fatal --top-module $(TOP) $(VSRCS)

# ============================================================================
# NVBoard 接入（引脚约束由 NXDC 指定）
# ============================================================================
ifneq ($(NVBOARD_HOME),)
include $(NVBOARD_HOME)/scripts/nvboard.mk
endif

# NVBoard 驱动默认复用 CSRC；也可单独指定，例如
#   make nvboard NVBOARD_CSRC=csrc/nvboard_main.cpp
NVBOARD_CSRC ?= $(CSRC)
NVBOARD_BIN  := $(BUILD)/$(TOP)_nvboard
NVBOARD_OBJ  := $(BUILD)/obj_nvboard_$(TOP)
NVBOARD_AUTO := $(BUILD)/auto_bind_$(TOP).cpp

$(NVBOARD_AUTO): $(NXDC)
	@mkdir -p $(BUILD)
	python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $< $@

$(NVBOARD_BIN): $(VSRCS) $(NVBOARD_CSRC) $(NVBOARD_AUTO) $(NVBOARD_ARCHIVE) | check-src
	@mkdir -p $(BUILD)
	$(VERILATOR) --cc --exe --build --top-module $(TOP) \
	  -Mdir $(NVBOARD_OBJ) -o $(abspath $(NVBOARD_BIN)) \
	  -Wall -Wno-fatal --x-assign fast --x-initial fast \
	  $(VSRCS) $(NVBOARD_CSRC) $(NVBOARD_AUTO) $(NVBOARD_ARCHIVE) \
	  -CFLAGS "$(CXXFLAGS)" \
	  -CFLAGS "-I$(abspath $(NVBOARD_OBJ))" \
	  -CFLAGS "-I$(NVBOARD_HOME)/usr/include" \
	  -LDFLAGS "$(LDFLAGS)"

nvboard: | check-src
	@test -n "$(NVBOARD_HOME)" || { \
	  echo "错误：NVBOARD_HOME 未设置，请先运行 bash init.sh nvboard 并重新登录"; \
	  exit 1; \
	}
	@$(MAKE) --no-print-directory run-nvboard

run-nvboard: $(NVBOARD_BIN)
	@./$(NVBOARD_BIN)

test: $(BUILD)/minirv_emu_test
	@./$(BUILD)/minirv_emu_test

$(BUILD)/minirv_emu_test: csrc/minirv_emu_test.cpp csrc/minirv_emu.cpp csrc/difftest.cpp
	@mkdir -p $(BUILD)
	g++ -std=c++17 -O2 -Wall -Wextra -Icsrc $^ -o $@

clean:
	rm -rf $(BUILD)

.PHONY: all help check-src sim run wave lint nvboard run-nvboard test clean

# 引入框架提供的 git_commit 宏；必须放在文件末尾，且不要删除
include ../Makefile
