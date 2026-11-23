#include "difftest.h"

#include <iomanip>
#include <sstream>

namespace {
std::string mismatch_message(const char *stage, uint32_t pc, uint32_t inst,
                             const std::string &item, uint32_t dut,
                             uint32_t ref) {
  std::ostringstream out;
  out << stage << "：pc=0x" << std::hex << std::setw(8) << std::setfill('0')
      << pc << " inst=0x" << std::setw(8) << inst << " " << item
      << "，DUT=0x" << std::setw(8) << dut << "，REF=0x" << std::setw(8)
      << ref;
  return out.str();
}
} // namespace

void DiffTest::load_program(const std::vector<uint32_t> &words) {
  emu_.load_program(words);
  error_.clear();
  history_count_ = 0;
  history_next_ = 0;
}

bool DiffTest::compare_pc(uint32_t dut_pc, const char *stage, uint32_t pc,
                          uint32_t inst) {
  if (dut_pc == emu_.pc()) {
    return true;
  }
  error_ = mismatch_message(stage, pc, inst, "下一 PC 不一致", dut_pc,
                            emu_.pc());
  return false;
}

bool DiffTest::compare_regs(const uint32_t *dut_regs, uint32_t pc,
                            uint32_t inst) {
  for (std::size_t i = 0; i < MinirvEmu::kRegCount; ++i) {
    if (dut_regs[i] != emu_.regs()[i]) {
      error_ = mismatch_message("DiffTest", pc, inst,
                                "x" + std::to_string(i) + " 不一致",
                                dut_regs[i], emu_.regs()[i]);
      return false;
    }
  }
  return true;
}

void DiffTest::record(uint32_t pc, uint32_t inst) {
  history_[history_next_] = {pc, inst};
  history_next_ = (history_next_ + 1) % kHistorySize;
  if (history_count_ < kHistorySize) {
    ++history_count_;
  }
}

std::string DiffTest::history() const {
  std::ostringstream out;
  out << "最近执行记录（旧 → 新）：\n";
  if (history_count_ == 0) {
    out << "  （无）\n";
    return out.str();
  }

  for (std::size_t i = 0; i < history_count_; ++i) {
    const std::size_t index =
        (history_next_ + kHistorySize - history_count_ + i) % kHistorySize;
    out << "  pc=0x" << std::hex << std::setw(8) << std::setfill('0')
        << history_[index].pc << " inst=0x" << std::setw(8)
        << history_[index].inst << '\n';
  }
  return out.str();
}

bool DiffTest::check_state(uint32_t dut_pc, uint32_t dut_inst,
                           const uint32_t *dut_regs) {
  error_.clear();
  const uint32_t ref_inst = emu_.fetch();
  if (!compare_pc(dut_pc, "执行前 PC 检查", emu_.pc(), ref_inst)) {
    return false;
  }

  if (dut_inst != ref_inst) {
    error_ = mismatch_message("取指检查", dut_pc, dut_inst, "指令不一致",
                              dut_inst, ref_inst);
    return false;
  }
  return compare_regs(dut_regs, dut_pc, dut_inst);
}

bool DiffTest::step_and_compare(uint32_t dut_pc, const uint32_t *dut_regs) {
  error_.clear();
  const uint32_t pc = emu_.pc();
  const uint32_t inst = emu_.fetch();
  record(pc, inst);
  emu_.step();

  if (!compare_pc(dut_pc, "执行后 PC 检查", pc, inst)) {
    return false;
  }
  return compare_regs(dut_regs, pc, inst);
}
