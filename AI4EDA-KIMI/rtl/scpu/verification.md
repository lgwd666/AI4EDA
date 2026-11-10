# sCPU 验证策略

## 验证目标

验证 RTL 符合 F5 的 sISA 约定：8 位 PC 从 0 开始，4 个 8 位 GPR 支持双读单写，`li`、`add` 和 `bner0` 的运算、写回及下一 PC 行为正确。

## 测试场景

`tb_scpu.sv` 加载 `sum.hex` 中的 F5 数列求和程序，覆盖：

- 复位后 PC 为 0。
- `li` 将 4 位立即数零扩展后写入指定 GPR。
- `add` 同时读取两个源寄存器并写回 8 位和。
- `bner0` 条件成立时跳回地址 4，条件不成立时进入地址 7。
- 地址 7 的自循环持续执行时，PC 保持不变。
- 100 个时钟内未得到结果则判定超时失败。

## 通过标准

程序到达 PC=7 时，必须满足 `R0=10`、`R1=10`、`R2=55`、`R3=1`；随后再执行 3 个时钟，PC 必须保持为 7。testbench 输出 `PASS` 且进程返回码为 0。

Verilator lint 不得报告警告或错误；Yosys `check` 不得报告结构问题。

## 执行命令

在本目录执行：

```bash
verilator --lint-only --Wall -Wno-DECLFILENAME --top-module scpu scpu.sv
verilator --lint-only --Wall -Wno-DECLFILENAME --top-module scpu_rom scpu.sv
iverilog -g2012 -s tb_scpu -o tb_scpu.vvp scpu.sv tb_scpu.sv
vvp tb_scpu.vvp
yosys -p 'read_verilog -sv scpu.sv; hierarchy -check -top scpu; proc; check'
```

`tb_scpu.vvp` 是仿真构建产物，验证后删除，不提交到仓库。
