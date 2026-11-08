module axi_lite_regs #(
    parameter ADDR_W = 32,
    parameter [31:0] ID_VALUE = 32'h4158_4C31
)(
    input  wire              ACLK,
    input  wire              ARESETN,
    input  wire [ADDR_W-1:0] S_AWADDR,
    input  wire              S_AWVALID,
    output wire              S_AWREADY,
    input  wire [31:0]       S_WDATA,
    input  wire [3:0]        S_WSTRB,
    input  wire              S_WVALID,
    output wire              S_WREADY,
    output wire [1:0]        S_BRESP,
    output wire              S_BVALID,
    input  wire              S_BREADY,
    input  wire [ADDR_W-1:0] S_ARADDR,
    input  wire              S_ARVALID,
    output wire              S_ARREADY,
    output wire [31:0]       S_RDATA,
    output wire [1:0]        S_RRESP,
    output wire              S_RVALID,
    input  wire              S_RREADY,
    output wire [31:0]       ctrl_out,
    output wire [31:0]       data_out,
    input  wire [31:0]       status_set
);
 
    wire        reg_wr, reg_wrange, reg_werr;
    wire [1:0]  reg_widx, reg_ridx;
    wire [31:0] reg_wdata, reg_rdata;
    wire [3:0]  reg_wstrb;
 
    axi_lite_slave_if sif (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_AWADDR(S_AWADDR), .S_AWVALID(S_AWVALID), .S_AWREADY(S_AWREADY),
        .S_WDATA(S_WDATA), .S_WSTRB(S_WSTRB), .S_WVALID(S_WVALID), .S_WREADY(S_WREADY),
        .S_BRESP(S_BRESP), .S_BVALID(S_BVALID), .S_BREADY(S_BREADY),
        .S_ARADDR(S_ARADDR), .S_ARVALID(S_ARVALID), .S_ARREADY(S_ARREADY),
        .S_RDATA(S_RDATA), .S_RRESP(S_RRESP), .S_RVALID(S_RVALID), .S_RREADY(S_RREADY),
        .reg_wr(reg_wr), .reg_widx(reg_widx), .reg_wrange(reg_wrange),
        .reg_wdata(reg_wdata), .reg_wstrb(reg_wstrb), .reg_werr(reg_werr),
        .reg_ridx(reg_ridx), .reg_rdata(reg_rdata), .reg_rerr(1'b0)
    );
 
    assign reg_werr = reg_widx[1] & reg_widx[0];          // ID register is read-only
 
    wire [3:0] wsel;
    dec2 u_dec (.en(reg_wr & reg_wrange), .a(reg_widx), .y(wsel));
 
    wire [31:0] ctrl, status, data;
    reg32_strb u_ctrl (.clk(ACLK), .rstn(ARESETN), .we(wsel[0]), .strb(reg_wstrb), .d(reg_wdata), .q(ctrl));
    reg32_strb u_data (.clk(ACLK), .rstn(ARESETN), .we(wsel[2]), .strb(reg_wstrb), .d(reg_wdata), .q(data));
 
    wire [31:0] bytemask   = {{8{reg_wstrb[3]}}, {8{reg_wstrb[2]}}, {8{reg_wstrb[1]}}, {8{reg_wstrb[0]}}};
    wire [31:0] status_clr = reg_wdata & bytemask & {32{wsel[1]}};
    flag_reg #(32) u_status (.clk(ACLK), .rstn(ARESETN), .set(status_set), .clr(status_clr), .q(status));
 
    mux4 #(32) u_rmux (.s(reg_ridx), .d0(ctrl), .d1(status), .d2(data), .d3(ID_VALUE), .y(reg_rdata));
 
    assign ctrl_out = ctrl;
    assign data_out = data;
 
endmodule
 
