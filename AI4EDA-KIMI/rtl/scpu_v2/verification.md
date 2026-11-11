# sCPU v2（F6 sISA v2）验证策略

本目录验证 `scpu.sv` + `dff_pn.sv` 组成的 8 位单周期 CPU，以及 `sum_io.hex` 和四个定向测试程序。设备模型与输出保持寄存器位于 `tb_scpu.sv`，不属于处理器 RTL。

## 1. 接口与设备译码

`scpu` 不再输出 `io_idx`，也不再使用一组共享的 `io_wen/io_wdata/io_rdata` 连接所有设备。指令中的 `idx` 只在 CPU 内部译码，顶层端口按设备拆分：

| 方向 | 端口 | 对应设备与指令编号 |
| --- | --- | --- |
| 输入 | `switches[7:0]` | 拨码开关，`io` 输入 `idx=0` |
| 输入 | `buttons[7:0]` | 按钮，`io` 输入 `idx=1` |
| 输出 | `led_wen`、`led_wdata[7:0]` | LED，`io` 输出 `idx=0` |
| 输出 | `seven_seg_wen`、`seven_seg_wdata[7:0]` | 七段数码管，`io` 输出 `idx=1` |

未定义输入编号读 `8'h00`；未定义输出编号不产生任何写使能。两个输出写使能均与 `rst_n` 相与，复位期间不会产生输出事务。LED 和数码管的保持寄存器分别只响应自己的 `wen`，在时钟上升沿更新，复位异步清零，其余时间保持。

## 2. 验证目标

1. 复位后 PC、4 个 GPR、LED 和数码管输出寄存器全部清零；复位可在运行中异步生效。
2. `sum_io.hex` 在 `switches=10` 时完整跑通，最终 `R2=55`、`led=55`、`seven_seg=55`、`PC=9`。
3. 开关和按钮分别通过独立输入端口读入；未定义输入编号读 0。
4. LED 与数码管分别收到独立写使能和写数据；目标设备更新时另一个设备的写使能必须为 0。
5. `li` 的四种 `s`（移位 0/2/4/6）结果正确，特别验证 `li r0,192` 的编码 `0x8f`。
6. `bner0` 的正偏移、负偏移和条件不成立行为正确，偏移相对当前 PC。
7. 输出设备在源 GPR 改变后保持；输入指令、非 `io` 指令和复位期间两个输出写使能均为 0。
8. `step_sum.hex` 只在按钮完成一次“按下并释放”后累加一项，长按不累加，累加结果只输出到 LED。
9. testbench 具备 ROM 编码自检、超时保护和失败非零退出。

## 3. 文件与职责

| 文件 | 作用 |
| --- | --- |
| `scpu.sv` | 被测 RTL：指令译码、PC、GPR、内部输入选择及独立设备接口 |
| `dff_pn.sv` | 参数化异步低有效复位触发器 |
| `sum_io.hex` | 开关输入、数列求和、LED/数码管输出 |
| `li_test.hex` | `li` 四种移位及 `li r0,192` |
| `branch_test.hex` | `bner0` 正/负偏移、条件不成立和自循环 |
| `io_test.hex` | 按钮输入、未定义输入编号、独立输出及输出保持 |
| `step_sum.hex` | 按下并释放一次累加一项，结果输出到 LED |
| `tb_scpu.sv` | 五套测试系统、设备保持寄存器、逐拍自检、超时与 VCD 开关 |

testbench 同时例化五套 `scpu_sys`（ROM + `scpu` + 输出设备模型），共享 `clk/rst_n`，按场景复位后分时运行。层次路径 `u_sum.dut.u_gpr.regs[0..3]`（以及其他系统对应路径）用于观察 GPR；内部 `io_rdata` 仅用于检查输入选择结果。

## 4. 被测程序与预期

### 4.1 `sum_io.hex`

| PC | 指令 | 语义 |
| --- | --- | --- |
| 0 | `40` | `io in R0, idx0`，读 `switches` |
| 1 | `90` | `li R1,0` |
| 2 | `a0` | `li R2,0` |
| 3 | `b1` | `li R3,1` |
| 4 | `17` | `add R1,R1,R3` |
| 5 | `29` | `add R2,R2,R1` |
| 6 | `f9` | `bner0 R1,-2`，条件成立时跳回 PC4 |
| 7 | `68` | `io out R2, idx0`，只拉高 `led_wen` |
| 8 | `69` | `io out R2, idx1`，只拉高 `seven_seg_wen` |
| 9 | `c3` | 偏移 0，自循环 |

`switches=10` 时，循环中 `R1` 从 1 增到 10，`R2=1+2+...+10=55`。PC7 执行后 LED 变为 55，PC8 执行后数码管变为 55，最终 PC 保持在 9。

### 4.2 `li_test.hex`

依次覆盖 `s=0/1/2/3` 和不同立即数。第 1 拍后 `R0=192`；最终 `PC=8`，`(R0,R1,R2,R3)=(64,12,128,3)`，随后自循环。

