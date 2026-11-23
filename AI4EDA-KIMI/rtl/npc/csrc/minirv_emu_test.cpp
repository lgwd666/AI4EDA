#include "difftest.h"
#include "minirv_emu.h"

#include <array>
#include <cstdint>
#include <cstdio>
#include <vector>

namespace {
uint32_t encode_i(uint32_t imm, uint32_t rs1, uint32_t funct3, uint32_t rd,
                  uint32_t opcode) {
  return ((imm & 0xfff) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) |
         opcode;
}

uint32_t encode_r(uint32_t rs2, uint32_t rs1, uint32_t rd) {
  return (rs2 << 20) | (rs1 << 15) | (rd << 7) | 0x33;
}

uint32_t encode_u(uint32_t imm20, uint32_t rd) {
  return (imm20 << 12) | (rd << 7) | 0x37;
}

uint32_t encode_s(uint32_t imm, uint32_t rs2, uint32_t rs1,
                  uint32_t funct3) {
  return (((imm >> 5) & 0x7f) << 25) | (rs2 << 20) | (rs1 << 15) |
         (funct3 << 12) | ((imm & 0x1f) << 7) | 0x23;
}

std::vector<uint32_t> test_program() {
  return {
      encode_u(0x80000, 1),           // 00: lui x1, 0x80000
      encode_i(20, 0, 0, 10, 0x13),   // 04: addi x10, x0, 20
      encode_i(-5, 0, 0, 2, 0x13),    // 08: addi x2, x0, -5
      encode_r(2, 10, 3),             // 0c: add x3, x10, x2
      encode_u(0x12345, 4),           // 10: lui x4, 0x12345
      encode_i(0x678, 4, 0, 4, 0x13), // 14: addi x4, x4, 0x678
      encode_i(0x100, 1, 0, 5, 0x13), // 18: addi x5, x1, 0x100
      encode_s(0, 4, 5, 2),           // 1c: sw x4, 0(x5)
      encode_i(0, 5, 2, 6, 0x03),     // 20: lw x6, 0(x5)
      encode_i(0, 5, 4, 7, 0x03),     // 24: lbu x7, 0(x5)
      encode_i(1, 5, 4, 8, 0x03),     // 28: lbu x8, 1(x5)
      encode_i(2, 5, 4, 9, 0x03),     // 2c: lbu x9, 2(x5)
      encode_i(3, 5, 4, 10, 0x03),    // 30: lbu x10, 3(x5)
      encode_i(0xef, 0, 0, 11, 0x13), // 34: addi x11, x0, 0xef
      encode_s(0, 11, 5, 0),          // 38: sb x11, 0(x5)
      encode_i(0xcd, 0, 0, 12, 0x13), // 3c: addi x12, x0, 0xcd
      encode_s(1, 12, 5, 0),          // 40: sb x12, 1(x5)
      encode_i(0xab, 0, 0, 13, 0x13), // 44: addi x13, x0, 0xab
      encode_s(2, 13, 5, 0),          // 48: sb x13, 2(x5)
      encode_i(0x90, 0, 0, 14, 0x13), // 4c: addi x14, x0, 0x90
      encode_s(3, 14, 5, 0),          // 50: sb x14, 3(x5)
      encode_i(0, 5, 2, 15, 0x03),    // 54: lw x15, 0(x5)
      encode_i(0x60, 1, 0, 1, 0x67),  // 58: jalr x1, 0x60(x1)
      0x00100073,                     // 5c: ebreak
      encode_i(0, 0, 0, 10, 0x13),    // 60: addi x10, x0, 0
      encode_i(0, 1, 0, 0, 0x67),     // 64: jalr x0, 0(x1)
  };
}

bool check_emulator(const std::vector<uint32_t> &program) {
  MinirvEmu emu;
  emu.load_program(program);
  for (int cycle = 0; cycle < 100 && !emu.halted(); ++cycle) {
    emu.step();
  }

  std::array<uint32_t, MinirvEmu::kRegCount> expected{};
  expected[1] = MinirvEmu::kResetPc + 0x5c;
  expected[2] = 0xfffffffb;
  expected[3] = 15;
  expected[4] = 0x12345678;
  expected[5] = MinirvEmu::kMemoryBase + 0x100;
  expected[6] = 0x12345678;
  expected[7] = 0x78;
  expected[8] = 0x56;
  expected[9] = 0x34;
  expected[10] = 0;
  expected[11] = 0xef;
  expected[12] = 0xcd;
  expected[13] = 0xab;
  expected[14] = 0x90;
  expected[15] = 0x90abcdef;

  if (!emu.halted() || emu.pc() != MinirvEmu::kResetPc + 0x5c ||
      emu.regs() != expected) {
    std::fprintf(stderr, "minirvEMU 指令测试失败\n");
    return false;
  }
  return true;
}

bool check_mismatch_detection(const std::vector<uint32_t> &program) {
  MinirvEmu dut_model;
  dut_model.load_program(program);
  DiffTest difftest;
  difftest.load_program(program);

  if (!difftest.check_state(dut_model.pc(), dut_model.fetch(),
                            dut_model.regs().data())) {
    std::fprintf(stderr, "DiffTest 初始状态检查失败：%s\n",
                 difftest.error().c_str());
    return false;
  }

  dut_model.step();
  std::array<uint32_t, MinirvEmu::kRegCount> wrong_regs = dut_model.regs();
  wrong_regs[1] ^= 1;
  if (difftest.step_and_compare(dut_model.pc(), wrong_regs.data())) {
    std::fprintf(stderr, "DiffTest 未发现注入的 x1 错误\n");
    return false;
  }
  if (difftest.error().find("x1") == std::string::npos) {
    std::fprintf(stderr, "DiffTest 错误信息未指出 x1\n");
    return false;
  }
  return true;
}
} // namespace

int main() {
  const std::vector<uint32_t> program = test_program();
  if (!check_emulator(program) || !check_mismatch_detection(program)) {
    return 1;
  }
  std::printf("minirvEMU TEST PASS: 8 instructions, ebreak and DiffTest mismatch detection\n");
  return 0;
}
