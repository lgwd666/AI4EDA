# minirvEMU 与 NPC DiffTest 架构

本文对应当前 `npc/` 中的实现，目标是：

1. 用独立 C++ 模型实现 minirv 的 8 条指令；
2. 用 `ebreak` 作为仿真结束约定；
3. 在每条指令执行前后比较 NPC 与 minirvEMU 的架构状态；
4. 将比较失败、程序错误和超时都转换为非零进程退出码。

官方依据：[一生一芯 E5：实现 minirv](https://ysyx.oscc.cc/docs/2607/e/5.html)。

## 1. 文件分工

```text
npc/
├── csrc/
│   ├── main.cpp              # 仿真主循环、时钟、复位、trap 和退出码
│   ├── pmem.cpp/.h           # NPC 侧的 DPI-C 统一存储器
│   ├── minirv_emu.cpp/.h     # 独立参考指令集模拟器
│   ├── difftest.cpp/.h       # 状态比较与差异定位
│   └── minirv_emu_test.cpp   # 8 条指令和差异注入自测
├── vsrc/                     # 用户的 minirv NPC RTL
├── docs/minirvEMU-difftest.md
└── Makefile                  # Verilator 构建与主机侧自测
```

`minirv_emu` 不包含 Verilator 头文件，也不访问 `VNPC`。这样可以单独编译和测试参考模型，避免参考模型依赖被测硬件。

## 2. 总体数据流

```text
                         同一份 program.bin
                                │
                    load_program() 读入并转为小端字数组
                                │
                 ┌──────────────┴──────────────┐
                 │                             │
                 ▼                             ▼
       NPC 统一存储器 pmem_load()       DiffTest::load_program()
                 │                             │
                 ▼                             ▼
        Verilator NPC（DUT）             MinirvEmu（REF）
        PC / inst / x0-x15               PC / inst / x0-x15
                 │                             │
                 └──────────────┬──────────────┘
                                ▼
                         逐指令状态比较
                                │
                 ┌──────────────┴──────────────┐
                 ▼                             ▼
              全部一致                       任一差异
           继续执行/检查 trap          打印 DIFFTEST FAIL，返回非零
```

DUT（Device Under Test）是用户的 NPC；REF（Reference）是 minirvEMU。两者加载相同的程序，但寄存器、PC 和统一存储器各自独立，NPC 的写入不会直接改变参考模型。

## 3. minirvEMU 的架构状态

`MinirvEmu` 在 `csrc/minirv_emu.h` 中定义，包含：

- `pc_`：32 位程序计数器，复位为 `0x80000000`；
- `regs_[16]`：16 个 32 位通用寄存器，对应 minirv 使用的 RV32E 寄存器数量；
- `memory_`：128 MiB 统一存储器，同时保存指令和数据；
- `halted_`：是否已经执行 `ebreak`。

`load_program()` 会同时完成参考模型复位：清空寄存器和统一存储器、加载完整程序、恢复初始 PC、清除停止状态。这样每次运行新程序都不会继承上一次运行的数据。

### x0 的处理

`write_reg()` 对 `x0` 的写入直接忽略，`step()` 结束时也强制保持 `regs_[0] = 0`。因此 `x0` 永远读出零。

### 寄存器编号检查

虽然指令中的寄存器字段有 5 位，minirv 只有 16 个寄存器。参考模型对实际使用的 `rd/rs1/rs2` 检查范围，编号大于 15 会报错，而不是越界访问数组。

## 4. 取指、译码和执行

主接口是：

```cpp
uint32_t MinirvEmu::fetch() const;
void MinirvEmu::step();
```

`fetch()` 使用当前 PC 从自己的 `memory_` 取指。当前 AM 约定的取指基址是 `0x80000000`，首个字节的数组索引为：

```text
pc - 0x80000000
```

`fetch()` 从该位置按小端序读取 4 个 byte。PC 非 4 字节对齐、低于基址或超出存储器范围都会报告错误。

`step()` 一次只执行一条指令：

1. 从 `memory_` 取出当前指令；
2. 如果是 `ebreak`，设置 `halted_` 并返回；
3. 提取 `opcode/rd/funct3/rs1/rs2/funct7`；
4. 生成 I 型或 S 型符号扩展立即数；
5. 默认下一 PC 为 `pc + 4`；
6. 根据指令完成运算、访存或跳转；
7. 更新 PC，并保持 `x0 = 0`。

### 支持的指令

| 指令 | opcode | funct3 | 参考模型行为 |
| --- | --- | --- | --- |
| `add` | `0x33` | `0` | `x[rd] = x[rs1] + x[rs2]`，同时要求 `funct7 = 0` |
| `addi` | `0x13` | `0` | `x[rd] = x[rs1] + sext(imm_i)` |
| `lui` | `0x37` | — | `x[rd] = inst & 0xfffff000` |
| `lw` | `0x03` | `2` | 从 `x[rs1] + sext(imm_i)` 读取 32 位并写入 `rd` |
| `lbu` | `0x03` | `4` | 读取一个 byte，并零扩展到 32 位 |
| `sw` | `0x23` | `2` | 将 `x[rs2]` 的 32 位写入 `x[rs1] + sext(imm_s)` |
| `sb` | `0x23` | `0` | 只将 `x[rs2][7:0]` 写入目标 byte |
| `jalr` | `0x67` | `0` | `rd = pc + 4`，`pc = (rs1 + sext(imm_i)) & ~1` |

所有 32 位加法都通过 `uint32_t` 自然截断，符合 RV32 的模 `2^32` 运算。

### 立即数

I 型立即数来自 `inst[31:20]`，S 型由 `inst[31:25]` 和 `inst[11:7]` 拼接。两者都做 12 位符号扩展：

```cpp
sign = 1 << 11;
result = (value ^ sign) - sign;
```

这种方法将 12 位负数正确扩展到 32 位，例如 `0xfff` 变为 `0xffffffff`。

### JALR 的读写顺序

参考模型先根据旧的 `rs1` 计算目标地址，再写 `rd = pc + 4`。因此即使 `rd == rs1`，跳转目标也不会被新写入的返回地址破坏。目标地址最低位按规范清零。

## 5. 存储器模型

### NPC 侧存储器

`pmem.cpp` 使用一个 128 MiB 的 `pmem` 数组，为 DPI-C 提供：

- `pmem_read()`：供 IFU 取指和 LSU 读取数据，两个模块都传入完整 CPU 地址；
- `pmem_write()`：按照 4 位 `wmask` 写统一存储器；
- `pmem_load()`：将完整程序加载到统一存储器，指令和初始化数据只需加载一次。

取指和数据访问的 CPU 地址范围是：

```text
0x80000000 ～ 0x87ffffff
```

DPI 读取采用对齐的 32 位总线语义；RTL 负责根据地址低两位选择 `lbu` 字节，以及移动 `sb` 的数据和写掩码。IFU 和 LSU 共用 `pmem_read()`，其地址都按 `addr - 0x80000000` 转换为数组偏移，因此数据写操作也可以修改后续指令。

### 参考模型存储器

minirvEMU 不复用 NPC 的 `pmem` 数组，而是使用自己的 128 MiB `memory_`：

- 取指和数据访问都使用 `memory_`；
- `load_program()` 将完整程序按小端序复制到 `memory_` 开头；
- `lw/sw` 直接按小端读取或写入 4 个 byte；
- `lbu/sb` 直接访问一个 byte，无需模拟 32 位总线的 `wmask`；
- `lw/sw` 地址必须 4 字节对齐，这是 E5 当前允许的简化。

DUT 和 REF 各自拥有统一存储器，既能保持一致的取指与数据访问语义，也能避免 NPC 的写入直接修改参考模型。

## 6. DiffTest 的比较点

`DiffTest` 内部拥有一个 `MinirvEmu`，对外提供两个主要操作。

### 执行前：check_state()

在 NPC 时钟上升沿之前比较：

1. 当前 PC；
2. 当前取出的指令；
3. `x0` 到 `x15` 的全部寄存器。

指令比较不仅检查执行结果，也能发现 IFU 地址映射、程序加载或取指错误。

### 执行后：step_and_compare()

`main.cpp` 先调用 `single_cycle()`，让 NPC 在上升沿完成当前指令。随后 DiffTest：

1. 让参考模型执行它自己的当前指令；
2. 比较参考模型下一 PC 与 NPC 当前 PC；
3. 比较双方所有 16 个寄存器。

每次比较失败后保存的信息包括：

- 出错阶段；
- 刚执行指令的 PC 和机器码；
- 第一个不一致的寄存器或下一 PC；
- DUT 值与 REF 值；
- 最近 16 条已执行指令的 PC 和机器码。

例如：

```text
DIFFTEST FAIL: DiffTest：pc=0x80000000 inst=0x800000b7 x1 不一致，DUT=0x80000001，REF=0x80000000
最近执行记录（旧 → 新）：
  pc=0x80000000 inst=0x800000b7
```

历史记录使用 16 项循环缓冲区，正常运行时只记录、不打印，因此不会产生大量日志。发生差异时按从旧到新的顺序输出，最后一条就是当前出错指令。对于执行后 PC 不一致，错误中的 `pc/inst` 仍指向刚执行的指令，`DUT/REF` 则分别表示实际和期望的下一 PC。

当前实现按寄存器编号从低到高报告第一个差异。找到第一个根本差异后停止仿真，避免后续错误传播产生大量无意义日志。

## 7. 主循环的时序

`main.cpp` 的核心顺序是：

```text
读取 bin 一次
  → 同时加载到 NPC 和参考模型
  → NPC 复位两拍
  → 退出复位并 eval()，更新当前取指
  → 执行前 check_state()
  → 若为 ebreak，停止并检查 a0
  → NPC single_cycle()
  → 参考模型执行同一条指令
  → 执行后 step_and_compare()
  → 进入下一条指令
```

退出复位后的 `eval()` 很重要：它让 `debug_inst` 在第一次检查前更新为复位 PC 对应的指令，而不是复位期间使用的零值。

当前最多执行 1,000,000 拍，防止程序或 NPC 出错时永久运行。该上限是仿真保护，不属于 ISA。

## 8. ebreak、GOOD/BAD TRAP 与退出码

`ebreak` 的机器码固定为：

```text
0x00100073
```

它是仿真环境与被运行程序之间的结束约定，不需要在 RTL 中实现完整 RISC-V 调试或异常机制。

执行前状态比较通过后，若当前指令是 `ebreak`：

- 不再让 NPC 或参考模型继续执行；
- 读取 NPC 的 `debug_regs[10]`，即 `a0`；
- `a0 == 0`：打印 `HIT GOOD TRAP`，进程返回 0；
- `a0 != 0`：打印 `HIT BAD TRAP`，进程返回非零。

DiffTest 差异、参考模型非法指令、访存越界和超时也都返回非零。因此 AM 上层 Makefile 可以正确显示 FAIL。

BAD TRAP 不一定意味着 DiffTest 失败：例如 `wrong` 是故意让程序以错误状态结束的测试，NPC 和参考模型可以完全一致，但最终仍应返回 BAD TRAP。

## 9. 构建和运行

### 主机侧自测

```bash
cd /home/lgwd666/work/work/AI4EDA/AI4EDA-KIMI/ysyx-workbench/npc
make test
```

该命令只用主机 `g++` 编译参考模型、DiffTest 和自测程序，不启动 Verilator。

自测程序覆盖：

- 全部 8 条 minirv 指令；
- `addi` 的负立即数；
- `lw/lbu/sw/sb` 和小端字节顺序；
- `jalr` 的跳转与返回地址；
- `ebreak` 停止；
- 故意把 DUT 的 `x1` 翻转一位，确认 DiffTest 能指出该寄存器。

### 通过 AM 运行 dummy

```bash
cd /home/lgwd666/work/work/AI4EDA/AI4EDA-KIMI/ysyx-workbench/am-kernels/tests/cpu-tests
make ARCH=minirv-npc ALL=dummy run
```

`abstract-machine/scripts/platform/npc.mk` 会先构建 NPC，再将生成的 `.bin` 路径传给 `build/NPC`。

### 运行 wrong

```bash
make ARCH=minirv-npc ALL=wrong run
```

预期看到 `HIT BAD TRAP`，并且对应测试显示 FAIL。

### 直接运行一个 bin

```bash
cd /home/lgwd666/work/work/AI4EDA/AI4EDA-KIMI/ysyx-workbench/npc
./build/NPC /absolute/path/to/program.bin
```

如果 NPC 源码有变化，先执行 `make build/NPC`，或通过 AM 的 `run` 规则自动构建。

## 10. 当前边界

当前 DiffTest 针对的是本阶段的单周期 minirv NPC：

- 只比较顶层暴露的 `x0–x15`；
- 支持 8 条 minirv 指令，另将 `ebreak` 作为仿真控制；
- 不支持不对齐 `lw/sw`；
- 尚未处理 UART、时钟等设备访问；
- 使用统一存储器，数据写操作可以修改后续指令，暂不提供代码区写保护或指令缓存一致性控制；
- 每条指令恰好对应一个 NPC 时钟周期，尚不适用于多周期或流水线提交机制。

后续扩展 ISA 时，应同时扩展参考模型；引入流水线后，比较点应从“每个时钟周期”改为“每条指令提交”，而不是直接比较流水线中间状态。
