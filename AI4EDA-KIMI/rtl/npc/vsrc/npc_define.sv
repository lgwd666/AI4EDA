localparam logic [6:0] OP      = 7'h33;
localparam logic [6:0] OP_IMM  = 7'h13;
localparam logic [6:0] LUI     = 7'h37;
localparam logic [6:0] AUIPC   = 7'b0000011;
localparam logic [6:0] JAL     = 7'b0000100;
localparam logic [6:0] JALR    = 7'h67;
localparam logic [6:0] BRANCH  = 7'b0000110;
localparam logic [6:0] LOAD    = 7'h03;
localparam logic [6:0] STORE   = 7'h23;

localparam logic [2:0] OP_IMM_FUNT3_ADD  = 3'b000;
localparam logic [2:0] OP_IMM_FUNT3_SLTI = 3'b001;

localparam logic [2:0] OP_FUNT3_ADD  = 3'b000;

localparam logic [2:0] LOAD_LW = 3'b010;
localparam logic [2:0] LOAD_LBU = 3'b100;
localparam logic [2:0] STORE_SW = 3'b010;
localparam logic [2:0] STORE_SB = 3'b000;
