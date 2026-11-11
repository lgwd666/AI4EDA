`timescale 1ns/1ps

// 输出保持寄存器只存在于 testbench，不进入处理器 RTL。
module scpu_io_dev (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       led_wen,
    input  logic [7:0] led_wdata,
    input  logic       seven_seg_wen,
    input  logic [7:0] seven_seg_wdata,
    output logic [7:0] led,
    output logic [7:0] seven_seg
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led       <= 8'h00;
            seven_seg <= 8'h00;
        end else begin
            if (led_wen) begin
                led <= led_wdata;
            end
            if (seven_seg_wen) begin
                seven_seg <= seven_seg_wdata;
            end
        end
    end
endmodule

module scpu_sys #(
    parameter INIT_FILE = ""
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] switches,
    input  logic [7:0] buttons,
    output logic [7:0] pc,
    output logic       led_wen,
    output logic [7:0] led_wdata,
    output logic       seven_seg_wen,
    output logic [7:0] seven_seg_wdata,
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
        .clk             (clk),
        .rst_n           (rst_n),
        .instr           (instr),
        .switches        (switches),
        .buttons         (buttons),
        .pc              (pc),
        .led_wen         (led_wen),
        .led_wdata       (led_wdata),
        .seven_seg_wen   (seven_seg_wen),
        .seven_seg_wdata (seven_seg_wdata)
    );

    scpu_io_dev u_dev (
        .clk             (clk),
        .rst_n           (rst_n),
        .led_wen         (led_wen),
        .led_wdata       (led_wdata),
        .seven_seg_wen   (seven_seg_wen),
        .seven_seg_wdata (seven_seg_wdata),
        .led             (led),
        .seven_seg       (seven_seg)
    );
endmodule

module tb_scpu;
    localparam integer MAX_SIM_NS = 10000;

    localparam integer SYS_SUM    = 0;
    localparam integer SYS_BRANCH = 1;
    localparam integer SYS_LI     = 2;
    localparam integer SYS_IO     = 3;

    logic clk   = 1'b0;
    logic rst_n = 1'b0;

    logic [7:0] sw_sum    = 8'd10;
    logic [7:0] sw_branch = 8'h00;
    logic [7:0] sw_li     = 8'h00;
    logic [7:0] sw_io     = 8'hA5;
    logic [7:0] btn_sum    = 8'h00;
    logic [7:0] btn_branch = 8'h00;
    logic [7:0] btn_li     = 8'h00;
    logic [7:0] btn_io     = 8'h3C;

    logic [7:0] pc_sum, pc_branch, pc_li, pc_io;
    logic       led_wen_sum, led_wen_branch, led_wen_li, led_wen_io;
    logic       seg_wen_sum, seg_wen_branch, seg_wen_li, seg_wen_io;
    logic [7:0] led_wdata_sum, led_wdata_branch, led_wdata_li, led_wdata_io;
    logic [7:0] seg_wdata_sum, seg_wdata_branch, seg_wdata_li, seg_wdata_io;
    logic [7:0] led_sum, led_branch, led_li, led_io;
    logic [7:0] seg_sum, seg_branch, seg_li, seg_io;

    integer checks = 0;

    scpu_sys #(.INIT_FILE("sum_io.hex")) u_sum (
        .clk             (clk),
        .rst_n           (rst_n),
        .switches        (sw_sum),
        .buttons         (btn_sum),
        .pc              (pc_sum),
        .led_wen         (led_wen_sum),
        .led_wdata       (led_wdata_sum),
        .seven_seg_wen   (seg_wen_sum),
        .seven_seg_wdata (seg_wdata_sum),
        .led             (led_sum),
        .seven_seg       (seg_sum)
    );

    scpu_sys #(.INIT_FILE("branch_test.hex")) u_branch (
        .clk             (clk),
        .rst_n           (rst_n),
        .switches        (sw_branch),
        .buttons         (btn_branch),
        .pc              (pc_branch),
        .led_wen         (led_wen_branch),
        .led_wdata       (led_wdata_branch),
        .seven_seg_wen   (seg_wen_branch),
        .seven_seg_wdata (seg_wdata_branch),
        .led             (led_branch),
        .seven_seg       (seg_branch)
    );

    scpu_sys #(.INIT_FILE("li_test.hex")) u_li (
        .clk             (clk),
        .rst_n           (rst_n),
        .switches        (sw_li),
        .buttons         (btn_li),
        .pc              (pc_li),
        .led_wen         (led_wen_li),
        .led_wdata       (led_wdata_li),
        .seven_seg_wen   (seg_wen_li),
        .seven_seg_wdata (seg_wdata_li),
        .led             (led_li),
        .seven_seg       (seg_li)
    );

    scpu_sys #(.INIT_FILE("io_test.hex")) u_io (
        .clk             (clk),
        .rst_n           (rst_n),
        .switches        (sw_io),
        .buttons         (btn_io),
        .pc              (pc_io),
        .led_wen         (led_wen_io),
        .led_wdata       (led_wdata_io),
        .seven_seg_wen   (seg_wen_io),
        .seven_seg_wdata (seg_wdata_io),
        .led             (led_io),
        .seven_seg       (seg_io)
    );

    always #5 clk = ~clk;

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

    function automatic logic get_led_wen(input integer sys);
        case (sys)
            SYS_SUM:    get_led_wen = led_wen_sum;
            SYS_BRANCH: get_led_wen = led_wen_branch;
            SYS_LI:     get_led_wen = led_wen_li;
            SYS_IO:     get_led_wen = led_wen_io;
            default:    get_led_wen = 1'bx;
        endcase
    endfunction

    function automatic logic get_seg_wen(input integer sys);
        case (sys)
            SYS_SUM:    get_seg_wen = seg_wen_sum;
            SYS_BRANCH: get_seg_wen = seg_wen_branch;
            SYS_LI:     get_seg_wen = seg_wen_li;
            SYS_IO:     get_seg_wen = seg_wen_io;
            default:    get_seg_wen = 1'bx;
        endcase
    endfunction

    function automatic logic [7:0] get_led_wdata(input integer sys);
        case (sys)
            SYS_SUM:    get_led_wdata = led_wdata_sum;
            SYS_BRANCH: get_led_wdata = led_wdata_branch;
            SYS_LI:     get_led_wdata = led_wdata_li;
            SYS_IO:     get_led_wdata = led_wdata_io;
            default:    get_led_wdata = 8'hxx;
        endcase
    endfunction

    function automatic logic [7:0] get_seg_wdata(input integer sys);
        case (sys)
            SYS_SUM:    get_seg_wdata = seg_wdata_sum;
            SYS_BRANCH: get_seg_wdata = seg_wdata_branch;
            SYS_LI:     get_seg_wdata = seg_wdata_li;
            SYS_IO:     get_seg_wdata = seg_wdata_io;
            default:    get_seg_wdata = 8'hxx;
        endcase
    endfunction

    function automatic logic [7:0] get_io_rdata(input integer sys);
        case (sys)
            SYS_SUM:    get_io_rdata = u_sum.dut.io_rdata;
            SYS_BRANCH: get_io_rdata = u_branch.dut.io_rdata;
            SYS_LI:     get_io_rdata = u_li.dut.io_rdata;
            SYS_IO:     get_io_rdata = u_io.dut.io_rdata;
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

    task automatic tick(input integer sys, input logic [7:0] e_pc, input string tag);
        @(posedge clk);
        #1;
        check_pc(sys, e_pc, tag);
        checks = checks + 1;
    endtask

    task automatic check_io_in(input integer sys, input logic [7:0] e_rdata,
                               input string tag);
        if (get_led_wen(sys) !== 1'b0 || get_seg_wen(sys) !== 1'b0) begin
            $fatal(1, "FAIL: t=%0t %s: output write enable asserted during io input",
                   $time, tag);
        end
        if (get_io_rdata(sys) !== e_rdata) begin
            $fatal(1, "FAIL: t=%0t %s: io_rdata=%02h expected=%02h",
                   $time, tag, get_io_rdata(sys), e_rdata);
        end
        checks = checks + 1;
    endtask

    task automatic check_led_out(input integer sys, input logic [7:0] e_wdata,
                                 input string tag);
        if (get_led_wen(sys) !== 1'b1 || get_seg_wen(sys) !== 1'b0) begin
            $fatal(1, "FAIL: t=%0t %s: led_wen=%b seven_seg_wen=%b expected=1/0",
                   $time, tag, get_led_wen(sys), get_seg_wen(sys));
        end
        if (get_led_wdata(sys) !== e_wdata) begin
            $fatal(1, "FAIL: t=%0t %s: led_wdata=%02h expected=%02h",
                   $time, tag, get_led_wdata(sys), e_wdata);
        end
        checks = checks + 1;
    endtask

    task automatic check_seg_out(input integer sys, input logic [7:0] e_wdata,
                                 input string tag);
        if (get_led_wen(sys) !== 1'b0 || get_seg_wen(sys) !== 1'b1) begin
            $fatal(1, "FAIL: t=%0t %s: led_wen=%b seven_seg_wen=%b expected=0/1",
                   $time, tag, get_led_wen(sys), get_seg_wen(sys));
        end
        if (get_seg_wdata(sys) !== e_wdata) begin
            $fatal(1, "FAIL: t=%0t %s: seven_seg_wdata=%02h expected=%02h",
                   $time, tag, get_seg_wdata(sys), e_wdata);
        end
        checks = checks + 1;
    endtask

    task automatic check_no_io(input integer sys, input string tag);
        if (get_led_wen(sys) !== 1'b0 || get_seg_wen(sys) !== 1'b0) begin
            $fatal(1, "FAIL: t=%0t %s: led_wen=%b seven_seg_wen=%b should be 0/0",
                   $time, tag, get_led_wen(sys), get_seg_wen(sys));
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
            if (get_led_wen(s) !== 1'b0 || get_seg_wen(s) !== 1'b0) begin
                $fatal(1, "FAIL: %s: sys%0d output write enable asserted after reset", tag, s);
            end
        end
        checks = checks + 1;
    endtask

    task automatic run_sum;
        integer k;

        check_io_in(SYS_SUM, sw_sum, "sum PC0 io input switches");

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

        tick(SYS_SUM, 8'd5, "sum final add R1");
        check_state(SYS_SUM, "sum final R1=10", 8'd5, 8'd10, 8'd10, 8'd45, 8'd1, 8'd0, 8'd0);

        tick(SYS_SUM, 8'd6, "sum final add R2");
        check_state(SYS_SUM, "sum final R2=55", 8'd6, 8'd10, 8'd10, 8'd55, 8'd1, 8'd0, 8'd0);

        tick(SYS_SUM, 8'd7, "sum PC6 bner0 not taken");
        check_state(SYS_SUM, "sum condition false", 8'd7, 8'd10, 8'd10, 8'd55, 8'd1, 8'd0, 8'd0);
        check_led_out(SYS_SUM, 8'd55, "sum PC7 io out R2 to LED");

        tick(SYS_SUM, 8'd8, "sum PC7 io out led");
        check_state(SYS_SUM, "sum led=55", 8'd8, 8'd10, 8'd10, 8'd55, 8'd1, 8'd55, 8'd0);
        check_seg_out(SYS_SUM, 8'd55, "sum PC8 io out R2 to seven_seg");

        tick(SYS_SUM, 8'd9, "sum PC8 io out seven_seg");
        check_state(SYS_SUM, "sum seven_seg=55", 8'd9,
                    8'd10, 8'd10, 8'd55, 8'd1, 8'd55, 8'd55);
        check_no_io(SYS_SUM, "sum PC9 bner0");

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

    task automatic run_branch;
        integer k;

        tick(SYS_BRANCH, 8'd1, "branch c1 li R0,3");
        check_state(SYS_BRANCH, "branch c1", 8'd1, 8'd3, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd2, "branch c2 li R1,0");
        check_state(SYS_BRANCH, "branch c2", 8'd2, 8'd3, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd3, "branch c3 li R3,1");
        check_state(SYS_BRANCH, "branch c3", 8'd3, 8'd3, 8'd0, 8'd0, 8'd1, 8'd0, 8'd0);

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

        tick(SYS_BRANCH, 8'd4, "branch final add R1");
        check_state(SYS_BRANCH, "branch R1=3", 8'd4, 8'd3, 8'd3, 8'd0, 8'd1, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd5, "branch bner0 not taken");
        check_state(SYS_BRANCH, "branch cond false", 8'd5,
                    8'd3, 8'd3, 8'd0, 8'd1, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd6, "branch li R2,2");
        check_state(SYS_BRANCH, "branch R2=2", 8'd6, 8'd3, 8'd3, 8'd2, 8'd1, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd8, "branch bner0 taken (+2)");
        check_state(SYS_BRANCH, "branch pos taken, PC7 skipped", 8'd8,
                    8'd3, 8'd3, 8'd2, 8'd1, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd9, "branch li R3,3");
        check_state(SYS_BRANCH, "branch R3=3", 8'd9, 8'd3, 8'd3, 8'd2, 8'd3, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd10, "branch bner0 false with +3");
        check_state(SYS_BRANCH, "branch false ignores +3", 8'd10,
                    8'd3, 8'd3, 8'd2, 8'd3, 8'd0, 8'd0);

        tick(SYS_BRANCH, 8'd11, "branch li R2,4");
        check_state(SYS_BRANCH, "branch R2=4", 8'd11,
                    8'd3, 8'd3, 8'd4, 8'd3, 8'd0, 8'd0);

        repeat (3) begin
            tick(SYS_BRANCH, 8'd11, "branch self-loop");
            check_state(SYS_BRANCH, "branch self-loop state", 8'd11,
                        8'd3, 8'd3, 8'd4, 8'd3, 8'd0, 8'd0);
        end

        $display("INFO: branch_test done: pc=%0d R0=%0d R1=%0d R2=%0d R3=%0d",
                 get_pc(SYS_BRANCH), get_reg(SYS_BRANCH, 2'd0), get_reg(SYS_BRANCH, 2'd1),
                 get_reg(SYS_BRANCH, 2'd2), get_reg(SYS_BRANCH, 2'd3));
    endtask

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

    task automatic run_io;
        tick(SYS_IO, 8'd1, "io c1 li R3,1");
        check_state(SYS_IO, "io c1", 8'd1, 8'd0, 8'd0, 8'd0, 8'd1, 8'd0, 8'd0);

        tick(SYS_IO, 8'd2, "io c2 li R1,48");
        check_state(SYS_IO, "io c2", 8'd2, 8'd0, 8'd48, 8'd0, 8'd1, 8'd0, 8'd0);
        check_io_in(SYS_IO, btn_io, "io PC2 input buttons");

        tick(SYS_IO, 8'd3, "io c3 io in R1<-buttons");
        check_state(SYS_IO, "io c3: R1=buttons", 8'd3,
                    8'd0, btn_io, 8'd0, 8'd1, 8'd0, 8'd0);
        check_io_in(SYS_IO, 8'h00, "io PC3 input undefined device");

        tick(SYS_IO, 8'd4, "io c4 io in R2<-undefined(0)");
        check_state(SYS_IO, "io c4: R2=0", 8'd4, 8'd0, btn_io, 8'd0, 8'd1, 8'd0, 8'd0);
        check_led_out(SYS_IO, btn_io, "io PC4 out R1 to LED");

        tick(SYS_IO, 8'd5, "io c5 led<-buttons");
        check_state(SYS_IO, "io c5: led=buttons", 8'd5,
                    8'd0, btn_io, 8'd0, 8'd1, btn_io, 8'd0);
        check_seg_out(SYS_IO, btn_io, "io PC5 out R1 to seven_seg");

        tick(SYS_IO, 8'd6, "io c6 seven_seg<-buttons");
        check_state(SYS_IO, "io c6: seven_seg=buttons", 8'd6,
                    8'd0, btn_io, 8'd0, 8'd1, btn_io, btn_io);
        check_no_io(SYS_IO, "io PC6 li");

        tick(SYS_IO, 8'd7, "io c7 li R1,192");
        check_state(SYS_IO, "io c7: R1=192, devices hold", 8'd7,
                    8'd0, 8'd192, 8'd0, 8'd1, btn_io, btn_io);
        check_led_out(SYS_IO, 8'd192, "io PC7 out R1 to LED");

        tick(SYS_IO, 8'd8, "io c8 led<-192");
        check_state(SYS_IO, "io c8: led=192, seven_seg holds", 8'd8,
                    8'd0, 8'd192, 8'd0, 8'd1, 8'd192, btn_io);
        check_no_io(SYS_IO, "io PC8 li");

        tick(SYS_IO, 8'd9, "io c9 li R1,1");
        check_state(SYS_IO, "io c9: R1=1, devices hold", 8'd9,
                    8'd0, 8'd1, 8'd0, 8'd1, 8'd192, btn_io);
        check_seg_out(SYS_IO, 8'd1, "io PC9 out R1 to seven_seg");

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

    initial begin
        // $dumpfile("tb_scpu.vcd");
        // $dumpvars(0, tb_scpu);

        rst_n = 1'b0;

        apply_reset("initial reset");

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

        @(negedge clk);
        rst_n = 1'b1;
        #1;
        run_sum();

        #3;
        rst_n = 1'b0;
        #1;
        check_state(SYS_SUM, "sum async reset at PC9", 8'd0,
                    8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0);
        check_no_io(SYS_SUM, "sum reset io output");

        apply_reset("reset before branch");
        @(negedge clk);
        rst_n = 1'b1;
        #1;
        run_branch();

        apply_reset("reset before li");
        @(negedge clk);
        rst_n = 1'b1;
        #1;
        run_li();

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
