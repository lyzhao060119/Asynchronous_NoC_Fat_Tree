`timescale 1ns/1ps

module tb_phase_adapter_dff_toy;
  reg reset = 1'b1;
  reg [3:0] select = 4'b0, opm_ack = 4'b0;
  reg ipm_req = 1'b0;
  wire ipm_ack;
  wire [3:0] opm_req;
  integer failures = 0;
  reg [3:0] req_before;
  reg ack_before;

  LanePhaseAdapterDFF #(.LANES(4)) dut (
    .reset(reset), .LaneSelect(select), .IPMReqOut(ipm_req),
    .OPMAckOut(opm_ack), .IPMAckIn(ipm_ack), .OPMReqIn(opm_req)
  );
  task automatic check(input bit ok, input string text);
    if (!ok) begin
      failures++;
      $display("TB_RESULT FAIL %s t=%0t req=%b ack=%b opm_req=%b opm_ack=%b select=%b",
               text, $time, ipm_req, ipm_ack, opm_req, opm_ack, select);
    end
  endtask

  // A valid transaction keeps select[lane] asserted until physical Ack returns.
  task automatic one_transaction(input integer lane);
    begin
      select[lane] = 1'b1;
      #1;
      ack_before = ipm_ack;
      req_before = opm_req;
      ipm_req = ~ipm_req;
      #1;
      check(opm_req[lane] == ~req_before[lane], "request did not toggle exactly once");
      check(ipm_ack == ack_before, "IPM Ack advanced before physical Ack");
      #2;
      check(opm_req[lane] == ~req_before[lane] && ipm_ack == ack_before,
            "request or Ack changed while waiting for physical Ack");
      opm_ack[lane] = opm_req[lane];
      #1;
      check(ipm_ack == ~ack_before, "physical Ack did not toggle IPM Ack");
      check(opm_req[lane] == ~req_before[lane], "physical Ack changed OPM Req");
      #2;
      check(ipm_ack == ~ack_before && opm_req[lane] == ~req_before[lane],
            "extra Toggle event after completed transaction");
      select[lane] = 1'b0;
      #1;
      check(ipm_ack == ~ack_before && opm_req[lane] == ~req_before[lane],
            "idle select release changed a completed lane");
    end
  endtask

  initial begin
    #2; reset = 0;
    #2;
    check(ipm_ack == 0 && opm_req == 0, "reset state incorrect");

    // Idle selection edges are not Ack edges.
    select = 4'b0001;
    #2;
    check(ipm_ack == 0 && opm_req == 0, "idle LaneSelect caused a Toggle");
    select = 0;

    // A pending request can wait while unselected, then issue once selected.
    ipm_req = 1'b1;
    #2;
    check(opm_req == 0 && ipm_ack == 0, "unselected request escaped or acknowledged");
    select[3] = 1'b1;
    #1;
    check(opm_req[3] == 1 && ipm_ack == 0, "selected pending request did not issue cleanly");
    opm_ack[3] = 1'b1;
    #1;
    check(ipm_ack == 1, "selected pending request did not return Ack");
    select[3] = 1'b0;

    // Repeated branch request phases routed through different physical lanes.
    one_transaction(0);
    one_transaction(1);
    one_transaction(2);
    one_transaction(3);
    one_transaction(0);
    one_transaction(2);

    if (failures == 0) $display("TB_RESULT PASS PhaseAdapterDFF valid-protocol regression");
    else $display("TB_RESULT FAIL PhaseAdapterDFF valid-protocol regression failures=%0d", failures);
    $finish;
  end
endmodule
