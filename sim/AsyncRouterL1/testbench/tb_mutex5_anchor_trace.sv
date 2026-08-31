`timescale 1ns/1ps

// Simulation-only trace for TAC-A local contention; no DUT interface changes.
module tb_mutex5_anchor_trace;
  reg reset = 1'b1;
  reg [4:0] req = 5'b0;
  wire [4:0] grant;
  integer i;

  Mutex5Anchor dut(.reset(reset), .req(req), .grant(grant));

  task automatic snapshot;
    begin
      $display("M5_TRACE t=%0t req=%b grant=%b reqA/B/P=%b/%b/%b rootA/B/P=%b/%b/%b arboA=%b%b maskA=%b%b localA=%b%b x/y=%b%b%b/%b%b%b",
        $time, req, grant, dut.req_a, dut.req_b, req[4],
        dut.root_a, dut.root_b, dut.root_p,
        dut.arbo_a1, dut.arbo_a0, dut.masked_a1, dut.masked_a0,
        dut.local_a1, dut.local_a0,
        dut.root.x_a, dut.root.x_b, dut.root.x_p,
        dut.root.y_a, dut.root.y_b, dut.root.y_p);
    end
  endtask

  initial begin
    #2; reset = 0; #2; snapshot();
    req = 5'b00011;
    for (i = 0; i < 20; i = i + 1) begin #0.5; snapshot(); end
    $finish;
  end
endmodule
