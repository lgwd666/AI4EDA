#ifndef NPC_DIFFTEST_H
#define NPC_DIFFTEST_H

#include "minirv_emu.h"

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

class DiffTest {
public:
  void load_program(const std::vector<uint32_t> &words);

  bool check_state(uint32_t dut_pc, uint32_t dut_inst,
                   const uint32_t *dut_regs);
  bool step_and_compare(uint32_t dut_pc, const uint32_t *dut_regs);

  const std::string &error() const { return error_; }
  std::string history() const;

private:
  struct TraceEntry {
    uint32_t pc;
    uint32_t inst;
  };

  static constexpr std::size_t kHistorySize = 16;

  bool compare_pc(uint32_t dut_pc, const char *stage, uint32_t pc,
                  uint32_t inst);
  bool compare_regs(const uint32_t *dut_regs, uint32_t pc, uint32_t inst);
  void record(uint32_t pc, uint32_t inst);

  MinirvEmu emu_;
  std::string error_;
  std::array<TraceEntry, kHistorySize> history_{};
  std::size_t history_count_ = 0;
  std::size_t history_next_ = 0;
};

#endif
