`timescale 1ns/1ps

module tb_fpga_noc64_axi_smoke;
  localparam integer AW = 16;
  localparam [AW-1:0] REG_CTRL = 16'h0000;
  localparam [AW-1:0] REG_STATUS = 16'h0004;
  localparam [AW-1:0] REG_DELIVERED = 16'h0018;
  localparam [AW-1:0] REG_RX_COUNT_BASE = 16'h0140;
  localparam [AW-1:0] REG_TX_COUNT_BASE = 16'h0040;
  localparam [AW-1:0] TX_BASE = 16'h1000;

  reg clock = 0;
  reg resetn = 0;
  reg [AW-1:0] awaddr = 0;
  reg awvalid = 0;
  wire awready;
  reg [31:0] wdata = 0;
  reg [3:0] wstrb = 4'hf;
  reg wvalid = 0;
  wire wready;
  wire [1:0] bresp;
  wire bvalid;
  reg bready = 1;
  reg [AW-1:0] araddr = 0;
  reg arvalid = 0;
  wire arready;
  wire [31:0] rdata;
  wire [1:0] rresp;
  wire rvalid;
  reg rready = 1;
  wire irq;
  reg [31:0] status, delivered, rx1;
  integer polls;

  always #10 clock = ~clock;

  fpga_noc64_axi_wrapper dut (
    .s_axi_aclk(clock), .s_axi_aresetn(resetn),
    .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
    .irq(irq)
  );

  task automatic axi_write(input [AW-1:0] address, input [31:0] data);
    begin
      @(posedge clock);
      awaddr <= address; awvalid <= 1;
      wdata <= data; wvalid <= 1;
      while (!(awready && wready)) @(posedge clock);
      @(posedge clock);
      awvalid <= 0; wvalid <= 0;
      while (!bvalid) @(posedge clock);
      if (bresp != 2'b00) $fatal(1, "AXI write error at %h", address);
    end
  endtask

  task automatic axi_read(input [AW-1:0] address, output [31:0] data);
    begin
      @(posedge clock);
      araddr <= address; arvalid <= 1;
      while (!arready) @(posedge clock);
      @(posedge clock);
      arvalid <= 0;
      while (!rvalid) @(posedge clock);
      if (rresp != 2'b00) $fatal(1, "AXI read error at %h", address);
      data = rdata;
    end
  endtask

  task automatic write_descriptor(input integer entry, input integer issue_cycle, input [27:0] flit);
    reg [AW-1:0] low_addr;
    begin
      low_addr = TX_BASE + entry * 8;
      axi_write(low_addr, {4'd0, flit});
      // high word: [23:0] issue cycle, valid bit at bit 24
      axi_write(low_addr + 4, {7'd0, 1'b1, issue_cycle[23:0]});
    end
  endtask

  initial begin
    repeat (10) @(posedge clock);
    resetn = 1;

    // 0 -> 1, one three-flit packet.  This is the directed NoC64 smoke
    // packet from noc64_00_to_10_3flit.case.
    write_descriptor(0, 0, 28'h8004004);
    write_descriptor(1, 1, 28'h0004004);
    write_descriptor(2, 2, 28'h4004004);
    axi_write(REG_TX_COUNT_BASE, 3);
    axi_write(REG_CTRL, 1);

    polls = 0;
    status = 0;
    while ((status[1] == 0) && polls < 200000) begin
      axi_read(REG_STATUS, status);
      polls = polls + 1;
    end
    if (!status[1] || status[2] || status[3]) $fatal(1, "run did not complete cleanly: %h", status);
    axi_read(REG_DELIVERED, delivered);
    axi_read(REG_RX_COUNT_BASE + 4, rx1);
    if (delivered != 3 || rx1 != 3) $fatal(1, "delivery mismatch delivered=%0d rx1=%0d", delivered, rx1);
    $display("FPGA_NOC64_AXI_SMOKE PASS delivered=%0d rx1=%0d polls=%0d", delivered, rx1, polls);
    $finish;
  end
endmodule
