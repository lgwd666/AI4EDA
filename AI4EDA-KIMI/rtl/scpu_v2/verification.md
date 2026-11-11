# sCPU v2（F6 sISA v2）验证策略

本目录验证 `scpu.sv` + `dff_pn.sv` 组成的 8 位单周期 CPU，以及 `sum_io.hex` 和三个定向测试程序。
testbench 与设备模型全部在 `tb_scpu.sv` 中实现，未修改任何 RTL；主代理负责独立复验。

## 1. 验证目标

1. 复位后 PC、4 个 GPR、输出设备全部清零；复位可在运行中异步生效。
2. `sum_io.hex` 在 `switches=10` 时完整跑通：PC6 的负偏移回跳、条件最终不成立、PC9 偏移 0 自循环，最终 `R2=55`、`led=55`、`seven_seg=55`、`PC=9`。
3. 两个输入设备编号（idx=0 switches、idx=1 buttons）和两个输出设备编号（idx=0 led、idx=1 seven_seg）均正确；未定义编号读 0。
4. `li` 的四种 `s`（移位 0/2/4/6）结果正确，特别验证 `li r0,192` 的编码 `0x8f`。
5. `bner0` 的正偏移、负偏移、条件不成立三类行为正确，且偏移相对**当前 PC** 而不是 PC+1。
6. 输出设备在源 GPR 改变后保持；非 io 指令（`io_wen=0`）期间设备不更新。
7. 超时保护、逐项自检、失败时非零退出码。

## 2. 文件与职责

| 文件 | 作用 |
| --- | --- |
| `scpu.sv` | 被测 RTL（未修改） |
| `dff_pn.sv` | 通用触发器（未修改） |
| `sum_io.hex` | 主程序（未修改）：开关求和后输出到 LED/数码管 |
| `li_test.hex` | 定向程序：`li` 四种 `s` + `li r0,192`（`0x8f`） |
| `branch_test.hex` | 定向程序：`bner0` 正/负偏移、条件不成立、相对当前 PC |
| `io_test.hex` | 定向程序：buttons 输入、输出保持、无 `io_wen` 不更新 |
| `tb_scpu.sv` | testbench：设备模型、ROM 编码自检、逐拍检查、超时与 VCD 开关 |

`tb_scpu.sv` 同时例化四套 `scpu_sys`（ROM + `scpu` + 设备模型），共享 `clk`/`rst_n`，按场景复位后分时运行；层次路径 `u_sum.dut.u_gpr.regs[0..3]`（以及 `u_branch`/`u_li`/`u_io` 对应路径）用于观察 GPR。

## 3. 设备模型（tb 内实现，不进入 RTL）

```systemverilog
always_comb
    case (io_idx)
        3'd0:    io_rdata = switches;
        3'd1:    io_rdata = buttons;
        default: io_rdata = 8'h00;
    endcase

always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin led <= 0; seven_seg <= 0; end
    else if (io_wen) begin
        case (io_idx)
            3'd0: led       <= io_wdata;
            3'd1: seven_seg <= io_wdata;
            default: ;  // 其他编号保持
        endcase
    end
```

- 输入为组合 mux，`io_idx` 对输入/输出均有效。
- 输出为保持寄存器，只在 `clk` 上升沿且 `io_wen=1` 时按编号更新；复位异步清零；其余时间保持。
- 设备模型放在 `scpu_sys` 内，每套 DUT 独立，避免四套测试互相污染。
- `sum`：`switches=8'd10`，`buttons=0`；`io`：`switches=0xA5`（本程序不读 idx0），`buttons=0x3C`；`li`/`branch` 均为 0。

## 4. 被测程序与预期

### 4.1 `sum_io.hex`（未修改）

| PC | 指令 | 语义 |
| --- | --- | --- |
| 0 | `40` | `io in R0, idx0`，读 switches |
| 1 | `90` | `li R1,0` |
| 2 | `a0` | `li R2,0` |
| 3 | `b1` | `li R3,1` |
| 4 | `17` | `add R1,R1,R3` |
| 5 | `29` | `add R2,R2,R1` |
| 6 | `f9` | `bner0 R1,-2`：`R0!=R1` 时 `PC=6-2=4` |
| 7 | `68` | `io out R2, idx0` → led |
| 8 | `69` | `io out R2, idx1` → seven_seg |
| 9 | `c3` | `bner0 R3,0`：偏移 0，自循环 |

