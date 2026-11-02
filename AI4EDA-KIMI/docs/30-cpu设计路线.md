# CPU 设计路线（EDA 学习线的实践载体）

> 2026-11-02 调整：本文档原为学习总纲 v3，现降级为**学习线（docs/20-学习线-EDA长期.md）
> 的实践载体**——CPU 项目提供真实 RTL 供 EDA 流程练手，不再是独立的求职主线。
> 总入口见 docs/00-学习总纲.md。求职冲刺期本线冻结，入职后按精力恢复。
>
> 原 v3 说明：阶段划分与 ysyx F/E/D/C/B/A 对齐；补入自制模拟器（NEMU/PA）、
> AM 运行时环境、调试基础设施（sdb/trace/DiffTest）、SoC 接入、综合与后端物理设计、
> 形式化验证；微架构顺序为"单周期 → 总线/SoC → cache → 流水线"（先完成，后完美）

## 一、背景与能力校准

**实际经历**：MCU 外设前端设计——PWM（定时器/比较器）、CAN/LIN（协议控制器）、
寄存器接口、AHB/APB 从设备、外设侧中断；做过 AXI4 Master + 仲裁器练手项目。

**已有优势**：
- RTL 编码与仿真调试功底扎实 → ysyx F 阶段（Logisim/HDLBits/数字电路实验）可跳过，
  E1（HDL）、E2（C 语言）、E3（Linux）可跳过
- 总线协议的从设备视角经验 + AXI4 Master 练手 → C 阶段总线部分是舒适区
- 外设中断源设计经验 → 学核内中断处理有外设端的对照系

**真正盲区**（学习重点）：
- 微架构：流水线、冒险、前递、分支预测、cache——几乎零基础
- 系统软件视角：从没写过模拟器；AM/运行时环境/bootloader/链接脚本——ysyx 的
  软件半边（NEMU + AM）恰是 v2 计划完全缺失的
- 工具链底层：编译/链接/ELF、golden model、difftest
- 量化设计方法论：性能计数器、Amdahl 定律、cachesim/branchsim 先评估再动手

**目标岗位画像**：平头哥/芯来/赛昉/奕斯伟/海思/玄戒/展锐等的 CPU 前端设计岗位。

## 二、最终交付物（面试作品集，v3 修订）

**主线**（对齐 ysyx B 阶段考核水平）：
- RV32IM 流水线 NPC：五级流水、转发、BTB 分支预测、精确异常
- I/D Cache、AXI4 接口、CLINT，接入 ysyxSoC 运行 RT-Thread
- **自研指令集模拟器**（类 NEMU，RV32IM）作为 DiffTest 的 REF
- **调试基础设施全家桶**：sdb、itrace/mtrace/ftrace、DiffTest
- microbench 跑分 + IPC/性能计数器分析报告（不用 coremark 作为主打，
  讲义明确指出 coremark/Dhrystone 代表性弱，microbench 更科学）
- yosys-sta 综合与 STA 报告；（可选）TinyTapeout 流片

**延伸**（A 阶段方向，长线）：乘除法器优化、系统调用、启动 Linux。

**支线 S1**：AI 加速器权重硬化实验（见 P7 后），面向 AI 芯片岗位。

## 三、讲义方法论（v3 新增，贯穿全程）

从讲义中提炼的核心思想，比具体知识点更重要：

1. **状态机模型贯穿一切**：ISA 是状态机，C 程序是状态机，处理器是用数字电路
   实现 ISA 状态机——调试和验证都从这个视角推导（F4）
2. **先完成，后完美**：先让处理器达到"可流片"形态（接总线、接 SoC），再逐项
   量化优化；不要先憋一个完美流水线核（B3/B4 的顺序安排即是体现）
3. **基础设施先行**：加指令之前先搭 sdb/trace/DiffTest——"不做工具人，
   不在波形里浪费生命"（D8）
4. **量化驱动优化**：任何优化先用性能计数器 + cachesim/branchsim 估算理想收益，
   用数据决定是否投入 RTL 实现；"可以选择不实现，但要用数据佐证决策"（B3/B4）
