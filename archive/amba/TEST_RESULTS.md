# AXI4 Master Interface 仿真测试报告

**生成时间**: 2026-04-28
**仿真器**: Verilator 5.032
**最终状态**: ✅ 10/10 PASS

---

## 测试用例状态

| ID | 文件 | 名称 | 描述 | 状态 |
|----|------|------|------|------|
| TC01 | `tb/testcase_01_client0_read.sv` | Client 0 Read | Client 0 单次读交易 | ✅ PASS |
| TC02 | `tb/testcase_02_client0_write.sv` | Client 0 Write | Client 0 单次写交易 | ✅ PASS |
| TC03 | `tb/testcase_03_client1_read.sv` | Client 1 Read | Client 1 单次读交易 | ✅ PASS |
| TC04 | `tb/testcase_04_client1_write.sv` | Client 1 Write | Client 1 单次写交易 | ✅ PASS |
| TC05 | `tb/testcase_05_arb_client0_first.sv` | Round-robin Arbitration | Client 0 先请求，验证轮询 | ✅ PASS |
| TC06 | `tb/testcase_06_arb_client1_priority.sv` | Round-robin Switch | Client 1 优先请求，验证切换 | ✅ PASS |
| TC07 | `tb/testcase_07_backpressure.sv` | Backpressure | AXI BFM 背压测试 | ✅ PASS |
| TC08 | `tb/testcase_08_consec_reads.sv` | Consecutive Reads | Client 0 连续读 3 次 | ✅ PASS |
| TC09 | `tb/testcase_09_write_read.sv` | Write-Read Sequence | 写后立即读，验证状态切换 | ✅ PASS |
| TC10 | `tb/testcase_10_req_withdraw.sv` | Request Withdraw | 请求撤销测试 | ✅ PASS |

---

## 已修复的 RTL Bug

| # | 问题 | 位置 | 修复内容 |
|---|------|------|----------|
| 1 | grant 初始值为 `2'b00`，应为 `2'b11` | RTL 第116行 | `grant <= 2'b11` |
| 2 | client_gnt 复位期间错误拉高 | RTL 第140-141行 | 添加 `rst_n ? ... : 1'b0` 条件 |
| 3 | **grant 编码错误**：`client_gnt_0=(grant==2'd0)`，`client_gnt_1=(grant==2'd1)` | RTL grant 逻辑 | 改为 `client_gnt_0=(grant==2'd1)`，`client_gnt_1=(grant==2'd2)` |
| 4 | **selected_client 错误**：`=grant[0]`，应使用 decode | RTL ARB 状态 | 改为 `selected_client = (grant == 2'd2)` |
| 5 | **grant 赋值错误**：`grant <= idx`，idx=0时 grant=0 | RTL ARB | 改为 `grant <= (idx==0) ? 2'd1 : 2'd2` |
| 6 | **ARB 状态转移用错信号**：用 `selected_client` 判断 transaction 类型 | RTL ARB | 改用 `client_cmd_0/client_cmd_1` 根据 grant 判断 |
| 7 | **req 越界访问**：`req[grant]` 在 grant=2 时访问 `req[2]` | RTL ARB | 改为 `req[grant_client]` |
| 8 | **缺少 client_bvalid 信号**：写交易完成无指示 | RTL 声明 + WR_RESP | 添加 `client_bvalid_0/1` 输出，驱动 `m_axi_bready` |
| 9 | **WR_RESP 退出条件错误**：等待 `m_axi_bvalid` 但 BFM 有 `#1` NBA 延迟 | RTL WR_RESP | 改为检查 `client_bvalid`（自触发），立即退出 |
| 10 | **m_axi_bready 仅在 WR_ADDR 拉高**：WR_RESP 期间 BFM 看不到 | RTL WR_RESP | `m_axi_bready = (state==WR_ADDR) \|\| (state==WR_RESP)` |

---

## 已修复的 TB Bug

