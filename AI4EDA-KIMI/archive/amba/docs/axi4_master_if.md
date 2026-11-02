# AXI4 Master Interface Design Document

## 1. Overview

- **模块名**: `axi4_master_if`
- **功能**: 32-bit AXI4 Master 接口，带轮询仲裁器，支持两个独立使用者
- **协议**: AXI4（不含 Out-of-order 和 Outstanding 功能）
- **位宽**: 32-bit 数据/地址

## 2. Architecture

```
                    ┌─────────────────────────────────────────┐
                    │              axi4_master_if              │
                    │                                         │
Client 0 ───────────┼──► req ──► ┌────────┐      ┌─────────┐  │
   (read/write)     │           │        │      │         │  │
                    │           │ Arbiter│ ───► │  AXI4   │──┼──► m_axi_*
Client 1 ───────────┼──► req ──► │        │      │  Master │  │
   (read/write)     │           │(RR)    │      │         │  │
                    │           └────────┘      └─────────┘  │
                    │                                         │
                    └─────────────────────────────────────────┘
```

## 3. 参数定义

| 参数名 | 值 | 说明 |
|--------|-----|------|
| `DATA_WIDTH` | 32 | 数据位宽 |
| `ADDR_WIDTH` | 32 | 地址位宽 |
| `ID_WIDTH` | 4 | Master ID 位宽 |

## 4. 端口定义

### 4.1 系统信号

| 信号 | 方向 | 说明 |
|------|------|------|
| `clk` | input | 时钟 |
| `rst_n` | input | 低有效异步复位 |

### 4.2 Client 接口 (x2)

每个使用者有独立的请求和响应通道。

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `client_req[1:0]` | input | 2 | 请求有效信号，高有效 |
| `client_cmd[1:0]` | input | 2 | 0=读, 1=写 |
| `client_addr[1:0]` | input | 32 | 访问地址 |
| `client_wdata[1:0]` | input | 32 | 写数据 |
| `client_be[1:0]` | input | 4 | 字节使能（写） |
| `client_gnt` | output | 2 | 授权信号 |
| `client_rvalid` | output | 1 | 读数据/写响应有效 |
| `client_rdata` | output | 32 | 读数据 |
| `client_resp` | output | 2 | 响应码：0=OK, 1=SLVERR, 2=DECERR |

### 4.3 AXI4 Master 接口

| 信号 | 方向 | 说明 |
|------|------|------|
| `m_axi_awid` | output | 写地址 ID |
| `m_axi_awaddr` | output | 写地址 |
| `m_axi_awlen` | output | 突发长度 |
| `m_axi_awsize` | output | 突发大小 |
| `m_axi_awburst` | output | 突发类型 (01=INCR) |
| `m_axi_awvalid` | output | 写地址有效 |
| `m_axi_awready` | input | 写地址就绪 |
| `m_axi_wdata` | output | 写数据 |
| `m_axi_wstrb` | output | 写数据字节使能 |
| `m_axi_wvalid` | output | 写数据有效 |
| `m_axi_wready` | input | 写数据就绪 |
| `m_axi_wlast` | output | 写数据最后突发 |
| `m_axi_bid` | input | 写响应 ID |
| `m_axi_bresp` | input | 写响应 |
| `m_axi_bvalid` | input | 写响应有效 |
| `m_axi_bready` | output | 写响应就绪 |
| `m_axi_arid` | output | 读地址 ID |
| `m_axi_araddr` | output | 读地址 |
| `m_axi_arlen` | output | 突发长度 |
| `m_axi_arsize` | output | 突发大小 |
| `m_axi_arburst` | output | 突发类型 |
| `m_axi_arvalid` | output | 读地址有效 |
| `m_axi_arready` | input | 读地址就绪 |
| `m_axi_rid` | input | 读数据 ID |
| `m_axi_rdata` | input | 读数据 |
| `m_axi_rresp` | input | 读响应 |
| `m_axi_rvalid` | input | 读数据有效 |
| `m_axi_rready` | output | 读数据就绪 |

## 5. 仲裁策略 — 轮询 (Round-Robin)

### 5.1 仲裁规则

1. 每次授权后，更新 `grant_ptr` 指向下一个客户端
2. 下次仲裁从 `grant_ptr` 开始检查
3. 只有请求的客户端才能被授权
4. 如果被授权客户端请求撤销，立即释放总线

### 5.2 状态机

```
IDLE ──► ARB ──► RD_ADDR ──► RD_DATA ──► RD_RESP ──► IDLE
                 │
                 └────► WR_ADDR ──► WR_DATA ──► WR_RESP ──► IDLE
```

**状态说明：**
- `IDLE`: 等待请求
- `ARB`: 仲裁选择客户端
- `RD_ADDR`: 发送读地址
- `RD_DATA`: 接收读数据
- `RD_RESP`: 返回读数据给客户端
- `WR_ADDR`: 发送写地址
- `WR_DATA`: 发送写数据
- `WR_RESP`: 接收写响应并返回给客户端

## 6. 时序图

### 6.1 读交易时序

```
clk:    │__│__│__│__│__│__│__│__│__│__│__
arvalid:    │───────
arready:        │
rvalid:             │
rready:                 │
```

### 6.2 轮询仲裁示例

```
Time    Client0   Client1   Grant
 T0       1         0        0     <- 初始授权 Client0
 T1       1         1        1     <- Client1 优先
 T2       0         1        1     <- Client1 继续
 T3       0         0        -     <- 无请求，IDLE
```

## 7. 使用示例

### 7.1 模块例化

```systemverilog
axi4_master_if u_axi4_master_if (
    .clk            (clk),
    .rst_n          (rst_n),
    // Client 0
    .client_req[0]  (req0),
    .client_cmd[0]  (cmd0),
    .client_addr[0] (addr0),
    .client_wdata[0](wdata0),
    .client_be[0]   (be0),
    .client_gnt[0]  (gnt0),
    .client_rvalid  (rvalid0),
    .client_rdata   (rdata0),
    .client_resp    (resp0),
    // Client 1
    .client_req[1]  (req1),
    .client_cmd[1]  (cmd1),
    .client_addr[1] (addr1),
    .client_wdata[1](wdata1),
    .client_be[1]   (be1),
    .client_gnt[1]  (gnt1),
    .client_rvalid  (rvalid1),
    .client_rdata   (rdata1),
    .client_resp    (resp1),
    // AXI4 Master
    .m_axi_*
);
```

### 7.2 客户端使用

```systemverilog
// Client 0 发起读请求
req0 = 1;
cmd0 = 1'b0;  // 读
addr0 = 32'h1000;
wait(gnt0);   // 等待授权
req0 = 0;
wait(rvalid0); // 等待数据返回
data = rdata0;
```

## 8. 设计约束

1. **突发长度**: 固定为 1（不支持突发）
2. **突发类型**: INCR（地址递增）
3. **不支持**: Outstanding, Out-of-order, Narrow burst
4. **响应码**: 仅返回 OKAY/SLVERR/DECERR，不做错误恢复

## 9. 验证计划

- [ ] 单客户端读写交易
- [ ] 双客户端并发请求
- [ ] 轮询公平性验证
- [ ] 背压处理（AXI Ready 控制）
- [ ] 错误响应传播

---

*Last updated: 2026-04-27*