module scpu #(
    parameter STEP_MODE = 0
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] instr,
    input  logic [7:0] switches,
    input  logic [7:0] buttons,
    output logic [7:0] pc,
    output logic       led_wen,
    output logic [7:0] led_wdata,
    output logic       seven_seg_wen,
    output logic [7:0] seven_seg_wdata
);
    localparam logic [1:0] OP_ADD   = 2'b00;
    localparam logic [1:0] OP_IO    = 2'b01;
    localparam logic [1:0] OP_LI    = 2'b10;
    localparam logic [1:0] OP_BNER0 = 2'b11;

    logic       is_add;
    logic       is_io;
    logic       is_li;
    logic       is_bner0;
    logic       io_dir;
    logic [7:0] io_rdata;
    logic [1:0] raddr1;
    logic [1:0] raddr2;
    logic [7:0] rdata1;
    logic [7:0] rdata2;
    logic       wen;
    logic [1:0] waddr;
    logic [7:0] li_data;
    logic [7:0] add_data;
    logic [7:0] wdata;
    logic [7:0] branch_offset;
    logic [7:0] pc_step;
    logic [7:0] next_pc;
    logic [7:0] buttons_d;
    logic       button_rise;
    logic       wait_button;
    logic       pc_wen;

    assign is_add   = instr[7:6] == OP_ADD;
    assign is_io    = instr[7:6] == OP_IO;
    assign is_li    = instr[7:6] == OP_LI;
    assign is_bner0 = instr[7:6] == OP_BNER0;
    assign io_dir   = instr[3];

    // bner0 固定比较 R0；io 与 add 的第一个源寄存器使用不同字段。
    assign raddr1 = is_bner0 ? 2'd0
                  : is_io    ? instr[5:4] : instr[3:2];
    assign raddr2 = instr[1:0];
    assign waddr  = instr[5:4];
    assign wen    = is_add || is_li || (is_io && !io_dir);

    // li 把 2 位立即数按 instr[3:2] 左移 0/2/4/6 位。
    always_comb begin
        case (instr[3:2])
            2'b00: li_data = {6'b000000, instr[1:0]};
            2'b01: li_data = {4'b0000, instr[1:0], 2'b00};
            2'b10: li_data = {2'b00, instr[1:0], 4'b0000};
            default: li_data = {instr[1:0], 6'b000000};
        endcase
    end

    // 设备编号只在 CPU 内部译码，各外设使用独立输入或写使能。
    assign io_rdata = instr[2:0] == 3'd0 ? switches
                    : instr[2:0] == 3'd1 ? buttons : 8'h00;
    assign add_data = rdata1 + rdata2;
    assign wdata    = is_li ? li_data
                    : is_io ? io_rdata : add_data;

    assign led_wen        = rst_n && is_io && io_dir && instr[2:0] == 3'd0;
    assign led_wdata      = rdata1;
    assign seven_seg_wen  = rst_n && is_io && io_dir && instr[2:0] == 3'd1;
    assign seven_seg_wdata = rdata1;

    // STEP_MODE 下，按钮输入指令是等待点；只有按钮上升沿才释放 PC。
    assign button_rise = |(buttons & ~buttons_d);
    assign wait_button = STEP_MODE && is_io && !io_dir && instr[2:0] == 3'd1;
    assign pc_wen      = !wait_button || button_rise;

    // bner0 的 4 位有符号偏移相对当前 PC，而不是下一条指令。
    assign branch_offset = {{4{instr[5]}}, instr[5:2]};
    assign pc_step = is_bner0 && (rdata1 != rdata2) ? branch_offset : 8'd1;
    assign next_pc = pc + pc_step;

    dff_pn #(
        .WIDTH       (8),
        .RESET_VALUE (8'h00)
    ) u_pc_dff (
        .clk   (clk),
        .rst_n (rst_n),
        .d     (pc_wen ? next_pc : pc),
        .q     (pc)
    );

    dff_pn #(
        .WIDTH       (8),
        .RESET_VALUE (8'h00)
    ) u_buttons_dff (
        .clk   (clk),
        .rst_n (rst_n),
        .d     (buttons),
        .q     (buttons_d)
    );

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

// 4 个 8 位 GPR，共用两个组合读端口和一个时钟上升沿写端口。
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
    generate
        for (reg_idx = 0; reg_idx < 4; reg_idx = reg_idx + 1) begin : gen_gpr
            localparam logic [1:0] REG_ADDR = reg_idx;
            logic [7:0] d;

            assign d = wen && (waddr == REG_ADDR) ? wdata : regs[reg_idx];

            dff_pn #(
                .WIDTH       (8),
                .RESET_VALUE (8'h00)
            ) u_dff_pn (
                .clk   (clk),
                .rst_n (rst_n),
                .d     (d),
                .q     (regs[reg_idx])
            );
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
