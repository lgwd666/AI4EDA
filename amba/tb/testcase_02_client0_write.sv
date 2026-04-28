// Copyright (c) 2026, AI4EDA
// Testcase: testcase_02_client0_write
// Description: Client 0 single write transaction
// Author: lgwd666
// Date: 2026-04-28

`timescale 1ns / 1ps

module testcase_02_client0_write;

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
        .client_bvalid_0 (tb_bvalid_0),
        .client_bvalid_1 (tb_bvalid_1),
        .client_rdata_0 (tb_rdata_0),
        .client_resp_0  (tb_resp_0),
        // Client 1
        .client_req_1   (tb_req_1),
        .client_cmd_1   (tb_cmd_1),
        .client_addr_1  (tb_addr_1),
        .client_wdata_1 (tb_wdata_1),
        .client_be_1    (tb_be_1),
        .client_gnt_1   (tb_gnt_1),
        .client_rvalid_1 (tb_rvalid_1),
        .client_rdata_1 (tb_rdata_1),
        .client_resp_1  (tb_resp_1),
        // AXI4 Master
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
    logic        tb_req_0;
    logic        tb_cmd_0;
    logic [31:0] tb_addr_0;
    logic [31:0] tb_wdata_0;
    logic [3:0]  tb_be_0;
    logic        tb_gnt_0;
    logic        tb_rvalid_0;
    logic        tb_bvalid_0;
    logic        tb_bvalid_1;
    logic [31:0] tb_rdata_0;
    logic [1:0]  tb_resp_0;

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

    // ========== AXI BFM ==========
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            axi_awready <= 0;
        else
            axi_awready <= axi_awvalid ? 1'b0 : 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            axi_wready <= 0;
        else
            axi_wready <= axi_wvalid ? 1'b0 : 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_bvalid <= 0;
            axi_bresp <= 2'b00;
        end else if (axi_awvalid && axi_awready) begin
            axi_bvalid <= 1;
            axi_bresp <= 2'b00;
        end else if (axi_bvalid && axi_bready) begin
            axi_bvalid <= 0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            axi_arready <= 0;
        else
            axi_arready <= axi_arvalid ? 1'b0 : 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_rvalid <= 0;
            axi_rdata <= 32'h0;
            axi_rresp <= 2'b00;
        end else if (axi_arvalid && axi_arready) begin
            axi_rvalid <= 1;
            axi_rdata <= 32'hDEADBEEF;
            axi_rresp <= 2'b00;
        end else if (axi_rvalid && axi_rready) begin
            axi_rvalid <= 0;
        end
    end

    // ========== Test Sequence ==========
    initial begin
        $display("========== Testcase 02: Client 0 Single Write ==========");

        tb_req_0 = 0; tb_cmd_0 = 0; tb_addr_0 = 0; tb_wdata_0 = 0; tb_be_0 = 0;
        tb_req_1 = 0; tb_cmd_1 = 0; tb_addr_1 = 0; tb_wdata_1 = 0; tb_be_1 = 0;

        wait (rst_n);
        repeat(2) @(posedge clk);
        #1;
        wait (rst_n);
        $display("[TC02] Starting Client 0 Write transaction");
        $display("[TC02] Address: 0x2000, Data: 0xDEADBEEF");

        tb_req_0 = 1;
        tb_cmd_0 = 1;        // Write
        tb_addr_0 = 32'h2000;
        tb_wdata_0 = 32'hDEADBEEF;
        tb_be_0 = 4'hF;

        @(posedge clk); #1;
        wait (tb_gnt_0);
        $display("[TC02] Grant received from arbiter");

        wait (tb_bvalid_0);
        $display("[TC02] Write completed");
        $display("[TC02] Write response: %b", tb_resp_0);

        // Check result
        if (tb_resp_0 == 2'b00) begin
            $display("[TC02] PASS - Response OKAY");
        end else begin
            $display("[TC02] FAIL - Response: %b", tb_resp_0);
        end

        #50;
        $display("========== Testcase 02 Complete ==========");
        $finish;
    end

    // ========== Timeout ==========
    initial begin
        #5000;
        $display("[TC02] ERROR: Timeout");
        $finish;
    end

    // ========== Waveform Dump ==========
    initial begin
        $dumpfile("testcase_02_client0_write.vcd");
        $dumpvars(0, testcase_02_client0_write);
    end

endmodule
