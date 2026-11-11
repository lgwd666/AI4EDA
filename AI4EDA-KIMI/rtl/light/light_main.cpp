// ============================================================================
// 流水灯（时序逻辑）的 Verilator 仿真驱动
//
// 时序电路需要显式的时钟和复位，这是与组合逻辑仿真的关键区别：
//   single_cycle(): clk 拉低 -> eval -> clk 拉高 -> eval，产生一个上升沿
//   reset(n):        rst 保持 n 个周期，然后释放
//
// 被测顶层是 light_fast（CNT_MAX = 4），每 5 个周期移位一次，
// 因此 200 个周期可以观察到多轮完整移位。C++ 中同步维护一份参考模型，
// 每个周期都与 RTL 的 led 比对。
// ============================================================================
#include <verilated.h>
#include "Vlight_fast.h"

#include <cassert>
#include <cstdint>
#include <cstdio>

#if VM_TRACE
#include <verilated_fst_c.h>
#endif

#ifndef WAVE_FILE
#define WAVE_FILE "build/light_fast.fst"
#endif

// light_fast 内部例化的 light 的参数值（与 vsrc/light_fast.v 保持一致）
static const int kCntMax = 4;

static Vlight_fast* dut;

#if VM_TRACE
static VerilatedFstC* tfp;
static uint64_t sim_time = 0;
#endif

// 产生一个完整时钟周期（一个上升沿）
static void single_cycle() {
  dut->clk = 0;
  dut->eval();
#if VM_TRACE
  tfp->dump(sim_time++);  // 记录 clk 低电平阶段
#endif

  dut->clk = 1;
  dut->eval();
#if VM_TRACE
  tfp->dump(sim_time++);  // 记录 clk 高电平阶段，此时时序逻辑更新
#endif
}

// 复位 n 个周期后释放复位
static void reset(int n) {
  dut->rst = 1;
  while (n-- > 0) single_cycle();
  dut->rst = 0;
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);

  dut = new Vlight_fast;

#if VM_TRACE
  Verilated::traceEverOn(true);
  tfp = new VerilatedFstC;
  dut->trace(tfp, 99);
  tfp->open(WAVE_FILE);
#endif

  reset(10);

  // 复位后 led 应该只有最低位为 1
  assert(dut->led == 0x0001);

  // C++ 参考模型：led_exp 为期望的灯状态，count_exp 为期望的分频计数
  uint16_t led_exp   = 0x0001;
  uint32_t count_exp = 0;

  const int kCycles = 200;
  int shifts = 0;

  for (int c = 1; c <= kCycles; ++c) {
    uint16_t led_before = dut->led;
    single_cycle();

    // ---- 参考模型：与 light.v 的 always 块逐条对应 ----
    if (count_exp == 0) {
      led_exp = static_cast<uint16_t>((led_exp << 1) | (led_exp >> 15));
      ++shifts;
    }
    count_exp = (count_exp >= static_cast<uint32_t>(kCntMax)) ? 0 : count_exp + 1;

    // 比较 RTL 与参考模型
    assert(dut->led == led_exp);

    if (dut->led != led_before) {
      std::printf("周期 %3d：led = 0x%04x（第 %d 次移位）\n",
                  c, static_cast<unsigned>(dut->led), shifts);
    }
  }

  std::printf("流水灯仿真通过：%d 个周期，%d 次移位，最终 led = 0x%04x\n",
              kCycles, shifts, static_cast<unsigned>(dut->led));

  dut->final();

#if VM_TRACE
  tfp->close();
  delete tfp;
#endif

  delete dut;
  return 0;
}
