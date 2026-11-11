`timescale 1ns / 1ps

// ============================================================================
// 流水灯（时序逻辑示例，对应 E4 讲义“示例: 流水灯”）
//
// 复位时 led = 16'h0001（最右边一位亮）。
// 之后每隔 CNT_MAX + 1 个时钟周期，led 循环左移一位：
//   0001 -> 0002 -> 0004 -> ... -> 8000 -> 0001 -> ...
//
// CNT_MAX 默认 5000000，与讲义一致，适合在 NVBoard 上观察。
// 纯仿真时用 light_fast 包装模块把 CNT_MAX 改小，避免仿真时间过长。
// ============================================================================
module light #(
  parameter integer CNT_MAX = 5000000  // 移位间隔（单位：时钟周期）
) (
  input  wire        clk,
  input  wire        rst,
  output reg  [15:0] led
);

  reg [31:0] count;  // 分频计数器

  always @(posedge clk) begin
    if (rst) begin
      // 同步复位：led 回到最右一位，计数器清零
      led   <= 16'h0001;
      count <= 32'd0;
    end else begin
      // count 为 0 时移位；其余时刻只计数
      if (count == 32'd0)
        led <= {led[14:0], led[15]};  // 循环左移一位

      // 计满 CNT_MAX 后回到 0，产生周期性移位
      count <= (count >= CNT_MAX) ? 32'd0 : count + 32'd1;
    end
  end

endmodule
