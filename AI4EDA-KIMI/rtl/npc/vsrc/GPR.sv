module GPR (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [4: 0] rs1,
    input  logic [4: 0] rs2,
    input  logic [4: 0] rd,
    input  logic        rd_wen,
    input  logic [31:0] rd_wdata,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data
);

    logic [31:0] xreg_pre [31:0];
    logic [31:0] xreg     [31:0];

    genvar i ;
    generate
        for(i=0;i<32;i++) begin
            assign xreg_pre[i] = i==0 ? 32'b0 : rd_wen&(rd==i) ? rd_wdata : xreg[i];
            dff_pn #(32, 0) u_xreg (.clk(clk), .rst_n(rst_n), .d(xreg_pre[i]), .q(xreg[i]));
        end
    endgenerate

    assign rs1_data = xreg[rs1];
    assign rs2_data = xreg[rs2];

    

endmodule
