#ifndef NPC_PMEM_H
#define NPC_PMEM_H

#include <cstdint>
#include <vector>

void pmem_reset();
void pmem_load(uint32_t addr, const std::vector<uint32_t> &words);
uint32_t pmem_peek32(uint32_t addr);

#endif
