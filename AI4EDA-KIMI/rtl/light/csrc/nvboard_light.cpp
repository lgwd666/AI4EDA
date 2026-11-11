// ============================================================================
// 把流水灯接入 NVBoard（虚拟 FPGA 板卡）
//
// 引脚分配见 light.nxdc：led[15:0] -> LD15..LD0。
// NVBoard 不提供时钟，所以时钟由本文件中的 single_cycle() 软件产生；
// 每个仿真周期调用一次 nvboard_update() 刷新显示。
// ============================================================================
#include <nvboard.h>
#include "Vlight.h"

static Vlight dut;

// 由 NVBoard 的脚本 auto_pin_bind.py 根据 .nxdc 自动生成
void nvboard_bind_all_pins(Vlight* top);

// 产生一个完整时钟周期（一个上升沿）
static void single_cycle() {
  dut.clk = 0;
  dut.eval();
  dut.clk = 1;
  dut.eval();
}

// 复位 n 个周期
static void reset(int n) {
  dut.rst = 1;
  while (n-- > 0) single_cycle();
  dut.rst = 0;
}

int main() {
  nvboard_bind_all_pins(&dut);
  nvboard_init();

  reset(10);

  while (true) {
    nvboard_update();  // 刷新 LED 显示
    single_cycle();    // 推进一个时钟周期
  }
}
