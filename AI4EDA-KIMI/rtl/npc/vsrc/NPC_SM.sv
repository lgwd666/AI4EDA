module NPC_SM (
    input  logic        clk,
    input  logic        rst_n,
    output logic [2: 0] npc_state
);

    logic [2: 0] npc_state_pre;
    assign npc_state_pre = !rst_n ? IDLE : npc_state==IDLE ? WAIT : IDLE;
    dff_pn #(3,IDLE) u_npc_state_reg (.clk(clk), .rst_n(rst_n), .d(npc_state_pre), .q(npc_state));


endmodule