`switches=10`：循环中 `R1` 从 1 增到 10，`R2=1+2+...+10=55`。第 35/36/37 个上升沿依次执行 PC7/PC8/PC9，最终 `PC=9`、`R2=55`、`led=55`、`seven_seg=55`，之后 PC9 保持。

### 4.2 `li_test.hex`

| PC | 指令 | 语义 | 结果 |
| --- | --- | --- | --- |
| 0 | `8f` | `li R0, 3<<6` | R0=192（核心编码用例） |
| 1 | `91` | `li R1, 1<<0` | R1=1 |
| 2 | `a6` | `li R2, 2<<2` | R2=8 |
| 3 | `b9` | `li R3, 1<<4` | R3=16 |
| 4 | `8d` | `li R0, 1<<6` | R0=64 |
| 5 | `97` | `li R1, 3<<2` | R1=12 |
| 6 | `ae` | `li R2, 2<<6` | R2=128 |
| 7 | `b3` | `li R3, 3<<0` | R3=3 |
| 8 | `c3` | `bner0 R3,0` | R0=64≠R3=3，自循环 |

最终 `PC=8`，`(R0,R1,R2,R3)=(64,12,128,3)`；第 1 拍后必须出现 `R0=192`。

### 4.3 `branch_test.hex`

| PC | 指令 | 语义 |
| --- | --- | --- |
| 0 | `83` | `li R0,3`（比较基准） |
| 1 | `90` | `li R1,0` |
| 2 | `b1` | `li R3,1` |
| 3 | `17` | `add R1,R1,R3` |
| 4 | `f9` | `bner0 R1,-2`：R1≠3 时跳到 `PC-2=2` |
| 5 | `a2` | `li R2,2`（条件不成立落点） |
| 6 | `ca` | `bner0 R2,+2`：R0≠R2 时跳到 `PC+2=8` |
| 7 | `b7` | `li R3,7`（必须被跳过） |
| 8 | `b3` | `li R3,3`（正偏移落点） |
| 9 | `cd` | `bner0 R1,+3`：R0=R1=3，条件不成立，偏移不得生效 |
| 10 | `a5` | `li R2,4`（必须执行，证明 PC9 未跳转） |
| 11 | `c2` | `bner0 R2,0`：R0=3≠R2=4，偏移 0 自循环 |

预期 PC 轨迹：`1,2,3,(4,2,3)x2,4,5,6,8,9,10,11,11,...`；最终 `PC=11`，`(R0,R1,R2,R3)=(3,3,4,3)`。

关键判定：

- PC4→PC2 验证负偏移且相对当前 PC（若错误地相对 PC+1，会落到 PC3，轨迹立即不同）。
- PC6→PC8 验证正偏移且相对当前 PC（若相对 PC+1，会落到 PC9 并跳过 PC8 的 `li R3,3`）。
- PC9 条件不成立且偏移为 +3：必须落到 PC10（若错误跳转，`R2` 不会是 4）。
- PC7 的 `li R3,7` 未执行：PC8 后 `R3` 仍为 1，PC9 后为 3。

### 4.4 `io_test.hex`

| PC | 指令 | 语义 |
| --- | --- | --- |
| 0 | `b1` | `li R3,1` |
| 1 | `9b` | `li R1,48` |
| 2 | `51` | `io in R1, idx1`，读 buttons |
| 3 | `62` | `io in R2, idx2`，未定义编号应读 0 |
| 4 | `58` | `io out R1, idx0` → led |
| 5 | `59` | `io out R1, idx1` → seven_seg |
| 6 | `9f` | `li R1,192`（改变源 GPR，设备保持） |
| 7 | `58` | `io out R1, idx0` → led=192，seven_seg 保持 |
| 8 | `91` | `li R1,1`（改变源 GPR，设备保持） |
| 9 | `59` | `io out R1, idx1` → seven_seg=1，led 保持 |
| 10 | `c3` | `bner0 R3,0`：R0=0≠R3=1，自循环 |

`buttons=0x3C`，最终 `PC=10`、`R1=1`、`led=0xC0`、`seven_seg=0x01`，中间 `R2=0`。

## 5. 测试场景与检查点

所有场景共享时钟，`rst_n` 低有效。每项检查在上升沿后 1ns 采样（此时 GPR 与设备已完成更新），使用 `$fatal(1, ...)` 立即失败。

### 场景 1：复位 + `sum_io` 完整运行

