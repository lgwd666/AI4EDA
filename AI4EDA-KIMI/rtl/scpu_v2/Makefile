# NPC 风格目录：vsrc/ 放 RTL，csrc/ 放仿真器与 C++ 驱动，HEX 留在运行目录。
CXX ?= g++
VERILATOR ?= verilator
CXXFLAGS ?= -O2

BUILD := build
SEMU_BIN := $(BUILD)/semu
DIFF_BIN := $(BUILD)/difftest
DIFF_OBJ := $(BUILD)/obj_difftest
RTL_SRCS := vsrc/dff_pn.sv vsrc/scpu.sv vsrc/difftest_top.sv
SEMU_SRCS := csrc/semu.cpp csrc/semu_main.cpp
DIFF_SRCS := csrc/semu.cpp csrc/difftest_main.cpp
SEMU_HDR := csrc/semu.h

all: test

$(BUILD):
	mkdir -p $@

$(SEMU_BIN): $(SEMU_SRCS) $(SEMU_HDR) | $(BUILD)
	$(CXX) -std=c++17 -Wall -Wextra -Werror $(CXXFLAGS) $(SEMU_SRCS) -o $@

$(DIFF_BIN): $(RTL_SRCS) $(DIFF_SRCS) $(SEMU_HDR) Makefile | $(BUILD)
	$(VERILATOR) --cc --exe --build --top-module difftest_top \
	  -Mdir $(DIFF_OBJ) -o $(abspath $(DIFF_BIN)) \
	  -Wall -Wno-fatal -Wno-DECLFILENAME --x-assign fast --x-initial fast \
	  $(RTL_SRCS) $(DIFF_SRCS) \
	  -CFLAGS "-std=c++17 -Wall -Wextra -Werror $(CXXFLAGS)"

semu: $(SEMU_BIN)
	./$(SEMU_BIN)

difftest: $(DIFF_BIN)
	./$(DIFF_BIN)

fault-gpr: $(DIFF_BIN)
	@./$(DIFF_BIN) 40 5 0x10; status=$$?; \
	if test $$status -eq 1; then \
	  echo "FAULT-GPR PASS: DiffTest detected the injected destination-register error"; \
	else \
	  echo "FAULT-GPR FAIL: mismatch was not detected"; exit 1; \
	fi

fault-pc: $(DIFF_BIN)
	@./$(DIFF_BIN) 40 6 0x04; status=$$?; \
	if test $$status -eq 1; then \
	  echo "FAULT-PC PASS: DiffTest detected the injected branch-offset error"; \
	else \
	  echo "FAULT-PC FAIL: mismatch was not detected"; exit 1; \
	fi

test: semu difftest fault-gpr fault-pc

lint:
	$(VERILATOR) --lint-only -Wall -Wno-DECLFILENAME \
	  --top-module difftest_top $(RTL_SRCS)

clean:
	rm -rf $(BUILD)

.PHONY: all semu difftest fault-gpr fault-pc test lint clean