### 4.3 `branch_test.hex`

预期 PC 轨迹为 `1,2,3,(4,2,3)x2,4,5,6,8,9,10,11,11,...`。PC4→PC2 验证负偏移，PC6→PC8 验证正偏移，PC9→PC10 验证条件不成立时忽略非零偏移。最终 `(R0,R1,R2,R3)=(3,3,4,3)`。

### 4.4 `io_test.hex`

| PC | 指令 | 检查点 |
| --- | --- | --- |
| 0 | `b1` | `li R3,1` |
| 1 | `9b` | `li R1,48` |
| 2 | `51` | 从 `buttons=0x3C` 读入 R1，两个输出写使能为 0 |
| 3 | `62` | 未定义输入 `idx=2` 读 0 到 R2 |
| 4 | `58` | 仅 LED 写使能有效，LED 更新为 `0x3C` |
| 5 | `59` | 仅数码管写使能有效，数码管更新为 `0x3C` |
| 6 | `9f` | R1 改为 192，两个设备保持 |
| 7 | `58` | 仅 LED 更新为 `0xC0`，数码管保持 |
| 8 | `91` | R1 改为 1，两个设备保持 |
| 9 | `59` | 仅数码管更新为 `0x01`，LED 保持 |
| 10 | `c3` | 自循环，两个输出写使能均为 0 |

最终 `PC=10`、`R1=1`、`R2=0`、`led=0xC0`、`seven_seg=0x01`。

### 4.5 `step_sum.hex`

该程序固定以 `switches=10` 为末项，LED 初始显示 0。每次检测到 `buttons=1` 后，还必须等待按钮回到 0，才执行一次 `i++` 和 `sum+=i`。第 1 次至第 10 次按下并释放后，LED 依次为 `1,3,6,10,15,21,28,36,45,55`。

| PC | 指令 | 语义 |
| --- | --- | --- |
| 0 | `40` | R0←switches，读末项 N=10 |
| 1~3 | `90 a0 b1` | 初始化 `i=0`、`sum=0`、R3=1 |
| 4 | `68` | 将当前 sum 输出到 LED |
| 5 | `81` | R0=1，作为按钮按下的比较值 |
| 6 | `71` | R3←buttons |
| 7 | `ff` | 按钮不为 1 时跳回 PC6，持续等待按下 |
| 8 | `f3` | 按下后 R0=R3=1，顺序进入释放轮询；循环返回时 R0=10、R3=1，跳回 PC4 |
| 9 | `80` | R0=0，作为按钮释放的比较值 |
| 10 | `71` | R3←buttons |
| 11 | `fb` | 按钮仍非 0 时跳回 PC9，持续等待释放 |
| 12 | `40` | 重新读入 N=10 |
| 13 | `b1` | 恢复常数 R3=1 |
| 14 | `17` | `i++` |
| 15 | `29` | `sum+=i` |
| 16 | `e1` | 尚未到第 10 项时跳回 PC8，再由 PC8 返回 PC4 |
| 17 | `68` | 将最终 sum=55 输出到 LED |
| 18 | `c3` | 完成后自循环 |

寄存器复用关系：R1 始终保存 `i`，R2 始终保存 `sum`；R0 在 N、1、0 之间切换，R3 在常数 1 与按钮采样值之间切换。PC8 同时承担按下后的顺序出口和循环跳转入口，使所有分支偏移都处于 `-8~+7` 范围内。

## 5. 测试场景与通过标准

所有检查在时钟上升沿后 1ns 采样，使用 `$fatal(1, ...)` 在失败时立即非零退出。

- 上电及每个场景前复位两拍，检查五套系统的 PC、GPR、输出寄存器和两个写使能。
- `sum_io` 逐拍检查循环中的 PC/GPR、两个独立输出事务和最终自循环，并在自循环中验证异步复位。
- `li` 每拍检查 PC 和目标 GPR，覆盖四种移位。
- `branch` 检查完整 PC 轨迹及 GPR，确认应跳过的指令没有执行。
- `io` 检查独立输入数据、未定义编号读 0、两个写使能互斥、写数据及设备保持。
- `step_sum` 完整执行 10 次按下—保持—释放；每次长按三个轮询周期，检查 `i`、`sum` 和 LED 不变，释放后只累加一次；最终 PC18 自循环且 LED=55。
- ROM 编码自检覆盖关键指令，防止 hex 文件写错后测试了其他程序。
- 独立超时块在 `MAX_SIM_NS=10000` 后失败退出。

通过标准：打印 `PASS: tb_scpu completed 583 checks (sum_io, branch, li, io, step_sum)`，`vvp` 返回 0，且上述最终状态全部成立。

## 6. 实际命令与结果

在 `AI4EDA-KIMI/rtl/scpu_v2/` 下执行：

```bash
iverilog -g2012 -Wall -o tb_scpu.vvp scpu.sv dff_pn.sv tb_scpu.sv
vvp tb_scpu.vvp

verilator --lint-only -Wall -Wno-DECLFILENAME --top-module scpu scpu.sv dff_pn.sv

yosys -p 'read_verilog -sv dff_pn.sv scpu.sv; hierarchy -check -top scpu; proc; check'
```

