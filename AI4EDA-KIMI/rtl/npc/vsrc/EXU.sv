module EXU (
    input  logic [2: 0] npc_state,
    input  logic [31:0] pc,
    input  logic [6: 0] opcode,
    input  logic [2: 0] funt3,
    input  logic [6: 0] funt7,
    input  logic [31:0] imm,
    input  logic [31:0] mem_rdata,
    input  logic [31:0] rs1_data,
    input  logic [31:0] rs2_data,
    output logic [31:0] rd_data,
    output logic        rd_wen,
    output logic [31:0] mem_addr,
    output logic        mem_valid,
    output logic        mem_wen,
    output logic [31:0] mem_wdata,
    output logic [3: 0] mem_wmask,
    output logic [31:0] new_pc
);

    logic [31:0] new_pc_addr;
    logic [7:0] mem_rdata_lb; 
    
    assign mem_rdata_lb = mem_addr[1:0] == 2'b00 ? mem_rdata[7:0] :
                          mem_addr[1:0] == 2'b01 ? mem_rdata[15:8] :
                          mem_addr[1:0] == 2'b10 ? mem_rdata[23:16] :
                          mem_addr[1:0] == 2'b11 ? mem_rdata[31:24] : 8'b0;
    assign rd_data = (opcode==OP_IMM)&(funt3==OP_IMM_FUNT3_ADD) ? rs1_data + {{20{imm[11]}}, imm[11:0]} : 
                     (opcode==JALR) ? pc+4 :
                     (opcode==OP)&(funt3==OP_FUNT3_ADD) ? rs1_data + rs2_data :
                     (opcode==LUI) ? {imm[31:12], 12'b0} : 
                     (opcode==LOAD)&(funt3==LOAD_LW) ? mem_rdata :
                     (opcode==LOAD)&(funt3==LOAD_LBU) ? {24'b0, mem_rdata_lb} : 32'b0;

    assign rd_wen = npc_state==IDLE ? 1'b0 : 
                    (opcode==OP_IMM)&(funt3==OP_IMM_FUNT3_ADD) ? 1'b1 :
                    (opcode==JALR) ? 1'b1 : 
                    (opcode==OP)&(funt3==OP_FUNT3_ADD) ? 1'b1 : 
                    (opcode==LUI) ? 1'b1 : 
                    (opcode==LOAD)&(funt3==LOAD_LW) ? 1'b1 :
                    (opcode==LOAD)&(funt3==LOAD_LBU) ? 1'b1 : 1'b0;

    assign new_pc_addr = rs1_data + {{20{imm[11]}}, imm[11:0]};
    assign new_pc = (opcode==JALR) ? {new_pc_addr[31:1], 1'b0} : pc+4;

    assign mem_addr = (opcode==STORE)||(opcode==LOAD) ? rs1_data + {{20{imm[11]}}, imm[11:0]} : 32'b0;
    assign mem_valid = (opcode==LOAD)||(opcode==STORE);
    assign mem_wen = npc_state==IDLE ? 1'b0 : (opcode==STORE) ? 1'b1 : 1'b0;
    assign mem_wdata = (opcode==STORE)&(funt3==STORE_SW) ? rs2_data : 
                       (opcode==STORE)&(funt3==STORE_SB) ? (
                           mem_addr[1:0] == 2'b00 ? {24'b0, rs2_data[7:0]} :
                           mem_addr[1:0] == 2'b01 ? {16'b0, rs2_data[7:0], 8'b0} :
                           mem_addr[1:0] == 2'b10 ? {8'b0, rs2_data[7:0], 16'b0} :
                           mem_addr[1:0] == 2'b11 ? {rs2_data[7:0], 24'b0} : 32'b0
                       ) : 32'b0;
    assign mem_wmask = (opcode==STORE)&(funt3==STORE_SW) ? 4'b1111 : 
                       (opcode==STORE)&(funt3==STORE_SB) ? (
                           mem_addr[1:0] == 2'b00 ? 4'b0001 :
                           mem_addr[1:0] == 2'b01 ? 4'b0010 :
                           mem_addr[1:0] == 2'b10 ? 4'b0100 :
                           mem_addr[1:0] == 2'b11 ? 4'b1000 : 4'b0
                       ) : 4'b0000;


endmodule
