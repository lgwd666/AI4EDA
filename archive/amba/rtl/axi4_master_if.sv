// Copyright (c) 2026, AI4EDA
// Module: axi4_master_if
// Description: AXI4 Master interface with round-robin arbiter for two clients
// Author: lgwd666
// Date: 2026-04-27

module axi4_master_if #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 4
) (
    // System
    input  logic                    clk,
    input  logic                    rst_n,

    // Client 0
    input  logic                    client_req_0,
    input  logic                    client_cmd_0,   // 0=read, 1=write
    input  logic [ADDR_WIDTH-1:0]   client_addr_0,
    input  logic [DATA_WIDTH-1:0]   client_wdata_0,
    input  logic [DATA_WIDTH/8-1:0] client_be_0,
    output logic                    client_gnt_0,
    output logic                    client_rvalid_0,
    output logic                    client_bvalid_0,
    output logic [DATA_WIDTH-1:0]   client_rdata_0,
    output logic [1:0]              client_resp_0,

    // Client 1
    input  logic                    client_req_1,
    input  logic                    client_cmd_1,
    input  logic [ADDR_WIDTH-1:0]   client_addr_1,
    input  logic [DATA_WIDTH-1:0]   client_wdata_1,
    input  logic [DATA_WIDTH/8-1:0] client_be_1,
    output logic                    client_gnt_1,
    output logic                    client_rvalid_1,
    output logic                    client_bvalid_1,
    output logic [DATA_WIDTH-1:0]   client_rdata_1,
    output logic [1:0]              client_resp_1,

    // AXI4 Master - Write Address Channel
    output logic [ID_WIDTH-1:0]     m_axi_awid,
    output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output logic [7:0]             m_axi_awlen,
    output logic [2:0]             m_axi_awsize,
    output logic [1:0]             m_axi_awburst,
    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,

    // AXI4 Master - Write Data Channel
    output logic [DATA_WIDTH-1:0]   m_axi_wdata,
    output logic [DATA_WIDTH/8-1:0] m_axi_wstrb,
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,
    output logic                    m_axi_wlast,

    // AXI4 Master - Write Response Channel
    input  logic [ID_WIDTH-1:0]    m_axi_bid,
    input  logic [1:0]             m_axi_bresp,
    input  logic                    m_axi_bvalid,
    output logic                    m_axi_bready,

    // AXI4 Master - Read Address Channel
    output logic [ID_WIDTH-1:0]     m_axi_arid,
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [7:0]             m_axi_arlen,
    output logic [2:0]             m_axi_arsize,
    output logic [1:0]             m_axi_arburst,
    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,

    // AXI4 Master - Read Data Channel
    input  logic [ID_WIDTH-1:0]    m_axi_rid,
    input  logic [DATA_WIDTH-1:0]  m_axi_rdata,
    input  logic [1:0]             m_axi_rresp,
    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready
);

    // ========== Internal Signals ==========
    typedef enum logic [3:0] {
        IDLE,
        ARB,
        WR_ADDR,
        WR_DATA,
        WR_RESP,
        RD_ADDR,
        RD_DATA,
        RD_RESP
    } state_t;

    state_t state, next_state;

    // Arbitration
    logic [1:0] grant_ptr;       // Round-robin grant pointer
    logic [1:0] grant;           // Current grant
    logic [1:0] req;            // Combined requests

    // Client mux
    logic       selected_client;
    logic [ADDR_WIDTH-1:0]   sel_addr;
    logic [DATA_WIDTH-1:0]   sel_wdata;
    logic [DATA_WIDTH/8-1:0] sel_be;

    // Response
    logic [1:0] resp;
    logic [DATA_WIDTH-1:0] rdata;

    // ID for transactions
    logic [ID_WIDTH-1:0] transaction_id;



    // ========== Request Combining ==========
    assign req = {client_req_1, client_req_0};

    // ========== Round-Robin Arbiter ==========
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant_ptr <= 2'b00;
            grant     <= 2'b00;
        end else if (state == IDLE) begin
            // Update grant based on round-robin
            if (req[grant_ptr] || req[(grant_ptr + 1) % 2]) begin
                // Find first requesting client starting from grant_ptr
                for (int i = 0; i < 2; i++) begin
                    logic [1:0] idx = (grant_ptr + i) % 2;
                    if (req[idx]) begin
                        grant <= (idx == 0) ? 2'd1 : 2'd2;  // Encode: 0→1, 1→2
                        grant_ptr <= (idx + 1) % 2;  // Next start position
                        break;
                    end
                end
            end else begin
                grant <= 2'b00;
            end
        end
    end

    // ========== Client Selection ==========
    always_comb begin
        selected_client = (grant == 2'd2);  // Map: 2'd1→0, 2'd2→1, 2'd0→0
        sel_addr   = selected_client ? client_addr_1   : client_addr_0;
        sel_wdata  = selected_client ? client_wdata_1  : client_wdata_0;
        sel_be     = selected_client ? client_be_1     : client_be_0;
    end

    // ========== Grant Outputs ==========
    assign client_gnt_0 = (grant == 2'd1) && (state == IDLE || state == ARB);
    assign client_gnt_1 = (grant == 2'd2) && (state == IDLE || state == ARB);

    // ========== State Machine ==========
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (req != 2'b00)
                    next_state = ARB;
            end

            ARB: begin
                // Determine transaction type based on granted client's command
                // grant encoding: 2'd1=Client0, 2'd2=Client1
                // Map grant back to client index for req[] access
                logic grant_client;  // 0=Client0, 1=Client1
                logic cmd;
                grant_client = (grant == 2'd2);  // 2→1, 1→0
                cmd = (grant == 2'd1) ? client_cmd_0 :
                      (grant == 2'd2) ? client_cmd_1 : 1'b0;
                next_state = (req[grant_client] == 1'b0) ? IDLE :  // Request withdrawn
                             (cmd ? WR_ADDR : RD_ADDR);
            end

            WR_ADDR: begin
                if (m_axi_awvalid && m_axi_awready)
                    next_state = WR_RESP;  // Single-beat write: skip WR_DATA
            end

            // WR_DATA state removed for single-beat writes

            WR_RESP: begin
                // Single-beat write: AW handshakes in WR_ADDR, we enter WR_RESP
                // DUT drives client_bvalid immediately; exit when it's high
                if (client_bvalid_0 || client_bvalid_1)
                    next_state = IDLE;
            end

            RD_ADDR: begin
                if (m_axi_arvalid && m_axi_arready)
                    next_state = RD_DATA;
            end

            RD_DATA: begin
                if (m_axi_rvalid && m_axi_rready)
                    next_state = RD_RESP;
            end

            RD_RESP: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // ========== AXI Write Address Channel ==========
    assign m_axi_awid    = transaction_id;
    assign m_axi_awaddr  = sel_addr;
    assign m_axi_awlen   = 8'd0;           // Single beat
    assign m_axi_awsize = 3'd2;           // 4 bytes
    assign m_axi_awburst = 2'b01;          // INCR
    assign m_axi_awvalid = (state == WR_ADDR);

    // ========== AXI Write Data Channel ==========
    assign m_axi_wdata   = sel_wdata;
    assign m_axi_wstrb   = sel_be;
    assign m_axi_wvalid   = (state == WR_DATA);
    assign m_axi_wlast    = (state == WR_DATA);

    // ========== AXI Write Response Channel ==========
    assign m_axi_bready   = (state == WR_ADDR) || (state == WR_RESP);  // Keep bready high through WR_RESP

    // ========== AXI Read Address Channel ==========
    assign m_axi_arid    = transaction_id;
    assign m_axi_araddr  = sel_addr;
    assign m_axi_arlen   = 8'd0;
    assign m_axi_arsize  = 3'd2;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arvalid = (state == RD_ADDR);

    // ========== AXI Read Data Channel ==========
    assign m_axi_rready  = (state == RD_DATA);

    // ========== Response Processing ==========
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata <= '0;
            resp  <= 2'b00;
            transaction_id <= '0;
        end else begin
            if (state == RD_DATA && m_axi_rvalid && m_axi_rready) begin
                rdata <= m_axi_rdata;
                resp  <= m_axi_rresp[1] ? 2'b01 : 2'b00;  // SLVERR or OK
            end
            if (state == WR_RESP && m_axi_bvalid && m_axi_bready) begin
                resp  <= m_axi_bresp[1] ? 2'b01 : 2'b00;
            end
            if (state == ARB && req[grant])
                transaction_id <= transaction_id + 1'b1;
        end
    end

    // ========== Client Response Output ==========
    assign client_rvalid_0 = (state == RD_RESP) && !selected_client;
    assign client_rvalid_1 = (state == RD_RESP) && selected_client;
    // Write response: DUT directly drives bvalid when entering WR_RESP
    // This is visible to TB immediately (no BFM delay)
    assign client_bvalid_0 = (state == WR_RESP) && !selected_client;
    assign client_bvalid_1 = (state == WR_RESP) && selected_client;
    assign client_rdata_0  = selected_client ? '0 : rdata;
    assign client_rdata_1  = selected_client ? rdata : '0;
    assign client_resp_0   = selected_client ? '0 : resp;
    assign client_resp_1   = selected_client ? resp : '0;

    // ========== Assertions ==========
    `ifdef SIMULATION
    assert property (@(posedge clk) disable iff (!rst_n)
        (state == WR_DATA) -> ##1 (state == WR_RESP || state == WR_ADDR))
        else $error("WR_DATA state error");

    assert property (@(posedge clk) disable iff (!rst_n)
        (state == RD_DATA) -> ##1 (state == RD_RESP || state == RD_ADDR))
        else $error("RD_DATA state error");
    `endif

endmodule