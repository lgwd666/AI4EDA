# 流水灯实验验证策略（E4）

本目录验证 E4 讲义中的流水灯时序电路：复位后 `led = 16'h0001`，之后每隔
`CNT_MAX + 1` 个时钟周期循环左移一位。本实验与 `ysyx-workbench/npc/` 中的
通用 Verilator 仿真框架相互独立，可单独运行。

## 1. 文件与职责

| 文件 | 作用 |
| --- | --- |
| `light.v` | 被测 RTL；`CNT_MAX` 默认 5000000，用于 NVBoard 观察 |
| `light_fast.v` | 包装模块，把 `CNT_MAX` 改成 4，供快速仿真 |
| `light_main.cpp` | Verilator 驱动：时钟/复位、C++ 参考模型逐周期比对、可选 FST 波形 |
| `nvboard_light.cpp` | NVBoard 驱动：软件产生时钟，`led[15:0]` 显示到 LD15..LD0 |
| `light.nxdc` | NVBoard 引脚约束 |
| `tb_light.v` | Icarus 自检 testbench，含参考模型、超时保护和 VCD 开关 |
| `Makefile` | `sim` / `wave` / `icarus` / `lint` / `nvboard` / `clean` |

## 2. 验证目标

1. 复位期间 `led` 保持 `16'h0001`，分频计数器为 0。
2. 复位释放后，每 5 个时钟周期（`CNT_MAX = 4`）循环左移一位。
3. 连续 200 个周期内，每个周期的 `led` 与参考模型一致。
4. 200 个周期共移位 40 次，最终 `led = 16'h0100`。
5. `CNT_MAX = 5000000` 的 `light` 能通过 Verilator lint，并能在 NVBoard 上
   正常产生移位。
6. testbench 在失败时返回非零退出码，并有超时保护。

## 3. 测试场景与通过标准

| 场景 | 激励 | 通过标准 |
| --- | --- | --- |
| Verilator 快速仿真 | `light_fast`，复位 10 周期，运行 200 周期 | 每周期 `led` 与 C++ 参考模型一致；退出码 0 |
| Icarus 自检 | `tb_light.v`，复位 10 周期，运行 200 周期 | 无 ERROR；打印 `tb_light PASS`；`shifts = 40`，最终 `led = 0x0100` |
| 静态检查 | `verilator --lint-only -Wall`，分别以 `light`、`light_fast` 为顶层 | 无 error/warning |
| NVBoard | `light`（`CNT_MAX = 5000000`），软件时钟 | 窗口打开；LD15..LD0 中亮灯依次移动 |

## 4. 实际执行命令

```bash
cd AI4EDA-KIMI/rtl/light

make sim        # Verilator 快速仿真
make icarus     # Icarus 自检
make lint       # Verilator 静态检查
make wave       # 生成 build/light_fast.fst 并打开 GTKWave
make nvboard    # 需要 NVBOARD_HOME 和 SDL2 开发包
make clean
```

生成 VCD 波形（Icarus）：

1. 解开 `tb_light.v` 中 `$dumpfile` / `$dumpvars` 两行注释；
2. 重新执行 `make icarus`；
3. 用 `gtkwave tb_light.vcd` 查看。

## 5. 波形关注信号

| 信号 | 预期行为 |
| --- | --- |
| `clk` | 周期 10 ns（Icarus tb）；Verilator 中每个周期两次 dump |
| `rst` | 前 10 个上升沿为高，之后保持低 |
| `led` | 复位值为 `0001`；之后每 5 个上升沿左移一位，16 次后回到 `0001` |
| `count`（内部） | 0..4 循环；为 0 时发生移位 |
| `led[15:0]`（NVBoard） | 同一时刻只有一位为 1，亮灯位置依次移动 |

## 6. 备注

- `light.v` 中的 `CNT_MAX` 是参数，NVBoard 使用默认值 5000000；纯仿真使用
  `light_fast` 的 4，避免运行时间过长。
- Verilator 版本为 Debian 包 5.032；讲义推荐 git stable 版本，二者在本实验
  所需功能上无差异。
