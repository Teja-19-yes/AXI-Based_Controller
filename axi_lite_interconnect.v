module axi_lite_interconnect #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32,
    parameter [31:0] BASE0 = 32'h4000_0000,
    parameter [31:0] BASE1 = 32'h4001_0000,
    parameter [31:0] BASE2 = 32'h4002_0000
)(
    input  wire                 ACLK,
    input  wire                 ARESETN,
 
    input  wire [ADDR_W-1:0]    M_AWADDR,
    input  wire                 M_AWVALID,
    output wire                 M_AWREADY,
    input  wire [DATA_W-1:0]    M_WDATA,
    input  wire [DATA_W/8-1:0]  M_WSTRB,
    input  wire                 M_WVALID,
    output wire                 M_WREADY,
    output wire [1:0]           M_BRESP,
    output wire                 M_BVALID,
    input  wire                 M_BREADY,
    input  wire [ADDR_W-1:0]    M_ARADDR,
    input  wire                 M_ARVALID,
    output wire                 M_ARREADY,
    output wire [DATA_W-1:0]    M_RDATA,
    output wire [1:0]           M_RRESP,
    output wire                 M_RVALID,
    input  wire                 M_RREADY,
 
    output wire [ADDR_W-1:0]    S_AWADDR,
    output wire [2:0]           S_AWVALID,
    input  wire [2:0]           S_AWREADY,
    output wire [DATA_W-1:0]    S_WDATA,
    output wire [DATA_W/8-1:0]  S_WSTRB,
    output wire [2:0]           S_WVALID,
    input  wire [2:0]           S_WREADY,
    input  wire [5:0]           S_BRESP,
    input  wire [2:0]           S_BVALID,
    output wire [2:0]           S_BREADY,
    output wire [ADDR_W-1:0]    S_ARADDR,
    output wire [2:0]           S_ARVALID,
    input  wire [2:0]           S_ARREADY,
    input  wire [3*DATA_W-1:0]  S_RDATA,
    input  wire [5:0]           S_RRESP,
    input  wire [2:0]           S_RVALID,
    output wire [2:0]           S_RREADY
);
 
    // broadcast channels
    assign S_AWADDR = M_AWADDR;
    assign S_WDATA  = M_WDATA;
    assign S_WSTRB  = M_WSTRB;
    assign S_ARADDR = M_ARADDR;
 
    // ---------------- address decoders (three comparators per channel) ----------------
    wire [2:0] aw_hit, ar_hit;
    comp_eq #(16) u_aw0 (.a(M_AWADDR[31:16]), .b(BASE0[31:16]), .eq(aw_hit[0]));
    comp_eq #(16) u_aw1 (.a(M_AWADDR[31:16]), .b(BASE1[31:16]), .eq(aw_hit[1]));
    comp_eq #(16) u_aw2 (.a(M_AWADDR[31:16]), .b(BASE2[31:16]), .eq(aw_hit[2]));
    comp_eq #(16) u_ar0 (.a(M_ARADDR[31:16]), .b(BASE0[31:16]), .eq(ar_hit[0]));
    comp_eq #(16) u_ar1 (.a(M_ARADDR[31:16]), .b(BASE1[31:16]), .eq(ar_hit[1]));
    comp_eq #(16) u_ar2 (.a(M_ARADDR[31:16]), .b(BASE2[31:16]), .eq(ar_hit[2]));
    wire aw_none = ~|aw_hit;
    wire ar_none = ~|ar_hit;
 
    // =========================== write path ===========================
    wire       w_data, w_resp;
    wire [2:0] wr_oh;
    wire       w_idle  = ~w_data & ~w_resp;
    wire       wr_err  = ~|wr_oh;
 
    assign S_AWVALID = aw_hit & {3{M_AWVALID & w_idle}};
    assign M_AWREADY = w_idle & M_AWVALID & (aw_none | (|(aw_hit & S_AWREADY)));
    wire   aw_hs     = M_AWVALID & M_AWREADY;
 
    assign S_WVALID  = wr_oh & {3{w_data & M_WVALID}};
    assign M_WREADY  = w_data & (wr_err | (|(wr_oh & S_WREADY)));
    wire   w_hs      = M_WVALID & M_WREADY;
 
    assign S_BREADY  = wr_oh & {3{w_resp & M_BREADY}};
    assign M_BVALID  = w_resp & (wr_err | (|(wr_oh & S_BVALID)));
    wire [1:0] bresp_mux = ({2{wr_oh[0]}} & S_BRESP[1:0]) |
                           ({2{wr_oh[1]}} & S_BRESP[3:2]) |
                           ({2{wr_oh[2]}} & S_BRESP[5:4]);
    assign M_BRESP   = ({2{w_resp & wr_err}}) | ({2{w_resp}} & bresp_mux);   // 11 = DECERR
    wire   b_hs      = M_BVALID & M_BREADY;
 
    dff_reg #(1) f_wdata (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(aw_hs | (w_data & ~w_hs)),          .q(w_data));
    dff_reg #(1) f_wresp (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(w_hs  | (w_resp & ~b_hs)),          .q(w_resp));
    dff_reg #(3) f_wsel  (.clk(ACLK), .rstn(ARESETN), .en(aw_hs), .d(aw_hit),                           .q(wr_oh));
 
    // =========================== read path ===========================
    wire       r_data;
    wire [2:0] rd_oh;
    wire       r_idle  = ~r_data;
    wire       rd_err  = ~|rd_oh;
 
    assign S_ARVALID = ar_hit & {3{M_ARVALID & r_idle}};
    assign M_ARREADY = r_idle & M_ARVALID & (ar_none | (|(ar_hit & S_ARREADY)));
    wire   ar_hs     = M_ARVALID & M_ARREADY;
 
    assign S_RREADY  = rd_oh & {3{r_data & M_RREADY}};
    assign M_RVALID  = r_data & (rd_err | (|(rd_oh & S_RVALID)));
    wire [DATA_W-1:0] rdata_mux = ({DATA_W{rd_oh[0]}} & S_RDATA[DATA_W-1:0]) |
                                  ({DATA_W{rd_oh[1]}} & S_RDATA[2*DATA_W-1:DATA_W]) |
                                  ({DATA_W{rd_oh[2]}} & S_RDATA[3*DATA_W-1:2*DATA_W]);
    assign M_RDATA   = {DATA_W{r_data}} & rdata_mux;
    wire [1:0] rresp_mux = ({2{rd_oh[0]}} & S_RRESP[1:0]) |
                           ({2{rd_oh[1]}} & S_RRESP[3:2]) |
                           ({2{rd_oh[2]}} & S_RRESP[5:4]);
    assign M_RRESP   = ({2{r_data & rd_err}}) | ({2{r_data}} & rresp_mux);   // 11 = DECERR
    wire   r_hs      = M_RVALID & M_RREADY;
 
    dff_reg #(1) f_rdata (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(ar_hs | (r_data & ~r_hs)), .q(r_data));
    dff_reg #(3) f_rsel  (.clk(ACLK), .rstn(ARESETN), .en(ar_hs), .d(ar_hit),                  .q(rd_oh));
 
endmodule
 
