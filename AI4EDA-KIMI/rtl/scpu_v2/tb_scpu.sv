`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// 设备模型：只存在于 testbench，不进入 RTL。
// 输入侧组合 mux：idx=0 -> switches，idx=1 -> buttons，其余为 0。
// 输出侧保持寄存器：clk 上升沿且 io_wen=1 时按 idx 更新，复位清零，其余保持。
// ---------------------------------------------------------------------------
module scpu_io_dev (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] switches,
    input  logic [7:0] buttons,
    input  logic [2:0] io_idx,
    input  logic       io_wen,
    input  logic [7:0] io_wdata,
    output logic [7:0] io_rdata,
    output logic [7:0] led,
    output logic [7:0] seven_seg
);
    always_comb begin
        case (io_idx)
            3'd0:    io_rdata = switches;
            3'd1:    io_rdata = buttons;
            default: io_rdata = 8'h00;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led       <= 8'h00;
            seven_seg <= 8'h00;
        end else if (io_wen) begin
            case (io_idx)
                3'd0:    led       <= io_wdata;
                3'd1:    seven_seg <= io_wdata;
                default: ;  // 其他设备编号：不更新，保持原值
            endcase
        end
    end
endmodule

// ---------------------------------------------------------------------------
// 单个测试系统：ROM + scpu + 设备模型，INIT_FILE 选择被测程序。
// ---------------------------------------------------------------------------
module scpu_sys #(
    parameter INIT_FILE = ""
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] switches,
    input  logic [7:0] buttons,
    output logic [7:0] pc,
    output logic       io_wen,
    output logic [2:0] io_idx,
    output logic [7:0] io_wdata,
    output logic [7:0] io_rdata,
    output logic [7:0] led,
    output logic [7:0] seven_seg
);
    logic [7:0] instr;

    scpu_rom #(
        .INIT_FILE (INIT_FILE)
    ) u_rom (
        .addr  (pc),
        .rdata (instr)
    );

    scpu dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .instr    (instr),
        .io_rdata (io_rdata),
        .pc       (pc),
        .io_wen   (io_wen),
        .io_idx   (io_idx),
        .io_wdata (io_wdata)
    );

    scpu_io_dev u_dev (
        .clk       (clk),
        .rst_n     (rst_n),
        .switches  (switches),
        .buttons   (buttons),
        .io_idx    (io_idx),
        .io_wen    (io_wen),
        .io_wdata  (io_wdata),
        .io_rdata  (io_rdata),
        .led       (led),
        .seven_seg (seven_seg)
    );
endmodule

// ---------------------------------------------------------------------------
// 顶层 testbench：四套独立 DUT+ROM+设备模型共享 clk/rst_n，按场景分时复用。
// 所有检查在时钟上升沿后 1ns 采样（此时寄存器与输出设备均已更新）。
// ---------------------------------------------------------------------------
module tb_scpu;
    localparam integer MAX_SIM_NS = 10000;

    localparam integer SYS_SUM    = 0;
    localparam integer SYS_BRANCH = 1;
    localparam integer SYS_LI     = 2;
    localparam integer SYS_IO     = 3;

    logic clk   = 1'b0;
    logic rst_n = 1'b0;

    // 各系统的外部设备输入
    logic [7:0] sw_sum    = 8'd10;  // 求和程序：开关输入 10
    logic [7:0] sw_branch = 8'h00;
    logic [7:0] sw_li     = 8'h00;
    logic [7:0] sw_io     = 8'hA5;  // 本程序不读 idx0，仅用于确认不会误采
    logic [7:0] btn_sum    = 8'h00;
    logic [7:0] btn_branch = 8'h00;
    logic [7:0] btn_li     = 8'h00;
    logic [7:0] btn_io     = 8'h3C;  // io 程序从 idx=1 读按钮

    logic [7:0] pc_sum,    pc_branch,    pc_li,    pc_io;
    logic       wen_sum,   wen_branch,   wen_li,   wen_io;
    logic [2:0] idx_sum,   idx_branch,   idx_li,   idx_io;
    logic [7:0] wdata_sum, wdata_branch, wdata_li, wdata_io;
    logic [7:0] rdata_sum, rdata_branch, rdata_li, rdata_io;
    logic [7:0] led_sum,   led_branch,   led_li,   led_io;
    logic [7:0] seg_sum,   seg_branch,   seg_li,   seg_io;

    integer checks = 0;

    scpu_sys #(.INIT_FILE("sum_io.hex")) u_sum (
        .clk       (clk),
        .rst_n     (rst_n),
        .switches  (sw_sum),
        .buttons   (btn_sum),
        .pc        (pc_sum),
        .io_wen    (wen_sum),
        .io_idx    (idx_sum),
        .io_wdata  (wdata_sum),
        .io_rdata  (rdata_sum),
        .led       (led_sum),
        .seven_seg (seg_sum)
    );

    scpu_sys #(.INIT_FILE("branch_test.hex")) u_branch (
        .clk       (clk),
        .rst_n     (rst_n),
        .switches  (sw_branch),
        .buttons   (btn_branch),
        .pc        (pc_branch),
        .io_wen    (wen_branch),
        .io_idx    (idx_branch),
        .io_wdata  (wdata_branch),
        .io_rdata  (rdata_branch),
        .led       (led_branch),
        .seven_seg (seg_branch)
    );

    scpu_sys #(.INIT_FILE("li_test.hex")) u_li (
        .clk       (clk),
        .rst_n     (rst_n),
        .switches  (sw_li),
        .buttons   (btn_li),
        .pc        (pc_li),
        .io_wen    (wen_li),
        .io_idx    (idx_li),
        .io_wdata  (wdata_li),
        .io_rdata  (rdata_li),
        .led       (led_li),
        .seven_seg (seg_li)
    );

    scpu_sys #(.INIT_FILE("io_test.hex")) u_io (
        .clk       (clk),
        .rst_n     (rst_n),
        .switches  (sw_io),
        .buttons   (btn_io),
        .pc        (pc_io),
        .io_wen    (wen_io),
        .io_idx    (idx_io),
        .io_wdata  (wdata_io),
        .io_rdata  (rdata_io),
        .led       (led_io),
        .seven_seg (seg_io)
    );

    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // 层次化观察函数
    // ------------------------------------------------------------------
    function automatic logic [7:0] get_pc(input integer sys);
        case (sys)
            SYS_SUM:    get_pc = pc_sum;
            SYS_BRANCH: get_pc = pc_branch;
            SYS_LI:     get_pc = pc_li;
            SYS_IO:     get_pc = pc_io;
            default:    get_pc = 8'hxx;
        endcase
    endfunction

    function automatic logic [7:0] get_reg(input integer sys, input logic [1:0] idx);
        case (sys)
            SYS_SUM:    get_reg = u_sum.dut.u_gpr.regs[idx];
            SYS_BRANCH: get_reg = u_branch.dut.u_gpr.regs[idx];
            SYS_LI:     get_reg = u_li.dut.u_gpr.regs[idx];
            SYS_IO:     get_reg = u_io.dut.u_gpr.regs[idx];
            default:    get_reg = 8'hxx;
        endcase
    endfunction

    function automatic logic get_io_wen(input integer sys);
        case (sys)
            SYS_SUM:    get_io_wen = wen_sum;
            SYS_BRANCH: get_io_wen = wen_branch;
            SYS_LI:     get_io_wen = wen_li;
            SYS_IO:     get_io_wen = wen_io;
            default:    get_io_wen = 1'bx;
        endcase
    endfunction

    function automatic logic [2:0] get_io_idx(input integer sys);
        case (sys)
            SYS_SUM:    get_io_idx = idx_sum;
            SYS_BRANCH: get_io_idx = idx_branch;
            SYS_LI:     get_io_idx = idx_li;
            SYS_IO:     get_io_idx = idx_io;
            default:    get_io_idx = 3'bxxx;
        endcase
    endfunction

    function automatic logic [7:0] get_io_wdata(input integer sys);
        case (sys)
            SYS_SUM:    get_io_wdata = wdata_sum;
            SYS_BRANCH: get_io_wdata = wdata_branch;
            SYS_LI:     get_io_wdata = wdata_li;
            SYS_IO:     get_io_wdata = wdata_io;
            default:    get_io_wdata = 8'hxx;
        endcase
    endfunction

    function automatic logic [7:0] get_io_rdata(input integer sys);
        case (sys)
            SYS_SUM:    get_io_rdata = rdata_sum;
            SYS_BRANCH: get_io_rdata = rdata_branch;
            SYS_LI:     get_io_rdata = rdata_li;
            SYS_IO:     get_io_rdata = rdata_io;
            default:    get_io_rdata = 8'hxx;
        endcase
    endfunction

    function automatic logic [7:0] get_led(input integer sys);
        case (sys)
            SYS_SUM:    get_led = led_sum;
            SYS_BRANCH: get_led = led_branch;
            SYS_LI:     get_led = led_li;
            SYS_IO:     get_led = led_io;
            default:    get_led = 8'hxx;
        endcase
    endfunction

    function automatic logic [7:0] get_seg(input integer sys);
        case (sys)
            SYS_SUM:    get_seg = seg_sum;
            SYS_BRANCH: get_seg = seg_branch;
            SYS_LI:     get_seg = seg_li;
            SYS_IO:     get_seg = seg_io;
            default:    get_seg = 8'hxx;
        endcase
    endfunction

    // ------------------------------------------------------------------
    // 检查任务
    // ------------------------------------------------------------------
    task automatic check_pc(input integer sys, input logic [7:0] e_pc, input string tag);
        if (get_pc(sys) !== e_pc) begin
            $fatal(1, "FAIL: t=%0t %s: pc=%0d expected=%0d (instr=%02h)",
                   $time, tag, get_pc(sys), e_pc,
                   (sys == SYS_SUM) ? u_sum.u_rom.mem[get_pc(sys)] : 8'hxx);
        end
    endtask

    task automatic check_reg(input integer sys, input logic [1:0] idx,
                             input logic [7:0] expected, input string tag);
        if (get_reg(sys, idx) !== expected) begin
            $fatal(1, "FAIL: t=%0t %s: R%0d=%0d expected=%0d",
                   $time, tag, idx, get_reg(sys, idx), expected);
        end
    endtask

    task automatic check_state(
        input integer sys,
        input string  tag,
        input logic [7:0] e_pc,
        input logic [7:0] e_r0,
        input logic [7:0] e_r1,
        input logic [7:0] e_r2,
        input logic [7:0] e_r3,
        input logic [7:0] e_led,
        input logic [7:0] e_seg
    );
        check_pc(sys, e_pc, tag);
        check_reg(sys, 2'd0, e_r0, tag);
        check_reg(sys, 2'd1, e_r1, tag);
        check_reg(sys, 2'd2, e_r2, tag);
        check_reg(sys, 2'd3, e_r3, tag);
        if (get_led(sys) !== e_led) begin
            $fatal(1, "FAIL: t=%0t %s: led=%02h expected=%02h",
                   $time, tag, get_led(sys), e_led);
        end
        if (get_seg(sys) !== e_seg) begin
            $fatal(1, "FAIL: t=%0t %s: seven_seg=%02h expected=%02h",
                   $time, tag, get_seg(sys), e_seg);
        end
        checks = checks + 1;
    endtask

    // 等待下一个上升沿，并在寄存器/设备更新后检查 PC。
    task automatic tick(input integer sys, input logic [7:0] e_pc, input string tag);
        @(posedge clk);
        #1;
        check_pc(sys, e_pc, tag);
        checks = checks + 1;
    endtask

    // 当前 pc 指向 io 输入指令时使用：io_wen 必须为 0，io_idx 必须正确。
    task automatic check_io_in(input integer sys, input logic [2:0] e_idx, input string tag);
        if (get_io_wen(sys) !== 1'b0) begin
            $fatal(1, "FAIL: t=%0t %s: io_wen=%b during io input", $time, tag, get_io_wen(sys));
        end
        if (get_io_idx(sys) !== e_idx) begin
            $fatal(1, "FAIL: t=%0t %s: io_idx=%0d expected=%0d", $time, tag, get_io_idx(sys), e_idx);
        end
        checks = checks + 1;
    endtask

    // 当前 pc 指向 io 输出指令时使用：io_wen=1、idx 与 wdata 必须正确。
    task automatic check_io_out(input integer sys, input logic [2:0] e_idx,
                                input logic [7:0] e_wdata, input string tag);
        if (get_io_wen(sys) !== 1'b1) begin
            $fatal(1, "FAIL: t=%0t %s: io_wen=%b expected=1", $time, tag, get_io_wen(sys));
        end
        if (get_io_idx(sys) !== e_idx) begin
            $fatal(1, "FAIL: t=%0t %s: io_idx=%0d expected=%0d", $time, tag, get_io_idx(sys), e_idx);
        end
        if (get_io_wdata(sys) !== e_wdata) begin
            $fatal(1, "FAIL: t=%0t %s: io_wdata=%02h expected=%02h",
                   $time, tag, get_io_wdata(sys), e_wdata);
        end
        checks = checks + 1;
    endtask

    // 非 io 指令期间不得产生写使能。
    task automatic check_no_io(input integer sys, input string tag);
        if (get_io_wen(sys) !== 1'b0) begin
            $fatal(1, "FAIL: t=%0t %s: io_wen=%b should be 0", $time, tag, get_io_wen(sys));
        end
        checks = checks + 1;
    endtask

    task automatic check_rom_encoding(input logic [7:0] actual,
                                      input logic [7:0] expected,
                                      input string tag);
        if (actual !== expected) begin
            $fatal(1, "FAIL: ROM %s=%02h expected=%02h", tag, actual, expected);
        end
        checks = checks + 1;
    endtask

    // 复位两拍后检查四套系统的 PC/GPR/设备/io_wen 全部清零。
    task automatic apply_reset(input string tag);
        integer s;
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        for (s = SYS_SUM; s <= SYS_IO; s = s + 1) begin
            if (get_pc(s) !== 8'd0) begin
                $fatal(1, "FAIL: %s: sys%0d pc=%0d expected=0", tag, s, get_pc(s));
            end
            if (get_reg(s, 2'd0) !== 8'd0 || get_reg(s, 2'd1) !== 8'd0 ||
                get_reg(s, 2'd2) !== 8'd0 || get_reg(s, 2'd3) !== 8'd0) begin
                $fatal(1, "FAIL: %s: sys%0d GPR not cleared", tag, s);
            end
            if (get_led(s) !== 8'd0 || get_seg(s) !== 8'd0) begin
                $fatal(1, "FAIL: %s: sys%0d device not cleared", tag, s);
            end
            if (get_io_wen(s) !== 1'b0) begin
                $fatal(1, "FAIL: %s: sys%0d io_wen=%b after reset", tag, s, get_io_wen(s));
            end
        end
        checks = checks + 1;
    endtask

    // ------------------------------------------------------------------
    // 程序 1：sum_io.hex 完整运行
    // ------------------------------------------------------------------
    task automatic run_sum;
        integer k;

        // 释放复位后 pc=0 为 io 输入指令（0x40）：idx=0、io_wen=0。
        check_io_in(SYS_SUM, 3'd0, "sum PC0 io input idx0");
        if (get_io_rdata(SYS_SUM) !== sw_sum) begin
            $fatal(1, "FAIL: sum PC0 io_rdata=%02h expected switches=%02h",
                   get_io_rdata(SYS_SUM), sw_sum);
        end
        checks = checks + 1;

        tick(SYS_SUM, 8'd1, "sum c1");
        check_state(SYS_SUM, "sum c1: io input R0<-switches(10)",
                    8'd1, 8'd10, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0);

        tick(SYS_SUM, 8'd2, "sum c2 li R1,0");
        check_state(SYS_SUM, "sum c2", 8'd2, 8'd10, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0);

        tick(SYS_SUM, 8'd3, "sum c3 li R2,0");
        check_state(SYS_SUM, "sum c3", 8'd3, 8'd10, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0);

        tick(SYS_SUM, 8'd4, "sum c4 li R3,1");
        check_state(SYS_SUM, "sum c4", 8'd4, 8'd10, 8'd0, 8'd0, 8'd1, 8'd0, 8'd0);
        check_no_io(SYS_SUM, "sum PC4 add");

        // k=1..9：PC6 的 bner0 条件成立，负偏移 -2 跳回 PC4。
        for (k = 1; k <= 9; k = k + 1) begin
            tick(SYS_SUM, 8'd5, "sum loop add R1");
            check_state(SYS_SUM, "sum loop after add R1", 8'd5,
                        8'd10, k[7:0], (k * (k - 1)) / 2, 8'd1, 8'd0, 8'd0);

            tick(SYS_SUM, 8'd6, "sum loop add R2");
            check_state(SYS_SUM, "sum loop after add R2", 8'd6,
                        8'd10, k[7:0], (k * (k + 1)) / 2, 8'd1, 8'd0, 8'd0);

            tick(SYS_SUM, 8'd4, "sum PC6 bner0 taken (-2)");
            check_state(SYS_SUM, "sum loop branch taken", 8'd4,
                        8'd10, k[7:0], (k * (k + 1)) / 2, 8'd1, 8'd0, 8'd0);
        end

        // k=10：R1==R0，条件不成立，顺序执行到 PC7。
        tick(SYS_SUM, 8'd5, "sum final add R1");
        check_state(SYS_SUM, "sum final R1=10", 8'd5, 8'd10, 8'd10, 8'd45, 8'd1, 8'd0, 8'd0);

        tick(SYS_SUM, 8'd6, "sum final add R2");
        check_state(SYS_SUM, "sum final R2=55", 8'd6, 8'd10, 8'd10, 8'd55, 8'd1, 8'd0, 8'd0);

        tick(SYS_SUM, 8'd7, "sum PC6 bner0 not taken");
        check_state(SYS_SUM, "sum condition false", 8'd7, 8'd10, 8'd10, 8'd55, 8'd1, 8'd0, 8'd0);
        check_io_out(SYS_SUM, 3'd0, 8'd55, "sum PC7 io out idx0 R2");

        tick(SYS_SUM, 8'd8, "sum PC7 io out led");
        check_state(SYS_SUM, "sum led=55", 8'd8, 8'd10, 8'd10, 8'd55, 8'd1, 8'd55, 8'd0);
        check_io_out(SYS_SUM, 3'd1, 8'd55, "sum PC8 io out idx1 R2");

        tick(SYS_SUM, 8'd9, "sum PC8 io out seven_seg");
        check_state(SYS_SUM, "sum seven_seg=55", 8'd9,
                    8'd10, 8'd10, 8'd55, 8'd1, 8'd55, 8'd55);
        check_no_io(SYS_SUM, "sum PC9 bner0");

        // PC9 的 bner0 偏移 0，条件成立，自循环。
        repeat (3) begin
            tick(SYS_SUM, 8'd9, "sum PC9 self-loop");
            check_state(SYS_SUM, "sum self-loop state", 8'd9,
                        8'd10, 8'd10, 8'd55, 8'd1, 8'd55, 8'd55);
        end

        $display("INFO: sum_io done: pc=%0d R0=%0d R1=%0d R2=%0d R3=%0d led=%0d seg=%0d",
                 get_pc(SYS_SUM), get_reg(SYS_SUM, 2'd0), get_reg(SYS_SUM, 2'd1),
                 get_reg(SYS_SUM, 2'd2), get_reg(SYS_SUM, 2'd3),
                 get_led(SYS_SUM), get_seg(SYS_SUM));
    endtask

    // ------------------------------------------------------------------
    // 程序 2：branch_test.hex，正/负偏移、条件不成立、相对当前 PC
    // ------------------------------------------------------------------
    task automatic run_branch;
        integer k;

        tick(SYS_BRANCH, 8'd1, "branch c1 li R0,3");
        check_state(SYS_BRANCH, "branch c1", 8'd1, 8'd3, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd2, "branch c2 li R1,0");
        check_state(SYS_BRANCH, "branch c2", 8'd2, 8'd3, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd3, "branch c3 li R3,1");
        check_state(SYS_BRANCH, "branch c3", 8'd3, 8'd3, 8'd0, 8'd0, 8'd1, 8'd0, 8'd0);

        // k=1,2：PC4 的 bner0 条件成立，偏移 -2 相对当前 PC 跳回 PC2。
        for (k = 1; k <= 2; k = k + 1) begin
            tick(SYS_BRANCH, 8'd4, "branch add R1");
            check_state(SYS_BRANCH, "branch after add R1", 8'd4,
                        8'd3, k[7:0], 8'd0, 8'd1, 8'd0, 8'd0);

            tick(SYS_BRANCH, 8'd2, "branch bner0 taken (-2)");
            check_state(SYS_BRANCH, "branch neg taken", 8'd2,
                        8'd3, k[7:0], 8'd0, 8'd1, 8'd0, 8'd0);

            tick(SYS_BRANCH, 8'd3, "branch li R3,1");
            check_state(SYS_BRANCH, "branch loop head", 8'd3,
                        8'd3, k[7:0], 8'd0, 8'd1, 8'd0, 8'd0);
        end

        // k=3：R1==R0，条件不成立，落到 PC5。
        tick(SYS_BRANCH, 8'd4, "branch final add R1");
        check_state(SYS_BRANCH, "branch R1=3", 8'd4, 8'd3, 8'd3, 8'd0, 8'd1, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd5, "branch bner0 not taken");
        check_state(SYS_BRANCH, "branch cond false", 8'd5,
                    8'd3, 8'd3, 8'd0, 8'd1, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd6, "branch li R2,2");
        check_state(SYS_BRANCH, "branch R2=2", 8'd6, 8'd3, 8'd3, 8'd2, 8'd1, 8'd0, 8'd0);

        // PC6 的 bner0 条件成立，偏移 +2 相对当前 PC 跳到 PC8（跳过 PC7）。
        tick(SYS_BRANCH, 8'd8, "branch bner0 taken (+2)");
        check_state(SYS_BRANCH, "branch pos taken, PC7 skipped", 8'd8,
                    8'd3, 8'd3, 8'd2, 8'd1, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd9, "branch li R3,3");
        check_state(SYS_BRANCH, "branch R3=3", 8'd9, 8'd3, 8'd3, 8'd2, 8'd3, 8'd0, 8'd0);

        // PC9 的 bner0 条件不成立，非零偏移 +3 不得生效，顺序到 PC10。
        tick(SYS_BRANCH, 8'd10, "branch bner0 false with +3");
        check_state(SYS_BRANCH, "branch false ignores +3", 8'd10,
                    8'd3, 8'd3, 8'd2, 8'd3, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd11, "branch li R2,4");
        check_state(SYS_BRANCH, "branch R2=4", 8'd11,
                    8'd3, 8'd3, 8'd4, 8'd3, 8'd0, 8'd0);

        // PC11 的 bner0 条件成立（R0=3, R2=4），偏移 0 自循环。
        repeat (3) begin
            tick(SYS_BRANCH, 8'd11, "branch self-loop");
            check_state(SYS_BRANCH, "branch self-loop state", 8'd11,
                        8'd3, 8'd3, 8'd4, 8'd3, 8'd0, 8'd0);
        end

        $display("INFO: branch_test done: pc=%0d R0=%0d R1=%0d R2=%0d R3=%0d",
                 get_pc(SYS_BRANCH), get_reg(SYS_BRANCH, 2'd0), get_reg(SYS_BRANCH, 2'd1),
                 get_reg(SYS_BRANCH, 2'd2), get_reg(SYS_BRANCH, 2'd3));
    endtask

    // ------------------------------------------------------------------
    // 程序 3：li_test.hex，四种 s 与 li r0,192 (0x8f)
    // ------------------------------------------------------------------
    task automatic run_li;
        tick(SYS_LI, 8'd1, "li c1 0x8f li r0,192");
        check_state(SYS_LI, "li c1: li r0,192 (0x8f)", 8'd1,
                    8'd192, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0);

        tick(SYS_LI, 8'd2, "li c2 0x91 li r1,1");
        check_state(SYS_LI, "li c2: s=0 imm=1", 8'd2,
                    8'd192, 8'd1, 8'd0, 8'd0, 8'd0, 8'd0);

        tick(SYS_LI, 8'd3, "li c3 0xa6 li r2,8");
        check_state(SYS_LI, "li c3: s=1 imm=2", 8'd3,
                    8'd192, 8'd1, 8'd8, 8'd0, 8'd0, 8'd0);

        tick(SYS_LI, 8'd4, "li c4 0xb9 li r3,16");
        check_state(SYS_LI, "li c4: s=2 imm=1", 8'd4,
                    8'd192, 8'd1, 8'd8, 8'd16, 8'd0, 8'd0);

        tick(SYS_LI, 8'd5, "li c5 0x8d li r0,64");
        check_state(SYS_LI, "li c5: s=3 imm=1", 8'd5,
                    8'd64, 8'd1, 8'd8, 8'd16, 8'd0, 8'd0);

        tick(SYS_LI, 8'd6, "li c6 0x97 li r1,12");
        check_state(SYS_LI, "li c6: s=1 imm=3", 8'd6,
                    8'd64, 8'd12, 8'd8, 8'd16, 8'd0, 8'd0);

        tick(SYS_LI, 8'd7, "li c7 0xae li r2,128");
        check_state(SYS_LI, "li c7: s=3 imm=2", 8'd7,
                    8'd64, 8'd12, 8'd128, 8'd16, 8'd0, 8'd0);

        tick(SYS_LI, 8'd8, "li c8 0xb3 li r3,3");
        check_state(SYS_LI, "li c8: s=0 imm=3", 8'd8,
                    8'd64, 8'd12, 8'd128, 8'd3, 8'd0, 8'd0);
        check_no_io(SYS_LI, "li c8 no io");

        repeat (2) begin
            tick(SYS_LI, 8'd8, "li self-loop");
            check_state(SYS_LI, "li self-loop state", 8'd8,
                        8'd64, 8'd12, 8'd128, 8'd3, 8'd0, 8'd0);
        end

        $display("INFO: li_test done: pc=%0d R0=%0d R1=%0d R2=%0d R3=%0d",
                 get_pc(SYS_LI), get_reg(SYS_LI, 2'd0), get_reg(SYS_LI, 2'd1),
                 get_reg(SYS_LI, 2'd2), get_reg(SYS_LI, 2'd3));
    endtask

    // ------------------------------------------------------------------
    // 程序 4：io_test.hex，buttons 输入、输出保持、无 io_wen 不更新
    // ------------------------------------------------------------------
    task automatic run_io;
        tick(SYS_IO, 8'd1, "io c1 li R3,1");
        check_state(SYS_IO, "io c1", 8'd1, 8'd0, 8'd0, 8'd0, 8'd1, 8'd0, 8'd0);

        tick(SYS_IO, 8'd2, "io c2 li R1,48");
        check_state(SYS_IO, "io c2", 8'd2, 8'd0, 8'd48, 8'd0, 8'd1, 8'd0, 8'd0);
        // 下一拍执行 PC2（0x51，io 输入 idx=1）。
        check_io_in(SYS_IO, 3'd1, "io PC2 input idx1 buttons");
        if (get_io_rdata(SYS_IO) !== btn_io) begin
            $fatal(1, "FAIL: io PC2 io_rdata=%02h expected buttons=%02h",
                   get_io_rdata(SYS_IO), btn_io);
        end
        checks = checks + 1;

        tick(SYS_IO, 8'd3, "io c3 io in R1<-buttons");
        check_state(SYS_IO, "io c3: R1=buttons", 8'd3,
                    8'd0, btn_io, 8'd0, 8'd1, 8'd0, 8'd0);
        // 下一拍执行 PC3（0x62，io 输入 idx=2），未定义设备编号应读 0。
        check_io_in(SYS_IO, 3'd2, "io PC3 input idx2");
        if (get_io_rdata(SYS_IO) !== 8'h00) begin
            $fatal(1, "FAIL: io PC3 io_rdata=%02h expected=00", get_io_rdata(SYS_IO));
        end
        checks = checks + 1;

        tick(SYS_IO, 8'd4, "io c4 io in R2<-idx2(0)");
        check_state(SYS_IO, "io c4: R2=0", 8'd4, 8'd0, btn_io, 8'd0, 8'd1, 8'd0, 8'd0);
        // 下一拍执行 PC4（0x58，io 输出 idx0，源 R1=buttons）。
        check_io_out(SYS_IO, 3'd0, btn_io, "io PC4 out idx0 R1");

        tick(SYS_IO, 8'd5, "io c5 led<-buttons");
        check_state(SYS_IO, "io c5: led=buttons", 8'd5,
                    8'd0, btn_io, 8'd0, 8'd1, btn_io, 8'd0);
        check_io_out(SYS_IO, 3'd1, btn_io, "io PC5 out idx1 R1");

        tick(SYS_IO, 8'd6, "io c6 seven_seg<-buttons");
        check_state(SYS_IO, "io c6: seven_seg=buttons", 8'd6,
                    8'd0, btn_io, 8'd0, 8'd1, btn_io, btn_io);
        check_no_io(SYS_IO, "io PC6 li, no io_wen");

        // 输出后改变源 GPR R1，设备必须保持原值。
        tick(SYS_IO, 8'd7, "io c7 li R1,192");
        check_state(SYS_IO, "io c7: R1=192, devices hold", 8'd7,
                    8'd0, 8'd192, 8'd0, 8'd1, btn_io, btn_io);
        check_io_out(SYS_IO, 3'd0, 8'd192, "io PC7 out idx0 R1");

        tick(SYS_IO, 8'd8, "io c8 led<-192");
        check_state(SYS_IO, "io c8: led=192, seven_seg holds", 8'd8,
                    8'd0, 8'd192, 8'd0, 8'd1, 8'd192, btn_io);
        check_no_io(SYS_IO, "io PC8 li, no io_wen");

        tick(SYS_IO, 8'd9, "io c9 li R1,1");
        check_state(SYS_IO, "io c9: R1=1, devices hold", 8'd9,
                    8'd0, 8'd1, 8'd0, 8'd1, 8'd192, btn_io);
        check_io_out(SYS_IO, 3'd1, 8'd1, "io PC9 out idx1 R1");

        tick(SYS_IO, 8'd10, "io c10 seven_seg<-1");
        check_state(SYS_IO, "io c10: seven_seg=1, led holds", 8'd10,
                    8'd0, 8'd1, 8'd0, 8'd1, 8'd192, 8'd1);
        check_no_io(SYS_IO, "io PC10 bner0");

        repeat (2) begin
            tick(SYS_IO, 8'd10, "io self-loop");
            check_state(SYS_IO, "io self-loop state", 8'd10,
                        8'd0, 8'd1, 8'd0, 8'd1, 8'd192, 8'd1);
        end

        $display("INFO: io_test done: pc=%0d R0=%0d R1=%0d R2=%0d R3=%0d led=%02h seg=%02h",
                 get_pc(SYS_IO), get_reg(SYS_IO, 2'd0), get_reg(SYS_IO, 2'd1),
                 get_reg(SYS_IO, 2'd2), get_reg(SYS_IO, 2'd3),
                 get_led(SYS_IO), get_seg(SYS_IO));
    endtask

    // ------------------------------------------------------------------
    // 主流程
    // ------------------------------------------------------------------
    initial begin
        // $dumpfile("tb_scpu.vcd");
        // $dumpvars(0, tb_scpu);

        rst_n = 1'b0;

        apply_reset("initial reset");

        // 检查 ROM 中关键指令编码，防止 hex 文件写错导致"测试了别的程序"。
        check_rom_encoding(u_sum.u_rom.mem[0],  8'h40, "sum_io.hex[0] io in idx0");
        check_rom_encoding(u_sum.u_rom.mem[6],  8'hf9, "sum_io.hex[6] bner0 -2");
        check_rom_encoding(u_sum.u_rom.mem[7],  8'h68, "sum_io.hex[7] io out idx0");
        check_rom_encoding(u_sum.u_rom.mem[8],  8'h69, "sum_io.hex[8] io out idx1");
        check_rom_encoding(u_sum.u_rom.mem[9],  8'hc3, "sum_io.hex[9] self-loop");
        check_rom_encoding(u_li.u_rom.mem[0],   8'h8f, "li_test.hex[0] li r0,192");
        check_rom_encoding(u_branch.u_rom.mem[4], 8'hf9, "branch_test.hex[4] bner0 -2");
        check_rom_encoding(u_branch.u_rom.mem[6], 8'hca, "branch_test.hex[6] bner0 +2");
        check_rom_encoding(u_branch.u_rom.mem[9], 8'hcd, "branch_test.hex[9] bner0 +3");
        check_rom_encoding(u_io.u_rom.mem[2],   8'h51, "io_test.hex[2] io in idx1");
        check_rom_encoding(u_io.u_rom.mem[3],   8'h62, "io_test.hex[3] io in idx2");
        check_rom_encoding(u_io.u_rom.mem[5],   8'h59, "io_test.hex[5] io out idx1");

        // ---- 场景 1：sum_io.hex 完整运行 ----
        @(negedge clk);
        rst_n = 1'b1;
        #1;
        run_sum();

        // PC9 自循环中异步复位：PC、GPR、设备必须立即清零。
        #3;
        rst_n = 1'b0;
        #1;
        check_state(SYS_SUM, "sum async reset at PC9", 8'd0,
                    8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0);
        check_no_io(SYS_SUM, "sum reset io_wen");

        // ---- 场景 2：bner0 正/负偏移与条件不成立 ----
        apply_reset("reset before branch");
        @(negedge clk);
        rst_n = 1'b1;
        #1;
        run_branch();

        // ---- 场景 3：li 四种 s 与 li r0,192 ----
        apply_reset("reset before li");
        @(negedge clk);
        rst_n = 1'b1;
        #1;
        run_li();

        // ---- 场景 4：io 输入/输出与设备保持 ----
        apply_reset("reset before io");
        @(negedge clk);
        rst_n = 1'b1;
        #1;
        run_io();

        $display("PASS: tb_scpu completed %0d checks (sum_io, branch, li, io)", checks);
        $finish;
    end

    initial begin
        #(MAX_SIM_NS);
        $display("FAIL: timeout after %0d ns, pc_sum=%0d", MAX_SIM_NS, pc_sum);
        $fatal(1);
    end
endmodule
