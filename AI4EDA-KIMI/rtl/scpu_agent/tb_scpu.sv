// Self-checking testbench for scpu (F5 sum program).
//
// Checks: reset clears PC/GPRs, the program runs the expected number of
// cycles, PC=7 with R0=10/R1=10/R2=55/R3=1, the bner0 r3,7 self-loop keeps
// PC at 7, and a second reset clears the machine again. A cycle timeout
// prevents infinite hangs.

`timescale 1ns/1ps

module tb_scpu;

  localparam integer TIMEOUT_CYCLES = 200;
  localparam integer HOLD_CYCLES    = 5;

  logic       clk;
  logic       rst_n;
  logic [7:0] pc;

  integer errors;
  integer cycle_count;
  logic   seen_pc4;
  logic   seen_pc7;

  scpu dut (
      .clk  (clk),
      .rst_n(rst_n),
      .pc   (pc)
  );

  // Uncomment the two dump statements below to generate a VCD waveform.
  initial begin
    // $dumpfile("tb_scpu.vcd");
    // $dumpvars(0, tb_scpu);
  end

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task automatic check(input logic cond, input string label);
    if (cond !== 1'b1) begin
      errors = errors + 1;
      $display("[FAIL] %s", label);
    end else begin
      $display("[PASS] %s", label);
    end
  endtask

  task automatic check_reset_state(input string tag);
    check(pc === 8'd0, {tag, ": PC = 0"});
    check(dut.gpr[0] === 8'd0, {tag, ": R0 = 0"});
    check(dut.gpr[1] === 8'd0, {tag, ": R1 = 0"});
    check(dut.gpr[2] === 8'd0, {tag, ": R2 = 0"});
    check(dut.gpr[3] === 8'd0, {tag, ": R3 = 0"});
  endtask

  task automatic check_final_state(input string tag);
    check(pc === 8'd7, {tag, ": PC = 7"});
    check(dut.gpr[0] === 8'd10, {tag, ": R0 = 10"});
    check(dut.gpr[1] === 8'd10, {tag, ": R1 = 10"});
    check(dut.gpr[2] === 8'd55, {tag, ": R2 = 55"});
    check(dut.gpr[3] === 8'd1, {tag, ": R3 = 1"});
  endtask

  initial begin
    errors      = 0;
    cycle_count = 0;
    seen_pc4    = 1'b0;
    seen_pc7    = 1'b0;
    rst_n       = 1'b0;

    // Hold reset for a few cycles and confirm the architectural state.
    repeat (2) @(negedge clk);
    check_reset_state("reset");

    @(negedge clk);
    rst_n = 1'b1;

    // Run until the self-loop at PC=7 is entered, or the timeout fires.
    while (!seen_pc7 && cycle_count < TIMEOUT_CYCLES) begin
      @(negedge clk);
      cycle_count = cycle_count + 1;
      $display("[TRACE] cycle=%0d pc=%0d R0=%0d R1=%0d R2=%0d R3=%0d",
               cycle_count, pc, dut.gpr[0], dut.gpr[1], dut.gpr[2], dut.gpr[3]);

      // After the four li instructions, before the first add.
      if (!seen_pc4 && pc === 8'd4) begin
        seen_pc4 = 1'b1;
        check(dut.gpr[0] === 8'd10, "after li block: R0 = 10");
        check(dut.gpr[1] === 8'd0, "after li block: R1 = 0");
        check(dut.gpr[2] === 8'd0, "after li block: R2 = 0");
        check(dut.gpr[3] === 8'd1, "after li block: R3 = 1");
      end

      if (pc === 8'd7) seen_pc7 = 1'b1;
    end

    if (!seen_pc7) begin
      errors = errors + 1;
      $display("[FAIL] timeout: PC never reached 7 within %0d cycles", TIMEOUT_CYCLES);
    end else begin
      check(cycle_count == 34, "PC reaches 7 after 34 cycles");
      check_final_state("final");

      // bner0 r3,7 always branches to itself: R0=10 != R3=1.
      repeat (HOLD_CYCLES) begin
        @(negedge clk);
        check(pc === 8'd7, "self-loop: PC stays 7");
      end
      check(dut.gpr[0] === 8'd10, "self-loop: R0 unchanged");
      check(dut.gpr[1] === 8'd10, "self-loop: R1 unchanged");
      check(dut.gpr[2] === 8'd55, "self-loop: R2 unchanged");
      check(dut.gpr[3] === 8'd1, "self-loop: R3 unchanged");

      // Reset must clear PC and every GPR again, without waiting for a clock.
      rst_n = 1'b0;
      #1;
      check_reset_state("async reset");
      repeat (2) @(negedge clk);
      check_reset_state("second reset");
    end

    if (errors == 0) begin
      $display("TEST PASSED");
      $finish;
    end else begin
      $display("TEST FAILED: %0d error(s)", errors);
      $fatal(1);
    end
  end

endmodule