5. **总线视角统一微架构**：valid/ready 握手 + 分布式控制，单周期/多周期/流水线/
   乱序只是模块间通信协议不同，演进无需推翻重写（C4）
6. **RTFM/STFW/RTFSC**：手册是第一信息源（RISC-V 手册、C99、AXI 手册）

## 四、ysyx 阶段映射（v3 新增）

| ysyx 阶段 | 内容 | 官方估时* | 本计划 |
|---|---|---|---|
| F（预科） | 状态机模型、sCPU、数逻实验 | 42h | 精选融入 P0 |
| E（预学习） | HDL/C/Linux、Verilator+DiffTest、minirv NPC、SimpleBus+ysyxSoC、后端流片 | 65h | E1-E3 跳过；E4/E5 入 P0；E7/E8 打散到 P3/P7 |
| D（基础） | 编译链条、NEMU(PA1)、ISA、AM(PA2)、RV32E NPC+基础设施 | 69h | P1/P2 |
| C（系统） | 设备 IO、总线（AXI4/仲裁/Xbar/CLINT）、接入 ysyxSoC | 54h | P3 |
| B（进阶） | 异常+RT-Thread、时序、性能方法论+cache、流水线 | 60h | P4/P5/P6 |
| A（高级） | 乘除法器、syscall、虚存、xv6、启动 Linux、cache/分支预测进阶 | 自选 | P7 延伸 |
| S | 待续（官方未完） | - | - |

\* 官方按"中等水平"估计；我有 RTL 功底但系统软件弱，预计 D/C 阶段按 1.5 倍计。

## 五、阶段规划（v3）

### P0 状态机思维与第一个处理器（第 1~3 周）★对应 F4/F5/E4/E5
- 精读 F4 讲义（状态机模型）：这是整个 ysyx 的元认知
- E4：搭建 Verilator 环境（lint -Wall 习惯从此养成）+ FST 波形 + Makefile 一键仿真；
  NVBoard 跑双控开关/流水灯（无需 FPGA 的虚拟板卡）
- **写 minirvEMU**：C 语言实现 8 条迷你 RV 指令（add/addi/lui/lw/lbu/sw/sb/jalr）的
  模拟器——第一次亲手写"执行程序的程序"（E5）★v2 缺口
- RTL 实现 minirv NPC（IFU/IDU/EXU/LSU/WBU 模块划分）、DPI-C 访存、ebreak 结束仿真
- sCPU↔sEMU 的 DiffTest 雏形（E4 末尾），理解 DUT/REF 概念
- **交付**：minirv NPC 跑通测试程序 + 笔记"指令在核里的旅行"
- **验收**：能口述"取指→译码→执行→访存→写回"，能说清 DiffTest 为什么比看波形高效

### P1 程序是如何跑起来的 + 自研模拟器（第 4~8 周）★对应 D1/D2/D3/D4/D5
- D1 编译链条动手实验：gcc -E/-S/-c、clang -emit-llvm、objdump 反汇编、
  crt*.o 与加载器、"程序不是从 main 开始的"；C99 的未定义/未指定行为（面试加分项）
- **NEMU（PA1）**：RV32IM 模拟器 + 简易调试器 sdb（单步/打印寄存器/扫描内存/
  表达式求值/监视点）★v2 最大缺口，20h 硬仗
- D3/D4：RV32I 全貌 + 机器级表示；**填完 docs/p0-isa-notes.md**
- D5：AM 运行时环境（PA2 阶段 1-2）——TRM 三要素：可计算内存、入口、halt
- spike 观察执行降级为辅助手段（原本 P0a 的内容融入此处）
- **交付**：自研 NEMU 跑通 dummy + cpu-tests；能逐行解释 C↔汇编↔机器码

### P2 RV32E 全指令 + 调试基础设施（第 9~11 周）★对应 D6/D7/D8
- NPC 从 minirv 扩到 RV32E 全指令
- **基础设施全家桶**（先于加指令！）：NPC 版 sdb、itrace/mtrace/ftrace、
  **NEMU 作为 REF 的 DiffTest**（动态库链接，注入 bug 验证有效性）
