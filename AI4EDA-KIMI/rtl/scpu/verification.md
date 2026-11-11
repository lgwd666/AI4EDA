# sCPU 验证策略

## 验证对象

本目录的验证分为两层，均不依赖触发器内部实现：

| 层级 | 被测模块 | testbench | 验证重点 |
| --- | --- | --- | --- |
| 单元级 | `dff_pn`（默认 1 位实例 + 8 位参数化实例） | `tb_dff_pn.sv` | 低有效异步复位、非零复位值、复位优先、仅上升沿采样、向量整体采样、默认参数兼容性 |
| 系统级 | `scpu`（含 `scpu_gpr`、`scpu_rom`） | `tb_scpu.sv` | F5 求和程序的指令语义、控制流和最终状态，以及复位后确定性重跑 |

系统级通过层次路径 `dut.u_gpr.regs[0..3]` 观察 GPR 的架构状态，不依赖 `gen_gpr`、`u_dff_pn` 等内部实例名，也不检查单个触发器的赋值方式。

## RTL 结构与参数

### dff_pn

```systemverilog
module dff_pn #(
    parameter integer WIDTH = 1,
    parameter logic [WIDTH-1:0] RESET_VALUE = {WIDTH{1'b0}}
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
```

- `WIDTH`：数据与状态的位宽，默认 1。
- `RESET_VALUE`：`rst_n` 低有效异步复位时载入 `q` 的值，默认全 0。
- 行为：`rst_n` 下降沿（异步）立即令 `q <= RESET_VALUE`，复位优先于时钟；复位释放后 `q` 保持，直到 `clk` 上升沿整体采样 `d`。
- 不传参数时 `WIDTH=1`、`RESET_VALUE=1'b0`，与原单比特零复位单元完全等价。

### scpu 中的实例

`scpu.sv` 共例化 **5 个** `dff_pn`，参数均为 `WIDTH=8`、`RESET_VALUE=8'h00`：

| 路径 | 数量 | 作用 |
| --- | --- | --- |
| `dut.u_pc_dff` | 1 | 8 位 PC |
| `dut.u_gpr.gen_gpr[0..3].u_dff_pn` | 4 | 4 个 8 位 GPR（`dut.u_gpr.regs[0..3]` 可观察） |

`scpu_gpr` 用 `generate` 为每个寄存器生成一个 `dff_pn`：写使能命中时 `d` 为写数据，否则回环自身；4 个寄存器共用 `rst_n`，异步复位后 GPR 全部为 0。Yosys 会把参数完全相同的 5 个实例合并成一个参数化模块定义，但网表中仍是 5 个触发器实例。

## 被测程序与预期时序

`sum.hex` 中的程序：

| 地址 | 指令字 | 语义 |
| --- | --- | --- |
| 0 | `8a` | `li R0, 10` |
| 1 | `90` | `li R1, 0` |
| 2 | `a0` | `li R2, 0` |
| 3 | `b1` | `li R3, 1` |
| 4 | `17` | `add R1, R1, R3` |
| 5 | `29` | `add R2, R2, R1` |
| 6 | `d1` | `bner0 R1, 4`（隐含的 `R0 != R1` 时跳回 4） |
| 7 | `df` | `bner0 R3, 7`（隐含的 `R0 != R3` 时跳回 7，自循环） |

从释放复位后的第一个上升沿开始计数：

- 第 1~4 拍依次执行 4 条 `li`，第 4 拍结束后 `PC=4`，`(R0,R1,R2,R3)=(10,0,0,1)`。
- 循环体每 3 拍完成一次 `add R1`、`add R2`、`bner0`。`R1` 从 1 递增到 10 共 10 次循环，占 30 拍。
- 第 34 拍执行地址 6 的 `bner0`，此时 `R1=R0=10`，条件不成立，`PC` 变为 7；`(R0,R1,R2,R3)=(10,10,55,1)`。
- 第 35 拍起执行地址 7 的 `bner0`，`R3=1 != R0=10` 且跳转目标就是 7，`PC` 保持 7。

