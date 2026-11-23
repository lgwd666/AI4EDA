# riscv-tests/add BAD TRAP 与统一存储器调试记录

> 日期：2026-11-23  
> 阶段：E5/E6，minirv NPC、minirvEMU 与 DiffTest  
> 问题：`riscv-tests/add` 在没有 DiffTest 差异的情况下输出 `HIT BAD TRAP`  
> 当前结论：程序初始化数据未加载的问题已经修复；完整 `add` 仍未通过，当前阻塞点是独立的 LBU 负立即数地址扩展问题

## 1. 实验背景

本次调试涉及两个执行主体：

- **DUT（Device Under Test）**：`ysyx-workbench/npc/vsrc/` 中的单周期 minirv NPC RTL。
- **REF（Reference）**：`ysyx-workbench/npc/csrc/minirv_emu.cpp` 中的独立 C++ 参考模型。

当前 minirv 支持：

```text
add / addi / lui / lw / lbu / sw / sb / jalr
```

另外使用 `ebreak` 结束仿真。DiffTest 在每条指令执行前后比较：

- PC；
- 当前取出的指令；
- `x0～x15` 寄存器。

本次运行的是：

```bash
cd /home/lgwd666/work/work/AI4EDA/AI4EDA-KIMI/ysyx-workbench/riscv-tests
make ARCH=minirv-npc ALL=add run
```

## 2. 初始故障现象

程序最终输出：

```text
HIT BAD TRAP: pc=0x800033c8, a0=0x00000001
```

但没有出现：

```text
DIFFTEST FAIL
```

这个现象包含两个重要信息：

1. 程序确实执行到了 `ebreak`，不是仿真超时。
2. 到达 `ebreak` 前，DUT 和 REF 的 PC、取指和寄存器没有发现差异。

因此不能直接把问题归结为“NPC 某条指令与参考模型实现不一致”。还有一种可能：**DUT 和 REF 基于同一个错误环境，一致地执行了错误路径。**

## 3. 先确认 BAD TRAP 是谁报告的

反汇编文件：

```text
ysyx-workbench/riscv-tests/build/add-minirv-npc.txt
```

末尾关键代码为：

```asm
8000339c <fail>:
8000339c: 00100513    li a0, 1
800033a0: 80003237    lui tp, 0x80003
800033a4: 3c420213    addi tp, tp, 964
800033a8: 00020067    jr tp

800033ac <pass>:
800033ac: 00000513    li a0, 0

800033c4 <halt>:
800033c4: 00050513    mv a0, a0
800033c8: 00100073    ebreak
```

`npc/csrc/main.cpp` 的结束判断是：

- 检测到 `ebreak`；
- `a0 == 0`，输出 `HIT GOOD TRAP`；
- `a0 != 0`，输出 `HIT BAD TRAP`。

因此：

```text
HIT BAD TRAP
```

并不是 DiffTest 生成的错误，也不是仿真器主动把 `a0` 改成 `1`，而是测试程序先跳入 `fail`，由 `fail` 设置 `a0=1`，最后执行 `ebreak`。

`pc=0x800033c8` 只是公共结束位置，不能说明第一条出错指令就在这里。

## 4. 原始 add 测试想做什么

测试源文件：

```text
ysyx-workbench/riscv-tests/isa/rv64ui/add.S
```

第一组测试是：

```asm
TEST_RR_OP(2, add, 0, 0, 0)
```

宏展开后的核心逻辑相当于：

```asm
li  x1,  0
li  x11, 0
add x14, x1, x11    # 实际结果 0 + 0
li  x7,  0          # 预期结果 0
bne x14, x7, fail
```

所以第一组测试的预期行为非常明确：

```text
实际结果 = 0
预期结果 = 0
结果相同，不应进入 fail
```

但是 minirv 不支持 `bne`。当前生成的 ELF 已将条件跳转改写为查表和间接跳转，因此不能只阅读原始汇编宏，还必须检查实际反汇编。

## 5. 第一组测试的实际执行过程

实际指令开头为：

```asm
80000040 <main>:
80000040: 00200513    li a0, 2
80000044: 00000093    li ra, 0
80000048: 00000593    li a1, 0
8000004c: 00b08733    add a4, ra, a1
80000050: 00000393    li t2, 0
```

寄存器别名对应为：

```text
ra=x1，a1=x11，a4=x14，t2=x7
```

这里 `add a4, ra, a1` 得到 `a4=0`，ADD 本身执行正确。

随后程序保存实际结果和预期结果：

