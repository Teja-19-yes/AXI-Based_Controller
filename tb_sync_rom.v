`timescale 1ns/1ps
// Run: iverilog -o sim_rom sync_rom.v tb_sync_rom.v && vvp sim_rom
module tb_sync_rom;
`define NO_MASTER
`include "tb_common.vh"
 
    reg  [3:0]  raddr = 4'd0;
    wire [37:0] rdat;
 
    sync_rom dut (.clk(ACLK), .rstn(ARESETN), .addr(raddr), .data(rdat));
 
    // present an address, wait one clock, then check the registered output
    task chk(input [3:0] a, input [5:0] hi, input [31:0] lo);
    begin
        raddr = a;
        @(posedge ACLK); #1;
        expect_eq("rom word [37:32]       ", rdat[37:32], hi);
        expect_eq("rom word [31:0]        ", rdat[31:0],  lo);
    end
    endtask
 
    initial begin
        $dumpfile("sync_rom.vcd");
        $dumpvars(0, tb_sync_rom);
        reset_dut;
 
        chk(4'd0, 6'h14, 32'h0000_00FF);        // GPIO DIR = 0xFF
        // synchronous behaviour: a new address must NOT change the output before a clock edge
        raddr = 4'd1; #2;
        expect_eq("output holds before clk", rdat[31:0], 32'h0000_00FF);
        @(posedge ACLK); #1;
        expect_eq("word 1 after one clock ", rdat[31:0], 32'h0000_00A5);
 
        chk(4'd1, 6'h15, 32'h0000_00A5);        // GPIO OUT = 0xA5
        chk(4'd2, 6'h19, 32'h0000_0064);        // TIMER COMPARE = 100
        chk(4'd3, 6'h18, 32'h0000_0007);        // TIMER CTRL = 7
        chk(4'd4, 6'h10, 32'h0000_0001);        // REGS CTRL = 1
        chk(4'd5, 6'h03, 32'h0000_0000);        // read REGS ID
        chk(4'd6, 6'h24, 32'h0000_0000);        // read GPIO DIR, LAST = 1
        chk(4'd9, 6'h00, 32'h0000_0000);        // unused word
 
        summary;
        $finish;
    end
endmodule
 
