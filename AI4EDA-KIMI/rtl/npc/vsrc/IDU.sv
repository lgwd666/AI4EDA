module IDU (
    input  logic [31:0] inst,
    output logic [6: 0] opcode,
    output logic [2: 0] funt3,
    output logic [6: 0] funt7,
    output logic [4: 0] rs1,
    output logic [4: 0] rs2,
    output logic [4: 0] rd,
    output logic [31:0] imm
);

    assign opcode = inst[6 : 0];
    assign rd     = inst[11: 7];
    assign funt3  = inst[14:12];
    assign rs1    = inst[19:15];
    assign rs2    = inst[24:20];
    assign funt7  = (opcode==OP) ? inst[31:25] : 7'b0;
    assign imm    = (opcode==OP_IMM)||(opcode==JALR)||(opcode==LOAD) ? {20'b0, inst[31:20]} : 
                    (opcode==LUI) ? {inst[31:12], 12'b0} :
                    (opcode==STORE) ? {20'b0, inst[31:25], inst[11:7]} : 32'b0;

endmodule
