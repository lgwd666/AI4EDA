module LSU (
    input  logic [31:0] mem_addr,
    input  logic        mem_valid,
    input  logic        mem_wen,
    input  logic [31:0] mem_wdata,
    input  logic [3: 0] mem_wmask,
    output logic [31:0] mem_rdata
);

import "DPI-C" function int pmem_read(input int raddr);
import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wmask);
reg [31:0] rdata;
always @(*) begin
  if (mem_valid) begin // 有读写请求时
    rdata = pmem_read(mem_addr);
    if (mem_wen) begin // 有写请求时
      pmem_write(mem_addr, mem_wdata, mem_wmask);
    end
  end
  else begin
    rdata = 0;
  end
end
assign mem_rdata = rdata;

endmodule
