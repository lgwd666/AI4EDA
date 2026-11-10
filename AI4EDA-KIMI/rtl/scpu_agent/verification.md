# scpu（F5 sum 程序）验证说明

## 1. 验证目标

验证单周期 scpu 的以下规格：

- 8 位 PC，异步低有效复位（`rst_n=0` 时 PC 与 4 个 GPR 清零）。
- 4 个 8 位 GPR，R0 不是恒零，可被 `add/li` 写入。
- 8 位指令译码：`00 add`、`10 li`、`11 bner0`，其余 opcode 顺序执行且不写 GPR。
- `bner0`：`R[0] != R[instr[1:0]]` 时 `PC = {4'b0, instr[5:2]}`，否则 `PC+1`；分支不写 GPR。
- 256×8 ROM 通过 `$readmemh("sum.hex")` 加载 F5 程序。
- 执行 F5 程序后达到：`PC=7`、`R0=10`、`R1=10`、`R2=55`、`R3=1`，并在 `bner0 r3,7` 上自循环。

## 2. 测试环境与文件

| 文件 | 作用 |
| --- | --- |
| `scpu.sv` | RTL 实现（可综合） |
| `sum.hex` | F5 程序机器码，8 个字 |
| `tb_scpu.sv` | 自检查 testbench |
| `verification.md` | 本文件 |

工具版本：Verilator 5.032、Icarus Verilog 12.0、Yosys 0.52。

## 3. 指令与程序轨迹（预期值）

| 地址 | 机器码 | 汇编 | 效果 |
| --- | --- | --- | --- |
| 0 | `8a` | `li r0,10` | R0=10 |
| 1 | `90` | `li r1,0` | R1=0 |
| 2 | `a0` | `li r2,0` | R2=0 |
| 3 | `b1` | `li r3,1` | R3=1 |
| 4 | `17` | `add r1,r1,r3` | R1=R1+1 |
| 5 | `29` | `add r2,r2,r1` | R2=R2+R1 |
| 6 | `d1` | `bner0 r1,4` | R1!=10 时跳回 4，否则 PC=7 |
| 7 | `df` | `bner0 r3,7` | R0=10 != R3=1，PC 恒为 7 |

前 4 条指令执行完后：`PC=4, R0=10, R1=0, R2=0, R3=1`。
循环执行 10 次（R1：1→10），R2 依次累加 1+2+…+10=55。
第 10 次到 PC=6 时 R1=10，分支不成立，PC=7。总执行周期数为 4+3×10=34。
到 PC=7 后 `df` 恒跳转到自身，PC 保持 7，GPR 不再变化。

## 4. 测试场景

1. **复位检查**：`rst_n=0` 后不等待时钟沿立即检查 `PC=0`、`R0..R3=0`，
   再保持两个时钟确认复位期间状态不变。
2. **前段执行检查**：释放复位后，在首次采样到 `PC=4` 时检查 4 条 `li` 的结果
   （R0=10、R1=0、R2=0、R3=1）。
3. **循环与结束检查**：逐周期采样直到 `PC=7`；检查恰好 34 个周期到达，
   并检查最终 `PC=7, R0=10, R1=10, R2=55, R3=1`。
4. **自循环检查**：在 `PC=7` 继续运行 5 个周期，检查 PC 始终为 7 且 GPR 不变。
5. **二次复位检查**：再次拉低 `rst_n`，立即检查 PC 与所有 GPR 清零（异步复位），
   再保持两个周期确认。
6. **超时保护**：200 个周期内未到达 `PC=7` 则判失败并结束，避免死循环挂起。
7. **波形开关**：`$dumpfile`/`$dumpvars` 默认注释（`tb_scpu.sv:32-33`），
   解注释后重新编译运行即可生成 `tb_scpu.vcd`。

## 5. 通过标准

- 所有 `[PASS]` 检查通过，无 `[FAIL]`，仿真打印 `TEST PASSED`，`vvp` 返回 0。
- 到达 PC=7 的周期数等于 34。
- PC=7 后的 5 个周期内 PC 与 GPR 保持不变。
- Verilator lint 无 warning/error；Yosys 结构检查 0 problems。

