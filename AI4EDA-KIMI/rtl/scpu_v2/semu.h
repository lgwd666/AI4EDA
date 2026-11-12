#ifndef SCPU_V2_SEMU_H
#define SCPU_V2_SEMU_H

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>

class Semu {
public:
  Semu();

  bool load(const std::string &path, std::string &error);
  void reset();
  void set_io(uint8_t switches, uint8_t buttons);
  void step();

  uint8_t pc() const { return pc_; }
  uint8_t reg(std::size_t index) const { return regs_.at(index); }
  uint8_t instruction() const { return memory_[pc_]; }

private:
  std::array<uint8_t, 256> memory_{};
  std::array<uint8_t, 4> regs_{};
  uint8_t pc_ = 0;
  uint8_t switches_ = 0;
  uint8_t buttons_ = 0;
};

#endif