```asm
sw a4, -16(sp)    # 实际结果
sw t2, -20(sp)    # 预期结果
```

测试框架再逐字节比较两个结果。比较结束后：

```text
gp = 0：两个结果相同
gp ≠ 0：存在不同字节
```

第一组测试的数据全为零，所以得到 `gp=0`。

### 5.1 为什么全零测试暂时掩盖了 LBU 问题

比较过程中存在：

```asm
lbu gp, -16(sp)
```

当时 RTL 对 LBU 地址立即数使用零扩展，会把 `-16` 错算为 `+0xff0`。不过第一组测试中：

- 正确地址中的数据是 `0`；
- 错误地址中的未初始化数据也是 `0`。

因此这一组没有立即产生 DUT/REF 寄存器差异。故障被掩盖，并不代表 LBU 正确。

## 6. 条件跳转如何被改成查表

比较完成后，程序读取 `_same_result_table`：

```asm
lui  tp, 0x80003
addi tp, tp, 1280    # tp = 0x80003500
add  tp, tp, gp      # gp=0，读取第 0 项
lbu  tp, 0(tp)
```

接着将两个候选跳转地址放在栈上：

```text
sp-16：non_taken_0fail，继续下一组测试
sp-20：fail，失败处理
```

再根据表项计算应取哪一个地址：

```asm
add tp, tp, tp
add tp, tp, tp       # tp = 表项 × 4
add tp, sp, tp
lw  tp, -20(tp)
jr  tp
```

对应关系为：

| 表项 | 最终读取位置 | 跳转目标 |
|---:|---|---|
| `1` | `sp+4-20 = sp-16` | `non_taken_0fail` |
| `0` | `sp-20` | `fail` |

第一组比较正确时 `gp=0`，因此正确表初值必须满足：

```c
_same_result_table[0] = 1;
```

## 7. 检查 ELF 中的真实表初值

使用命令：

```bash
cd /home/lgwd666/work/work/AI4EDA/AI4EDA-KIMI/ysyx-workbench/riscv-tests
riscv64-linux-gnu-objdump -s \
  --start-address=0x80003500 \
  --stop-address=0x80003520 \
  build/add-minirv-npc.elf
```

输出：

```text
Contents of section .rodata:
 80003500 01000000 00000000 00010101 01010101
 80003510 01010101 01010101 01010101 01010101
```

这证明 ELF 本身没有问题：

```text
地址 0x80003500 的正确初值确实是 0x01
```

如果运行时读到 `0`，问题就在程序加载或数据访问路径，而不是测试程序生成了错误表。

## 8. 定位到仿真环境的加载缺陷

修改前，DUT 使用两个独立数组：

```cpp
Memory imem;
Memory dmem;
```

复位时：

```cpp
imem.fill(0);
dmem.fill(0);
```

加载程序时却只有：

```cpp
pmem_load(0, program);
```

而 `pmem_load()` 只写入 `imem`。

REF 也采用分离结构：

```cpp
program_ = words;                 // 指令
memory_.assign(kMemorySize, 0);  // 数据全部清零
```

因此，同一份 `.bin` 中虽然包含 `.rodata`，但数据访问路径没有看到它。

### 8.1 同一地址在两个数组中的内容不同

`_same_result_table` 的地址和偏移为：

```text
CPU 地址：0x80003500
数组偏移：0x80003500 - 0x80000000 = 0x3500
```

修改前的实际状态是：

```text
imem[0x3500]    = 0x01    # 整个 .bin 被装入指令区
dmem[0x3500]    = 0x00    # 数据区未加载
REF memory_[0x3500] = 0x00
```

`lbu` 是数据访问，不会读取 `imem`，所以程序实际得到：

```c
_same_result_table[0] = 0;
```

## 9. 完整的错误因果链

至此，初始 BAD TRAP 可以完整解释为：

```text
.bin 中包含正确的 .rodata 跳转表
→ 加载器只初始化指令区
→ LSU 和 REF 从全零数据区读取跳转表
→ _same_result_table[0] 从应有的 1 变成 0
→ 第一组 add 0, 0 虽然正确，程序仍选择 fail 地址
→ fail 设置 a0=1
→ 执行 ebreak
→ main.cpp 输出 HIT BAD TRAP
```

DUT 和 REF 都缺少相同的数据初始化，所以双方一起跳入 `fail`。这就是没有 DiffTest 差异却出现 BAD TRAP 的原因。

**DiffTest 检查的是双方是否一致，不直接检查程序语义是否正确。双方一致地走错时，DiffTest 会保持静默。**

## 10. 修复方案：合并为统一存储器

