`timescale 1ns/1ps

module tb_dff_pn;
    localparam integer MAX_SIM_NS = 2000;

    logic clk = 1'b0;
    logic rst_n;
    logic d;
    logic q;

    integer checks = 0;
    integer errors = 0;
    integer i;

    dff_pn dut (
        .clk   (clk),
        .rst_n (rst_n),
        .d     (d),
        .q     (q)
    );

    always #5 clk = ~clk;

    task automatic check_q(input logic expected, input string name);
        if (q !== expected) begin
            $display("FAIL: t=%0t %s: q=%b expected=%b", $time, name, q, expected);
            errors = errors + 1;
        end else begin
            checks = checks + 1;
            $display("  OK: t=%0t %s q=%b", $time, name, q);
        end
    endtask

    initial begin
        // $dumpfile("tb_dff_pn.vcd");
        // $dumpvars(0, tb_dff_pn);

        rst_n = 1'b1;
        d = 1'b0;

        // 1) 异步复位：不依赖时钟沿，立即把 q 清零
        #2;
        rst_n = 1'b0;
        #1;
        check_q(1'b0, "async reset drives q=0 immediately");

        // 2) 复位期间 d 任意变化、时钟上升沿都不影响 q
        d = 1'b1;
        #2;
        check_q(1'b0, "reset holds q=0 with d=1 between edges");
        @(posedge clk);
        #1;
        check_q(1'b0, "reset holds q=0 on posedge with d=1");
        @(negedge clk);
        d = 1'b0;
        #1;
        check_q(1'b0, "reset holds q=0 after d changes to 0");
        @(posedge clk);
        #1;
        check_q(1'b0, "reset holds q=0 on posedge with d=0");
        #2;
        d = 1'b1;
        #2;
        check_q(1'b0, "reset blocks d=1 between edges");

        // 3) 释放复位后，q 保持原值，直到 clk 上升沿才采样 d
        @(negedge clk);
        d = 1'b1;
        rst_n = 1'b1;
        #1;
        check_q(1'b0, "no update right after reset release");
        #2;
        check_q(1'b0, "q holds 0 before first posedge after release (d=1)");
        @(posedge clk);
        #1;
        check_q(1'b1, "first posedge after release samples d=1");

        // 4) 两个边沿之间改变 d 不影响 q，只有上升沿更新
        @(negedge clk);
        d = 1'b0;
        #1;
        check_q(1'b1, "q holds 1 after negedge with d=0");
        #2;
        check_q(1'b1, "q holds 1 before posedge with d=0");
        @(posedge clk);
        #1;
        check_q(1'b0, "posedge samples d=0");

        // 5) 连续采样序列 0,0,1,1,0,1,0,0
        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk);
            case (i)
                0: d = 1'b0;
                1: d = 1'b0;
                2: d = 1'b1;
                3: d = 1'b1;
                4: d = 1'b0;
                5: d = 1'b1;
                6: d = 1'b0;
                default: d = 1'b0;
            endcase
            @(posedge clk);
            #1;
            check_q(d, "consecutive sampling");
        end

        // 6) q=1 时再次异步复位（非时钟沿），检查复位优先并立即清零
        @(negedge clk);
        d = 1'b1;
        @(posedge clk);
        #1;
        check_q(1'b1, "q=1 before second async reset");
        #2;
        rst_n = 1'b0;
        #1;
        check_q(1'b0, "second async reset clears q immediately");

        @(posedge clk);
        #1;
        check_q(1'b0, "q stays 0 on posedge during second reset (d=1)");

        @(negedge clk);
        rst_n = 1'b1;
        d = 1'b0;
        #1;
        check_q(1'b0, "q holds 0 after second reset release");
        @(posedge clk);
        #1;
        check_q(1'b0, "first posedge after second release samples d=0");

        if (errors == 0) begin
            $display("PASS: %0d checks, dff_pn async reset and posedge sampling verified",
                     checks);
            $finish;
        end else begin
            $display("FAIL: %0d error(s) in %0d checks", errors, checks + errors);
            $fatal(1);
        end
    end

    initial begin
        #(MAX_SIM_NS);
        $display("FAIL: timeout after %0d ns", MAX_SIM_NS);
        $fatal(1);
    end
endmodule