- 上电复位 2 拍后检查四套系统 `PC=0`、`GPR` 全 0、`led/seven_seg=0`、`io_wen=0`。
- 释放复位后 `PC=0` 为 io 输入：`io_wen=0`、`io_idx=0`、`io_rdata=switches=10`。
- 第 1 拍后 `R0=10`。
- 循环每轮逐拍检查 `PC`、`R1`、`R2`（`R2=k(k±1)/2`），共 9 轮，确认 PC6 的 -2 分支成立。
- `R1=10` 时 PC6 条件不成立，逐拍检查 PC7→8→9。
- PC7/PC8 分别检查 `io_wen=1`、`io_idx=0/1`、`io_wdata=55`，并检查 `led`/`seven_seg` 依次变为 55。
- PC9 自循环保持 3 拍，状态不变。
- 自循环中异步复位，PC/GPR/设备立即清零。

### 场景 2：`li`

- 第 1 拍后检查 `R0=192`（`0x8f` 编码用例）。
- 每拍检查目标 GPR 和 PC，覆盖 `s=0/1/2/3` 与不同 `imm`。
- 非 io 指令期间 `io_wen=0`。

### 场景 3：`io`

- PC2 执行前检查 `io_wen=0`、`io_idx=1`、`io_rdata=buttons=0x3C`，下一拍 `R1=0x3C`。
- PC3 执行前检查 `io_idx=2`、`io_rdata=0`，下一拍 `R2=0`。
- PC4/PC5 执行前检查 `io_wen=1`、idx 与 `io_wdata`；执行后 `led`/`seven_seg` 均为 0x3C。
- PC6（`li`，无 `io_wen`）后设备保持，但 `R1=192`。
- PC7 只更新 `led=192`，`seven_seg` 保持 0x3C；PC8（`li`）后设备保持。
- PC9 只更新 `seven_seg=1`，`led` 保持 192。
- PC10 自循环 `io_wen=0`，设备不再变化。

### 场景 4：`bner0`

- 逐拍检查 PC 轨迹与 GPR：负偏移 2 次、条件不成立落 PC5、正偏移跳 PC8、PC9 的 +3 条件不成立不跳转、PC11 偏移 0 自循环。

### 场景 5：超时、自检与失败返回

- 独立 `initial` 块在 `MAX_SIM_NS=10000` 后 `$fatal(1)`，防止死锁仿真挂起。
- ROM 编码自检：`sum_io.hex[0/6/7/8/9]`、`li_test.hex[0]`、`branch_test.hex[4/6/9]`、`io_test.hex[2/3/5]` 与预期机器码逐字节比对，防止 hex 写错导致"测了别的程序还通过"。
- 所有检查失败均调用 `$fatal(1, ...)`；`vvp` 返回码非 0。开发过程中曾因方向位编码错误触发失败，`vvp` 返回 1，已确认失败路径有效。

## 6. 通过标准

1. 仿真输出 `PASS: tb_scpu completed 196 checks ...`，`vvp` 退出码为 0。
2. 四个最终状态同时成立：
   - sum：`PC=9`，`R0=10,R1=10,R2=55,R3=1`，`led=55`，`seven_seg=55`；
   - branch：`PC=11`，`R0=3,R1=3,R2=4,R3=3`；
   - li：`PC=8`，`R0=64,R1=12,R2=128,R3=3`，且过程中出现过 `R0=192`；
   - io：`PC=10`，`R0=0,R1=1,R2=0,R3=1`，`led=0xC0`，`seven_seg=0x01`。
3. 所有中间逐拍检查通过；任一失败即 `$fatal` 非零退出。

## 7. 实际命令与结果

在 `AI4EDA-KIMI/rtl/scpu_v2/` 下执行：

```bash
iverilog -g2012 -Wall -o tb_scpu.vvp scpu.sv dff_pn.sv tb_scpu.sv
vvp tb_scpu.vvp
echo $?
```

实际输出（`-Wall` 下 Icarus 对短 hex 文件给出 `$readmemh ... Not enough words` 提示，属正常现象）：

```text
INFO: sum_io done: pc=9 R0=10 R1=10 R2=55 R3=1 led=55 seg=55
INFO: branch_test done: pc=11 R0=3 R1=3 R2=4 R3=3
INFO: li_test done: pc=8 R0=64 R1=12 R2=128 R3=3
INFO: io_test done: pc=10 R0=0 R1=1 R2=0 R3=1 led=c0 seg=01
PASS: tb_scpu completed 196 checks (sum_io, branch, li, io)
```

`echo $?` 为 `0`。

生成波形：解开 `tb_scpu.sv` 顶部的两行注释

```systemverilog
// $dumpfile("tb_scpu.vcd");
// $dumpvars(0, tb_scpu);
```

后重新编译运行：