可选方案有两种：

1. 保留 IMEM/DMEM 分离，把初始化数据分别加载到两个数据存储模型。
2. 合并为统一存储器，让取指和数据访问看到同一份内容。

本次选择第二种，更适合当前简单的单周期 minirv，也避免重复维护加载逻辑。

对应提交：

```text
7090035 合并DUT与参考模型的指令数据存储器
```

### 10.1 DUT 修改

`npc/csrc/pmem.cpp` 中：

```cpp
Memory imem;
Memory dmem;
```

合并为：

```cpp
Memory pmem;
```

以下接口全部访问同一个数组：

- 取指读取；
- 数据读取；
- 数据写入；
- 程序加载；
- 调试查看。

这样 `.bin` 只需加载一次，`lbu` 就能读到与 `.bin` 一致的跳转表。

### 10.2 REF 修改

删除独立的 `program_`，只保留：

```cpp
std::vector<uint8_t> memory_;
```

`load_program()` 在清空 `memory_` 后，将完整 `words` 按小端序复制到其开头。

`fetch()` 改为通过 `read32(pc_)` 取指，与 `lw` 使用同一个存储器和相同的地址换算。

DUT 与 REF 仍各自拥有一份存储器，NPC 的写入不会直接修改 REF；但两者内部都实现了统一取指和数据访问。

## 11. 进一步统一读取接口

对应提交：

```text
4243634 统一取指与数据读取接口
```

删除：

```cpp
pmem_pc_read()
```

IFU 改为与 LSU 共用：

```systemverilog
import "DPI-C" function int pmem_read(input int raddr);
assign inst = !rst_n ? 0 : pmem_read(pc);
```

此时 IFU 传入完整 PC，不再先减去 `0x80000000`。

环境的职责变为：

1. 接收完整 CPU 地址；
2. 检查地址是否落在当前 SRAM 范围；
3. 计算 SRAM 局部偏移；
4. 访问统一 `pmem` 数组。

当前映射为：

```text
CPU 地址 = SRAM 基址 + SRAM 内部偏移
SRAM 内部偏移 = CPU 地址 - 0x80000000
```

例如：

| 内容 | CPU 地址 | `.bin`/SRAM 偏移 |
|---|---:|---:|
| 第一条指令 | `0x80000000` | `0` |
| `main` 第一条指令 | `0x80000040` | `0x40` |
| `_same_result_table` | `0x80003500` | `0x3500` |

内部偏移 `0` 不等于 CPU 地址 `0`。当前直接访问 CPU 地址 `0` 会因未映射而报错。

## 12. 为什么 .bin 从偏移 0 开始

运行地址由链接器指定，不由 `.bin` 文件自行记录。

`abstract-machine/scripts/platform/npc.mk` 中：

```make
LDFLAGS += --defsym=_pmem_start=0x80000000 --defsym=_entry_offset=0x0
```

官方 `abstract-machine/scripts/linker.ld` 使用：

```ld
. = _pmem_start + _entry_offset;
```

所以 ELF 中第一条指令地址为 `0x80000000`。

随后框架执行：

```bash
objcopy ... -O binary program.elf program.bin
```

生成扁平二进制时，第一个需要加载的字节被写到文件偏移 `0`。`.bin` 只保存字节，不保存运行基址。

因此以下三者必须保持一致：

- 链接脚本的程序基址；
- NPC 的复位 PC；
- SoC/仿真环境的存储器地址映射。

## 13. 对未来 SoC 地址译码的意义

IFU 应产生完整 PC，不应绑定某个具体 SRAM 的局部偏移。否则未来增加其他指令存储设备时，硬编码基址会失效。

推荐的结构是：

```text
IFU / LSU 发出完整 CPU 地址
              │
              ▼
       总线或环境地址译码
        ├─ SRAM：addr - SRAM_BASE
        ├─ UART：addr - UART_BASE
        └─ Flash：addr - FLASH_BASE
```

当前把 `0x80000000` 映射到 SRAM 偏移 `0`，正是这一结构在单设备环境下的简化形式。

统一存储器还意味着：

- `lw` 可以把指令当作数据读取；
- `sw` 可以修改后续指令；
- 数据地址错误可能破坏程序；
- 当前没有代码区写保护、I-cache 或 `fence.i` 一致性处理。

这些行为符合统一存储模型的特点，接入 SoC 时需要根据实际需求决定是否增加保护。

## 14. 修复后的验证

### 14.1 主机侧自测

运行：

