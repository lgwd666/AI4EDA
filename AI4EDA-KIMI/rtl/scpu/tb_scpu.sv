`timescale 1ns/1ps

module tb_scpu;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic [7:0] pc;
    logic [7:0] instr;
    integer cycles;

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

    initial begin
        // $dumpfile("tb_scpu.vcd");
        // $dumpvars(0, tb_scpu);

        repeat (2) @(posedge clk);
        if (pc !== 8'd0) begin
            $display("FAIL: reset PC=%0d, expected 0", pc);
            $fatal(1);
        end
        @(negedge clk) rst_n = 1'b1;

        for (cycles = 0; cycles < 100; cycles = cycles + 1) begin
            @(posedge clk);
            #1;
            if (pc == 8'd7) begin
                if (dut.u_gpr.regs[0] !== 8'd10 ||
                    dut.u_gpr.regs[1] !== 8'd10 ||
                    dut.u_gpr.regs[2] !== 8'd55 ||
                    dut.u_gpr.regs[3] !== 8'd1) begin
                    $display("FAIL: PC=%0d R0=%0d R1=%0d R2=%0d R3=%0d",
                             pc, dut.u_gpr.regs[0], dut.u_gpr.regs[1],
                             dut.u_gpr.regs[2], dut.u_gpr.regs[3]);
                    $fatal(1);
                end

                repeat (3) begin
                    @(posedge clk);
                    #1;
                    if (pc !== 8'd7) begin
                        $display("FAIL: final loop changed PC to %0d", pc);
                        $fatal(1);
                    end
                end

                $display("PASS: PC=%0d R0=%0d R1=%0d R2=%0d R3=%0d",
                         pc, dut.u_gpr.regs[0], dut.u_gpr.regs[1],
                         dut.u_gpr.regs[2], dut.u_gpr.regs[3]);
                $finish;
            end
        end

        $display("FAIL: timeout, PC=%0d", pc);
        $fatal(1);
    end
endmodule
