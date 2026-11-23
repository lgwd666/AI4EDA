module NPC (
    input  logic        clk,
    input  logic        rst_n,
    output logic [31:0] debug_pc,
    output logic [31:0] debug_inst,
    output logic [31:0] debug_regs [15:0]
);
    logic [31:0] pc;
    logic [31:0] inst;
    logic [6:0]  opcode;
    logic [2:0]  funt3;
    logic [6:0]  funt7;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [4:0]  rd;
    logic [31:0] imm;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] rd_data;
    logic        rd_wen;
    logic [31:0] new_pc;
    logic [31:0] mem_addr;
    logic        mem_valid;
    logic        mem_wen;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wmask;
    logic [31:0] mem_rdata;

    IFU u_ifu (
        .clk    (clk),
        .rst_n  (rst_n),
        .new_pc (new_pc),
        .pc     (pc),
        .inst   (inst)
    );

    IDU u_idu (
        .inst   (inst),
        .opcode (opcode),
        .funt3  (funt3),
        .funt7  (funt7),
        .rs1    (rs1),
        .rs2    (rs2),
        .rd     (rd),
        .imm    (imm)
    );

    GPR u_gpr (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1      (rs1),
        .rs2      (rs2),
        .rd       (rd),
        .rd_wen   (rd_wen),
        .rd_wdata (rd_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    EXU u_exu (
        .pc        (pc),
        .opcode    (opcode),
        .funt3     (funt3),
        .funt7     (funt7),
        .imm       (imm),
        .mem_rdata (mem_rdata),
        .rs1_data  (rs1_data),
        .rs2_data  (rs2_data),
        .rd_data   (rd_data),
        .rd_wen    (rd_wen),
        .mem_addr  (mem_addr),
        .mem_valid (mem_valid),
        .mem_wen   (mem_wen),
        .mem_wdata (mem_wdata),
        .mem_wmask (mem_wmask),
        .new_pc    (new_pc)
    );

    LSU u_lsu (
        .mem_addr  (mem_addr),
        .mem_valid (mem_valid),
        .mem_wen   (mem_wen),
        .mem_wdata (mem_wdata),
        .mem_wmask (mem_wmask),
        .mem_rdata (mem_rdata)
    );

    // 仿真观察端口，不参与处理器内部数据通路。
    assign debug_pc = pc;
    assign debug_inst = inst;

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_debug_regs
            assign debug_regs[i] = u_gpr.xreg[i];
        end
    endgenerate
endmodule