逐拍 PC 序列（第 1~34 拍）：`1,2,3,4,5,6,4,5,6,4,...,5,6,4,5,6,7`，其中第 5~33 拍按 `5,6,4` 循环。

## dff_pn 单元级测试

### 测试实例

`tb_dff_pn.sv` 同时例化两个单元，共用 `clk` 与 `rst_n`：

| 实例 | 参数 | 用途 |
| --- | --- | --- |
| `dut` | 默认参数（`WIDTH=1`，`RESET_VALUE=0`） | 复验原单比特行为并检查默认参数兼容性 |
| `dut_vec` | `WIDTH=8`，`RESET_VALUE=8'hA5` | 验证非零复位值、向量整体采样和参数化行为 |

### 测试场景

默认参数实例按以下顺序驱动并自检：

1. 在非时钟沿处拉低 `rst_n`，检查 `q` 立即变为 0（异步清零，不等待 `clk`）。
2. 保持复位，令 `d` 在 0/1 之间变化并跨越多个时钟上升沿，检查 `q` 始终为 0（复位优先、复位期间 `d` 不影响 `q`）。
3. 在两个时钟沿之间释放 `rst_n`，先检查 `q` 保持 0，再检查第一个上升沿采样 `d=1` 后 `q=1`（释放复位后只在上升沿更新）。
4. 在上升沿后把 `d` 改为 0，检查下降沿处及下一个上升沿之前 `q` 仍为 1，直到下一个上升沿才变为 0（两个边沿之间 `d` 改变不影响 `q`）。
5. 连续 8 个周期驱动 `d` 序列 `0,0,1,1,0,1,0,0`，逐拍检查 `q` 等于上一拍建立好的 `d`（连续采样 0/1）。
6. `q=1` 时在非时钟沿处再次拉低 `rst_n`，检查 `q` 立即清零；保持复位跨越上升沿，检查 `q` 仍为 0；释放后检查 `q` 仍保持 0，直到下一个上升沿采样 `d=0`。

参数化 8 位实例及默认参数兼容性：

7. **默认参数兼容性**：读层次参数和位宽，检查 `dut.WIDTH=1`、`dut.RESET_VALUE=0`、`dut` 的 `d/q` 均为 1 位；同时检查 `dut_vec` 的 `d/q` 均为 8 位、`RESET_VALUE=8'hA5`。
8. **向量初始化**：在正常复位释放状态下令 `d8=8'h3C`，检查上升沿后 `q8=8'h3C`，作为后续异步复位的前值。
9. **异步载入非零默认值**：在非时钟沿处拉低 `rst_n`，检查 `q8` 立即从 `8'h3C` 变为 `8'hA5`，不等待 `clk`。
10. **复位优先**：保持复位，令 `d8` 分别为 `8'hFF`、`8'h00`，在边沿间和上升沿处检查 `q8` 始终为 `8'hA5`。
11. **释放后保持与首次采样**：释放复位前令 `d8=8'h5A`，释放后先检查 `q8` 仍为 `8'hA5`，直到第一个上升沿才整体采样为 `8'h5A`。
12. **边沿间保持与向量整体采样**：在下降沿后把 `d8` 改为 `8'hF0`，检查 `q8` 仍为 `8'h5A`；随后逐拍令 `d8` 为 `8'hF0`、`8'h0F`、`8'h81`、`8'h7E`，检查每个上升沿后 `q8` 完整等于整个 8 位向量，未出现只更新部分位或位序错乱。
13. **再次异步复位**：`q8=8'h7E` 时在非时钟沿处拉低 `rst_n`，检查 `q8` 立即回到 `8'hA5`；保持复位跨越上升沿仍为 `8'hA5`；释放后保持 `8'hA5`，直到下一个上升沿采样 `d8=8'h00`。

### 通过标准

