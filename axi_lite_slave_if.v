module axi_lite_slave_if (
    input  wire        ACLK,
    input  wire        ARESETN,
 
    input  wire [31:0] S_AWADDR,
    input  wire        S_AWVALID,
    output wire        S_AWREADY,
    input  wire [31:0] S_WDATA,
    input  wire [3:0]  S_WSTRB,
    input  wire        S_WVALID,
    output wire        S_WREADY,
    output wire [1:0]  S_BRESP,
    output wire        S_BVALID,
    input  wire        S_BREADY,
    input  wire [31:0] S_ARADDR,
    input  wire        S_ARVALID,
    output wire        S_ARREADY,
    output wire [31:0] S_RDATA,
    output wire [1:0]  S_RRESP,
    output wire        S_RVALID,
    input  wire        S_RREADY,
 
    // register side
    output wire        reg_wr,
    output wire [1:0]  reg_widx,
    output wire        reg_wrange,
    output wire [31:0] reg_wdata,
    output wire [3:0]  reg_wstrb,
    input  wire        reg_werr,
    output wire [1:0]  reg_ridx,
    input  wire [31:0] reg_rdata,
    input  wire        reg_rerr
);
 
    // ------------------------- write path -------------------------
    wire aw_got, w_got, aw_range;
    wire [1:0] aw_idx;
 
    assign S_AWREADY = ~aw_got & ~S_BVALID;
    assign S_WREADY  = ~w_got  & ~S_BVALID;
 
    wire aw_hs     = S_AWVALID & S_AWREADY;
    wire w_hs      = S_WVALID  & S_WREADY;
    wire do_write  = aw_got & w_got & ~S_BVALID;
 
    dff_reg #(1) r_awg (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(aw_hs | (aw_got & ~do_write)), .q(aw_got));
    dff_reg #(1) r_wg  (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(w_hs  | (w_got  & ~do_write)), .q(w_got));
 
    dff_reg #(2) r_awidx (.clk(ACLK), .rstn(ARESETN), .en(aw_hs), .d(S_AWADDR[3:2]),     .q(aw_idx));
    dff_reg #(1) r_awrng (.clk(ACLK), .rstn(ARESETN), .en(aw_hs), .d(~|S_AWADDR[15:4]),  .q(aw_range));
    dff_reg #(32) r_wd   (.clk(ACLK), .rstn(ARESETN), .en(w_hs),  .d(S_WDATA),           .q(reg_wdata));
    dff_reg #(4)  r_ws   (.clk(ACLK), .rstn(ARESETN), .en(w_hs),  .d(S_WSTRB),           .q(reg_wstrb));
 
    assign reg_wr     = do_write;
    assign reg_widx   = aw_idx;
    assign reg_wrange = aw_range;
 
    dff_reg #(1) r_bv (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(do_write | (S_BVALID & ~S_BREADY)), .q(S_BVALID));
    dff_reg #(2) r_br (.clk(ACLK), .rstn(ARESETN), .en(do_write), .d({~aw_range | reg_werr, 1'b0}), .q(S_BRESP));
 
    // ------------------------- read path -------------------------
    assign S_ARREADY = ~S_RVALID;
 
    wire ar_hs   = S_ARVALID & S_ARREADY;
    wire rrange  = ~|S_ARADDR[15:4];
    assign reg_ridx = S_ARADDR[3:2];
 
    dff_reg #(1)  r_rv (.clk(ACLK), .rstn(ARESETN), .en(1'b1),  .d(ar_hs | (S_RVALID & ~S_RREADY)), .q(S_RVALID));
    dff_reg #(32) r_rd (.clk(ACLK), .rstn(ARESETN), .en(ar_hs), .d(reg_rdata & {32{rrange & ~reg_rerr}}), .q(S_RDATA));
    dff_reg #(2)  r_rr (.clk(ACLK), .rstn(ARESETN), .en(ar_hs), .d({~rrange | reg_rerr, 1'b0}), .q(S_RRESP));
 
endmodule
 
