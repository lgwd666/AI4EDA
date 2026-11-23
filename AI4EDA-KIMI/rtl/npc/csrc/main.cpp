#include "VNPC.h"
#include "difftest.h"
#include "pmem.h"
#include <verilated.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <fstream>
#include <vector>

#if VM_TRACE
#include <verilated_fst_c.h>
#endif

static VNPC dut;

#if VM_TRACE
static VerilatedFstC tfp;
static uint64_t sim_time = 0;
#endif

static std::vector<uint32_t> load_program(const char *path) {
  std::ifstream file(path, std::ios::binary | std::ios::ate);
  if (!file) {
    std::fprintf(stderr, "无法打开程序文件：%s\n", path);
    std::exit(EXIT_FAILURE);
  }

  const std::streamsize size = file.tellg();
  if (size <= 0) {
    std::fprintf(stderr, "程序文件为空或无法读取：%s\n", path);
    std::exit(EXIT_FAILURE);
  }

  file.seekg(0, std::ios::beg);
  std::vector<uint8_t> bytes(static_cast<std::size_t>(size));
  if (!file.read(reinterpret_cast<char *>(bytes.data()), size)) {
    std::fprintf(stderr, "读取程序文件失败：%s\n", path);
    std::exit(EXIT_FAILURE);
  }

  std::vector<uint32_t> words((bytes.size() + 3) / 4, 0);
  for (std::size_t i = 0; i < bytes.size(); ++i) {
    words[i / 4] |= static_cast<uint32_t>(bytes[i]) << ((i % 4) * 8);
  }
  return words;
}

static void dump() {
#if VM_TRACE
  tfp.dump(sim_time++);
#endif
}

static void single_cycle() {
  dut.clk = 0;
  dut.eval();
  dump();
  dut.clk = 1;
  dut.eval();
  dump();
}

static void reset() {
  dut.rst_n = 0;
  single_cycle();
  single_cycle();
  dut.rst_n = 1;
  dut.eval();
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  if (argc != 2) {
    std::fprintf(stderr, "用法：%s <program.bin>\n", argv[0]);
    return EXIT_FAILURE;
  }
  const char *program_path = argv[1];

#if VM_TRACE
  Verilated::traceEverOn(true);
  dut.trace(&tfp, 99);
  tfp.open("build/NPC.fst");
#endif

  const std::vector<uint32_t> program = load_program(program_path);
  pmem_reset();
  pmem_load(0, program);

  DiffTest difftest;
  difftest.load_program(program);
  reset();

  bool halted = false;
  bool diff_passed = true;
  constexpr uint64_t max_cycles = 100000000;
  try {
    for (uint64_t cycle = 0; cycle < max_cycles; ++cycle) {
      if (!difftest.check_state(dut.debug_pc, dut.debug_inst,
                                &dut.debug_regs[0])) {
        std::fprintf(stderr, "DIFFTEST FAIL: %s\n%s", difftest.error().c_str(),
                     difftest.history().c_str());
        diff_passed = false;
        break;
      }

      if (dut.debug_inst == 0x00100073) {
        halted = true;
        break;
      }

      single_cycle();
      if (!difftest.step_and_compare(dut.debug_pc, &dut.debug_regs[0])) {
        std::fprintf(stderr, "DIFFTEST FAIL: %s\n%s", difftest.error().c_str(),
                     difftest.history().c_str());
        diff_passed = false;
        break;
      }
    }
  } catch (const std::exception &error) {
    std::fprintf(stderr, "MINIRV EMU ERROR: %s\n", error.what());
    diff_passed = false;
  }

  bool good_trap = false;
  if (!diff_passed) {
    // 比较器已经输出具体差异，进程最后返回非零。
  } else if (!halted) {
    std::fprintf(stderr, "NPC TEST FAIL: ebreak not reached, pc=0x%08x\n",
                 dut.debug_pc);
  } else if (dut.debug_regs[10] == 0) {
    std::printf("HIT GOOD TRAP: pc=0x%08x, a0=0\n", dut.debug_pc);
    good_trap = true;
  } else {
    std::printf("HIT BAD TRAP: pc=0x%08x, a0=0x%08x\n", dut.debug_pc,
                dut.debug_regs[10]);
  }

  dut.final();
#if VM_TRACE
  tfp.close();
#endif
  return good_trap ? EXIT_SUCCESS : EXIT_FAILURE;
}
