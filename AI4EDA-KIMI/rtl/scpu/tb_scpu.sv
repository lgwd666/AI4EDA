`timescale 1ns/1ps

module tb_scpu;
    localparam integer MAX_SIM_NS = 5000;

    logic       clk = 1'b0;
    logic       rst_n = 1'b0;
    logic [7:0] pc;
    logic [7:0] instr;
    integer     cycle;

    scpu_rom #(.INIT_FILE("sum.hex")) u_rom (
        .addr  (pc),
        .rdata (instr)
    );

    scpu dut (
        .clk   (clk),
        .rst_n (rst_n),
        .instr (instr),
        .pc    (pc)
    );

    always #5 clk = ~clk;

    task automatic check_pc(input logic [7:0] expected);
        if (pc !== expected) begin
            $display("FAIL: t=%0t cycle=%0d pc=%0d expected=%0d instr=%02h",
                     $time, cycle, pc, expected, instr);
            $fatal(1);
        end
    endtask

    task automatic check_reg(input integer idx, input logic [7:0] expected);
        if (dut.u_gpr.regs[idx] !== expected) begin
            $display("FAIL: t=%0t cycle=%0d R%0d=%0d expected=%0d",
                     $time, cycle, idx, dut.u_gpr.regs[idx], expected);
            $fatal(1);
        end
    endtask

    task automatic check_all_regs(
        input logic [7:0] e0,
        input logic [7:0] e1,
        input logic [7:0] e2,
        input logic [7:0] e3
    );
        check_reg(0, e0);
        check_reg(1, e1);
        check_reg(2, e2);
        check_reg(3, e3);
    endtask

    // 从释放复位后的第一个上升沿开始计数，逐拍检查 PC 序列，
    // 并在第 4 拍（li 段结束）和第 34 拍（程序结束）检查 GPR。
    task automatic run_program;
        integer     n;
        integer     pc_off;
        logic [7:0] exp_pc;

        for (n = 1; n <= 34; n = n + 1) begin
            @(posedge clk);
            #1;
            cycle = n;

            if (n <= 4) begin
                exp_pc = n[7:0];
            end else if (n <= 33) begin
                pc_off = (n - 4) % 3;
                exp_pc = 8'd4 + pc_off[7:0];
            end else begin
                exp_pc = 8'd7;
            end
            check_pc(exp_pc);

            if (n == 4) begin
                $display("INFO: cycle 4 (li segment done), pc=%0d R0=%0d R1=%0d R2=%0d R3=%0d",
                         pc, dut.u_gpr.regs[0], dut.u_gpr.regs[1],
                         dut.u_gpr.regs[2], dut.u_gpr.regs[3]);
                check_all_regs(8'd10, 8'd0, 8'd0, 8'd1);
            end

            if (n == 34) begin
                $display("INFO: cycle 34 (program done), pc=%0d R0=%0d R1=%0d R2=%0d R3=%0d",
                         pc, dut.u_gpr.regs[0], dut.u_gpr.regs[1],
                         dut.u_gpr.regs[2], dut.u_gpr.regs[3]);
                check_all_regs(8'd10, 8'd10, 8'd55, 8'd1);
            end
        end
    endtask

    initial begin
        // $dumpfile("tb_scpu.vcd");
        // $dumpvars(0, tb_scpu);

        cycle = 0;
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        $display("INFO: reset held, pc=%0d", pc);
        check_pc(8'd0);
        check_all_regs(8'd0, 8'd0, 8'd0, 8'd0);

        @(negedge clk);
        rst_n = 1'b1;

        run_program;

        for (cycle = 35; cycle <= 37; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            check_pc(8'd7);
            check_all_regs(8'd10, 8'd10, 8'd55, 8'd1);
        end
        $display("INFO: PC=7 self-loop held for 3 cycles");

        // 在 PC=7 自循环期间、非时钟沿处异步复位，检查立即清零。
        #3;
        rst_n = 1'b0;
        #1;
        $display("INFO: mid-run async reset, pc=%0d", pc);
        check_pc(8'd0);
        check_all_regs(8'd0, 8'd0, 8'd0, 8'd0);

        @(posedge clk);
        #1;
        check_pc(8'd0);
        check_all_regs(8'd0, 8'd0, 8'd0, 8'd0);

        // 释放复位后重新运行完整程序，验证复位后状态可确定性重建。
        @(negedge clk);
        rst_n = 1'b1;
        run_program;
        $display("INFO: program re-ran after reset, final pc=%0d R0=%0d R1=%0d R2=%0d R3=%0d",
                 pc, dut.u_gpr.regs[0], dut.u_gpr.regs[1],
                 dut.u_gpr.regs[2], dut.u_gpr.regs[3]);

        $display("PASS: PC=7 R0=10 R1=10 R2=55 R3=1, 34-cycle completion and reset verified");
        $finish;
    end

    initial begin
        #(MAX_SIM_NS);
        $display("FAIL: timeout after %0d ns, pc=%0d", MAX_SIM_NS, pc);
        $fatal(1);
    end
endmodule