实际结果：

```text
INFO: sum_io done: pc=9 R0=10 R1=10 R2=55 R3=1 led=55 seg=55
INFO: branch_test done: pc=11 R0=3 R1=3 R2=4 R3=3
INFO: li_test done: pc=8 R0=64 R1=12 R2=128 R3=3
INFO: io_test done: pc=10 R0=0 R1=1 R2=0 R3=1 led=c0 seg=01
INFO: step_sum done: pc=18 i=10 sum=55 led=55, 10 press-release cycles
PASS: tb_scpu completed 583 checks (sum_io, branch, li, io, step_sum)
```

- Icarus 仿真返回 0；短 hex 文件的 `$readmemh ... Not enough words` 提示为预期现象，ROM 其余地址已由初始化循环填 0。
- Verilator lint 返回 0，无功能告警。
- Yosys 返回 0，输出 `Found and reported 0 problems`；`Replacing memory \regs with list of registers` 是 GPR 数组展开的正常信息。

生成波形时，解开 `tb_scpu.sv` 主初始块中的以下两行注释，再重新编译运行：

```systemverilog
// $dumpfile("tb_scpu.vcd");
// $dumpvars(0, tb_scpu);
```

## 7. 波形关注信号与预期

| 信号（层次路径） | 预期行为 |
| --- | --- |
| `clk`, `rst_n` | 时钟周期 10ns；每场景开始复位至少两拍 |
| `u_sum.pc` / `u_sum.instr` | PC 序列 `0,1,2,3,(4,5,6)x9,4,5,6,7,8,9,9...` |
| `u_sum.dut.io_rdata` | PC0 等于 `switches=0x0A` |
| `u_sum.led_wen` / `u_sum.led_wdata` | 仅 PC7 写使能有效，写数据为 `0x37` |
| `u_sum.seven_seg_wen` / `u_sum.seven_seg_wdata` | 仅 PC8 写使能有效，写数据为 `0x37` |
| `u_sum.led` / `u_sum.seven_seg` | 分别在 PC7、PC8 上升沿后变为 `0x37`，此后保持 |
| `u_sum.dut.u_gpr.regs[0..3]` | R1 每轮加 1，R2 累加至 55，R0 恒为 10，R3 恒为 1 |
| `u_io.dut.io_rdata` | PC2 为 `buttons=0x3C`，PC3 为 `0x00` |
| `u_io.led_wen` / `u_io.seven_seg_wen` | PC4/PC7 仅 LED 有效；PC5/PC9 仅数码管有效；其他检查点为 0/0 |
| `u_io.led` / `u_io.seven_seg` | PC4/PC5 后均为 `0x3C`；PC7 后 LED 为 `0xC0`；PC9 后数码管为 `0x01` |
| `u_li.pc` | `1..8,8...`；R0 第 1 拍为 192，第 5 拍变为 64 |
| `u_branch.pc` | `4→2`、`6→8`、`9→10`，最后在 PC11 自循环 |
| `u_step.pc` | 等待按下时在 PC6/7 往返；长按时在 PC9/10/11 往返；释放后依次执行 PC12~16 |
| `u_step.dut.u_gpr.regs[1]` / `regs[2]` | 只在释放后分别更新 `i` 和 `sum`，等待与长按期间保持 |
| `u_step.led_wen` / `u_step.led` | 初始输出 0；每次循环在 PC4 输出新和；最终 PC17 输出 55 |
| `u_step.seven_seg_wen` / `u_step.seven_seg` | 写使能始终为 0，数码管保持 0 |
| 各 `u_*.led` / `u_*.seven_seg` | 复位时为 0，仅在对应写使能有效的上升沿变化 |

## 8. RTL 观察与边界

1. `idx` 是 `io` 指令字段，不是处理器对外总线端口；具体设备关联由 `scpu` 内部译码完成。
2. 两个 `wdata` 均直接反映当前源 GPR，只有对应 `wen` 有效时才表示一次输出事务。
3. `step_sum.hex` 的循环跳转和结束自循环以 N=10 为前提；没有扩展为任意末项，也未处理 F6 已说明的 N=0 情况。
4. `scpu_rom` 把未写入地址填为 `0x00`，它是合法的 `add R0,R0,R0`；所有测试程序均以自循环收尾，避免 PC 跑出程序区。
5. `scpu.sv` 内同时定义 `scpu`、`scpu_gpr`、`scpu_rom`，因此 lint 命令保留 `-Wno-DECLFILENAME`。
6. RTL 无延时语句且未声明 `timescale`，Icarus 的时间单位提示不影响本测试结果。

## 9. 生成物清理

验证后删除 `tb_scpu.vvp`、`tb_scpu.vcd`、日志和其他构建产物，不纳入提交；`$dumpfile/$dumpvars` 默认保持注释。