- D6：yosys-sta 综合评估 ALU/NPC 主频，理解"综合报告≠真实频率"
- **交付**：RV32E NPC + 全基础设施，随机指令流 difftest 通过
- **面试映射**："你的验证方法学是什么"标准题

### P3 总线与 SoC（第 12~15 周）★对应 C2/C4/C5 —— 相对舒适区
- C2：MMIO 设备（串口/时钟），NPC 跑字符版红白机游戏（可选趣味项）
- C4 核心：SimpleBus 三阶段演进（1 周期延迟 → reqValid/respValid → 完整握手）
  → AXI4-Lite → 完整 AXI4；仲裁器 + Xbar + CLINT；握手的死锁/活锁约束
  ——**用你写过的 valid-ready 反压经验锚定，但你写过的 AXI4 Master 在这里直接复用**
- C5：接入 ysyxSoC——MROM/SRAM/flash/PSRAM/SDRAM、bootloader、
  链接脚本 VMA/LMA、mem-test、UART16550 初始化与轮询 putch
- E7 思想融入：IPC 测量、CPU/外设频率校准、"提频为什么不值得"（内存墙初体验）
- **交付**：NPC 在 ysyxSoC 上跑通 cpu-tests/riscv-tests/microbench
- **验收**：能讲清一次 load 从 LSU 到 SDRAM 颗粒返回的完整旅程

### P4 异常与系统（第 16~17 周）★对应 B1/B2
- CSR/ecall/mret；mstatus/mtvec/mepc/mcause 最小集
- NEMU 和 NPC 先后运行 RT-Thread（从外设中断源视角切入核内视角）
- B2：时序分析与优化
- **交付**：NPC 跑 RT-Thread + 中断全场景测试

### P5 性能方法论与 cache（第 18~20 周）★对应 B3 —— v2 顺序错误修正
- 性能公式三因子、Amdahl 定律、性能计数器体系、benchmark 选择
  （为什么 microbench 优于 coremark）
- **cachesim 先行**：用 mtrace 离线评估 cache 参数的收益，再决定 RTL 方案
- icache 实现 + AXI burst refill；**fence.i 与缓存一致性**（bootloader 复现反例）
- dcache：先用 cachesim 证明收益再决定是否实现（讲义预期：面积预算下可能不值）
- **交付**：带 icache 的核 + 量化分析报告（每个决策有数据支撑）

### P6 五级流水线（第 21~24 周）★对应 B4 —— 核心硬仗，放在 cache 之后
- 基于握手分布式控制改造流水线（C4 打的基础在此兑现）
- 三类冒险；转发（与教科书转发到 EX 的方案对比）；load-use
- 推测执行三要素（选择/检查/恢复）；BTFN、BTB；**branchsim 先行**评估准确率
- 精确异常在流水线中的实现；fence.i 冲刷
- **形式化验证（BMC）**：流水线 NPC vs 单周期 NPC 作为 REF，遍历指令序列
  ——ysyx 独有的杀手锏，面试差异化亮点（可选但强烈推荐）
- **交付**：流水线核 + microbench 对比报告（多周期 vs 流水线）+ IPC 归因分析

### P7 求职收尾 + A 阶段延伸（第 25 周~）
- 乘除法器（M 扩展硬件化）；系统调用；启动 Linux（长线目标，rv32imac）
- E8 后端物理设计体验：lint 清理、四值仿真（iverilog 查 X 传播）、网表仿真
- 简历包装 + 模拟面试（我出题）

### 支线 S1：AI 加速器——权重硬化实验（P6 完成后启动，与 P7 并行）
- **定位**：面向 AI 芯片设计岗位的加分项目，不影响主线节奏
- **核心问题**：把小模型权重"烧成硬件"值不值？用双版本对比回答：
  1. **可编程版**：INT8 transformer 加速器（GEMM 阵列 + 片上 SRAM + AXI4 从接口），
     权重可加载，跑 stories15M 级小模型（llama2.c 做 golden 对照）
  2. **硬连线版**：同一模型，权重烧 ROM / 综合成常数逻辑
  3. **PPA 对比报告**：量化"烧权重"的收益与灵活性代价——面试该讲的架构判断
