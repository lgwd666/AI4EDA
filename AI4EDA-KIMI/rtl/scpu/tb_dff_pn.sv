`timescale 1ns/1ps

module tb_dff_pn;
    localparam integer MAX_SIM_NS = 2000;

    logic       clk = 1'b0;
    logic       rst_n;
    logic       d;
    logic       q;
    logic [7:0] d8;
    logic [7:0] q8;

    integer checks = 0;
    integer errors = 0;
    integer i;

    // 默认参数实例：WIDTH=1，RESET_VALUE=0，应与原单比特单元行为一致。
    dff_pn dut (
        .clk   (clk),
        .rst_n (rst_n),
        .d     (d),
        .q     (q)
    );

    // 参数化实例：8 位向量，非零异步复位默认值 8'hA5。
    dff_pn #(
        .WIDTH       (8),
        .RESET_VALUE (8'hA5)
    ) dut_vec (
        .clk   (clk),
        .rst_n (rst_n),
        .d     (d8),
        .q     (q8)
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

    task automatic check_q8(input logic [7:0] expected, input string name);
        if (q8 !== expected) begin
            $display("FAIL: t=%0t %s: q=%02h expected=%02h", $time, name, q8, expected);
            errors = errors + 1;
        end else begin
            checks = checks + 1;
            $display("  OK: t=%0t %s q=%02h", $time, name, q8);
        end
    endtask

    initial begin
        // $dumpfile("tb_dff_pn.vcd");
        // $dumpvars(0, tb_dff_pn);

        rst_n = 1'b1;
        d = 1'b0;
        d8 = 8'h00;

        // ===== 默认参数实例（WIDTH=1，RESET_VALUE=0）=====

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

        // ===== 参数化实例（WIDTH=8，RESET_VALUE=8'hA5）=====

        // 7) 默认参数兼容性：不传参时仍为 1 位、复位值 0
        if (dut.WIDTH !== 1) begin
            $display("FAIL: t=%0t default dut.WIDTH=%0d expected=1", $time, dut.WIDTH);
            errors = errors + 1;
        end else begin
            checks = checks + 1;
            $display("  OK: t=%0t default dut.WIDTH=%0d", $time, dut.WIDTH);
        end
        if (dut.RESET_VALUE !== 1'b0) begin
            $display("FAIL: t=%0t default dut.RESET_VALUE=%0b expected=0",
                     $time, dut.RESET_VALUE);
            errors = errors + 1;
        end else begin
            checks = checks + 1;
            $display("  OK: t=%0t default dut.RESET_VALUE=%0b", $time, dut.RESET_VALUE);
        end
        if ($bits(q) !== 1 || $bits(d) !== 1) begin
            $display("FAIL: t=%0t default instance is not 1-bit (d=%0d q=%0d)",
                     $time, $bits(d), $bits(q));
            errors = errors + 1;
        end else begin
            checks = checks + 1;
            $display("  OK: t=%0t default instance d/q width=1", $time);
        end
        if ($bits(d8) !== 8 || $bits(q8) !== 8) begin
            $display("FAIL: t=%0t vector instance width != 8 (d=%0d q=%0d)",
                     $time, $bits(d8), $bits(q8));
            errors = errors + 1;
        end else begin
            checks = checks + 1;
            $display("  OK: t=%0t vector instance d/q width=8", $time);
        end

        // 8) 先让 8 位实例采样一个非 A5 值，便于观察异步载入 A5 的效果
        rst_n = 1'b1;
        d8 = 8'h3C;
        @(negedge clk);
        @(posedge clk);
        #1;
        check_q8(8'h3C, "vec: posedge samples d=3C");

        // 9) 非时钟沿处异步复位，检查立即载入非零默认值 A5
        #2;
        rst_n = 1'b0;
        #1;
        check_q8(8'hA5, "vec: async reset loads A5 immediately");
        if (dut_vec.RESET_VALUE !== 8'hA5) begin
            $display("FAIL: t=%0t dut_vec.RESET_VALUE=%02h expected=A5",
                     $time, dut_vec.RESET_VALUE);
            errors = errors + 1;
        end else begin
            checks = checks + 1;
            $display("  OK: t=%0t dut_vec.RESET_VALUE=%02h", $time, dut_vec.RESET_VALUE);
        end

        // 10) 复位优先：复位期间 d 变化并跨越上升沿，q 始终保持 A5
        d8 = 8'hFF;
        #2;
        check_q8(8'hA5, "vec: reset holds A5 with d=FF");
        @(posedge clk);
        #1;
        check_q8(8'hA5, "vec: reset holds A5 on posedge with d=FF");
        @(negedge clk);
        d8 = 8'h00;
        #1;
        check_q8(8'hA5, "vec: reset holds A5 after d changes to 00");
        @(posedge clk);
        #1;
        check_q8(8'hA5, "vec: reset holds A5 on posedge with d=00");

        // 11) 释放复位：先保持 A5，直到上升沿才整体采样 5A
        @(negedge clk);
        d8 = 8'h5A;
        rst_n = 1'b1;
        #1;
        check_q8(8'hA5, "vec: holds A5 right after reset release");
        #2;
        check_q8(8'hA5, "vec: holds A5 before first posedge (d=5A)");
        @(posedge clk);
        #1;
        check_q8(8'h5A, "vec: first posedge after release samples 5A");

        // 12) 两个边沿之间 d 变化不影响 q；上升沿整体采样整个向量
        @(negedge clk);
        d8 = 8'hF0;
        #1;
        check_q8(8'h5A, "vec: holds 5A after negedge with d=F0");
        #2;
        check_q8(8'h5A, "vec: holds 5A before posedge with d=F0");
        @(posedge clk);
        #1;
        check_q8(8'hF0, "vec: posedge samples whole vector F0");

        @(negedge clk);
        d8 = 8'h0F;
        @(posedge clk);
        #1;
        check_q8(8'h0F, "vec: posedge samples whole vector 0F");

        @(negedge clk);
        d8 = 8'h81;
        @(posedge clk);
        #1;
        check_q8(8'h81, "vec: posedge samples whole vector 81");

        @(negedge clk);
        d8 = 8'h7E;
        @(posedge clk);
        #1;
        check_q8(8'h7E, "vec: posedge samples whole vector 7E");

        // 13) q 非零时再次异步复位，检查复位优先并立即回到 A5
        #2;
        check_q8(8'h7E, "vec: q=7E before second async reset");
        rst_n = 1'b0;
        #1;
        check_q8(8'hA5, "vec: second async reset reloads A5 immediately");
        @(posedge clk);
        #1;
        check_q8(8'hA5, "vec: reset holds A5 on posedge (d=7E)");
        @(negedge clk);
        rst_n = 1'b1;
        d8 = 8'h00;
        #1;
        check_q8(8'hA5, "vec: holds A5 after second reset release");
        @(posedge clk);
        #1;
        check_q8(8'h00, "vec: first posedge after second release samples 00");

        if (errors == 0) begin
            $display("PASS: %0d checks, dff_pn async reset, posedge sampling and parameterized vector verified",
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
