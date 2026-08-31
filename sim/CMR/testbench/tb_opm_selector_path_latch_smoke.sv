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

  task automatic force_clear;
    begin
      RouteSel[0] = 1'b0;
      TailPassed[0] = 1'b1;
      check_q(1'b0, "force_clear");
      TailPassed[0] = 1'b0;
      check_q(1'b0, "clear_hold");
    end
  endtask

  task automatic release_r_with_s_lead(input realtime lead_ns);
    begin
      force_clear();
      TailPassed[0] = 1'b1;
      RouteSel[0] = 1'b1;
      #(lead_ns);
      TailPassed[0] = 1'b0;
      check_q(1'b1, "S_before_R_release");
      RouteSel[0] = 1'b0;
      check_q(1'b1, "set_hold");
    end
  endtask

  task automatic set_after_r_release(input realtime lag_ns);
    begin
      force_clear();
      TailPassed[0] = 1'b1;
      #(lag_ns);
      TailPassed[0] = 1'b0;
      #(lag_ns);
      RouteSel[0] = 1'b1;
      check_q(1'b1, "R_release_before_S");
      RouteSel[0] = 1'b0;
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

    RouteSel[0] = 1'b1;
    check_q(1'b1, "set");
    RouteSel[0] = 1'b0;
    check_q(1'b1, "hold");
    TailPassed[0] = 1'b1;
    check_q(1'b0, "clear");

    RouteSel[0] = 1'b1;
    check_q(1'b0, "S_and_R_clear_dominant");
    TailPassed[0] = 1'b0;
    check_q(1'b1, "release_R_with_S_high");
    RouteSel[0] = 1'b0;

    release_r_with_s_lead(0.025);
    release_r_with_s_lead(0.050);
    release_r_with_s_lead(0.100);
    release_r_with_s_lead(0.200);
    set_after_r_release(0.025);
    set_after_r_release(0.050);
    set_after_r_release(0.100);
    set_after_r_release(0.200);

    force_clear();
    TailPassed[0] = 1'b1;
    RouteSel[0] = 1'b1;
    TailPassed[0] = 1'b0;
    check_q(1'b1, "zero_skew_release");

    reset = 1'b1;
    check_q(1'b0, "final_reset");
    if (errors == 0)
      $display("TB_RESULT PASS CMR OPMSelector PathLatch reset-dominant smoke");
    else
      $display("TB_RESULT FAIL CMR OPMSelector PathLatch errors=%0d", errors);
    $finish;
  end
endmodule