- **复用主线资产**：AXI4、DiffTest 框架、cachesim 方法论、量化评估思维
  （加速器本质也是"带宽 vs 计算"问题，B3 的内存墙视角直接适用）
- **流片（可选）**：TinyTapeout（Sky130，提交 GDS 即可，无需本地硬件）
- **交付**：加速器 RTL + difftest 报告 + PPA 对比报告

## 六、AI 辅助工作流

| 阶段 | 我的角色 |
|---|---|
| P0~P1 | **主导讲解**：概念课+类比+示例为主，你的任务是复现和提问 |
| P2~P3 | **脚手架+陪练**：搭 difftest/trace 框架讲解，review 你的 RTL |
| P4~P6 | **顾问**：你主导设计，我做取舍讨论与把关；性能数据由你分析 |
| S1/P7 | 面试官 + 简历教练 |

**不变的原则**：设计文档和关键决策必须出自你手（面试要讲得出来）；
讲义的精神同样适用于 AI——不要让我替你" RTMF "，我指方向，你读手册。

## 七、工作环境

### 目录结构
> 注：2026-11-02 起仓库内容整体迁移至 `AI4EDA-KIMI/` 二级目录，以下为该目录内结构
```
AI4EDA/AI4EDA-KIMI/
├── README.md          # 项目主页（简历直接引用）
├── docs/              # 学习笔记、设计文档、阶段报告
│   ├── 00-学习总纲.md
│   └── p0-isa-notes.md
├── nemu/              # P1：自研模拟器（对齐 PA 结构）
├── npc/               # P0 起：处理器 RTL + 仿真环境（csrc/vsrc）
├── am-kernels/        # P1 起：AM 运行时与测试程序（对齐 ysyx 结构）
├── ysyxSoC/           # P3：SoC 环境（ submodule 或 clone）
├── sw/p0/             # 早期实验（build.sh / link.ld 已就绪）
├── accel/             # 支线 S1：AI 加速器（P6 完成后建立）
└── tools/             # difftest/cachesim/branchsim 脚本
```

### 工具链
| 工具 | 用途 | 状态 |
|---|---|---|
| Verilator / iverilog / yosys / gtkwave | 仿真/四值仿真/综合/波形 | ✅ |
| riscv-none-elf-gcc 15.2.0 | 交叉编译 | ✅ ~/tools |
| spike | 参考模拟器（辅助观察，REF 以自研 NEMU 为主） | ✅ ~/tools |
| riscv-pk | 让 C 程序 printf | ✅ ~/tools/pk |
| NVBoard | 虚拟 FPGA 板卡（无需硬件） | ⬜ P0 安装 |
| ysyxSoC / am-kernels / nemu 框架 | P1~P3 逐步 clone | ⬜ 待获取 |
| VS Code + Remote-SSH | Windows 编辑 VM 代码 | ⬜ 待配置 |

### 硬件
虚拟机 4 核 / 3.3GB / 72GB——RV32 仿真够用；NVBoard 替代 FPGA；
流片走 TinyTapeout（云端提交）。代码全在 VM，Windows 经 Remote-SSH 编辑。

## 八、进度记录

| 日期 | 阶段 | 完成内容 | 下一步 |
|---|---|---|---|
| 2026-09-23 | v2 修订 | 按外设背景重排学习路径 | P0a |
| 2026-11-02 | 总纲更新 | 新增支线 S1（AI 加速器）；目录迁至 AI4EDA-KIMI/ | P0a |
| 2026-11-02 | **v3 重写** | 通读 ysyx v26.07 全部讲义，阶段对齐 F/E/D/C/B/A；补入 NEMU/AM/基础设施/SoC/后端/形式化验证六大缺口；微架构顺序改为"单周期→总线/SoC→cache→流水线"；总周期调整为约 25 周 | P0：F4 讲义 + Verilator 环境 |
