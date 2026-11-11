// ============================================================================
// 双控开关（组合逻辑）的 Verilator 仿真驱动
//
// 流程（对应 Verilator 手册中的 C++ 示例）：
//   1. Verilated::commandArgs 把命令行参数交给 Verilator
//   2. new Vtop 创建被测电路（类名 = V + 顶层模块名）
//   3. 给输入端口赋值 -> eval() -> 读取输出端口
//   4. 用 assert 自动比对参考结果
//
// 与讲义示例相比，这里把无限循环改成固定 100 组随机输入，
// 这样不需要 Ctrl+C 也能正常退出，并且可以用退出码表示通过/失败。
// ============================================================================
#include <verilated.h>
#include "Vtop.h"  // 由 Verilator 根据 vsrc/top.v 自动生成

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

#if VM_TRACE
#include <verilated_fst_c.h>  // WAVE=1 时才编译波形支持
#endif

// 波形文件路径；只有 WAVE=1 时才会真正被使用
#ifndef WAVE_FILE
#define WAVE_FILE "build/top.fst"
#endif

int main(int argc, char** argv) {
  // 让 Verilator 处理 +verilator+ 开头的仿真参数
  Verilated::commandArgs(argc, argv);

  Vtop* dut = new Vtop;  // dut = device under test

#if VM_TRACE
  // 打开波形跟踪：99 表示跟踪的最大层次深度
  Verilated::traceEverOn(true);
  VerilatedFstC* tfp = new VerilatedFstC;
  dut->trace(tfp, 99);
  tfp->open(WAVE_FILE);
  uint64_t sim_time = 0;
#endif

  const int kNumTests = 100;
  std::srand(1);  // 固定随机种子，保证失败时可复现

  for (int i = 0; i < kNumTests; ++i) {
    // 随机产生两个 1 bit 输入
    int a = std::rand() & 1;
    int b = std::rand() & 1;

    dut->a = a;
    dut->b = b;
    dut->eval();  // 组合逻辑：输入变化后立即求值

#if VM_TRACE
    tfp->dump(sim_time++);  // 每个测试点对应一个波形时间点
#endif

    std::printf("[%3d] a = %d, b = %d, f = %d\n", i, a, b, dut->f);

    // 自动检查：f 必须等于 a ^ b
    assert(dut->f == (a ^ b));
  }

  dut->final();  // 仿真结束前的清理

#if VM_TRACE
  tfp->close();
  delete tfp;
#endif

  delete dut;

  std::printf("双控开关仿真通过：%d 组随机输入全部满足 f = a ^ b\n",
              kNumTests);
  return 0;
}
