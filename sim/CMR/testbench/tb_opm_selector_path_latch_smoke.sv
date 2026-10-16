`timescale 1ns/1ps

module tb_opm_selector_path_latch_smoke;
  reg reset;
  reg [3:0] RouteSel;
  reg [3:0] TailPassed;
  wire [3:0] PathEnabled;
  integer errors;

  OPMSelector dut (
    .reset(reset),
    .RouteSel(RouteSel),
    .TailPassed(TailPassed),
    .PathEnabled(PathEnabled)
  );

  task automatic check_q(input bit expected, input [127:0] tag);
    begin
      #0.300;
      if ((PathEnabled[0] !== expected) || $isunknown(PathEnabled)) begin
        $display("TB_FAIL tag=%0s t=%0t S=%b R=%b Q=%b expected=%b",
                 tag, $time, RouteSel[0], TailPassed[0], PathEnabled, expected);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    errors = 0;
    reset = 1'b1;
    RouteSel = 4'b0000;
    TailPassed = 4'b0000;
    #2.000;
    check_q(1'b0, "reset");
    reset = 1'b0;
    // Satisfy the mapped DFF's recovery/removal window before its first
    // RouteSel clock edge.
    #0.100;

    RouteSel[0] = 1'b1;
    check_q(1'b1, "routesel_rising_sets");
    RouteSel[0] = 1'b0;
    check_q(1'b1, "holds_after_routesel_falls");
    TailPassed[0] = 1'b1;
    check_q(1'b0, "tailpassed_async_clear");
    TailPassed[0] = 1'b0;
    check_q(1'b0, "stays_clear_after_tailpassed");
    #0.100;

    // A high RouteSel during TailPassed must not set the state when the
    // asynchronous clear releases; only a subsequent rising edge may do so.
    RouteSel[0] = 1'b1;
    TailPassed[0] = 1'b1;
    check_q(1'b0, "clear_dominates_route_event");
    TailPassed[0] = 1'b0;
    check_q(1'b0, "no_retrigger_while_routesel_high");
    RouteSel[0] = 1'b0;
    #0.100;
    RouteSel[0] = 1'b1;
    check_q(1'b1, "next_routesel_rising_sets_again");

    reset = 1'b1;
    check_q(1'b0, "final_reset");
    if (errors == 0)
      $display("TB_RESULT PASS CMR OPMSelector RouteSel-clocked DFF smoke");
    else
      $display("TB_RESULT FAIL CMR OPMSelector PathStateDFF errors=%0d", errors);
    $finish;
  end
endmodule
