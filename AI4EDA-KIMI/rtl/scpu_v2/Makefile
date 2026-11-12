CXX ?= g++
VERILATOR ?= verilator
CXXFLAGS ?= -O2

BUILD := build
SEMU_BIN := $(BUILD)/semu
DIFF_BIN := $(BUILD)/difftest
DIFF_OBJ := $(BUILD)/obj_difftest
RTL_SRCS := dff_pn.sv scpu.sv difftest_top.sv

all: test

$(BUILD):
	mkdir -p $@

$(SEMU_BIN): semu.cpp semu.h semu_main.cpp | $(BUILD)
	$(CXX) -std=c++17 -Wall -Wextra -Werror $(CXXFLAGS) semu.cpp semu_main.cpp -o $@

$(DIFF_BIN): $(RTL_SRCS) semu.cpp semu.h difftest_main.cpp Makefile | $(BUILD)
	$(VERILATOR) --cc --exe --build --top-module difftest_top \
	  -Mdir $(DIFF_OBJ) -o $(abspath $(DIFF_BIN)) \
	  -Wall -Wno-fatal -Wno-DECLFILENAME --x-assign fast --x-initial fast \
	  $(RTL_SRCS) semu.cpp difftest_main.cpp \
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
