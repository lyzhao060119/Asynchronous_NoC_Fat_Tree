`timescale 1ns/1ps

// CMR fail-fast shell around tb_noc64_async_boundary.
// TOP_LANES: 8 Fat 1-2-4-8, 2 Fat 1-2-2-2 (`CMR_NOC64_TOP2), 1 Thin (`CMR_NOC64_THIN), 0 mesh (`CMR_NOC64_MESH).
module tb_cmr_noc64_async_boundary_failfast;
`ifdef CMR_MESH16
  localparam integer TOP_LANES = 0;
  localparam integer NUM_CORES = 16;
`elsif CMR_NOC64_MESH
  localparam integer TOP_LANES = 0;
  localparam integer NUM_CORES = 64;
`elsif CMR_NOC64_THIN
  localparam integer TOP_LANES = 1;
  localparam integer NUM_CORES = 64;
`elsif CMR_NOC64_TOP2
  localparam integer TOP_LANES = 2;
  localparam integer NUM_CORES = 64;
`else
  localparam integer TOP_LANES = 8;
  localparam integer NUM_CORES = 64;
`endif
  localparam integer NUM_PORTS = NUM_CORES + TOP_LANES;

  noc64_async_boundary_core #(
    .NUM_CORES(NUM_CORES),
    .TOP_LANES(TOP_LANES),
    .STRUCTURAL_ENDPOINTS(0),
    .ROBUST_DIRECT_HANDSHAKE(1)
  ) core();

  realtime stall_timeout_ns;
  realtime hard_timeout_ns;
  realtime watchdog_poll_ns;
  realtime traffic_start_ns;
  realtime last_progress_ns;
  reg watchdog_armed;
  reg failure_fired;
  reg dump_on_fail;
  reg trace_enabled;
  reg diagnostic_trigger;
  integer diagnostic_port;
  integer diagnostic_input;
  integer unex_port;
  integer unex_slot;
  integer unex_scan;
  integer unex_other;
  integer unex_near;
  integer unex_dist;
  integer unex_tmp;
  integer unex_bits;
  reg [27:0] unex_captured;
  reg [27:0] unex_near_flit;

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
        if (dump_on_fail) begin
          $display("TB_DUMP_ON_FAIL writing CSV before fatal");
          core.dump_csv_results();
        end
        dump_mesh_hop_counts();
        $fatal(1, "%0s", marker);
      end
    end
  endtask

  function integer popcount28;
    input [27:0] value;
    begin
      popcount28 = $countones(value);
    end
  endfunction

  task automatic dump_first_unexpected;
    begin
      unex_port = -1;
      unex_slot = -1;
      unex_captured = 28'b0;
      for (diagnostic_port = 0; diagnostic_port < NUM_PORTS;
           diagnostic_port = diagnostic_port + 1) begin
        if (core.rx_count[diagnostic_port] > 0) begin
          unex_tmp = core.rx_count[diagnostic_port] - 1;
          if (!core.rx_match[diagnostic_port][unex_tmp]) begin
            $display("TB_UNEX_RX port=%0d slot=%0d captured=%h match=0 req=%b ack=%b tb_req=%b tb_ack=%b",
                     diagnostic_port, unex_tmp,
                     core.rx_flit[diagnostic_port][unex_tmp],
                     core.noc_out_req[diagnostic_port],
                     core.noc_out_ack[diagnostic_port],
                     core.tb_out_req[diagnostic_port],
                     core.tb_out_ack[diagnostic_port]);
            if (unex_port < 0) begin
              unex_port = diagnostic_port;
              unex_slot = unex_tmp;
              unex_captured = core.rx_flit[diagnostic_port][unex_tmp];
            end
          end
        end
        $display("TB_UNEX_COUNT port=%0d rx=%0d expected=%0d",
                 diagnostic_port, core.rx_count[diagnostic_port],
                 core.expected_port_count[diagnostic_port]);
      end
      if (unex_port < 0) begin
        $display("TB_UNEX_PORT none unmatched slot visible unexpected=%0d",
                 core.unexpected_flits);
      end else begin
        unex_other = -1;
        unex_near = -1;
        unex_dist = 29;
        unex_near_flit = 28'b0;
        for (unex_scan = 0; unex_scan < core.expected_count;
             unex_scan = unex_scan + 1) begin
          if (!core.expected_seen[unex_scan] &&
              (core.expected_flit[unex_scan] === unex_captured)) begin
            for (diagnostic_port = 0; diagnostic_port < NUM_PORTS;
                 diagnostic_port = diagnostic_port + 1)
              if (core.expected_mask[unex_scan][diagnostic_port])
                unex_other = diagnostic_port;
          end
          if (!core.expected_seen[unex_scan] &&
              core.expected_mask[unex_scan][unex_port]) begin
            unex_bits = popcount28(core.expected_flit[unex_scan] ^ unex_captured);
            if (unex_bits < unex_dist) begin
              unex_dist = unex_bits;
              unex_near = unex_scan;
              unex_near_flit = core.expected_flit[unex_scan];
            end
          end
        end
        if (unex_captured === 28'b0)
          $display("TB_UNEX_CLASS zero_payload");
        else if ((unex_other >= 0) && (unex_other != unex_port))
          $display("TB_UNEX_CLASS misroute expect_port=%0d", unex_other);
        else
          $display("TB_UNEX_CLASS mismatch");
        $display("TB_UNEX_PORT port=%0d slot=%0d captured=%h head=%b tail=%b id=%0d x0=%0d y0=%0d x1=%0d y1=%0d",
                 unex_port, unex_slot, unex_captured,
                 unex_captured[27], unex_captured[26], unex_captured[1:0],
                 unex_captured[7:2], unex_captured[13:8],
                 unex_captured[19:14], unex_captured[25:20]);
        $display("TB_UNEX_NEAR idx=%0d dist=%0d flit=%h",
                 unex_near, unex_dist, unex_near_flit);
        diagnostic_port = unex_port;
      end
    end
  endtask

  // This monitor is event-driven.  No testbench clock is created or sampled.
  always @(core.running or core.noc_in_req or core.noc_in_ack or
           core.noc_out_req or core.noc_out_ack) begin
    if (watchdog_armed && core.running &&
        (((^core.noc_in_req)  === 1'bx) ||
         ((^core.noc_in_ack)  === 1'bx) ||
         ((^core.noc_out_req) === 1'bx) ||
         ((^core.noc_out_ack) === 1'bx))) begin
      $display("TB_X_FAIL boundary_control t=%0t in_req=%b in_ack=%b out_req=%b out_ack=%b",
               $time, core.noc_in_req, core.noc_in_ack,
               core.noc_out_req, core.noc_out_ack);
      diagnostic_trigger = 1'b1;
      #0;
`ifdef CMR_KEEP_RUNNING_ON_X
      $display("TB_X_CONTINUE define CMR_KEEP_RUNNING_ON_X");
`else
      if (!$test$plusargs("KEEP_RUNNING_ON_X"))
        stop_now("TB_X_FAIL boundary control contains X/Z");
      else
        $display("TB_X_CONTINUE plusarg KEEP_RUNNING_ON_X");
`endif
    end
  end

  // Input acknowledgement and output request transitions are useful network
  // progress.  Offered requests are deliberately not counted: a blocked input
  // must not keep the stall watchdog alive.
  always @(core.noc_in_ack or core.noc_out_req) begin
    if (watchdog_armed && core.running &&
        ((^core.noc_in_ack) !== 1'bx) && ((^core.noc_out_req) !== 1'bx))
      last_progress_ns = $realtime;
  end

  // The canonical checker increments this counter immediately after the first
  // duplicate, unexpected, mismatched, or X-corrupted captured flit.
  always @(core.unexpected_flits) begin
    if (watchdog_armed && core.running && (core.unexpected_flits > 0) &&
        !failure_fired) begin
      $display("TB_UNEXPECTED_FAIL t=%0t unexpected=%0d out_req=%b out_ack=%b out_data=%h",
               $time, core.unexpected_flits, core.noc_out_req,
               core.noc_out_ack, core.noc_out_data);
      dump_first_unexpected();
      diagnostic_trigger = 1'b1;
      #0;
      stop_now("TB_UNEXPECTED_FAIL first unexpected or corrupted flit");
    end
  end

  always @(core.tb_in_req[0] or core.tb_in_ack[0] or core.noc_in_req[0] or
           core.noc_in_ack[0] or core.noc_out_req or core.active_input[0]) begin
    if (trace_enabled)
      $display("TB_FF_TRACE t=%0t active0=%0d tb_req0=%b tb_ack0=%b noc_req0=%b noc_ack0=%b out_req=%b",
               $time, core.active_input[0], core.tb_in_req[0],
               core.tb_in_ack[0], core.noc_in_req[0], core.noc_in_ack[0],
               core.noc_out_req);
  end

`ifdef CMR_MESH16
  always @(core.noc_out_req[13] or core.noc_out_ack[13]) begin
    if (core.running && $test$plusargs("MESH_LOCAL_PROBE"))
      $display("TB_MESH_LOCAL13 t=%0t req=%b ack=%b data=%h rx=%0d unexpected=%0d",
               $time, core.noc_out_req[13], core.noc_out_ack[13],
               core.noc_out_data[13*28 +: 28], core.rx_count[13],
               core.unexpected_flits);
  end

  // XY 3→13: (3,0) west to (1,0), then north to (1,3) local.
  integer hop_n_3_0_local_in, hop_n_3_0_west, hop_n_2_0_west;
  integer hop_n_1_0_north, hop_n_1_1_north, hop_n_1_2_north;
  integer hop_n_1_3_south, hop_n_1_3_local, hop_n_1_3_path, hop_n_1_3_tail;

  `define TB_MESH_HOP(req, ack, flit, nm, cnt) \
    always @(req) begin \
      if (core.running && $test$plusargs("MESH_HOP_PROBE")) begin \
        cnt = cnt + 1; \
        $display("TB_HOP t=%0t link=%s n=%0d req=%b ack=%b ht=%0d%0d flit=%h", \
                 $time, nm, cnt, req, ack, flit[27], flit[26], flit); \
      end \
    end

  `TB_MESH_HOP(core.g_behavioral_noc_mesh16.noc.dut.meshR_3_0.io_inputs_parent_0_HS_Req,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_3_0.io_inputs_parent_0_HS_Ack,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_3_0.io_inputs_parent_0_Data_flit,
               "meshR_3_0.local_in", hop_n_3_0_local_in)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh16.noc.dut.meshR_3_0.io_outputs_child_0_0_HS_Req,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_3_0.io_outputs_child_0_0_HS_Ack,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_3_0.io_outputs_child_0_0_Data_flit,
               "meshR_3_0.west_out", hop_n_3_0_west)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh16.noc.dut.meshR_2_0.io_outputs_child_0_0_HS_Req,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_2_0.io_outputs_child_0_0_HS_Ack,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_2_0.io_outputs_child_0_0_Data_flit,
               "meshR_2_0.west_out", hop_n_2_0_west)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh16.noc.dut.meshR_1_0.io_outputs_child_3_0_HS_Req,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_1_0.io_outputs_child_3_0_HS_Ack,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_1_0.io_outputs_child_3_0_Data_flit,
               "meshR_1_0.north_out", hop_n_1_0_north)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh16.noc.dut.meshR_1_1.io_outputs_child_3_0_HS_Req,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_1_1.io_outputs_child_3_0_HS_Ack,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_1_1.io_outputs_child_3_0_Data_flit,
               "meshR_1_1.north_out", hop_n_1_1_north)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh16.noc.dut.meshR_1_2.io_outputs_child_3_0_HS_Req,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_1_2.io_outputs_child_3_0_HS_Ack,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_1_2.io_outputs_child_3_0_Data_flit,
               "meshR_1_2.north_out", hop_n_1_2_north)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh16.noc.dut.meshR_1_3.io_inputs_child_1_0_HS_Req,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_1_3.io_inputs_child_1_0_HS_Ack,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_1_3.io_inputs_child_1_0_Data_flit,
               "meshR_1_3.south_in", hop_n_1_3_south)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh16.noc.dut.meshR_1_3.io_outputs_parent_0_HS_Req,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_1_3.io_outputs_parent_0_HS_Ack,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_1_3.io_outputs_parent_0_Data_flit,
               "meshR_1_3.local_out", hop_n_1_3_local)

  always @(core.g_behavioral_noc_mesh16.noc.dut.meshR_1_3.InputPortModules_1_io_PathEnabled_3) begin
    if (core.running && $test$plusargs("MESH_HOP_PROBE")) begin
      hop_n_1_3_path = hop_n_1_3_path + 1;
      $display("TB_HOP t=%0t link=meshR_1_3.south_to_local.PathEnabled n=%0d val=%b",
               $time, hop_n_1_3_path,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_1_3.InputPortModules_1_io_PathEnabled_3);
    end
  end
  always @(core.g_behavioral_noc_mesh16.noc.dut.meshR_1_3.OutputPortModules_4_io_TailPassed_1) begin
    if (core.running && $test$plusargs("MESH_HOP_PROBE")) begin
      hop_n_1_3_tail = hop_n_1_3_tail + 1;
      $display("TB_HOP t=%0t link=meshR_1_3.local.TailPassed_south n=%0d val=%b",
               $time, hop_n_1_3_tail,
               core.g_behavioral_noc_mesh16.noc.dut.meshR_1_3.OutputPortModules_4_io_TailPassed_1);
    end
  end

  task automatic dump_mesh_hop_counts;
    begin
      if ($test$plusargs("MESH_HOP_PROBE"))
        $display("TB_HOP_COUNTS local_in=%0d w30=%0d w20=%0d n10=%0d n11=%0d n12=%0d south13=%0d local13=%0d path=%0d tail=%0d",
                 hop_n_3_0_local_in, hop_n_3_0_west, hop_n_2_0_west,
                 hop_n_1_0_north, hop_n_1_1_north, hop_n_1_2_north,
                 hop_n_1_3_south, hop_n_1_3_local, hop_n_1_3_path,
                 hop_n_1_3_tail);
    end
  endtask
