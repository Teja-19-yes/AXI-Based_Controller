module axi_lite_master #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32
)(
    input  wire                     ACLK,
    input  wire                     ARESETN,
 
    input  wire                     start,
    input  wire                     rw,
    input  wire [ADDR_W-1:0]        addr,
    input  wire [DATA_W-1:0]        wdata,
    input  wire [DATA_W/8-1:0]      wstrb,
    output wire                     busy,
    output wire                     done,
    output wire [DATA_W-1:0]        rdata,
    output wire [1:0]               resp,
 
    output wire [ADDR_W-1:0]        M_AWADDR,
    output wire [2:0]               M_AWPROT,
    output wire                     M_AWVALID,
    input  wire                     M_AWREADY,
    output wire [DATA_W-1:0]        M_WDATA,
    output wire [DATA_W/8-1:0]      M_WSTRB,
    output wire                     M_WVALID,
    input  wire                     M_WREADY,
    input  wire [1:0]               M_BRESP,
    input  wire                     M_BVALID,
    output wire                     M_BREADY,
    output wire [ADDR_W-1:0]        M_ARADDR,
    output wire [2:0]               M_ARPROT,
    output wire                     M_ARVALID,
    input  wire                     M_ARREADY,
    input  wire [DATA_W-1:0]        M_RDATA,
    input  wire [1:0]               M_RRESP,
    input  wire                     M_RVALID,
    output wire                     M_RREADY
);
 
    assign M_AWPROT = 3'b000;
    assign M_ARPROT = 3'b000;
 
    // ---------------- control equations ----------------
    wire s_write, s_wresp, s_raddr, s_rdata, s_done;
 
    wire idle    = ~(s_write | s_wresp | s_raddr | s_rdata | s_done);
    assign busy  = ~idle;
 
    wire start_w = idle & start &  rw;
    wire start_r = idle & start & ~rw;
 
    wire aw_fin     = ~M_AWVALID | M_AWREADY;
    wire w_fin      = ~M_WVALID  | M_WREADY;
    wire write_fin  = s_write & aw_fin & w_fin;
    wire b_hs       = s_wresp & M_BVALID & M_BREADY;
    wire ar_hs      = s_raddr & M_ARVALID & M_ARREADY;
    wire r_hs       = s_rdata & M_RVALID & M_RREADY;
 
    // ---------------- state flip-flops ----------------
    dff_reg #(1) f_write (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(start_w | (s_write & ~write_fin)), .q(s_write));
    dff_reg #(1) f_wresp (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(write_fin | (s_wresp & ~b_hs)),    .q(s_wresp));
    dff_reg #(1) f_raddr (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(start_r | (s_raddr & ~ar_hs)),     .q(s_raddr));
    dff_reg #(1) f_rdata (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(ar_hs | (s_rdata & ~r_hs)),        .q(s_rdata));
    dff_reg #(1) f_done  (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(b_hs | r_hs),                      .q(s_done));
    dff_reg #(1) f_pulse (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(s_done),                           .q(done));
 
    // ---------------- write channels ----------------
    dff_reg #(ADDR_W)   r_awaddr (.clk(ACLK), .rstn(ARESETN), .en(start_w), .d(addr),  .q(M_AWADDR));
    dff_reg #(DATA_W)   r_wdata  (.clk(ACLK), .rstn(ARESETN), .en(start_w), .d(wdata), .q(M_WDATA));
    dff_reg #(DATA_W/8) r_wstrb  (.clk(ACLK), .rstn(ARESETN), .en(start_w), .d(wstrb), .q(M_WSTRB));
    dff_reg #(1) f_awvalid (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(start_w | (M_AWVALID & ~M_AWREADY)), .q(M_AWVALID));
    dff_reg #(1) f_wvalid  (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(start_w | (M_WVALID  & ~M_WREADY)),  .q(M_WVALID));
    dff_reg #(1) f_bready  (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(write_fin | (M_BREADY & ~M_BVALID)), .q(M_BREADY));
 
    // ---------------- read channels ----------------
    dff_reg #(ADDR_W) r_araddr (.clk(ACLK), .rstn(ARESETN), .en(start_r), .d(addr), .q(M_ARADDR));
    dff_reg #(1) f_arvalid (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(start_r | (M_ARVALID & ~M_ARREADY)), .q(M_ARVALID));
    dff_reg #(1) f_rready  (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(ar_hs   | (M_RREADY  & ~M_RVALID)),  .q(M_RREADY));
 
    // ---------------- results ----------------
    dff_reg #(DATA_W) r_rdata (.clk(ACLK), .rstn(ARESETN), .en(r_hs), .d(M_RDATA), .q(rdata));
 
    wire [1:0] resp_d;
    mux2 #(2) m_resp (.s(s_wresp), .d0(M_RRESP), .d1(M_BRESP), .y(resp_d));
    dff_reg #(2) r_resp (.clk(ACLK), .rstn(ARESETN), .en(b_hs | r_hs), .d(resp_d), .q(resp));
 
endmodule
 
