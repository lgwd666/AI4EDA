module difftest_top #(
    parameter INIT_FILE = "sum_io.hex"
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] switches,
    input  logic [7:0] buttons,
    input  logic [7:0] inject_at,
    input  logic [7:0] inject_mask,
    output logic [7:0] pc,
    output logic [7:0] gpr0,
    output logic [7:0] gpr1,
    output logic [7:0] gpr2,
    output logic [7:0] gpr3,
    output logic       led_wen,
    output logic [7:0] led_wdata,
    output logic       seven_seg_wen,
    output logic [7:0] seven_seg_wdata
);
    logic [7:0] rom_instr;
    logic [7:0] cpu_instr;

    assign cpu_instr = rom_instr ^ (pc == inject_at ? inject_mask : 8'h00);

    scpu_rom #(
        .INIT_FILE (INIT_FILE)
    ) u_rom (
        .addr  (pc),
        .rdata (rom_instr)
    );

    scpu u_cpu (
        .clk             (clk),
        .rst_n           (rst_n),
        .instr           (cpu_instr),
        .switches        (switches),
        .buttons         (buttons),
        .pc              (pc),
        .led_wen         (led_wen),
        .led_wdata       (led_wdata),
        .seven_seg_wen   (seven_seg_wen),
        .seven_seg_wdata (seven_seg_wdata)
    );

    assign gpr0 = u_cpu.u_gpr.regs[0];
    assign gpr1 = u_cpu.u_gpr.regs[1];
    assign gpr2 = u_cpu.u_gpr.regs[2];
    assign gpr3 = u_cpu.u_gpr.regs[3];
endmodule
