#include "pmem.h"

#include <array>
#include <cstdio>
#include <cstdlib>

namespace {
constexpr uint32_t kPmemSize = 128 * 1024 * 1024;
constexpr uint32_t kImemBase = 0;
constexpr uint32_t kDmemBase = 0x80000000;
using Memory = std::array<uint8_t, kPmemSize>;

Memory pmem;

uint32_t aligned_offset(uint32_t addr, uint32_t base, const char *name) {
  if (addr < base) {
    std::fprintf(stderr, "%s ERROR: address 0x%08x is out of range\n", name,
                 addr);
    std::abort();
  }

  const uint32_t offset = (addr - base) & ~0x3u;
  if (offset > kPmemSize - 4) {
    std::fprintf(stderr, "%s ERROR: address 0x%08x is out of range\n", name,
                 addr);
    std::abort();
  }
  return offset;
}

uint32_t read32(const Memory &memory, uint32_t offset) {
  uint32_t value = 0;
  for (uint32_t i = 0; i < 4; ++i) {
    value |= static_cast<uint32_t>(memory[offset + i]) << (i * 8);
  }
  return value;
}
} // namespace

void pmem_reset() { pmem.fill(0); }

void pmem_load(uint32_t addr, const std::vector<uint32_t> &words) {
  for (uint32_t word : words) {
    const uint32_t offset = aligned_offset(addr, kImemBase, "IMEM");
    for (uint32_t i = 0; i < 4; ++i) {
      pmem[offset + i] = static_cast<uint8_t>(word >> (i * 8));
    }
    addr += 4;
  }
}

uint32_t pmem_peek32(uint32_t addr) {
  return read32(pmem, aligned_offset(addr, kDmemBase, "DMEM"));
}

extern "C" int pmem_read(int raddr) {
  const uint32_t addr = static_cast<uint32_t>(raddr);
  return static_cast<int>(
      read32(pmem, aligned_offset(addr, kDmemBase, "DMEM")));
}

// wmask 的低 4 位分别控制 wdata 的 4 个字节，其他字节保持不变。
extern "C" void pmem_write(int waddr, int wdata, char wmask) {
  const uint32_t addr = static_cast<uint32_t>(waddr);
  const uint32_t offset = aligned_offset(addr, kDmemBase, "DMEM");
  const uint32_t data = static_cast<uint32_t>(wdata);
  const uint8_t mask = static_cast<uint8_t>(wmask);
  for (uint32_t i = 0; i < 4; ++i) {
    if ((mask & (1u << i)) != 0) {
      pmem[offset + i] = static_cast<uint8_t>(data >> (i * 8));
    }
  }
}
