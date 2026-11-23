module IFU (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] new_pc,
    output logic [31:0] pc,
    output logic [31:0] inst
);

    dff_pn #(32,32'h80000000) u_pc_reg (.clk(clk), .rst_n(rst_n), .d(new_pc), .q(pc));

    import "DPI-C" function int pmem_read(input int raddr);
    assign inst = !rst_n ? 0 : pmem_read(pc);


endmodule