```bash
iverilog -g2012 -o tb_scpu.vvp scpu.sv dff_pn.sv tb_scpu.sv
vvp tb_scpu.vvp
ls -l tb_scpu.vcd   # 实测约 84KB
```

RTL lint（可选）：

```bash
verilator --lint-only -Wall -Wno-DECLFILENAME --top-module scpu scpu.sv dff_pn.sv
```

实测无功能告警；不加 `-Wno-DECLFILENAME` 时仅因 `scpu_gpr`/`scpu_rom` 与文件名不同而报一条风格告警。

## 8. 波形关注信号与预期

| 信号（层次路径） | 预期 |
| --- | --- |
| `clk`, `rst_n` | 10ns 周期；每场景开始复位至少 2 拍 |
| `u_sum.pc` / `u_sum.instr` | PC 序列 `0,1,2,3,(4,5,6)x9,4,5,6,7,8,9,9...`；PC6 处 instr=`f9`，PC9 处 `c3` |
| `u_sum.io_wen` | 仅 PC7、PC8 为 1，其余（含 bner0/li/add）为 0 |
| `u_sum.io_idx` | PC0=`0`（输入），PC7=`0`，PC8=`1` |
| `u_sum.io_wdata` | PC7、PC8 为 `0x37`（55） |
| `u_sum.io_rdata` | PC0 等于 `switches=0x0A` |
| `u_sum.led` / `u_sum.seven_seg` | 分别在 PC7、PC8 上升沿后变为 `0x37`，此后保持 |
| `u_sum.dut.u_gpr.regs[0..3]` | 循环中 `R1` 每轮 +1，`R2` 累加至 55，`R0` 恒 10，`R3` 恒 1 |
| `u_io.pc` | `0..10,10...`；PC2 instr=`51`，PC3=`62`，PC4=`58`，PC5=`59` |
| `u_io.dut.u_gpr.regs[1]` | `48 → 0x3C → 192 → 1` |
| `u_io.led` / `u_io.seven_seg` | PC4/PC5 后均为 `0x3C`；PC6 后保持；PC7 后 led=`0xC0`、seg 保持；PC9 后 seg=`0x01` |
| `u_io.io_wen` | PC2/PC3（输入）、PC6/PC8（li）、PC10（bner0）为 0；PC4/PC5/PC7/PC9 为 1 |
| `u_li.pc` | `1..8,8...`；`u_li.dut.u_gpr.regs[0]` 第 1 拍为 192，第 5 拍变为 64 |
| `u_branch.pc` | `4→2`（负偏移）、`6→8`（正偏移）、`9→10`（条件不成立）、`11` 自循环 |
| `u_branch.dut.u_gpr.regs[3]` | PC7 被跳过，PC8 后为 3；若为 7 则说明正偏移跳错 |
| 各 `u_*.led` / `u_*.seven_seg` | `rst_n=0` 期间为 0，且只有对应 `io_wen` 上升沿才变化 |

## 9. RTL 观察与疑虑（未修改 RTL）

1. `io_idx` 由 `instr[2:0]` 直接驱动，对非 io 指令也有值。规格只要求 io 输入/输出期间有效，且 `io_wen=0` 时设备不更新，因此当前测试不受影响；若将来有设备只看 `io_idx`，需注意。
2. `io_wen` 已与 `rst_n` 相与：复位期间即使 PC 指向 io 输出指令也不会产生输出事务；正常执行时仍仅由 io 输出指令拉高。
3. `scpu_rom` 把未写入的地址填 `0x00`，而 `0x00` 是合法 `add R0,R0,R0`。若 PC 意外跑出程序区，会静默执行并写 R0，而不是停机。本 tb 所有程序都以偏移 0 的 `bner0` 自循环收尾，不会跑飞。
4. `scpu.sv` 内同时定义 `scpu`/`scpu_gpr`/`scpu_rom`，触发 Verilator `DECLFILENAME` 风格告警；不影响功能。
5. `dff_pn.sv`、`scpu.sv` 未声明 `timescale`，Icarus 编译时给出时间单位告警；RTL 无延时语句，仿真结果不受影响。
6. 按规格逐项核对，F6 指令语义（`li` 四种移位、io 方向位、bner0 相对当前 PC 的符号扩展）与 RTL 实现一致，未发现功能缺陷。

## 10. 生成物清理

仿真产生的 `tb_scpu.vvp`、`tb_scpu.vcd`、日志等临时文件验证后删除，不纳入提交；`tb_scpu.sv` 中 `$dumpfile`/`$dumpvars` 保持默认注释。
