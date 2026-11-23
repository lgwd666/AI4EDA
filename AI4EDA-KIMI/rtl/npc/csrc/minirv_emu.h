#ifndef NPC_MINIRV_EMU_H
#define NPC_MINIRV_EMU_H

#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>

class MinirvEmu {
public:
  static constexpr uint32_t kResetPc = 0x80000000;
  static constexpr uint32_t kMemoryBase = 0x80000000;
  static constexpr std::size_t kMemorySize = 128 * 1024 * 1024;
  static constexpr std::size_t kRegCount = 16;

  MinirvEmu();

  void load_program(const std::vector<uint32_t> &words);
  uint32_t fetch() const;
  void step();

  uint32_t pc() const { return pc_; }
  bool halted() const { return halted_; }
  const std::array<uint32_t, kRegCount> &regs() const { return regs_; }

private:
  static uint32_t sign_extend(uint32_t value, unsigned width);
  static std::size_t memory_offset(uint32_t addr, std::size_t size);

  uint32_t read_reg(uint32_t index) const;
  void write_reg(uint32_t index, uint32_t value);
  uint8_t read8(uint32_t addr) const;
  uint32_t read32(uint32_t addr) const;
  void write8(uint32_t addr, uint8_t value);
  void write32(uint32_t addr, uint32_t value);

  std::array<uint32_t, kRegCount> regs_{};
  std::vector<uint8_t> memory_;
  uint32_t pc_ = kResetPc;
  bool halted_ = false;
};

#endif
