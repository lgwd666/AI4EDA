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

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 8'd0;
        end else begin
            pc <= next_pc;
        end
    end

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
    integer i;

    assign rdata1 = regs[raddr1];
    assign rdata2 = regs[raddr2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 4; i = i + 1) begin
                regs[i] <= 8'd0;
            end
        end else if (wen) begin
            regs[waddr] <= wdata;
        end
    end
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
