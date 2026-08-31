`timescale 1ns/1ps

module tb_rcu_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg Reqin = 1'b0;
  reg Ackout = 1'b0;
  reg [27:0] Datain = 28'b0;
  reg [3:0] TailPassed = 4'b0;
  wire [3:0] RouteSel;
  wire [3:0] PathEnabled;

  RCU dut (
    .clock(clock), .reset(reset),
    .io_Reqin(Reqin), .io_Ackout(Ackout), .io_Datain_flit(Datain),
    .io_TailPassed_0(TailPassed[0]), .io_TailPassed_1(TailPassed[1]),
    .io_TailPassed_2(TailPassed[2]), .io_TailPassed_3(TailPassed[3]),
    .io_RouteSel_0(RouteSel[0]), .io_RouteSel_1(RouteSel[1]),
    .io_RouteSel_2(RouteSel[2]), .io_RouteSel_3(RouteSel[3]),
    .io_PathEnabled_0(PathEnabled[0]), .io_PathEnabled_1(PathEnabled[1]),
    .io_PathEnabled_2(PathEnabled[2]), .io_PathEnabled_3(PathEnabled[3])
  );

  always #5 clock = ~clock;

  task automatic fail(input [8*180-1:0] message);
    begin
      $display("TB_RESULT FAIL %0s at %0t", message, $time);
      $display(" Reqin=%b Ackout=%b Datain=%h RouteSel=%b PathEnabled=%b TailPassed=%b",
        Reqin, Ackout, Datain, RouteSel, PathEnabled, TailPassed);
      $finish(1);
    end
  endtask

  task automatic check(input condition, input [8*180-1:0] message);
    begin if (!condition) fail(message); end
  endtask

  task automatic set_flit(
    input Head, input Tail,
    input [5:0] x0, input [5:0] y0,
    input [5:0] x1, input [5:0] y1
  );
    begin
      Datain = 28'b0;
      Datain[27] = Head;
      Datain[26] = Tail;
      Datain[7:2] = x0; Datain[13:8] = y0;
      Datain[19:14] = x1; Datain[25:20] = y1;
    end
  endtask

  task automatic launch_head(
    input [5:0] x0, input [5:0] y0,
    input [5:0] x1, input [5:0] y1,
    input [3:0] expected_path
  );
    begin
      set_flit(1'b1, 1'b0, x0, y0, x1, y1);
      Reqin = ~Reqin;
      // Req_rc first crosses the dedicated two-stage AddressRegister control
      // guard (0.4 ns in this functional model), then RouteSel crosses the
      // four-stage RCU matched delay and its InternalAck return traversal.
      // Wait beyond the complete bundled-data/control round trip.
      #3.0;
      check(PathEnabled === expected_path, "Head selected wrong quadtree path set");
      check(RouteSel === 4'b0000, "Internal Ack did not close RouteSel pulse");
      Ackout = Reqin;
      #0.4;
    end
  endtask

  task automatic complete_body;
    begin
      Reqin = ~Reqin;
      #0.2;
      Ackout = Reqin;
      #0.4;
    end
  endtask

  initial begin
    #1.0;
    reset = 1'b0;
    #1.0;
    check(RouteSel === 4'b0000 && PathEnabled === 4'b0000,
      "RCU reset state mismatch");

    // L1 router (0,0), parent ingress. Destination (0,0) maps to child 3.
    launch_head(0, 0, 0, 0, 4'b1000);

    // Address Register is closed after Head Ackout. Body addresses are ignored.
    set_flit(1'b0, 1'b0, 1, 0, 1, 0);
    complete_body;
    check(PathEnabled === 4'b1000 && RouteSel === 4'b0000,
      "Body changed packet-lifetime route state");

    // TailPassed releases the selected OPM before Tail Ackout reopens the
    // Address Register for the next packet.
    set_flit(1'b0, 1'b1, 2, 2, 3, 3);
    Reqin = ~Reqin;
    #0.2;
    TailPassed = 4'b1000;
    #0.3;
    check(PathEnabled === 4'b0000, "TailPassed did not reset selected SR Latch");
    Ackout = Reqin;
    #0.4;
    TailPassed = 4'b0000;
    #1.0;
    check(PathEnabled === 4'b0000 && RouteSel === 4'b0000,
      "Tail completion replayed the old route while input was idle");

    // The reopened register captures a different route on the next Head.
    launch_head(1, 0, 1, 0, 4'b0010);
    set_flit(1'b0, 1'b1, 0, 0, 0, 0);
    Reqin = ~Reqin;
    #0.2;
    TailPassed = 4'b0010;
    #0.3;
    Ackout = Reqin;
    #0.4;
    TailPassed = 4'b0000;

    // Rectangle (0,0)-(1,1) reaches all four L1 children concurrently.
    launch_head(0, 0, 1, 1, 4'b1111);
    check(PathEnabled === 4'b1111, "multicast Head did not set all selected paths");

    // Each TailPassed independently clears only its corresponding selector.
    TailPassed = 4'b0101;
    #0.3;
    check(PathEnabled === 4'b1010, "OPM Selector did not independently clear paths");
    TailPassed = 4'b1111;
    #0.3;
    check(PathEnabled === 4'b0000, "OPM Selector retained completed path");

    check((^RouteSel !== 1'bx) && (^PathEnabled !== 1'bx),
      "X/Z leaked to stable RCU outputs");
    $display("TB_RESULT PASS CMR Fig6 AddressRegister/RouteComputation/OPMSelector smoke");
    $finish;
  end
endmodule