## 6. 实际执行命令与结果

在当前目录 `AI4EDA-KIMI/rtl/scpu_agent/` 下执行（`sum.hex` 通过相对路径读取，
因此 `vvp` 必须在包含 `sum.hex` 的目录中运行）：

```bash
verilator --lint-only -Wall --top-module scpu scpu.sv
```

结果：退出码 0，无 warning/error。

```bash
iverilog -g2012 -Wall -o tb_scpu.vvp scpu.sv tb_scpu.sv
vvp tb_scpu.vvp
```

结果：编译无 warning；仿真 34 条 `[PASS]`、0 条 `[FAIL]`，打印 `TEST PASSED`，
`$finish` 于 440000（1ps），`vvp` 退出码 0。关键输出：

```text
[TRACE] cycle=34 pc=7 R0=10 R1=10 R2=55 R3=1
[PASS] PC reaches 7 after 34 cycles
[PASS] final: PC = 7
[PASS] final: R0 = 10
[PASS] final: R1 = 10
[PASS] final: R2 = 55
[PASS] final: R3 = 1
[PASS] self-loop: PC stays 7   (共 5 次)
[PASS] second reset: PC = 0
...
TEST PASSED
tb_scpu.sv:126: $finish called at 440000 (1ps)
```

```bash
yosys -p "read_verilog -sv scpu.sv; synth -top scpu; check; stat"
```

结果：退出码 0，`check` 报 0 problems；综合后 0 个 memory、305 个 cell
（`$_ANDNOT_` 116、`$_OR_` 43、`$_MUX_` 34、`$_DFFE_PN0P_` 32、`$_NOT_` 28、
`$_XOR_` 25、`$_DFF_PN0_` 8 等），说明 ROM 与 GPR 已映射为普通逻辑/触发器。

清理生成物：

```bash
rm -rf tb_scpu.vvp tb_scpu.vcd sim.log yosys.log obj_dir
```

说明：`sum.hex` 只包含 8 个字，ROM 其余地址为 X。这是预期行为；
F5 程序只访问 0~7，综合时 Yosys 把未初始化字视为 don't-care，因此逻辑被优化，
不影响本程序的功能正确性。

## 7. 波形关注信号与预期行为

解注释 `tb_scpu.sv:32-33` 后重新编译运行，用 GTKWave 打开 `tb_scpu.vcd`。
建议观察：

| 信号 | 预期行为 |
| --- | --- |
| `clk`, `rst_n` | 周期 10 ns；`rst_n` 低有效异步复位，复位段 PC/GPR 立即清零 |
| `pc[7:0]` | 复位为 0；0→1→2→3→4→5→6→4… 循环；第 34 拍变为 7 后保持 7 |
| `dut.instr[7:0]` | 依次为 8a,90,a0,b1,17,29,d1,df；PC=7 时恒为 df |
| `dut.gpr[0]` | PC=0 执行后变为 10，之后不再变化 |
| `dut.gpr[1]` | 0→1→2→…→10，每 3 拍加 1；到 10 后保持 |
| `dut.gpr[2]` | 1,3,6,10,15,21,28,36,45,55，最终 55 |
| `dut.gpr[3]` | 保持 1 |
| `dut.gpr_we` | `li/add` 时为 1；`bner0` 时为 0（不写 GPR） |
| `dut.branch_taken` | PC=6 时在 R1=1..9 为 1，R1=10 时为 0；PC=7 时恒为 1 |
| `dut.pc_next` | 顺序指令为 pc+1；分支成立时为 4 或 7 |

关键时间点：

- 复位释放后的第 1 个上升沿取指 `8a`，此后每拍执行一条指令。
- PC 从 6 跳回 4 的瞬间，`branch_taken=1`、`gpr_we=0`。
- 第 34 拍进入 PC=7；之后 `branch_taken=1` 且 `pc_next=7`，形成自循环。
