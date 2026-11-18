#include "semu.h"

#include <fstream>
#include <stdexcept>

Semu::Semu() { reset(); }

bool Semu::load(const std::string &path, std::string &error) {
  std::ifstream input(path);
  if (!input) {
    error = "cannot open " + path;
    return false;
  }

  memory_.fill(0);
  std::size_t address = 0;
  std::string word;
  try {
    while (input >> word) {
      if (address >= memory_.size()) {
        error = path + " contains more than 256 instructions";
        return false;
      }
      std::size_t consumed = 0;
      const unsigned long value = std::stoul(word, &consumed, 16);
      if (consumed != word.size() || value > 0xff) {
        error = "invalid byte '" + word + "' in " + path;
        return false;
      }
      memory_[address++] = static_cast<uint8_t>(value);
    }
  } catch (const std::exception &) {
    error = "invalid byte '" + word + "' in " + path;
    return false;
  }

  reset();
  return true;
}

void Semu::reset() {
  regs_.fill(0);
  pc_ = 0;
}

void Semu::set_io(uint8_t switches, uint8_t buttons) {
  switches_ = switches;
  buttons_ = buttons;
}

// 每次调用执行一条指令；uint8_t 截断对应 sISA 的 8 位数据与 PC 回绕。
void Semu::step() {
  const uint8_t inst = memory_[pc_];
  const uint8_t rd = (inst >> 4) & 0x3;
  const uint8_t rs1 = (inst >> 2) & 0x3;
  const uint8_t rs2 = inst & 0x3;
  uint8_t next_pc = static_cast<uint8_t>(pc_ + 1);

  // 高两位是 opcode；各指令再按 sISA 格式解释剩余字段。
  switch (inst >> 6) {
  case 0:
    regs_[rd] = static_cast<uint8_t>(regs_[rs1] + regs_[rs2]);
    break;
  case 1:
    if ((inst & 0x8) == 0) {
      const uint8_t index = inst & 0x7;
      regs_[rd] = index == 0 ? switches_ : index == 1 ? buttons_ : 0;
    }
    break;
  case 2:
    regs_[rd] = static_cast<uint8_t>(rs2 << (rs1 * 2));
    break;
  case 3:
    if (regs_[0] != regs_[rs2]) {
      uint8_t offset = static_cast<uint8_t>((inst >> 2) & 0xf);
      if ((offset & 0x8) != 0) {
        offset = static_cast<uint8_t>(offset | 0xf0);
      }
      next_pc = static_cast<uint8_t>(pc_ + offset);
    }
    break;
  }

  pc_ = next_pc;
}