- 全部 50 项自检打印 `OK`，最终打印 `PASS`，进程返回码为 0。
- 任何一项 `q`/`q8` 与预期不符、默认参数或位宽不符，都会打印 `FAIL` 并计入错误数，结束时以非 0 返回码退出。
- 2000 ns 看门狗超时则打印 `FAIL: timeout` 并以非 0 返回码退出。

## sCPU 系统级测试

`tb_scpu.sv` 保持原有测试场景与预期值不变，仅依赖参数化后的架构状态和 `pc` 输出；已在本版 RTL 上重新运行确认适用。

### 测试场景

`tb_scpu.sv` 加载 `sum.hex`，覆盖：

1. **初始复位**：保持 `rst_n=0` 两个时钟周期，检查 `PC=0` 且 4 个 GPR 均为 0；参数化实例的 `RESET_VALUE=8'h00` 必须让 8 位 PC 和 GPR 全部清零。
2. **前 4 拍 li 段**：释放复位后逐拍检查 PC 序列，第 4 拍检查 `PC=4`、`(R0,R1,R2,R3)=(10,0,0,1)`。
3. **精确 34 拍完成**：第 1~34 拍逐拍检查 PC 预期值；第 34 拍检查 `PC=7`、`(R0,R1,R2,R3)=(10,10,55,1)`。若程序提前到达 PC=7，逐拍 PC 检查会在对应拍失败。
4. **PC=7 自循环**：再执行 3 个时钟，检查 `PC` 始终为 7，且 GPR 不变。
5. **运行中异步复位**：在 PC=7 自循环期间、非时钟沿处拉低 `rst_n`，检查 `PC` 和 GPR 立即清零；保持复位跨越一个上升沿，确认仍为 0。
6. **复位后重跑**：释放复位，重新执行完整 34 拍并再次检查第 4 拍中间状态和第 34 拍最终状态，确认复位后状态可确定性重建。
7. **超时保护**：5000 ns 全局看门狗，仿真未正常结束时打印 `FAIL: timeout` 并以非 0 返回码退出。

### 通过标准

- 两个运行轮次都在第 4 拍得到 `(10,0,0,1)`，在第 34 拍得到 `(10,10,55,1)` 且 `PC=7`。
- PC=7 自循环期间 PC 和 GPR 保持不变；运行中异步复位后 PC 和 GPR 立即为 0。
- 最终打印 `PASS`，进程返回码为 0；任何检查失败都会打印带时间、拍数和实际值的 `FAIL` 并以非 0 返回码退出。

## 波形关注要点

两个 tb 中的 `$dumpfile` / `$dumpvars` 默认被注释。解注释后重新编译运行即可生成波形：

- `tb_dff_pn.sv` 生成 `tb_dff_pn.vcd`；
- `tb_scpu.sv` 生成 `tb_scpu.vcd`。

用 `gtkwave tb_dff_pn.vcd` 或 `gtkwave tb_scpu.vcd` 打开。

### dff_pn 波形

关注默认实例的 `clk`、`rst_n`、`d`、`q`，以及参数化实例的 `d8`、`q8`（也可展开 `dut`、`dut_vec`）：

- `rst_n` 下降沿后 `q` 立即变 0、`q8` 立即变 `8'hA5`，均不等 `clk`；复位期间无论 `d`/`d8` 怎么变、`clk` 是否上升，`q` 都为 0、`q8` 都为 `8'hA5`。
- 释放复位后 `q`/`q8` 保持旧值；只在 `clk` 上升沿后一个 delta 更新为 `d`/`d8` 的完整值。
- `q8` 的每次非复位变化都应从一个完整 8 位值跳到另一个完整 8 位值（`3C→5A→F0→0F→81→7E→00`），不出现按位分步更新。
- `q` 的每次变化都对应一个 `clk` 上升沿（复位沿除外），下降沿和 `d` 的中间变化不会引起 `q` 变化。

### sCPU 波形

