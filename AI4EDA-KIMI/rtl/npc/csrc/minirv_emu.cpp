#include "minirv_emu.h"

#include <iomanip>
#include <sstream>
#include <stdexcept>

namespace {
constexpr uint32_t kOpcodeLoad = 0x03;
constexpr uint32_t kOpcodeOpImm = 0x13;
constexpr uint32_t kOpcodeStore = 0x23;
constexpr uint32_t kOpcodeOp = 0x33;
constexpr uint32_t kOpcodeLui = 0x37;
constexpr uint32_t kOpcodeJalr = 0x67;
constexpr uint32_t kEbreak = 0x00100073;

[[noreturn]] void throw_error(const char *message, uint32_t value) {
  std::ostringstream out;
  out << message << " 0x" << std::hex << std::setw(8) << std::setfill('0')
      << value;
  throw std::runtime_error(out.str());
}
} // namespace

MinirvEmu::MinirvEmu() : memory_(kMemorySize, 0) {}

void MinirvEmu::load_program(const std::vector<uint32_t> &words) {
  regs_.fill(0);
  memory_.assign(kMemorySize, 0);
  if (words.size() * sizeof(uint32_t) > memory_.size()) {
    throw std::runtime_error("程序超过存储器容量");
  }
  for (std::size_t i = 0; i < words.size(); ++i) {
    for (std::size_t byte = 0; byte < sizeof(uint32_t); ++byte) {
      memory_[i * sizeof(uint32_t) + byte] =
          static_cast<uint8_t>(words[i] >> (byte * 8));
    }
  }
  pc_ = kResetPc;
  halted_ = false;
}

uint32_t MinirvEmu::sign_extend(uint32_t value, unsigned width) {
  const uint32_t sign = 1u << (width - 1);
  return (value ^ sign) - sign;
}

std::size_t MinirvEmu::memory_offset(uint32_t addr, std::size_t size) {
  if (addr < kMemoryBase) {
    throw_error("数据地址越界：", addr);
  }
  const uint32_t offset = addr - kMemoryBase;
  if (offset > kMemorySize || size > kMemorySize - offset) {
    throw_error("数据地址越界：", addr);
  }
  return offset;
}

uint32_t MinirvEmu::read_reg(uint32_t index) const {
  if (index >= kRegCount) {
    throw_error("minirv 寄存器编号越界：", index);
  }
  return regs_[index];
}

void MinirvEmu::write_reg(uint32_t index, uint32_t value) {
  if (index >= kRegCount) {
    throw_error("minirv 寄存器编号越界：", index);
  }
  if (index != 0) {
    regs_[index] = value;
  }
}

uint8_t MinirvEmu::read8(uint32_t addr) const {
  return memory_[memory_offset(addr, 1)];
}

uint32_t MinirvEmu::read32(uint32_t addr) const {
  if ((addr & 0x3) != 0) {
    throw_error("未对齐的 32 位读地址：", addr);
  }
  const std::size_t offset = memory_offset(addr, 4);
  uint32_t value = 0;
  for (std::size_t i = 0; i < 4; ++i) {
    value |= static_cast<uint32_t>(memory_[offset + i]) << (i * 8);
  }
  return value;
}

void MinirvEmu::write8(uint32_t addr, uint8_t value) {
  memory_[memory_offset(addr, 1)] = value;
}

void MinirvEmu::write32(uint32_t addr, uint32_t value) {
  if ((addr & 0x3) != 0) {
    throw_error("未对齐的 32 位写地址：", addr);
  }
  const std::size_t offset = memory_offset(addr, 4);
  for (std::size_t i = 0; i < 4; ++i) {
    memory_[offset + i] = static_cast<uint8_t>(value >> (i * 8));
  }
}

uint32_t MinirvEmu::fetch() const {
  if ((pc_ & 0x3) != 0) {
    throw_error("未对齐的取指地址：", pc_);
  }
  if (pc_ < kResetPc) {
    throw_error("取指地址越界：", pc_);
  }
  const uint32_t offset = pc_ - kResetPc;
  if (offset > memory_.size() ||
      sizeof(uint32_t) > memory_.size() - offset) {
    throw_error("取指地址越界：", pc_);
  }
  return read32(pc_);
}

void MinirvEmu::step() {
  if (halted_) {
    throw std::runtime_error("模拟器已经停止，不能继续执行");
  }

  const uint32_t inst = fetch();
  if (inst == kEbreak) {
    halted_ = true;
    return;
  }

  const uint32_t opcode = inst & 0x7f;
  const uint32_t rd = (inst >> 7) & 0x1f;
  const uint32_t funct3 = (inst >> 12) & 0x7;
  const uint32_t rs1 = (inst >> 15) & 0x1f;
  const uint32_t rs2 = (inst >> 20) & 0x1f;
  const uint32_t funct7 = inst >> 25;
  const uint32_t imm_i = sign_extend(inst >> 20, 12);
  const uint32_t imm_s =
      sign_extend(((inst >> 25) << 5) | ((inst >> 7) & 0x1f), 12);
  uint32_t next_pc = pc_ + 4;

  switch (opcode) {
  case kOpcodeOpImm:
    if (funct3 != 0) {
      throw_error("不支持的 OP-IMM 指令：", inst);
    }
    write_reg(rd, read_reg(rs1) + imm_i);
    break;
  case kOpcodeJalr: {
    if (funct3 != 0) {
      throw_error("不支持的 JALR 指令：", inst);
    }
    const uint32_t target = (read_reg(rs1) + imm_i) & ~1u;
    write_reg(rd, pc_ + 4);
    next_pc = target;
    break;
  }
  case kOpcodeOp:
    if (funct3 != 0 || funct7 != 0) {
      throw_error("不支持的 OP 指令：", inst);
    }
    write_reg(rd, read_reg(rs1) + read_reg(rs2));
    break;
  case kOpcodeLui:
    write_reg(rd, inst & 0xfffff000);
    break;
  case kOpcodeLoad: {
    const uint32_t addr = read_reg(rs1) + imm_i;
    if (funct3 == 2) {
      write_reg(rd, read32(addr));
    } else if (funct3 == 4) {
      write_reg(rd, read8(addr));
    } else {
      throw_error("不支持的 LOAD 指令：", inst);
    }
    break;
  }
  case kOpcodeStore: {
    const uint32_t addr = read_reg(rs1) + imm_s;
    if (funct3 == 2) {
      write32(addr, read_reg(rs2));
    } else if (funct3 == 0) {
      write8(addr, static_cast<uint8_t>(read_reg(rs2)));
    } else {
      throw_error("不支持的 STORE 指令：", inst);
    }
    break;
  }
  default:
    throw_error("不支持的指令：", inst);
  }

  pc_ = next_pc;
  regs_[0] = 0;
}
