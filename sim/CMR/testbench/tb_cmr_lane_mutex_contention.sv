`timescale 1ns/1ps

// Strict-SDF/RTL diagnostic for the CMR first-level two-lane selector.
// It deliberately does not prescribe which lane wins.  A one-hot winner that
// stops switching is success; exact simultaneous contention is classified,
// rather than hidden, when the digital mutex keeps oscillating.
module tb_cmr_lane_mutex_contention;
  reg reset;
  reg path_enabled;
  reg [1:0] other_grant;
  wire [1:0] mutex_req;
  wire [1:0] lane_select;
`ifdef CMR_POST_SYNTH
  // DC writes the WIDTH=2 generate label as the escaped identifier
  // "\\w2.root "; retain that gate-level hierarchy in the phase probe.
  wire q0 = dut.mutex.\w2.root .q0;
  wire q1 = dut.mutex.\w2.root .q1;
`else
  wire q0 = dut.mutex.w2.root.q0;
  wire q1 = dut.mutex.w2.root.q1;
`endif

  integer failures;
  integer q_events;
  integer grant_events;
  integer x_events;
  realtime last_q_change;
  realtime last_grant_change;

  CMRLaneSelectorMutex2Harness dut (
    .reset(reset), .PathEnabled(path_enabled), .OtherGrant(other_grant),
    .mutex_req(mutex_req), .LaneSelect(lane_select)
  );

  always @(q0 or q1) begin
    if (!reset) begin
      q_events = q_events + 1;
      last_q_change = $realtime;
      if ((q0 !== 1'b0 && q0 !== 1'b1) || (q1 !== 1'b0 && q1 !== 1'b1))
        x_events = x_events + 1;
    end
  end

  always @(lane_select) begin
    if (!reset) begin
      grant_events = grant_events + 1;
      last_grant_change = $realtime;
      if ((lane_select[0] !== 1'b0 && lane_select[0] !== 1'b1) ||
          (lane_select[1] !== 1'b0 && lane_select[1] !== 1'b1))
        x_events = x_events + 1;
    end
  end

  task automatic enter_idle;
    begin
      reset = 1'b1;
      path_enabled = 1'b0;
      other_grant = 2'b11;
      #0.200;
      reset = 1'b0;
      #0.200;
      q_events = 0;
      grant_events = 0;
      x_events = 0;
      last_q_change = $realtime;
      last_grant_change = $realtime;
    end
  endtask

  task automatic classify(input [8*40-1:0] tag, input bit require_onehot);
    realtime sample_time;
    integer q_before;
    integer grant_before;
    begin
      #5.000;
      sample_time = $realtime;
      q_before = q_events;
      grant_before = grant_events;
      #5.000;
      $display("LANE_MUTEX_SAMPLE tag=%0s t=%0t req=%b other=%b q=%b%b grant=%b q_events=%0d grant_events=%0d last_ns(q/grant)=%0.3f/%0.3f x_events=%0d",
               tag, $time, mutex_req, other_grant, q1, q0, lane_select,
               q_events, grant_events, last_q_change, last_grant_change,
               x_events);
      if ((lane_select === 2'b01 || lane_select === 2'b10) &&
          q_events == q_before && grant_events == grant_before && x_events == 0) begin
        $display("LANE_MUTEX_RESULT tag=%0s STABLE_ONEHOT", tag);
      end else if (q_events > q_before || grant_events > grant_before) begin
        $display("LANE_MUTEX_RESULT tag=%0s OSCILLATION", tag);
        if (require_onehot) begin
          failures = failures + 1;
          $display("TB_FAIL non-synchronous scenario did not settle tag=%0s", tag);
        end
      end else begin
        $display("LANE_MUTEX_RESULT tag=%0s NO_STABLE_WINNER", tag);
        if (require_onehot) begin
          failures = failures + 1;
          $display("TB_FAIL non-synchronous scenario has no one-hot winner tag=%0s", tag);
        end
      end
    end
  endtask

  task automatic run_sync;
    begin
      enter_idle();
      // The actual CMR field condition: both OtherGrant bits are already 0,
      // then one PathEnabled edge makes req go 00 -> 11 in one delta cycle.
      other_grant = 2'b00;
      path_enabled = 1'b1;
      classify("synchronous_00_to_11", 1'b0);
    end
  endtask

  // This preserves the failing router's actual selector history: both lanes
  // are already selectable (OtherGrant=00) while PathEnabled is low, so the
  // cross-coupled NANDs settle at q=11 before the single PathEnabled edge
  // requests both lanes.  The previous synchronous test changed OtherGrant
  // and PathEnabled together, which is not the same asynchronous history.
  task automatic run_router_history;
    begin
      reset = 1'b1;
      path_enabled = 1'b0;
      other_grant = 2'b00;
      #0.200;
      reset = 1'b0;
      #1.000;
      q_events = 0;
      grant_events = 0;
      x_events = 0;
      last_q_change = $realtime;
      last_grant_change = $realtime;
      path_enabled = 1'b1;
      classify("router_history_path_only", 1'b0);
    end
  endtask

  task automatic run_skew(input integer skew_ps);
    begin
      enter_idle();
      path_enabled = 1'b1;
      other_grant[0] = 1'b0;
      #(skew_ps * 0.001);
      other_grant[1] = 1'b0;
      case (skew_ps)
        25:  classify("skew_25ps", 1'b1);
        50:  classify("skew_50ps", 1'b1);
        100: classify("skew_100ps", 1'b1);
        200: classify("skew_200ps", 1'b1);
        default: classify("skew_unknown", 1'b1);
      endcase
    end
  endtask

  task automatic run_second_late;
    begin
      enter_idle();
      path_enabled = 1'b1;
      other_grant[0] = 1'b0;
      #1.000;
      other_grant[1] = 1'b0;
      classify("second_request_1ns_late", 1'b1);
    end
  endtask

  initial begin
    failures = 0;
    q_events = 0;
    grant_events = 0;
    x_events = 0;
    reset = 1'b1;
    path_enabled = 1'b0;
    other_grant = 2'b11;

    run_router_history();
    run_sync();
    run_skew(25);
    run_skew(50);
    run_skew(100);
    run_skew(200);
    run_second_late();

    if (failures == 0)
      $display("TB_RESULT PASS CMR lane-mutex contention diagnostic");
    else
      $display("TB_RESULT FAIL CMR lane-mutex contention failures=%0d", failures);
    $finish(failures != 0);
  end
endmodule
