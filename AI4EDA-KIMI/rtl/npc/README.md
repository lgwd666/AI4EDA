# minirv NPC 仿真环境

本目录包含用户的单周期 minirv NPC RTL、Verilator 仿真驱动、独立 minirvEMU
参考模型和逐指令 DiffTest。

## 目录结构

```text
npc/
├── Makefile
├── vsrc/                         # NPC RTL，顶层为 NPC
├── csrc/
│   ├── main.cpp                  # 时钟、复位、主循环、trap 和退出码
│   ├── pmem.cpp/.h               # NPC 的 DPI-C 统一存储器
│   ├── minirv_emu.cpp/.h         # 8 条指令的独立参考模拟器
│   ├── difftest.cpp/.h           # 逐指令 PC、取指和寄存器比较
│   └── minirv_emu_test.cpp       # 参考模型和差异注入自测
├── docs/minirvEMU-difftest.md    # 详细架构说明
└── build/                        # 生成物，不提交
```

## 常用命令

```bash
make lint          # RTL 静态检查
make test          # 主机侧 minirvEMU / DiffTest 自测
make build/NPC     # 构建 Verilator 仿真器
./build/NPC /absolute/path/to/program.bin
```

通常从 AM 测试目录自动构建并运行：

```bash
cd ../am-kernels/tests/cpu-tests
make ARCH=minirv-npc ALL=dummy run
make ARCH=minirv-npc ALL=wrong run
```

详细的数据流、8 条指令语义、比较时序和限制见
[minirvEMU 与 NPC DiffTest 架构](docs/minirvEMU-difftest.md)。
