// scpu: 8-bit single-cycle processor for the F5 (sum) program.
//
// Instruction format (8 bits):
//   [7:6] opcode
//     00 add   : rd=[5:4], rs1=[3:2], rs2=[1:0], R[rd] = R[rs1] + R[rs2]
//     10 li    : rd=[5:4], imm=[3:0],              R[rd] = {4'b0, imm}
//     11 bner0 : rs =[1:0], target=[5:2],          PC = {4'b0, target} if R[0] != R[rs]
//     others   : no GPR write, PC = PC + 1
//
// Reset is active low; PC and GPRs clear asynchronously, and all
// architectural state updates on the rising clock edge.

`timescale 1ns/1ps

module scpu (
    input  logic       clk,
    input  logic       rst_n,
    output logic [7:0] pc
);

  logic [7:0] rom[0:255];
  logic [7:0] gpr[0:3];

  logic [7:0] instr;
  logic [7:0] pc_next;
  logic       gpr_we;
  logic [1:0] gpr_waddr;
  logic [7:0] gpr_wdata;
  logic [7:0] rs1_data;
  logic [7:0] rs2_data;
  logic       branch_taken;

  initial begin
    $readmemh("sum.hex", rom);
  end

  assign instr        = rom[pc];
  assign rs1_data     = gpr[instr[3:2]];
  assign rs2_data     = gpr[instr[1:0]];
  assign branch_taken = (gpr[0] != gpr[instr[1:0]]);

  always @* begin
    pc_next   = pc + 8'd1;
    gpr_we    = 1'b0;
    gpr_waddr = instr[5:4];
    gpr_wdata = 8'd0;

    case (instr[7:6])
      2'b00: begin  // add
        gpr_we    = 1'b1;
        gpr_wdata = rs1_data + rs2_data;
      end
      2'b10: begin  // li
        gpr_we    = 1'b1;
        gpr_wdata = {4'b0000, instr[3:0]};
      end
      2'b11: begin  // bner0
        if (branch_taken) begin
          pc_next = {4'b0000, instr[5:2]};
        end
      end
      default: ;  // opcode 01 and reserved: PC + 1, no write
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc     <= 8'd0;
      gpr[0] <= 8'd0;
      gpr[1] <= 8'd0;
      gpr[2] <= 8'd0;
      gpr[3] <= 8'd0;
    end else begin
      pc <= pc_next;
      if (gpr_we) begin
        gpr[gpr_waddr] <= gpr_wdata;
      end
    end
  end

endmodule
