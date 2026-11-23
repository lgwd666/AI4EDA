# riscv-tests/add 的 LBU 负立即数调试记录

> 日期：2026-11-23  
> 阶段：E5/E6，minirv NPC 与 DiffTest  
> 前置问题：统一存储器和 `.rodata` 加载问题已经修复  
> 本次问题：`lbu` 的负地址偏移被零扩展，导致 DUT 访问错误地址  
> 最终结果：`riscv-tests/add` 输出 `HIT GOOD TRAP` 和 `PASS`

## 1. 前置背景

在上一篇调试记录中，`riscv-tests/add` 最初因为 `_same_result_table` 没有加载到数据区，在第一组测试后直接进入 `fail`，输出：

```text
HIT BAD TRAP: pc=0x800033c8, a0=0x00000001
```

合并 DUT/REF 的统一存储器并统一 `pmem_read()` 后，跳转表已经能够正确读取。程序不再立即进入 BAD TRAP，而是继续执行到第二组测试。

前置记录：

[riscv-tests/add BAD TRAP 与统一存储器调试记录](2026-11-23-riscv-tests-add统一存储器调试记录.md)

本次记录针对随后暴露的独立 RTL 问题。

## 2. 本次故障现象

运行命令：

```bash
cd /home/lgwd666/work/work/AI4EDA/AI4EDA-KIMI/ysyx-workbench/riscv-tests
make ARCH=minirv-npc ALL=add run
```

DiffTest 报告：

```text
DIFFTEST FAIL: DiffTest：pc=0x80000168 inst=0xff014183
x3 不一致，DUT=0x00000000，REF=0x00000002
```

测试最终显示：

```text
[           add] ***FAIL***
```

与前置问题相比，故障表现已经发生变化：

- 不再是程序一致地跳入 `fail`；
- 而是 DUT 和 REF 在执行一条具体指令后出现寄存器差异；
- DiffTest 给出了明确的 PC、指令编码、寄存器编号和双方数据。

因此，本次可以直接从 `0x80000168` 的指令及其前后数据流开始分析。

## 3. 检查失败点前后的指令

`build/add-minirv-npc.txt` 中的关键反汇编为：

```asm
8000013c <non_taken_0fail>:
8000013c: 00300513    li  a0, 3
80000140: 00100093    li  ra, 1
80000144: 00100593    li  a1, 1
80000148: 00b08733    add a4, ra, a1
8000014c: 00200393    li  t2, 2

80000150: fee12823    sw  a4, -16(sp)
80000154: fe712623    sw  t2, -20(sp)
...
80000168: ff014183    lbu gp, -16(sp)
```

这段代码属于第二组 ADD 测试：

```text
第一个操作数：ra = 1
第二个操作数：a1 = 1
ADD 实际结果：a4 = 1 + 1 = 2
预期结果：t2 = 2
```

随后：

```asm
sw a4, -16(sp)
```

把实际结果 `2` 保存到栈地址 `sp-16`。

再执行：

```asm
lbu gp, -16(sp)
```

应该把刚才保存结果的最低字节重新读出。正确结果显然是：

```text
gp = 2
```

但 DiffTest 检测到：

```text
DUT gp = 0
REF gp = 2
```

所以 ADD 本身已经正确完成，真正出错的是测试框架用于检查结果的 LBU。

## 4. 解码失败指令

失败指令编码：

```text
0xff014183
```

其关键字段为：

```text
opcode = LOAD
funct3 = 4，即 LBU
rs1    = x2，即 sp
rd     = x3，即 gp
imm    = 0xff0
```

RISC-V I-type 地址立即数是 12 位有符号数，因此：

```text
0xff0 = -16
```

正确的有效地址计算为：

```text
addr = sp + sign_extend(0xff0, 12)
     = sp + 0xfffffff0
     = sp - 16
```

REF 按这一规则访问栈，因此读出了之前保存的 `2`。

## 5. 定位 RTL 根因

修改前 `npc/vsrc/EXU.sv` 的地址计算为：

```systemverilog
assign mem_addr =
    (opcode==STORE)||((opcode==LOAD)&(funt3==LOAD_LW)) ?
        rs1_data + {{20{imm[11]}}, imm[11:0]} :
    ((opcode==LOAD)&(funt3==LOAD_LBU)) ?
        rs1_data + {20'b0, imm[11:0]} :
        32'b0;
```

其中 LW 和 STORE 使用：

```systemverilog
{{20{imm[11]}}, imm[11:0]}
```

这是正确的 12 位符号扩展。

但 LBU 单独使用：

```systemverilog
{20'b0, imm[11:0]}
```

这是零扩展。代入 `imm=0xff0` 后：

```text
DUT addr = sp + 0x00000ff0
         = sp + 4080
```

于是双方访问了不同地址：