`elsif CMR_NOC64_MESH
  always @(core.noc_out_req[44] or core.noc_out_ack[44]) begin
    if (core.running && $test$plusargs("MESH_LOCAL_PROBE"))
      $display("TB_MESH_LOCAL44 t=%0t req=%b ack=%b data=%h rx=%0d unexpected=%0d",
               $time, core.noc_out_req[44], core.noc_out_ack[44],
               core.noc_out_data[44*28 +: 28], core.rx_count[44],
               core.unexpected_flits);
  end

  // XY 6→44: (6,0) west to (4,0), then north to (4,5) local.
  // Count request transitions only.  Do not dump waveforms.
  integer hop_n_6_0_local_in, hop_n_6_0_west, hop_n_5_0_west;
  integer hop_n_4_0_north, hop_n_4_1_north, hop_n_4_2_north;
  integer hop_n_4_3_north, hop_n_4_4_north, hop_n_4_5_south, hop_n_4_5_local;
  integer hop_n_4_5_path, hop_n_4_5_tail;

  `define TB_MESH_HOP(req, ack, flit, nm, cnt) \
    always @(req) begin \
      if (core.running && $test$plusargs("MESH_HOP_PROBE")) begin \
        cnt = cnt + 1; \
        $display("TB_HOP t=%0t link=%s n=%0d req=%b ack=%b ht=%0d%0d flit=%h", \
                 $time, nm, cnt, req, ack, flit[27], flit[26], flit); \
      end \
    end

  `TB_MESH_HOP(core.g_behavioral_noc_mesh.noc.dut.meshR_6_0.io_inputs_parent_0_HS_Req,
               core.g_behavioral_noc_mesh.noc.dut.meshR_6_0.io_inputs_parent_0_HS_Ack,
               core.g_behavioral_noc_mesh.noc.dut.meshR_6_0.io_inputs_parent_0_Data_flit,
               "meshR_6_0.local_in", hop_n_6_0_local_in)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh.noc.dut.meshR_6_0.io_outputs_child_0_0_HS_Req,
               core.g_behavioral_noc_mesh.noc.dut.meshR_6_0.io_outputs_child_0_0_HS_Ack,
               core.g_behavioral_noc_mesh.noc.dut.meshR_6_0.io_outputs_child_0_0_Data_flit,
               "meshR_6_0.west_out", hop_n_6_0_west)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh.noc.dut.meshR_5_0.io_outputs_child_0_0_HS_Req,
               core.g_behavioral_noc_mesh.noc.dut.meshR_5_0.io_outputs_child_0_0_HS_Ack,
               core.g_behavioral_noc_mesh.noc.dut.meshR_5_0.io_outputs_child_0_0_Data_flit,
               "meshR_5_0.west_out", hop_n_5_0_west)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh.noc.dut.meshR_4_0.io_outputs_child_3_0_HS_Req,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_0.io_outputs_child_3_0_HS_Ack,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_0.io_outputs_child_3_0_Data_flit,
               "meshR_4_0.north_out", hop_n_4_0_north)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh.noc.dut.meshR_4_1.io_outputs_child_3_0_HS_Req,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_1.io_outputs_child_3_0_HS_Ack,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_1.io_outputs_child_3_0_Data_flit,
               "meshR_4_1.north_out", hop_n_4_1_north)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh.noc.dut.meshR_4_2.io_outputs_child_3_0_HS_Req,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_2.io_outputs_child_3_0_HS_Ack,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_2.io_outputs_child_3_0_Data_flit,
               "meshR_4_2.north_out", hop_n_4_2_north)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh.noc.dut.meshR_4_3.io_outputs_child_3_0_HS_Req,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_3.io_outputs_child_3_0_HS_Ack,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_3.io_outputs_child_3_0_Data_flit,
               "meshR_4_3.north_out", hop_n_4_3_north)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh.noc.dut.meshR_4_4.io_outputs_child_3_0_HS_Req,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_4.io_outputs_child_3_0_HS_Ack,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_4.io_outputs_child_3_0_Data_flit,
               "meshR_4_4.north_out", hop_n_4_4_north)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh.noc.dut.meshR_4_5.io_inputs_child_1_0_HS_Req,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_5.io_inputs_child_1_0_HS_Ack,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_5.io_inputs_child_1_0_Data_flit,
               "meshR_4_5.south_in", hop_n_4_5_south)
  `TB_MESH_HOP(core.g_behavioral_noc_mesh.noc.dut.meshR_4_5.io_outputs_parent_0_HS_Req,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_5.io_outputs_parent_0_HS_Ack,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_5.io_outputs_parent_0_Data_flit,
               "meshR_4_5.local_out", hop_n_4_5_local)

  always @(core.g_behavioral_noc_mesh.noc.dut.meshR_4_5.InputPortModules_1_io_PathEnabled_3) begin
    if (core.running && $test$plusargs("MESH_HOP_PROBE")) begin
      hop_n_4_5_path = hop_n_4_5_path + 1;
      $display("TB_HOP t=%0t link=meshR_4_5.south_to_local.PathEnabled n=%0d val=%b",
               $time, hop_n_4_5_path,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_5.InputPortModules_1_io_PathEnabled_3);
    end
  end
  always @(core.g_behavioral_noc_mesh.noc.dut.meshR_4_5.OutputPortModules_4_io_TailPassed_1) begin
    if (core.running && $test$plusargs("MESH_HOP_PROBE")) begin
      hop_n_4_5_tail = hop_n_4_5_tail + 1;
      $display("TB_HOP t=%0t link=meshR_4_5.local.TailPassed_south n=%0d val=%b",
               $time, hop_n_4_5_tail,
               core.g_behavioral_noc_mesh.noc.dut.meshR_4_5.OutputPortModules_4_io_TailPassed_1);
    end
  end

  task automatic dump_mesh_hop_counts;
    begin
      if ($test$plusargs("MESH_HOP_PROBE"))
        $display("TB_HOP_COUNTS local_in=%0d w60=%0d w50=%0d n40=%0d n41=%0d n42=%0d n43=%0d n44=%0d south45=%0d local45=%0d path=%0d tail=%0d",
                 hop_n_6_0_local_in, hop_n_6_0_west, hop_n_5_0_west,
                 hop_n_4_0_north, hop_n_4_1_north, hop_n_4_2_north,
                 hop_n_4_3_north, hop_n_4_4_north, hop_n_4_5_south,
                 hop_n_4_5_local, hop_n_4_5_path, hop_n_4_5_tail);
    end
  endtask
