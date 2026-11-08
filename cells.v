module dff_reg #(parameter W = 1)(
    input  wire         clk,
    input  wire         rstn,
    input  wire         en,
    input  wire [W-1:0] d,
    output reg  [W-1:0] q
);
    always @(posedge clk) begin
        if (!rstn)    q <= {W{1'b0}};
        else if (en)  q <= d;
    end
endmodule
 
// 2-to-1 multiplexer
module mux2 #(parameter W = 1)(
    input  wire         s,
    input  wire [W-1:0] d0,
    input  wire [W-1:0] d1,
    output wire [W-1:0] y
);
    assign y = s ? d1 : d0;
endmodule
 
// 4-to-1 multiplexer built from three 2-to-1 multiplexers
module mux4 #(parameter W = 1)(
    input  wire [1:0]   s,
    input  wire [W-1:0] d0,
    input  wire [W-1:0] d1,
    input  wire [W-1:0] d2,
    input  wire [W-1:0] d3,
    output wire [W-1:0] y
);
    wire [W-1:0] lo, hi;
    mux2 #(W) m_lo  (.s(s[0]), .d0(d0), .d1(d1), .y(lo));
    mux2 #(W) m_hi  (.s(s[0]), .d0(d2), .d1(d3), .y(hi));
    mux2 #(W) m_out (.s(s[1]), .d0(lo), .d1(hi), .y(y));
endmodule
 
// equality comparator
module comp_eq #(parameter W = 1)(
    input  wire [W-1:0] a,
    input  wire [W-1:0] b,
    output wire         eq
);
    assign eq = (a == b);
endmodule
 
// incrementer (y = a + 1)
module incr #(parameter W = 2)(
    input  wire [W-1:0] a,
    output wire [W-1:0] y
);
    assign y = a + {{(W-1){1'b0}}, 1'b1};
endmodule
 
// 2-to-4 decoder with enable
module dec2 (
    input  wire       en,
    input  wire [1:0] a,
    output wire [3:0] y
);
    assign y[0] = en & ~a[1] & ~a[0];
    assign y[1] = en & ~a[1] &  a[0];
    assign y[2] = en &  a[1] & ~a[0];
    assign y[3] = en &  a[1] &  a[0];
endmodule
 
// 32-bit register with one write-enable per byte (honours WSTRB)
module reg32_strb (
    input  wire        clk,
    input  wire        rstn,
    input  wire        we,
    input  wire [3:0]  strb,
    input  wire [31:0] d,
    output wire [31:0] q
);
    dff_reg #(8) b0 (.clk(clk), .rstn(rstn), .en(we & strb[0]), .d(d[7:0]),   .q(q[7:0]));
    dff_reg #(8) b1 (.clk(clk), .rstn(rstn), .en(we & strb[1]), .d(d[15:8]),  .q(q[15:8]));
    dff_reg #(8) b2 (.clk(clk), .rstn(rstn), .en(we & strb[2]), .d(d[23:16]), .q(q[23:16]));
    dff_reg #(8) b3 (.clk(clk), .rstn(rstn), .en(we & strb[3]), .d(d[31:24]), .q(q[31:24]));
endmodule
 
// set / write-1-to-clear flag register (set wins over clear)
module flag_reg #(parameter W = 1)(
    input  wire         clk,
    input  wire         rstn,
    input  wire [W-1:0] set,
    input  wire [W-1:0] clr,
    output wire [W-1:0] q
);
    wire [W-1:0] nxt = (q & ~clr) | set;
    dff_reg #(W) r (.clk(clk), .rstn(rstn), .en(1'b1), .d(nxt), .q(q));
endmodule
 
