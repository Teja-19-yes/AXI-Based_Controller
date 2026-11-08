module boot_sequencer (
    input  wire        ACLK,
    input  wire        ARESETN,
    output wire [3:0]  rom_addr,
    input  wire [37:0] rom_data,
    output wire        cmd_start,
    output wire        cmd_rw,
    output wire [31:0] cmd_addr,
    output wire [31:0] cmd_wdata,
    output wire [3:0]  cmd_wstrb,
    input  wire        cmd_done,
    input  wire [1:0]  cmd_resp,
    output wire        boot_done,
    output wire        boot_error
);
    wire s_fetch, s_issue, s_wait, s_next, s_fin, err;
 
    wire idle   = ~(s_fetch | s_issue | s_wait | s_next | s_fin);
    wire last   = rom_data[37];
    wire go_on  = s_next & ~last;
    wire finish = s_next &  last;
 
    dff_reg #(1) f_fetch (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(idle | go_on),                  .q(s_fetch));
    dff_reg #(1) f_issue (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(s_fetch),                       .q(s_issue));
    dff_reg #(1) f_wait  (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(s_issue | (s_wait & ~cmd_done)), .q(s_wait));
    dff_reg #(1) f_next  (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(s_wait & cmd_done),             .q(s_next));
    dff_reg #(1) f_fin   (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(s_fin | finish),                .q(s_fin));
    dff_reg #(1) f_err   (.clk(ACLK), .rstn(ARESETN), .en(1'b1), .d(err | (s_next & (|cmd_resp))),  .q(err));
 
    // ROM address counter
    wire [3:0] addr_q, addr_inc;
    incr    #(4) u_inc  (.a(addr_q), .y(addr_inc));
    dff_reg #(4) r_addr (.clk(ACLK), .rstn(ARESETN), .en(go_on), .d(addr_inc), .q(addr_q));
    assign rom_addr = addr_q;
 
    // command fields from the ROM word
    wire [15:0] base16;
    mux4 #(16) u_base (.s(rom_data[35:34]), .d0(16'h4000), .d1(16'h4001), .d2(16'h4002), .d3(16'h4003), .y(base16));
 
    assign cmd_start = s_issue;
    assign cmd_rw    = rom_data[36];
    assign cmd_addr  = {base16, 12'h000, rom_data[33:32], 2'b00};
    assign cmd_wdata = rom_data[31:0];
    assign cmd_wstrb = 4'hF;
 
    assign boot_done  = s_fin;
    assign boot_error = err;
endmodule
 
