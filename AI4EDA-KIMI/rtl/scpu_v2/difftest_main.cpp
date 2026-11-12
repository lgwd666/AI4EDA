#include "Vdifftest_top.h"
#include "semu.h"
#include <verilated.h>

#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

static Vdifftest_top dut;

static void single_cycle() {
  dut.clk = 0;
  dut.eval();
  dut.clk = 1;
  dut.eval();
}

static void reset() {
  dut.rst_n = 0;
  single_cycle();
  single_cycle();
  dut.rst_n = 1;
}

static uint8_t dut_reg(std::size_t index) {
  switch (index) {
  case 0:
    return dut.gpr0;
  case 1:
    return dut.gpr1;
  case 2:
    return dut.gpr2;
  default:
    return dut.gpr3;
  }
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  const int cycles = argc > 1 ? std::atoi(argv[1]) : 40;
  const uint8_t inject_at =
      argc > 2 ? static_cast<uint8_t>(std::strtoul(argv[2], nullptr, 0)) : 0;
  const uint8_t inject_mask =
      argc > 3 ? static_cast<uint8_t>(std::strtoul(argv[3], nullptr, 0)) : 0;
  if (cycles <= 0) {
    std::fprintf(stderr, "DIFFTEST ERROR: cycles must be positive\n");
    return 2;
  }

  Semu ref;
  std::string error;
  if (!ref.load("sum_io.hex", error)) {
    std::fprintf(stderr, "DIFFTEST ERROR: %s\n", error.c_str());
    return 2;
  }

  ref.set_io(10, 0);
  dut.switches = 10;
  dut.buttons = 0;
  dut.inject_at = inject_at;
  dut.inject_mask = inject_mask;
  reset();

  for (int cycle = 1; cycle <= cycles; ++cycle) {
    const uint8_t before_pc = ref.pc();
    const uint8_t inst = ref.instruction();

    single_cycle();
    ref.step();

    bool mismatch = dut.pc != ref.pc();
    for (std::size_t index = 0; index < 4; ++index) {
      mismatch = mismatch || dut_reg(index) != ref.reg(index);
    }

    if (mismatch) {
      std::fprintf(stderr,
                   "DIFFTEST MISMATCH: cycle=%d before_pc=%u inst=%02x\n",
                   cycle, before_pc, inst);
      std::fprintf(stderr, "PC: dut=%u ref=%u\n", dut.pc, ref.pc());
      for (std::size_t index = 0; index < 4; ++index) {
        std::fprintf(stderr, "R%zu: dut=%u ref=%u\n", index, dut_reg(index),
                     ref.reg(index));
      }
      dut.final();
      return 1;
    }
  }

  const bool pass = ref.pc() == 9 && ref.reg(0) == 10 && ref.reg(1) == 10 &&
                    ref.reg(2) == 55 && ref.reg(3) == 1;
  if (cycles >= 40 && !pass) {
    std::fprintf(stderr, "DIFFTEST FAIL: unexpected reference final state\n");
    dut.final();
    return 2;
  }

  std::printf(
      "DIFFTEST PASS: %d cycles, pc=%u R0=%u R1=%u R2=%u R3=%u\n", cycles,
      ref.pc(), ref.reg(0), ref.reg(1), ref.reg(2), ref.reg(3));
  dut.final();
  return 0;
}
