// ============================================================================
// 双控开关自检 testbench（Icarus Verilog）
//
// 组合逻辑只有 4 种输入组合，直接穷举检查 f == a ^ b。
//
// 波形：按 rtl/AGENTS.md 约定默认关闭。取消下面两行注释后重新执行
//       make icarus，会生成 tb_top.vcd。
// ============================================================================
`timescale 1ns / 1ps

module tb_top;

  reg  a;
  reg  b;
  wire f;

  top dut (
    .a(a),
    .b(b),
    .f(f)
  );

  integer i;
  integer errors;

  initial begin
    // $dumpfile("tb_top.vcd");
    // $dumpvars(0, tb_top);

    errors = 0;

    // 穷举 00、01、10、11
    for (i = 0; i < 4; i = i + 1) begin
      a = i[1];
      b = i[0];
      #1;  // 组合逻辑延迟，等输出稳定
      if (f !== (a ^ b)) begin
        $display("ERROR: a=%b, b=%b, f=%b, expected=%b", a, b, f, a ^ b);
        errors = errors + 1;
      end
    end

    if (errors == 0) begin
      $display("tb_top PASS: 4 种输入组合全部满足 f = a ^ b");
      $finish;
    end else begin
      $display("tb_top FAIL: %0d errors", errors);
      $fatal(1);
    end
  end

  // 超时保护
  initial begin
    #1000;
    $display("ERROR: timeout");
    $fatal(1);
  end

endmodule