```bash
cd /home/lgwd666/work/work/AI4EDA/AI4EDA-KIMI/ysyx-workbench/npc
make test
```

结果：

```text
minirvEMU TEST PASS: 8 instructions, ebreak and DiffTest mismatch detection
```

### 14.2 重新运行 riscv-tests/add

运行：

```bash
cd /home/lgwd666/work/work/AI4EDA/AI4EDA-KIMI/ysyx-workbench/riscv-tests
make ARCH=minirv-npc ALL=add run
```

修复前，程序在第一组全零测试后直接进入 BAD TRAP。

修复后，程序已经越过第一组测试，进入第二组非零测试，随后在 `0x80000168` 报告：

```text
DIFFTEST FAIL: pc=0x80000168 inst=0xff014183
x3 不一致，DUT=0x00000000，REF=0x00000002
```

这条指令为：

```asm
lbu gp, -16(sp)
```

第二组测试计算 `1+1=2`，REF 从正确栈地址读到 `2`，DUT 从错误地址读到 `0`。

这个结果说明：

1. 跳转表已经能正确加载和读取；
2. 第一组测试不再被误判；
3. 原先被全零数据掩盖的 LBU 问题现在暴露出来；
4. 统一读取接口能够正常取指，修改前后都到达同一个后续差异点。

因此，存储器初始化问题已经修复，但完整 `add` 仍不能标记为 PASS。

## 15. 尚未解决的独立问题

当前 `npc/vsrc/EXU.sv` 对 LBU 有效地址使用：

```systemverilog
rs1_data + {20'b0, imm[11:0]}
```

这把 12 位地址立即数零扩展。对于 `-16` 的编码 `12'hff0`：

```text
正确地址：sp - 16
当前 DUT 地址：sp + 0xff0
```

正确处理应区分：

- **地址立即数**：按 I-type 规则进行 12 位符号扩展；
- **LBU 读出的字节**：写入寄存器时进行零扩展。

这两种扩展发生在不同位置，不能混为一谈。

本次没有修改该 RTL，下一步由本人修正后重新运行：

```bash
make ARCH=minirv-npc ALL=add run
make ARCH=minirv-npc run
```

## 16. 本次调试经验

### 16.1 BAD TRAP 与 DIFFTEST FAIL 要分开分析

```text
DIFFTEST FAIL：DUT 与 REF 在某一指令点出现架构状态差异
HIT BAD TRAP：程序到达 ebreak，且 a0 非零
```

BAD TRAP 可能由 RTL 错误引起，也可能由测试环境、程序加载或软件自身逻辑引起，必须沿控制流继续定位。

### 16.2 没有 DiffTest 差异不等于程序正确

DUT 和 REF 共享相同的错误假设时，双方可以一致地得到错误结果。参考模型不仅要独立实现指令语义，其程序加载、地址映射和初始化数据也必须正确。

### 16.3 公共 fail/halt 不是第一故障点

`fail` 和 `ebreak` 只负责报告失败。应结合反汇编、最近执行历史和关键数据初值，向前寻找是谁选择了 `fail`。

### 16.4 原始源码和实际二进制都要检查

原始 `add.S` 使用 `bne`，而 minirv 实际二进制使用查表和 `jalr`。只阅读原始宏无法解释实际运行路径。

### 16.5 修复一个故障后进入下一个故障是有效进展

修复前是第一组测试后直接 BAD TRAP；修复后进入第二组测试并出现确定的 LBU 差异。故障点向后移动、第一故障现象消失，证明修复针对的问题已经生效，但不能据此宣称整个测试通过。

## 17. 相关文件与提交

主要文件：

```text
ysyx-workbench/npc/csrc/pmem.cpp
ysyx-workbench/npc/csrc/minirv_emu.cpp
ysyx-workbench/npc/csrc/minirv_emu.h
ysyx-workbench/npc/csrc/main.cpp
ysyx-workbench/npc/vsrc/IFU.sv
ysyx-workbench/npc/vsrc/EXU.sv
ysyx-workbench/npc/docs/minirvEMU-difftest.md
ysyx-workbench/riscv-tests/build/add-minirv-npc.txt
ysyx-workbench/abstract-machine/scripts/linker.ld
ysyx-workbench/abstract-machine/scripts/platform/npc.mk
```

相关提交：

```text
7090035 合并DUT与参考模型的指令数据存储器
4243634 统一取指与数据读取接口
```

统一存储器和 DiffTest 的当前架构说明见：

[minirvEMU 与 NPC DiffTest 架构](../../ysyx-workbench/npc/docs/minirvEMU-difftest.md)