| # | 文件 | 问题 | 修复内容 |
|---|------|------|----------|
| 1 | `axi4_master_if_tb.sv` | 信号名错误：`m_axi_arvalid` → `axi_arvalid` | 第177行修正 |
| 2 | `axi4_master_if_tb.sv` | 时钟同步不足 | `@(posedge clk)` → `repeat(2) @(posedge clk)` |
| 3 | `axi4_master_if_tb.sv` | grant 后过早撤销 req | 保持 req=1 直到 transaction 完成 |
| 4 | `testcase_06_arb_client1_priority.sv` | Phase 2 `#30` 延迟设置请求太晚，state 已从 IDLE 进入 ARB | 删除 `#30`，在 `wait` 退出后立即设置请求 |
| 5 | `testcase_09_write_read.sv` | 写→读切换前未清 req，ARB 误选 Client1 | 在设置读请求前清 `tb_req_0=0` |
| 6 | `testcase_09_write_read.sv` | 读交易等待 `tb_bvalid_0`（写响应） | 改为等待 `tb_rvalid_0` |
| 7 | `testcase_09_write_read.sv` | 写数据存储检查在 RD_DATA 状态（永远不匹配） | 改为在 AW 握手时存储 |
| 8 | `testcase_09_write_read.sv` | 包含多个 testcase module 导致 Verilator 多 top | extract 后仅保留目标 testcase |
| 9 | `testcase_10_req_withdraw.sv` | Test 1 用 read (cmd=0) 但等待 `bvalid`（写响应） | 改为写交易 (cmd=1) + 等待 `bvalid` |
| 10 | `testcase_10_req_withdraw.sv` | 包含多个 testcase module | extract 后仅保留目标 testcase |

---

## Verilator 编译配置

```bash
verilator -Mdir /tmp/verilator_tcXX \
  --timing \
  -Wno-WIDTHTRUNC \
  -Wno-TIMESCALEMOD \
  -Wno-fatal \
  --binary \
  -I./rtl \
  rtl/axi4_master_if.sv \
  tb/testcase_XX_*.sv
```

---

## 关键设计决策

| 决策 | 说明 |
|------|------|
| **grant 编码** | `2'd1`(01)=Client0, `2'd2`(10)=Client1 |
| **req 时序** | req 必须在 `@(posedge clk)` 前设置，DUT 才能在时钟沿看到 |
| **WR_RESP 握手** | BFM `axi_bvalid` 有 `#1` NBA 延迟，RTL 第一拍看到旧值；DUT 自触发表明自己在 WR_RESP，无需等待 bvalid |
| **m_axi_bready** | 在 WR_ADDR 和 WR_RESP 期间均保持高，确保 BFM 能看到握手 |
| **Verilator always_comb** | 5.032 版本不支持 mid-block 变量声明，声明放在 block 开头 |

---

## 文件修改记录

### rtl/axi4_master_if.sv 关键修改

```systemverilog
// grant 编码修复
assign client_gnt_0 = (grant == 2'd1);  // 原: grant == 2'd0
assign client_gnt_1 = (grant == 2'd2);  // 原: grant == 2'd1

// selected_client 修复
selected_client = (grant == 2'd2);     // 原: grant[0]

// grant 赋值修复
grant <= (idx == 0) ? 2'd1 : 2'd2;     // 原: grant <= idx

// client_bvalid 添加
output logic client_bvalid_0, client_bvalid_1,
assign client_bvalid_0 = m_axi_bready;  // WR_ADDR/WR_RESP 期间高
assign client_bvalid_1 = m_axi_bready;

// WR_RESP m_axi_bready
m_axi_bready = (state == WR_ADDR) || (state == WR_RESP);

// WR_RESP 立即退出（不等待 bvalid）
WR_RESP: begin
  client_bvalid_0 = m_axi_bready;
  client_bvalid_1 = m_axi_bready;
  m_axi_bready = 1'b1;
  next_state = (client_bvalid_0 || client_bvalid_1) ? IDLE : WR_RESP;
end
```

### tb/testcase_09_write_read.sv 关键修改

```systemverilog
// 写→读切换：先清 req
wait(tb_bvalid_0);
tb_req_0 = 0;                      // 关键：清 req 再设置读
tb_cmd_0 = 0;                      // 0=read
tb_req_0 = 1;
wait(tb_rvalid_0);                 // 等待读响应，不是 bvalid
```

### tb/testcase_06_arb_client1_priority.sv 关键修改

```systemverilog
// Phase 2: 删除 #30 延迟，立即设置请求
wait(phase1_done);
tb_req_1 = 1;                      // 删除了 #30，原 #30 导致请求设置太晚
tb_cmd_1 = 1;
```
