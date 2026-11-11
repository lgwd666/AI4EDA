// ============================================================================
// 把双控开关接入 NVBoard（虚拟 FPGA 板卡）
//
// 引脚分配见 constr/top.nxdc：
//   拨码开关 SW0 -> a
//   拨码开关 SW1 -> b
//   LED      LD0 -> f
//
// NVBoard 的输入信号需要先 nvboard_update() 从界面同步到 RTL 端口，
// 再 eval() 求值，最后再 update 一次把输出显示到 LED 上。
// ============================================================================
#include <nvboard.h>
#include "Vtop.h"

static Vtop dut;

// 由 NVBoard 的脚本 auto_pin_bind.py 根据 .nxdc 自动生成
void nvboard_bind_all_pins(Vtop* top);

int main() {
  nvboard_bind_all_pins(&dut);
  nvboard_init();

  while (true) {
    nvboard_update();  // 读取拨码开关，写入 dut.a / dut.b
    dut.eval();        // 组合逻辑立即求值
    nvboard_update();  // 把新的 dut.f 显示到 LED
  }
}
