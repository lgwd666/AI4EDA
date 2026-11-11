module dff_pn #(
    parameter integer WIDTH = 1,
    parameter logic [WIDTH-1:0] RESET_VALUE = {WIDTH{1'b0}}
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= RESET_VALUE;
        end else begin
            q <= d;
        end
    end
endmodule
