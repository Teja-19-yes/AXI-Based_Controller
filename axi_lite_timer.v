module axi_lite_timer #(
    parameter ADDR_W = 32
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
    output wire              timer_irq
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
 
    assign reg_werr = reg_widx[1] & ~reg_widx[0];         // COUNT (idx 2) is read-only
 
    wire [3:0] wsel;
    dec2 u_dec (.en(reg_wr & reg_wrange), .a(reg_widx), .y(wsel));
 
    // ---------------- CTRL register bits ----------------
    wire ctrl_en, ctrl_auto, ctrl_ie;
    wire eq, match;
    wire match_event = ctrl_en & eq;
    wire hw_clr      = match_event & ~ctrl_auto;          // one-shot: EN clears itself
    wire wr_ctrl     = wsel[0] & reg_wstrb[0];
 
    wire en_pre;
    mux2 #(1) u_enmux (.s(wr_ctrl), .d0(ctrl_en), .d1(reg_wdata[0]), .y(en_pre));
    dff_reg #(1) u_en   (.clk(ACLK), .rstn(ARESETN), .en(1'b1),    .d(en_pre & ~hw_clr), .q(ctrl_en));
    dff_reg #(1) u_auto (.clk(ACLK), .rstn(ARESETN), .en(wr_ctrl), .d(reg_wdata[1]),     .q(ctrl_auto));
    dff_reg #(1) u_ie   (.clk(ACLK), .rstn(ARESETN), .en(wr_ctrl), .d(reg_wdata[2]),     .q(ctrl_ie));
 
    // ---------------- COMPARE register and counter ----------------
    wire [31:0] compare, count, count_inc, cnt_eq, cnt_run;
    reg32_strb u_cmp (.clk(ACLK), .rstn(ARESETN), .we(wsel[1]), .strb(reg_wstrb), .d(reg_wdata), .q(compare));
    comp_eq #(32) u_eq  (.a(count), .b(compare), .eq(eq));
    incr    #(32) u_inc (.a(count), .y(count_inc));
    mux2    #(32) u_m1  (.s(ctrl_auto), .d0(count),     .d1(32'h0), .y(cnt_eq));    // at match: reload or hold
    mux2    #(32) u_m2  (.s(eq),        .d0(count_inc), .d1(cnt_eq), .y(cnt_run));  // otherwise count up
    dff_reg #(32) u_cnt (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(cnt_run & {32{ctrl_en}}), .q(count));
 
    // ---------------- MATCH flag (write-1-to-clear) ----------------
    wire match_clr = wsel[3] & reg_wstrb[0] & reg_wdata[0];
    flag_reg #(1) u_match (.clk(ACLK), .rstn(ARESETN), .set(match_event), .clr(match_clr), .q(match));
 
    assign timer_irq = ctrl_ie & match;
 
    mux4 #(32) u_rmux (.s(reg_ridx),
                       .d0({29'h0, ctrl_ie, ctrl_auto, ctrl_en}),
                       .d1(compare), .d2(count), .d3({31'h0, match}), .y(reg_rdata));
 
endmodule
 
