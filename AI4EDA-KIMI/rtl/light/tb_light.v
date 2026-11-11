// ============================================================================
// 流水灯自检 testbench（Icarus Verilog）
//
// 被测对象：light_fast（内部 light 的 CNT_MAX = 4）
// 每 5 个时钟周期循环左移一位，200 个周期共移位 40 次。
//
// 波形：按 rtl/AGENTS.md 约定默认关闭。取消下面两行注释后重新执行
//       make icarus，会生成 tb_light.vcd。
// ============================================================================
`timescale 1ns / 1ps

module tb_light;

  reg         clk;
  reg         rst;
  wire [15:0] led;

  light_fast dut (
    .clk(clk),
    .rst(rst),
    .led(led)
  );

  // 10 ns 时钟周期
  always #5 clk = ~clk;

  integer    cycle;
  integer    shifts;
  integer    errors;
  integer    cnt;       // 参考模型中的分频计数
  reg [15:0] expected;  // 参考模型中的期望灯状态

  initial begin
    // $dumpfile("tb_light.vcd");
    // $dumpvars(0, tb_light);

    clk      = 1'b0;
    rst      = 1'b1;
    cycle    = 0;
    shifts   = 0;
    errors   = 0;
    cnt      = 0;
    expected = 16'h0001;

    // 复位 10 个周期：led 应为 0001，计数器为 0
    repeat (10) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;

    if (led !== 16'h0001) begin
      $display("ERROR: after reset led=%h, expected=0001", led);
      errors = errors + 1;
    end

    // 运行 200 个周期，逐周期与参考模型比对
    for (cycle = 1; cycle <= 200; cycle = cycle + 1) begin
      @(posedge clk);
      #1;  // 等非阻塞赋值生效后再采样

      if (cnt == 0) begin
        expected = {expected[14:0], expected[15]};
        shifts   = shifts + 1;
      end
      cnt = (cnt >= 4) ? 0 : cnt + 1;

      if (led !== expected) begin
        $display("ERROR: cycle %0d, led=%h, expected=%h", cycle, led, expected);
        errors = errors + 1;
      end
    end

    // 总移位次数和最终状态
    if (shifts != 40) begin
      $display("ERROR: shifts=%0d, expected=40", shifts);
      errors = errors + 1;
    end
    if (led !== 16'h0100) begin
      $display("ERROR: final led=%h, expected=0100", led);
      errors = errors + 1;
    end

    if (errors == 0) begin
      $display("tb_light PASS: 200 cycles, 40 shifts, final led=0x%04h", led);
      $finish;
    end else begin
      $display("tb_light FAIL: %0d errors", errors);
      $fatal(1);
    end
  end

  // 超时保护：正常情况下 200 个周期约 2 us
  initial begin
    #100000;
    $display("ERROR: timeout");
    $fatal(1);
  end

endmodule
