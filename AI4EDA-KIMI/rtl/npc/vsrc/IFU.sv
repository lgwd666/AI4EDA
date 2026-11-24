module IFU (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] new_pc,
    input  logic [2: 0] npc_state,
    output logic [31:0] pc,
    output logic [31:0] inst
);

    logic [31:0] pc_pre;
    assign pc_pre = npc_state==IDLE ? pc : new_pc;
    dff_pn #(32,32'h80000000) u_pc_reg (.clk(clk), .rst_n(rst_n), .d(new_pc), .q(pc));

    import "DPI-C" function int pmem_read(input int raddr);
    //assign inst = !rst_n ? 0 : pmem_read(pc);
    always @(posedge clk) begin
        if (!rst_n)  inst = 0;
        else         inst = pmem_read(pc);
    end

endmodule
