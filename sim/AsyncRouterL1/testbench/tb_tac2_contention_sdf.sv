`timescale 1ns/1ps

// Simulation-only physical-arbitration diagnostic.
// It deliberately drives both TAC leaves at exactly the same simulation time.
// root_grant is held low first, matching the Mutex5 use case: group request
// propagation precedes return of the root group permission.
module tb_tac2_contention_sdf;
  reg reset;
  reg req0;
  reg req1;
  reg root_grant;
  wire req_up;
  wire grant0;
  wire grant1;
  wire arbo0;
  wire arbo1;
  wire masked0;
  wire masked1;
  integer failures;

  TAC2 dut (
    .reset(reset), .req0(req0), .req1(req1), .root_grant(root_grant),
    .req_up(req_up), .grant0(grant0), .grant1(grant1),
    .arbo0(arbo0), .arbo1(arbo1),
    .result_masked0(masked0), .result_masked1(masked1)
  );

  task automatic expect_onehot(input [8*48-1:0] tag);
    begin
      if (({grant1, grant0} !== 2'b01) && ({grant1, grant0} !== 2'b10)) begin
        failures = failures + 1;
        $display("TAC_CONTENTION_FAIL tag=%0s t=%0t req=%b%b root=%b arbo=%b%b grant=%b%b masked=%b%b",
          tag, $time, req1, req0, root_grant, arbo1, arbo0,
          grant1, grant0, masked1, masked0);
      end else begin
        $display("TAC_CONTENTION_RESOLVED tag=%0s t=%0t arbo=%b%b grant=%b%b",
          tag, $time, arbo1, arbo0, grant1, grant0);
      end
    end
  endtask

  initial begin
    failures = 0;
    reset = 1'b1; req0 = 1'b0; req1 = 1'b0; root_grant = 1'b0;
    #10;
    reset = 1'b0;
    #2;

    // Control: the non-contentious path must still pass a root permission.
    req0 = 1'b1;
    #1;
    root_grant = 1'b1;
    #5;
    if ({grant1, grant0} !== 2'b01) begin
      failures = failures + 1;
      $display("TAC_CONTROL_FAIL t=%0t arbo=%b%b grant=%b%b", $time, arbo1, arbo0, grant1, grant0);
    end

    // Return to idle, then reproduce the field ordering: both local requests
    // first, followed by the root group grant.
    reset = 1'b1; req0 = 1'b0; req1 = 1'b0; root_grant = 1'b0;
    #5;
    reset = 1'b0;
    #2;
    req0 = 1'b1; req1 = 1'b1;
    #1;
    root_grant = 1'b1;
    #20;
    expect_onehot("local_first_root_late");

    // Also cover a root permission that is already returned when equal-time
    // local contention begins.
    reset = 1'b1; req0 = 1'b0; req1 = 1'b0; root_grant = 1'b0;
    #5;
    reset = 1'b0;
    #2;
    root_grant = 1'b1;
    #1;
    req0 = 1'b1; req1 = 1'b1;
    #20;
    expect_onehot("root_first_local_simultaneous");

    if (failures == 0) $display("TB_RESULT PASS TAC2 strict-contention diagnostic");
    else               $display("TB_RESULT FAIL TAC2 strict-contention failures=%0d", failures);
    $finish(failures != 0);
  end
endmodule