`else
  task automatic dump_mesh_hop_counts;
    begin
    end
  endtask
`endif

  initial begin : fail_fast_watchdogs
    stall_timeout_ns = 50000.0;
    hard_timeout_ns = 400000.0;
    watchdog_poll_ns = 1000.0;
    watchdog_armed = 1'b0;
    failure_fired = 1'b0;
    dump_on_fail = 1'b0;
    trace_enabled = 1'b0;
`ifdef CMR_MESH16
    hop_n_3_0_local_in = 0; hop_n_3_0_west = 0; hop_n_2_0_west = 0;
    hop_n_1_0_north = 0; hop_n_1_1_north = 0; hop_n_1_2_north = 0;
    hop_n_1_3_south = 0; hop_n_1_3_local = 0; hop_n_1_3_path = 0;
    hop_n_1_3_tail = 0;
`elsif CMR_NOC64_MESH
    hop_n_6_0_local_in = 0; hop_n_6_0_west = 0; hop_n_5_0_west = 0;
    hop_n_4_0_north = 0; hop_n_4_1_north = 0; hop_n_4_2_north = 0;
    hop_n_4_3_north = 0; hop_n_4_4_north = 0; hop_n_4_5_south = 0;
    hop_n_4_5_local = 0; hop_n_4_5_path = 0; hop_n_4_5_tail = 0;
