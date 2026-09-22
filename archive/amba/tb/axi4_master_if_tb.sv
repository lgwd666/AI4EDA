// Copyright (c) 2026, AI4EDA
// Module: axi4_master_if_tb
// Description: Testbench for axi4_master_if
// Author: lgwd666
// Date: 2026-04-27

`timescale 1ns / 1ps

module axi4_master_if_tb;

    // Clock and Reset
    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end

    // ========== DUT Instantiation ==========
    axi4_master_if u_dut (
        .clk            (clk),
        .rst_n          (rst_n),
        // Client 0
        .client_req_0   (tb_req_0),
        .client_cmd_0   (tb_cmd_0),
        .client_addr_0  (tb_addr_0),
        .client_wdata_0 (tb_wdata_0),
        .client_be_0    (tb_be_0),
        .client_gnt_0   (tb_gnt_0),
        .client_rvalid_0(tb_rvalid_0),
        .client_rdata_0 (tb_rdata_0),
        .client_resp_0  (tb_resp_0),
        // Client 1
        .client_req_1   (tb_req_1),
        .client_cmd_1   (tb_cmd_1),
        .client_addr_1  (tb_addr_1),
        .client_wdata_1 (tb_wdata_1),
        .client_be_1    (tb_be_1),
        .client_gnt_1   (tb_gnt_1),
        .client_rvalid_1(tb_rvalid_1),
        .client_rdata_1 (tb_rdata_1),
        .client_resp_1  (tb_resp_1),
        // AXI4 Master (connected to BFM)
        .m_axi_awid     (axi_awid),
        .m_axi_awaddr   (axi_awaddr),
        .m_axi_awlen    (axi_awlen),
        .m_axi_awsize   (axi_awsize),
        .m_axi_awburst  (axi_awburst),
        .m_axi_awvalid  (axi_awvalid),
        .m_axi_awready  (axi_awready),
        .m_axi_wdata    (axi_wdata),
        .m_axi_wstrb    (axi_wstrb),
        .m_axi_wvalid   (axi_wvalid),
        .m_axi_wready   (axi_wready),
        .m_axi_wlast    (axi_wlast),
        .m_axi_bid      (axi_bid),
        .m_axi_bresp    (axi_bresp),
        .m_axi_bvalid   (axi_bvalid),
        .m_axi_bready   (axi_bready),
        .m_axi_arid     (axi_arid),
        .m_axi_araddr   (axi_araddr),
        .m_axi_arlen    (axi_arlen),
        .m_axi_arsize   (axi_arsize),
        .m_axi_arburst  (axi_arburst),
        .m_axi_arvalid  (axi_arvalid),
        .m_axi_arready  (axi_arready),
        .m_axi_rid      (axi_rid),
        .m_axi_rdata    (axi_rdata),
        .m_axi_rresp    (axi_rresp),
        .m_axi_rvalid   (axi_rvalid),
        .m_axi_rready   (axi_rready)
    );

    // ========== Testbench Signals ==========
    // Client 0
    logic        tb_req_0;
    logic        tb_cmd_0;
    logic [31:0] tb_addr_0;
    logic [31:0] tb_wdata_0;
    logic [3:0]  tb_be_0;
    logic        tb_gnt_0;
    logic        tb_rvalid_0;
    logic [31:0] tb_rdata_0;
    logic [1:0]  tb_resp_0;

    // Client 1
    logic        tb_req_1;
    logic        tb_cmd_1;
    logic [31:0] tb_addr_1;
    logic [31:0] tb_wdata_1;
    logic [3:0]  tb_be_1;
    logic        tb_gnt_1;
    logic        tb_rvalid_1;
    logic [31:0] tb_rdata_1;
    logic [1:0]  tb_resp_1;

    // AXI BFM signals
    logic [3:0]  axi_awid;
    logic [31:0] axi_awaddr;
    logic [7:0]  axi_awlen;
    logic [2:0]  axi_awsize;
    logic [1:0]  axi_awburst;
    logic        axi_awvalid;
    logic        axi_awready;
    logic [31:0] axi_wdata;
    logic [3:0]  axi_wstrb;
    logic        axi_wvalid;
    logic        axi_wready;
    logic        axi_wlast;
    logic [3:0]  axi_bid;
    logic [1:0]  axi_bresp;
    logic        axi_bvalid;
    logic        axi_bready;
    logic [3:0]  axi_arid;
    logic [31:0] axi_araddr;
    logic [7:0]  axi_arlen;
    logic [2:0]  axi_arsize;
    logic [1:0]  axi_arburst;
    logic        axi_arvalid;
    logic        axi_arready;
    logic [3:0]  axi_rid;
    logic [31:0] axi_rdata;
    logic [1:0]  axi_rresp;
    logic        axi_rvalid;
    logic        axi_rready;

    // ========== Simple AXI BFM ==========
    // Write address channel
    initial begin
        axi_awready = 0;
        forever begin
            @(posedge clk);
            if (axi_awvalid && axi_awready) begin
                $display("[BFM] Write Addr: addr=0x%h, len=%d", axi_awaddr, axi_awlen);
            end
        end
    end

    // Write data channel
    initial begin
        axi_wready = 0;
        forever begin
            @(posedge clk);
            if (axi_wvalid && axi_wready) begin
                $display("[BFM] Write Data: data=0x%h, strb=0x%h", axi_wdata, axi_wstrb);
            end
        end
    end

    // Write response channel
    initial begin
        axi_bvalid = 0;
        forever begin
            @(posedge clk);
            if (axi_bvalid && axi_bready) begin
                $display("[BFM] Write Resp: resp=%d", axi_bresp);
            end
        end
    end

    // Read address channel
    initial begin
        axi_arready = 0;
        forever begin
            @(posedge clk);
            if (axi_arvalid && axi_arready) begin
                $display("[BFM] Read Addr: addr=0x%h, len=%d", axi_araddr, axi_arlen);
            end
        end
    end

    // Read data channel
    initial begin
        axi_rvalid = 0;
        forever begin
            @(posedge clk);
            if (axi_rvalid && axi_rready) begin
                $display("[BFM] Read Data: data=0x%h, resp=%d", axi_rdata, axi_rresp);
            end
        end
    end

    // ========== Test Cases ==========
    initial begin
        $display("========== AXI4 Master Interface Testbench Start ==========");

        // Initialize
        tb_req_0 = 0; tb_cmd_0 = 0; tb_addr_0 = 0; tb_wdata_0 = 0; tb_be_0 = 0;
        tb_req_1 = 0; tb_cmd_1 = 0; tb_addr_1 = 0; tb_wdata_1 = 0; tb_be_1 = 0;

        wait (rst_n);
        @(posedge clk);
        #1;

        // Test 1: Single client 0 read
        $display("\n[Test 1] Client 0 Read");
        tb_req_0 = 1; tb_cmd_0 = 0; tb_addr_0 = 32'h1000;
        @(posedge clk); #1;
        wait (tb_gnt_0);
        tb_req_0 = 0;
        wait (tb_rvalid_0);
        $display("  Read data: 0x%h, resp: %d", tb_rdata_0, tb_resp_0);

        // Test 2: Single client 0 write
        #100;
        $display("\n[Test 2] Client 0 Write");
        tb_req_0 = 1; tb_cmd_0 = 1; tb_addr_0 = 32'h2000; tb_wdata_0 = 32'hDEADBEEF; tb_be_0 = 4'hF;
        @(posedge clk); #1;
        wait (tb_gnt_0);
        tb_req_0 = 0;
        wait (tb_rvalid_0);
        $display("  Write resp: %d", tb_resp_0);

        // Test 3: Round-robin arbitration
        #100;
        $display("\n[Test 3] Round-robin Arbitration");
        // Client 0 and Client 1 both request
        fork
            begin
                tb_req_0 = 1; tb_cmd_0 = 0; tb_addr_0 = 32'h3000;
            end
            begin
                #10 tb_req_1 = 1; tb_cmd_1 = 1; tb_addr_1 = 32'h4000; tb_wdata_1 = 32'h12345678; tb_be_1 = 4'hF;
            end
        join
        @(posedge clk); #1;

        // Should grant to client 0 first (initial grant_ptr=0)
        wait (tb_gnt_0);
        tb_req_0 = 0;
        wait (tb_rvalid_0);
        $display("  Client 0 read completed");

        // Now client 1 should get grant
        wait (tb_gnt_1);
        tb_req_1 = 0;
        wait (tb_rvalid_1);
        $display("  Client 1 write completed");

        #100;
        $display("\n========== All Tests Completed ==========");
        $finish;
    end

    // ========== Timeout Monitor ==========
    initial begin
        #10000;
        $display("ERROR: Timeout - simulation did not complete");
        $finish;
    end

    // ========== Waveform Dump ==========
    initial begin
        $dumpfile("axi4_master_if_tb.vcd");
        $dumpvars(0, axi4_master_if_tb);
    end

endmodule