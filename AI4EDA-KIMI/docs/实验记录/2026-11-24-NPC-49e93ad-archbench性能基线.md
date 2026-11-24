# minirv NPC archbench 性能基线（49e93ad）

> 记录日期：2026-11-24  
> 用途：保存当前 NPC 版本的独立性能基线，供后续 RTL 和仿真环境迭代逐项对比  
> 结论：**20 项全部 PASS，GEOMEAN 153 Marks，MEAN 413 Marks**

## 1. 基线版本

| 项目 | 版本 |
|---|---|
| NPC / 仿真环境 | `49e93ad1a7880f5123aace5fc480a13548779b56`（`按周期提交UART与存储器写请求`） |
| am-kernels | `4a90b52b7cd700955b305d3cf73b9a53ce8f42ae` |
| archbench | `52034e3c65e973cab0af7d2e6e614e6d4470cf86` |
| Verilator | 5.032 |

当前 NPC 的主要特征：

- 单周期 minirv，支持 `add/addi/lui/lw/lbu/sw/sb/jalr`。
- DUT 和 minirvEMU REF 逐指令执行 DiffTest，比较 PC、取指和 `x0~x15`。
- 指令与数据共用 128 MiB PMEM，起始地址为 `0x80000000`。
- UART 和计时器由仿真环境提供 MMIO 行为模型。
- PMEM/UART 写采用低电平观察、高电平单次提交的临时写窗口。
- 计时器按仿真周期计数，不使用宿主机墙钟时间。

## 2. 固定测试条件

| 配置 | 数值 |
|---|---|
| 输入规模 | `train` |
| 假设 NPC 频率 | 100MHz |
| 周期到微秒换算 | `time_us = cycle_count / 100` |
| 单项目周期上限 | 10,000,000,000 |
| 并行度 | `nproc=2` |
| DiffTest | 全程开启 |
| 波形记录 | 未开启 |

运行命令：

```bash
cd AI4EDA-KIMI/ysyx-workbench/archbench
export BENCH_HOME=$PWD
cd scripts
NPC_MAX_CYCLES=10000000000 nproc=2 \
  bash run.sh ARCH=minirv-npc mainargs=train
```

依赖环境：`time`、`parallel`、`python`、`python3-numpy`。`archbench` 的输入选择文件由脚本切换为 `train`。

## 3. 汇总结果

| 指标 | 结果 |
|---|---:|
| 通过项目 | 20 / 20 |
| **GEOMEAN** | **153 Marks** |
| MEAN | 413 Marks |
| 参考处理器分数 | 1,000,000 Marks @ AMD Ryzen 9 7950X3D |
| 并行运行阶段宿主总耗时 | 约 20 分 34 秒 |

所有项目均通过功能校验和 DiffTest，没有周期上限截断。几何平均值作为后续版本综合性能对比的首要指标，算术平均值仅作辅助参考。

## 4. 各项目基线

| Benchmark | Marks | NPC 计分时间（100MHz） | 宿主仿真耗时 |
|---|---:|---:|---:|
| 100.blockchain | 296 | 0.145140 s | 4.91 s |
| 101.igemm | 7 | 3.069514 s | 100.44 s |
| 102.queen | 623 | 0.883286 s | 24.81 s |
| 103.dinic | 808 | 0.136029 s | 31.94 s |
| 104.malloc | 699 | 0.925174 s | 26.24 s |
| 105.bf | 448 | 0.359105 s | 10.16 s |
| 106.qsort | 1144 | 0.211428 s | 59.11 s |
| 107.stream | 348 | 0.775804 s | 23.45 s |
| 108.ntt | 7 | 0.939385 s | 27.04 s |
| 200.genann | 8 | 7.777645 s | 210.26 s |
| 201.jpeg | 170 | 0.486290 s | 15.74 s |
| 202.llama2 | 5 | 39.824200 s | 1061.01 s |
| 203.rsa | 92 | 2.345059 s | 65.39 s |
| 204.hypergraph | 980 | 1.775825 s | 63.43 s |
| 300.bzip3 | 518 | 1.079093 s | 30.15 s |
| 301.gsim | 335 | 0.285990 s | 11.27 s |
| 302.lua | 581 | 0.118675 s | 4.66 s |
| 303.cproc | 931 | 0.194208 s | 6.56 s |
| 304.mp3 | 4 | 3.571835 s | 94.90 s |
| 305.h264 | 256 | 0.736002 s | 25.43 s |

`202.llama2` 是宿主仿真时间的主要来源，约占 17 分 41 秒。宿主耗时只反映仿真成本，不是 NPC 性能分数；版本间性能比较应使用相同假设频率下的 NPC 计分时间和 Marks。

## 5. 后续版本对比规则

每次迭代后另建一份以新提交号命名的基线文档，不覆盖本文档，并记录：

1. NPC 提交号、主要微结构变化和仿真环境变化。
2. 与本文一致的 benchmark、输入规模、编译环境和假设频率。
3. 20 项功能结果、NPC 计分时间、Marks、GEOMEAN 和 MEAN。
4. 新增或删除的指令、存储器结构、周期模型及 DiffTest 配置。

只有全部应通过项目功能正确时，性能提升才有效。若测试配置发生变化，应单独说明，不能直接与本文分数混合比较。

单项加速比可按以下方式计算：

```text
加速比 = 基线 NPC 计分时间 / 新版本 NPC 计分时间
```

在 benchmark 和参考分数不变时，也可以使用：

```text
加速比 ≈ 新版本 Marks / 基线 Marks
```

建议同时观察：

- GEOMEAN 是否提高；
- 哪些项目提升或回退最明显；
- 是否以增加面积、降低最高频率或削弱功能为代价；
- 宿主仿真耗时是否显著增加。

## 6. 原始数据

本次原始日志和分数序列保存在：

```text
AI4EDA-KIMI/ysyx-workbench/archbench/result/
AI4EDA-KIMI/ysyx-workbench/archbench/result/excel.txt
```

`excel.txt` 内容：

```text
153,413,296,7,623,808,699,448,1144,348,7,8,170,5,92,980,518,335,581,931,4,256
```

完整测试搭建过程见[NPC 时钟与性能评测实验记录](2026-11-24-NPC时钟与性能评测实验记录.md)。