`endif
    diagnostic_trigger = 1'b0;
    diagnostic_port = -1;
    unex_port = -1;
    if ($value$plusargs("STALL_TIMEOUT_NS=%f", stall_timeout_ns)) ;
    if ($value$plusargs("HARD_TIMEOUT_NS=%f", hard_timeout_ns)) ;
    if ($value$plusargs("WATCHDOG_POLL_NS=%f", watchdog_poll_ns)) ;
    if ($test$plusargs("CMR_FAILFAST_TRACE")) trace_enabled = 1'b1;
    if ($test$plusargs("DUMP_ON_FAIL")) dump_on_fail = 1'b1;
    wait (core.running === 1'b1);
    traffic_start_ns = $realtime;
    last_progress_ns = $realtime;
    watchdog_armed = 1'b1;
    $display("TB_INFO CMR NoC64 fail-fast armed top_lanes=%0d ports=%0d stall_ns=%0.3f hard_ns=%0.3f",
             TOP_LANES, NUM_PORTS, stall_timeout_ns, hard_timeout_ns);
    fork
      begin : hard_timeout
        #(hard_timeout_ns);
        if (!core.finish_requested && !failure_fired) begin
          $display("TB_HARD_TIMEOUT t=%0t elapsed_ns=%0.3f input_done=%b rx=%0d expected=%0d",
                   $time, $realtime - traffic_start_ns, core.input_done,
                   total_received(), total_required());
          stop_now("TB_HARD_TIMEOUT asynchronous case exceeded hard deadline");
        end
      end
      begin : stall_timeout
        forever begin
          #(watchdog_poll_ns);
          if (!core.finish_requested && !failure_fired && work_outstanding() &&
              (($realtime - last_progress_ns) >= stall_timeout_ns)) begin
            $display("TB_STALL_FAIL t=%0t idle_ns=%0.3f input_done=%b rx=%0d expected=%0d tb_in_req=%b tb_in_ack=%b in_req=%b in_ack=%b out_req=%b out_ack=%b active0=%0d",
                     $time, $realtime - last_progress_ns, core.input_done,
                     total_received(), total_required(), core.tb_in_req,
                     core.tb_in_ack, core.noc_in_req, core.noc_in_ack,
                     core.noc_out_req, core.noc_out_ack, core.active_input[0]);
            for (diagnostic_port = 0; diagnostic_port < NUM_PORTS;
                 diagnostic_port = diagnostic_port + 1) begin
              if (core.noc_in_req[diagnostic_port] !== core.noc_in_ack[diagnostic_port]) begin
                diagnostic_input = core.active_input[diagnostic_port];
                if (diagnostic_input >= 0)
                  $display("TB_STALL_PORT port=%0d active_input=%0d flit=%h head=%b tail=%b req=%b ack=%b",
                           diagnostic_port, diagnostic_input,
                           core.input_flit[diagnostic_input],
                           core.input_flit[diagnostic_input][27],
                           core.input_flit[diagnostic_input][26],
                           core.noc_in_req[diagnostic_port],
                           core.noc_in_ack[diagnostic_port]);
                else
                  $display("TB_STALL_PORT port=%0d active_input=none req=%b ack=%b",
                           diagnostic_port, core.noc_in_req[diagnostic_port],
                           core.noc_in_ack[diagnostic_port]);
              end
            end
            diagnostic_trigger = 1'b1;
            #0;
            stop_now("TB_STALL_FAIL no useful asynchronous handshake progress");
          end
        end
      end
    join_none
  end
endmodule
