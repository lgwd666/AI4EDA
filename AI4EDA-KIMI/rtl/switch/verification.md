# 双控开关实验验证策略（E4）

本目录验证 E4 讲义中的组合逻辑示例：两个开关 `a`、`b` 联合控制一盏灯，
`f = a ^ b`。实验目录结构与 `ysyx-workbench/npc/` 的仿真框架一致，可独立运行。

## 1. 文件与职责

| 文件 | 作用 |
| --- | --- |
| `vsrc/top.v` | 被测 RTL：`assign f = a ^ b` |
| `csrc/main.cpp` | Verilator 驱动：100 组随机输入 + `assert` 自动检查，可选 FST 波形 |
| `csrc/nvboard_top.cpp` | NVBoard 驱动：拨码开关驱动 `a`/`b`，LED 显示 `f` |
| `constr/top.nxdc` | NVBoard 引脚约束：`a -> SW0`、`b -> SW1`、`f -> LD0` |
| `tb_top.v` | Icarus 自检 testbench，穷举 4 种输入，含超时保护 |
| `Makefile` | `sim` / `wave` / `icarus` / `lint` / `nvboard` / `clean` |

## 2. 验证目标

1. 4 种输入组合下 `f` 都等于 `a ^ b`。
2. 100 组随机输入下 Verilator 驱动中的 `assert` 不触发。
3. `top` 通过 Verilator `-Wall` 静态检查。
4. NVBoard 上拨动 SW0 或 SW1，LD0 状态翻转。
5. testbench 失败时返回非零退出码，并有超时保护。

## 3. 测试场景与通过标准

| 场景 | 激励 | 通过标准 |
| --- | --- | --- |
| Verilator 随机仿真 | 100 组随机 `a`、`b` | 每组 `f == a ^ b`；退出码 0 |
| Icarus 穷举 | `tb_top.v`，00/01/10/11 | 无 ERROR；打印 `tb_top PASS` |
| 静态检查 | `verilator --lint-only -Wall` | 无 error/warning |
| NVBoard | 手动拨动 SW0/SW1 | LD0 随异或结果亮灭 |

## 4. 实际执行命令

```bash
cd AI4EDA-KIMI/rtl/switch

make sim        # Verilator 随机仿真
make icarus     # Icarus 穷举自检
make lint       # Verilator 静态检查
make wave       # 生成 build/top.fst 并打开 GTKWave
make nvboard    # 需要 NVBOARD_HOME 和 SDL2 开发包
make clean
```

生成 VCD 波形（Icarus）：

1. 解开 `tb_top.v` 中 `$dumpfile` / `$dumpvars` 两行注释；
2. 重新执行 `make icarus`；
3. 用 `gtkwave tb_top.vcd` 查看。

## 5. 波形关注信号

| 信号 | 预期行为 |
| --- | --- |
| `a`、`b` | 每个测试点取 00、01、10、11 之一 |
| `f` | 与 `a ^ b` 一致；`a`、`b` 相同时为 0，不同时为 1 |

组合逻辑没有时钟，Verilator 驱动中每个测试点对应一个波形时间点。

## 6. 备注

- `vsrc/top.v` 使用 `assign` 数据流建模，不包含时序逻辑。
- 本实验的 NVBoard 输入直接来自拨码开关，不需要软件产生时钟。
