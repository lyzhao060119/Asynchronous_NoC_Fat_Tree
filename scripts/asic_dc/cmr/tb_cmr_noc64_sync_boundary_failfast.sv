`timescale 1ns/1ps

// Fail-fast shell around tb_noc64_sync_boundary.
// Thin TOP_LANES=1; Fat 1-2-2-2 uses +define+CMR_SYNC64_TOP2.
module tb_cmr_noc64_sync_boundary_failfast;
`ifdef CMR_SYNC64_TOP2
  localparam integer TOP_LANES = 2;
`else
  localparam integer TOP_LANES = 1;
`endif
  localparam integer NUM_CORES = 64;
  localparam integer NUM_PORTS = NUM_CORES + TOP_LANES;

  noc64_sync_boundary_core #(
    .NUM_CORES(NUM_CORES),
    .TOP_LANES(TOP_LANES)
  ) core();

  realtime stall_timeout_ns;
  realtime hard_timeout_ns;
  realtime watchdog_poll_ns;
  realtime traffic_start_ns;
  realtime last_progress_ns;
  reg watchdog_armed;
  reg failure_fired;

  function integer total_received;
    integer port;
    begin
      total_received = 0;
      for (port = 0; port < NUM_PORTS; port = port + 1)
        total_received = total_received + core.rx_count[port];
    end
  endfunction

  function integer total_required;
    integer port;
    begin
      total_required = 0;
      for (port = 0; port < NUM_PORTS; port = port + 1)
        total_required = total_required + core.expected_port_count[port];
    end
  endfunction

  function automatic work_outstanding;
    begin
      work_outstanding = (core.input_done !== {NUM_PORTS{1'b1}}) ||
                         (total_received() < total_required());
    end
  endfunction

  task automatic stop_now(input string marker);
    begin
      if (!failure_fired) begin
        failure_fired = 1'b1;
        $display("%0s", marker);
        $fatal(1, "%0s", marker);
      end
    end
  endtask

  always @(posedge core.clock) begin
    if (watchdog_armed && core.running &&
        (((^core.noc_in_valid)  === 1'bx) ||
         ((^core.noc_in_ready)  === 1'bx) ||
         ((^core.noc_out_valid) === 1'bx) ||
         ((^core.noc_out_ready) === 1'bx))) begin
      $display("TB_X_FAIL boundary_control t=%0t in_valid=%b in_ready=%b out_valid=%b out_ready=%b",
               $time, core.noc_in_valid, core.noc_in_ready,
               core.noc_out_valid, core.noc_out_ready);
      if (!$test$plusargs("KEEP_RUNNING_ON_X"))
        stop_now("TB_X_FAIL boundary control contains X/Z");
      else
        $display("TB_X_CONTINUE plusarg KEEP_RUNNING_ON_X");
    end
  end

  always @(posedge core.clock) begin
    if (watchdog_armed && core.running &&
        (((core.noc_in_valid & core.noc_in_ready) !== {NUM_PORTS{1'b0}}) ||
         ((core.noc_out_valid & core.noc_out_ready) !== {NUM_PORTS{1'b0}})))
      last_progress_ns = $realtime;
  end

  always @(core.unexpected_flits) begin
    if (watchdog_armed && core.running && (core.unexpected_flits > 0) &&
        !failure_fired) begin
      $display("TB_UNEXPECTED_FAIL t=%0t unexpected=%0d out_valid=%b out_ready=%b out_data=%h",
               $time, core.unexpected_flits, core.noc_out_valid,
               core.noc_out_ready, core.noc_out_data);
      stop_now("TB_UNEXPECTED_FAIL first unexpected or corrupted flit");
    end
  end

  initial begin : fail_fast_watchdogs
    stall_timeout_ns = 50000.0;
    hard_timeout_ns = 400000.0;
    watchdog_poll_ns = 1000.0;
    watchdog_armed = 1'b0;
    failure_fired = 1'b0;
    if ($value$plusargs("STALL_TIMEOUT_NS=%f", stall_timeout_ns)) ;
    if ($value$plusargs("HARD_TIMEOUT_NS=%f", hard_timeout_ns)) ;
    if ($value$plusargs("WATCHDOG_POLL_NS=%f", watchdog_poll_ns)) ;
    wait (core.running === 1'b1);
    repeat (16) @(posedge core.clock);
    traffic_start_ns = $realtime;
    last_progress_ns = $realtime;
    watchdog_armed = 1'b1;
    $display("TB_INFO CMR sync NoC64 fail-fast armed top_lanes=%0d ports=%0d stall_ns=%0.3f hard_ns=%0.3f",
             TOP_LANES, NUM_PORTS, stall_timeout_ns, hard_timeout_ns);
    fork
      begin : hard_timeout
        #(hard_timeout_ns);
        if (!core.finish_requested && !failure_fired) begin
          $display("TB_HARD_TIMEOUT t=%0t elapsed_ns=%0.3f input_done=%b rx=%0d expected=%0d",
                   $time, $realtime - traffic_start_ns, core.input_done,
                   total_received(), total_required());
          stop_now("TB_HARD_TIMEOUT clocked case exceeded hard deadline");
        end
      end
      begin : stall_timeout
        forever begin
          #(watchdog_poll_ns);
          if (!core.finish_requested && !failure_fired && work_outstanding() &&
              (($realtime - last_progress_ns) >= stall_timeout_ns)) begin
            $display("TB_STALL_FAIL t=%0t idle_ns=%0.3f input_done=%b rx=%0d expected=%0d in_valid=%b in_ready=%b out_valid=%b out_ready=%b",
                     $time, $realtime - last_progress_ns, core.input_done,
                     total_received(), total_required(),
                     core.noc_in_valid, core.noc_in_ready,
                     core.noc_out_valid, core.noc_out_ready);
            stop_now("TB_STALL_FAIL no useful clocked valid/ready progress");
          end
        end
      end
    join_none
  end
endmodule
