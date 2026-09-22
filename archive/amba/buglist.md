# AXI4 Master Interface Bug List
*Created: 2026-04-28*
*Last Updated: 2026-04-28 — 所有问题已解决，10/10 PASS ✅*

---

## RTL Bugs (All Fixed ✅)

| # | 文件 | 问题 | 位置 | 修复 |
|---|------|------|------|------|
| 1 | `rtl/axi4_master_if.sv` | grant 初始值为 `2'b00`，应为 `2'b11` | 第116行 | `grant <= 2'b11` |
| 2 | `rtl/axi4_master_if.sv` | client_gnt 复位期间错误拉高，无条件赋值 | 第140-141行 | 改为 `rst_n ? ... : 1'b0` |
| 3 | `rtl/axi4_master_if.sv` | **grant 编码错误**：`client_gnt_0=(grant==2'd0)`，`client_gnt_1=(grant==2'd1)` | grant 逻辑 | 改为 `client_gnt_0=(grant==2'd1)`，`client_gnt_1=(grant==2'd2)` |
| 4 | `rtl/axi4_master_if.sv` | **selected_client 错误**：`=grant[0]`，应 decode grant | ARB 状态 | 改为 `selected_client = (grant == 2'd2)` |
| 5 | `rtl/axi4_master_if.sv` | **grant 赋值错误**：`grant <= idx`，idx=0 时 grant=0 | ARB | 改为 `grant <= (idx==0) ? 2'd1 : 2'd2` |
| 6 | `rtl/axi4_master_if.sv` | **ARB 状态转移用错信号**：用 `selected_client` 判断 transaction 类型 | ARB | 改用 `client_cmd_0/client_cmd_1` 根据 grant 判断 |
| 7 | `rtl/axi4_master_if.sv` | **req 越界访问**：`req[grant]` 在 grant=2 时访问 `req[2]` | ARB | 改为 `req[grant_client]` |
| 8 | `rtl/axi4_master_if.sv` | **缺少 client_bvalid 信号**：写交易完成无输出指示 | 声明 + WR_RESP | 添加 `client_bvalid_0/1` 输出，驱动 `m_axi_bready` |
| 9 | `rtl/axi4_master_if.sv` | **WR_RESP 退出条件错误**：等待 `m_axi_bvalid` 但 BFM 有 `#1` NBA 延迟 | WR_RESP | 改为检查 `client_bvalid`（自触发），立即退出 |
| 10 | `rtl/axi4_master_if.sv` | **m_axi_bready 仅在 WR_ADDR 拉高**：WR_RESP 期间 BFM 看不到 handshake | WR_RESP | `m_axi_bready = (state==WR_ADDR) \|\| (state==WR_RESP)` |

---

## TB Bugs (All Fixed ✅)

| # | 文件 | 问题 | 位置 | 修复 |
|---|------|------|------|----------|
| 1 | `axi4_master_if_tb.sv` | 信号名错误：`m_axi_arvalid` 应为 `axi_arvalid` | 第177行 | 替换信号名 |
| 2 | `axi4_master_if_tb.sv` | 时钟同步不足，单个@可能漏边沿 | 第195行 | `@(posedge clk)` → `repeat(2) @(posedge clk)` |
| 3 | `axi4_master_if_tb.sv` | **grant 后过早撤销 req**，导致状态机回 IDLE | 第211/223/243/249行 | 保持 req=1 直到 transaction 完成 |
| 4 | `testcase_06_arb_client1_priority.sv` | Phase 2 `#30` 延迟设置请求太晚，state 已从 IDLE 进入 ARB | Phase 2 | 删除 `#30`，在 `wait` 退出后立即设置请求 |
| 5 | `testcase_09_write_read.sv` | 写→读切换前未清 req，ARB 误选 Client1 | 写→读切换逻辑 | 在设置读请求前清 `tb_req_0=0` |
| 6 | `testcase_09_write_read.sv` | 读交易等待 `tb_bvalid_0`（写响应） | 读等待 | 改为等待 `tb_rvalid_0` |
| 7 | `testcase_09_write_read.sv` | 写数据存储检查在 RD_DATA 状态（永远不匹配） | 写数据检查 | 改为在 AW 握手时存储 |
| 8 | `testcase_09_write_read.sv` | 包含多个 testcase module 导致 Verilator 多 top | TB 文件 | extract 后仅保留目标 testcase module |
| 9 | `testcase_10_req_withdraw.sv` | Test 1 用 read (cmd=0) 但等待 `bvalid`（写响应） | Test 1 | 改为写交易 (cmd=1) + 等待 `bvalid` |
| 10 | `testcase_10_req_withdraw.sv` | 包含多个 testcase module | TB 文件 | extract 后仅保留目标 testcase module |

---

## Verilator 编译错误汇总

| # | 错误/警告 | 原因 | 解决 |
|---|-----------|------|------|
| 1 | `NEEDTIMINGOPT` | Verilator 5.032 不支持 SV 时序构造 | 加 `--timing` |
| 2 | `WIDTHTRUNC` (warning→error) | `req[grant_ptr]` 宽度截断 | 加 `-Wno-WIDTHTRUNC` |
| 3 | 路径含空格构建失败 | GNU Make 无法处理含空格路径 | 用 `-Mdir /tmp/verilator_build` |
| 4 | `--exe` 链接失败 | 无 main 函数 | 改用 `--binary` |
| 5 | `TIMESCALEMOD` warning | timescale 不匹配 | 加 `-Wno-TIMESCALEMOD` |
| 6 | `MULTITOP` | TB 文件包含多个 testcase module | extract 每个 TB 到独立文件，只保留一个 module |

---

## 待解决问题

**无。所有问题已解决，10/10 PASS ✅**

---

## 关键教训

### 1. AXI 请求保持原则
```
❌ 错误：grant 后立即撤销 req
wait(tb_gnt_0);
tb_req_0 = 0;        // 导致状态机回 IDLE
wait(tb_rvalid_0);

✅ 正确：transaction 完成后再处理
wait(tb_gnt_0);
wait(tb_rvalid_0);    // 等待完成，req 自动更新
```

### 2. grant 编码与 selected_client
```
grant 编码：2'd1(01)=Client0, 2'd2(10)=Client1
client_gnt_0 = (grant == 2'd1)   // 原错误: grant == 2'd0
client_gnt_1 = (grant == 2'd2)   // 原错误: grant == 2'd1
selected_client = (grant == 2'd2)  // grant=2 时选 Client1
```

### 3. WR_RESP BFM 握手时序
```
BFM axi_bvalid 有 #1 NBA 延迟
RTL 第一拍看到旧值，无法依赖 m_axi_bvalid 判断
解决：DUT 自触发表明自己在 WR_RESP，client_bvalid = m_axi_bready
      立即退出 WR_RESP，不等待 bvalid
```

### 4. Verilator always_comb 限制
```
Verilator 5.032 不支持 mid-block 变量声明
所有变量声明放在 always_comb block 开头
```

### 5. req 时序
```
req 必须在 @(posedge clk) 前设置，DUT 才能在时钟沿看到
#30 延迟会导致请求设置太晚，state 已离开 IDLE
```

### 6. 写→读切换
```
同一 client 从写切换到读，必须先清 req
否则 ARB 看到 req=1,cmd=1(写) 和 req=1,cmd=0(读) 同时存在
可能选错 client 或 transaction 类型
```
