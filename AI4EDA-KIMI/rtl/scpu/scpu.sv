module scpu (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] instr,
    output logic [7:0] pc
);
    localparam logic [1:0] OP_ADD   = 2'b00;
    localparam logic [1:0] OP_LI    = 2'b10;
    localparam logic [1:0] OP_BNER0 = 2'b11;

    logic [1:0] opcode;
    logic       is_add;
    logic       is_li;
    logic       is_bner0;
    logic [1:0] raddr1;
    logic [1:0] raddr2;
    logic [7:0] rdata1;
    logic [7:0] rdata2;
    logic       wen;
    logic [1:0] waddr;
    logic [7:0] wdata;
    logic [7:0] next_pc;

    assign opcode   = instr[7:6];
    assign is_add   = opcode == OP_ADD;
    assign is_li    = opcode == OP_LI;
    assign is_bner0 = opcode == OP_BNER0;

    assign raddr1 = is_bner0 ? 2'd0 : instr[3:2];
    assign raddr2 = instr[1:0];
    assign waddr  = instr[5:4];
    assign wen    = is_add || is_li;
    assign wdata  = is_li ? {4'b0000, instr[3:0]} : rdata1 + rdata2;

    assign next_pc = is_bner0 && (rdata1 != rdata2)
                   ? {4'b0000, instr[5:2]} : pc + 8'd1;

    genvar pc_bit;
    generate
        for (pc_bit = 0; pc_bit < 8; pc_bit = pc_bit + 1) begin : gen_pc_dff
            dff_pn u_dff_pn (
                .clk   (clk),
                .rst_n (rst_n),
                .d     (next_pc[pc_bit]),
                .q     (pc[pc_bit])
            );
        end
    endgenerate

    scpu_gpr u_gpr (
        .clk    (clk),
        .rst_n  (rst_n),
        .raddr1 (raddr1),
        .rdata1 (rdata1),
        .raddr2 (raddr2),
        .rdata2 (rdata2),
        .wen    (wen),
        .waddr  (waddr),
        .wdata  (wdata)
    );
endmodule

module scpu_gpr (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [1:0] raddr1,
    output logic [7:0] rdata1,
    input  logic [1:0] raddr2,
    output logic [7:0] rdata2,
    input  logic       wen,
    input  logic [1:0] waddr,
    input  logic [7:0] wdata
);
    logic [7:0] regs [0:3];

    assign rdata1 = regs[raddr1];
    assign rdata2 = regs[raddr2];

    genvar reg_idx;
    genvar bit_idx;
    generate
        for (reg_idx = 0; reg_idx < 4; reg_idx = reg_idx + 1) begin : gen_gpr
            localparam logic [1:0] REG_ADDR = reg_idx;
            logic [7:0] d;

            assign d = wen && (waddr == REG_ADDR) ? wdata : regs[reg_idx];

            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin : gen_dff
                dff_pn u_dff_pn (
                    .clk   (clk),
                    .rst_n (rst_n),
                    .d     (d[bit_idx]),
                    .q     (regs[reg_idx][bit_idx])
                );
            end
        end
    endgenerate
endmodule

module scpu_rom #(
    parameter INIT_FILE = ""
) (
    input  logic [7:0] addr,
    output logic [7:0] rdata
);
    logic [7:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            mem[i] = 8'h00;
        end
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    assign rdata = mem[addr];
endmodule