关注 `clk`、`rst_n`、`pc`、`instr`、`dut.next_pc`、`dut.wen`、`dut.waddr`、`dut.wdata`、`dut.raddr1`、`dut.rdata1`、`dut.rdata2`、`dut.u_gpr.regs[0..3]`；如需观察触发器本身，可展开 `dut.u_pc_dff` 和 `dut.u_gpr.gen_gpr[0..3].u_dff_pn`：

- `pc` 与 `instr`：PC=0~3 依次取出四条 `li`；循环期间 `pc` 按 4→5→6→4 变化，依次取出 `17`、`29`、`d1`；第 34 拍后 `pc` 停在 7，`instr` 保持 `df`。
- `dut.wen`、`dut.waddr`、`dut.wdata`：`li`/`add` 时 `wen=1`，写地址和写数据符合指令语义；`bner0` 时 `wen=0`，GPR 保持不变。
- `dut.raddr1`、`dut.rdata1`、`dut.rdata2`：`add` 时第一读地址为 `rs1`；`bner0` 时第一读地址固定为 0，读数据用于和 `R0` 比较。
- `dut.next_pc`：PC=6 且 `R1!=R0` 时为 4，`R1==R0` 时为 7；PC=7 时保持为 7。
- 5 个 8 位 `dff_pn` 实例的 `q` 都与对应架构状态一致（`u_pc_dff.q=pc`，`gen_gpr[i].u_dff_pn.q=regs[i]`），复位沿后全部为 0。
- GPR 状态：第 4 拍为 `(10,0,0,1)`；第一次循环后为 `(10,1,1,1)`；第 34 拍为 `(10,10,55,1)`；复位后全部为 0。

## 实际执行命令

在本目录执行：

```bash
# 单元级 lint（参数化 RTL）
verilator --lint-only --Wall -Wno-DECLFILENAME --top-module dff_pn dff_pn.sv

# 系统级 lint
verilator --lint-only --Wall -Wno-DECLFILENAME --top-module scpu dff_pn.sv scpu.sv
verilator --lint-only --Wall -Wno-DECLFILENAME --top-module scpu_rom dff_pn.sv scpu.sv

# dff_pn 单元仿真（默认 1 位实例 + 8 位 A5 复位实例）
iverilog -g2012 -s tb_dff_pn -o tb_dff_pn.vvp dff_pn.sv tb_dff_pn.sv
vvp tb_dff_pn.vvp

# sCPU 系统仿真
iverilog -g2012 -s tb_scpu -o tb_scpu.vvp dff_pn.sv scpu.sv tb_scpu.sv
vvp tb_scpu.vvp

# 结构检查
yosys -p 'read_verilog -sv dff_pn.sv scpu.sv; hierarchy -check -top scpu; proc; check'
```

实际运行结果：

- `tb_dff_pn` 打印 `PASS: 50 checks, dff_pn async reset, posedge sampling and parameterized vector verified`，返回码 0。
- `tb_scpu` 两轮均在第 4 拍得到 `(10,0,0,1)`、第 34 拍得到 `(10,10,55,1)`，打印 `PASS: PC=7 R0=10 R1=10 R2=55 R3=1, 34-cycle completion and reset verified`，返回码 0。
- 3 条 Verilator lint 均无告警；Yosys 输出 `Found and reported 0 problems`。

仿真时 iverilog 可能提示 `$readmemh(sum.hex): Not enough words in the file for the requested range [0:255]`，这是 ROM 初始化为 256 个字、而 `sum.hex` 只有 8 条指令的正常提示，其余字由 `initial` 循环填 0。Yosys 可能输出 `Replacing memory \regs with list of registers`，这是 GPR 数组被展开为寄存器列表的正常信息。

生成波形时，先把对应 tb 中 `$dumpfile` 和 `$dumpvars` 两行开头的 `//` 去掉，再执行上面的 `iverilog`/`vvp` 命令，最后运行：

```bash
gtkwave tb_dff_pn.vcd
gtkwave tb_scpu.vcd
```

`*.vvp`、`*.vcd` 均为仿真产物，验证结束后删除，不提交到仓库。