| 执行主体 | 地址计算 | 实际访问位置 | 读出数据 |
|---|---|---|---:|
| REF | `sp + 0xfffffff0` | `sp-16` | `2` |
| DUT | `sp + 0x00000ff0` | `sp+4080` | `0` |

错误地址位于已经清零的存储区域内，所以 DUT 读到 `0`，并在指令执行后形成 `x3` 差异。

## 6. 为什么 LBU 的“零扩展”容易被误用

RISC-V 规范确实要求 LBU 进行零扩展，但它针对的是**从存储器读出的 8 位数据**，不是地址立即数。

LBU 的完整语义可以写成：

```c
uint32_t addr = x[rs1] + sign_extend(imm, 12);
uint8_t byte = memory[addr];
x[rd] = zero_extend(byte, 32);
```

两种扩展的作用如下：

| 对象 | 扩展方式 | 原因 |
|---|---|---|
| 地址立即数 | 符号扩展 | load 可以使用负偏移，例如 `-16(sp)` |
| LBU 读出的字节 | 零扩展 | `U` 表示 unsigned，不能把无符号字节解释成负数 |

例如：

```asm
lbu x3, -16(x2)
```

如果目标字节为 `0x80`，正确过程是：

```text
地址：x2 - 16
读出：0x80
x3：  0x00000080
```

原 RTL 对读出数据的处理：

```systemverilog
{24'b0, mem_rdata_lb}
```

是正确的，不需要修改。

错误只在于把数据零扩展的思想误用到了地址立即数上。

## 7. 实际修复方式

本人将 `EXU.sv` 中 STORE、LW、LBU 分开的地址计算合并为统一的 LOAD/STORE 地址计算：

```systemverilog
assign mem_addr =
    (opcode==STORE)||(opcode==LOAD) ?
        rs1_data + {{20{imm[11]}}, imm[11:0]} :
        32'b0;
```

这个修改有两个效果：

1. LBU 与其他访存指令一样，对地址立即数进行符号扩展；
2. 删除重复的地址表达式，避免不同 load 类型以后再次出现不一致。

读出数据的路径仍然保留：

```systemverilog
{24'b0, mem_rdata_lb}
```

因此修复后同时满足：

```text
地址立即数符号扩展正确
LBU 数据零扩展正确
```

## 8. 修复后的验证

重新运行：

```bash
cd /home/lgwd666/work/work/AI4EDA/AI4EDA-KIMI/ysyx-workbench/riscv-tests
make ARCH=minirv-npc ALL=add run
```

Verilator 重新构建 NPC 后，程序完整执行到结束，输出：

```text
HIT GOOD TRAP: pc=0x800033c8, a0=0
test list [1 item(s)]: add
[           add] PASS
```

这次结果说明：

- 第二组测试中的 `lbu gp,-16(sp)` 能正确读出数据；
- 后续包含其他正、负偏移的访存序列也继续执行；
- 全部 `add` 测试用例完成；
- DUT 与 REF 没有再出现架构状态差异；
- 程序最终进入 `pass`，设置 `a0=0` 并执行 `ebreak`。

因此可以将本问题标记为已修复，`riscv-tests/add` 单项测试通过。

## 9. 构建中仍存在的非致命警告

本次构建还报告了：

- `LSU.sv` 中 `pmem_write` 的 `mem_wmask` 从 4 位扩展到 DPI `byte` 的位宽警告；
- `EXU.sv` 中 `funt7` 未使用；
- `new_pc_addr[0]` 未使用；
- `npc_define.sv` 中部分指令参数未使用。

这些警告没有阻止本次 `add` 测试通过，也不属于本次 LBU 地址错误。后续可以分别清理，不应与功能错误混在同一个修改中。

## 10. 调试结论与下一步

本次完整因果链为：

```text
统一存储器修复后，程序进入第二组非零 ADD 测试
→ sw 将结果 2 保存到 sp-16
→ lbu 使用 -16(sp) 重新读取
→ DUT 错把立即数 0xff0 零扩展为 +4080
→ DUT 从错误地址读到 0，REF 从正确地址读到 2
→ DiffTest 在 x3 上发现差异
→ 将 LBU 地址计算改为符号扩展
→ riscv-tests/add 全部通过
```

本次调试体现了两点：

1. **DiffTest 的价值**：它直接给出第一条产生架构状态差异的指令，避免把公共 `fail` 或最后的 `ebreak` 误认为根因。
2. **故障点向后移动是有效验证**：统一存储器修复后，测试从第一组推进到第二组；LBU 修复后，整个单项测试最终 PASS。

下一步可以运行完整 `riscv-tests` 和其他 AM 测试，检查是否还有被 `add` 覆盖不到的指令或访存边界问题：

```bash
make ARCH=minirv-npc run
```

完整测试若出现新的失败，应根据新的第一差异点单独定位，不把后续错误都归因于本次 LBU 问题。
