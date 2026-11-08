module axi_lite_gpio #(
    parameter ADDR_W = 32,
    parameter GPIO_W = 8
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
    input  wire [GPIO_W-1:0] gpio_in,
    output wire [GPIO_W-1:0] gpio_out,
    output wire [GPIO_W-1:0] gpio_oe
);
 
    wire        reg_wr, reg_wrange, reg_werr, reg_rerr;
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
        .reg_ridx(reg_ridx), .reg_rdata(reg_rdata), .reg_rerr(reg_rerr)
    );
 
    assign reg_werr = reg_widx[1];                        // idx 2 (IN) and 3 (reserved)
    assign reg_rerr = reg_ridx[1] & reg_ridx[0];          // idx 3 (reserved)
 
    wire [3:0] wsel;
    dec2 u_dec (.en(reg_wr & reg_wrange), .a(reg_widx), .y(wsel));
 
    wire [31:0] dir32, out32;
    reg32_strb u_dir (.clk(ACLK), .rstn(ARESETN), .we(wsel[0]), .strb(reg_wstrb), .d(reg_wdata), .q(dir32));
    reg32_strb u_out (.clk(ACLK), .rstn(ARESETN), .we(wsel[1]), .strb(reg_wstrb), .d(reg_wdata), .q(out32));
 
    wire [GPIO_W-1:0] in_s1, in_s2;
    dff_reg #(GPIO_W) u_s1 (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(gpio_in), .q(in_s1));
    dff_reg #(GPIO_W) u_s2 (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(in_s1),   .q(in_s2));
 
    wire [31:0] in_ext = {{(32-GPIO_W){1'b0}}, in_s2};
    mux4 #(32) u_rmux (.s(reg_ridx), .d0(dir32), .d1(out32), .d2(in_ext), .d3(32'h0), .y(reg_rdata));
 
    assign gpio_oe  = dir32[GPIO_W-1:0];
    assign gpio_out = out32[GPIO_W-1:0];
 
endmodule
 
