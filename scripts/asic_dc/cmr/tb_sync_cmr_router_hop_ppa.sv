`timescale 1ns/1ps

// Clocked R-U5 counterpart of tb_cmr_router_hop_ppa.  1.0 ns period.
module tb_sync_cmr_router_hop_ppa;
`ifdef GEOM_C2_P2
  localparam integer CHILD_LANES = 2;
  localparam integer PARENT_LANES = 2;
`else
  localparam integer CHILD_LANES = 1;
  localparam integer PARENT_LANES = 1;
`endif
  localparam integer NUM_PORTS = 4 * CHILD_LANES + PARENT_LANES;
  localparam integer PARENT_BASE = 4 * CHILD_LANES;
  localparam integer FLIT_W = 28;
  localparam integer NUM_FLITS = 5;
  localparam integer MAX_EVENTS = 64;

  reg clock = 1'b0;
  reg reset = 1'b1;
  reg running = 1'b0;
  real clock_ns = 1.0;

  reg [NUM_PORTS-1:0] tb_in_valid = '0;
  wire [NUM_PORTS-1:0] tb_in_ready;
  reg [NUM_PORTS*FLIT_W-1:0] tb_in_data = '0;
  wire [NUM_PORTS-1:0] tb_out_valid;
  reg [NUM_PORTS-1:0] tb_out_ready = '0;
  wire [NUM_PORTS*FLIT_W-1:0] tb_out_data;

  integer event_fd;
  integer failures = 0;
  integer selected_out = -1;
  integer delivered = 0;
  integer num_packets;
  integer expected_total;
  string hop_mode;
  real input_time [0:MAX_EVENTS-1];
  real output_time [0:MAX_EVENTS-1];
  real hop_latency [0:MAX_EVENTS-1];
  integer event_packet [0:MAX_EVENTS-1];
  integer event_flit [0:MAX_EVENTS-1];
  reg [FLIT_W-1:0] expected_flit [0:MAX_EVENTS-1];
  reg expected_seen [0:MAX_EVENTS-1];
  string event_csv;
  string vcd_file;
  string hop_kind;
  event rx_activity;

  always #(clock_ns / 2.0) clock = ~clock;

  function automatic [FLIT_W-1:0] make_flit(
    input bit head, input bit tail, input [1:0] id
  );
    begin
      make_flit = {FLIT_W{1'b0}};
      make_flit[27] = head;
      make_flit[26] = tail;
      make_flit[25:20] = 6'd8;
      make_flit[19:14] = 6'd8;
      make_flit[13:8] = 6'd8;
      make_flit[7:2] = 6'd8;
      make_flit[1:0] = id;
    end
  endfunction

  task automatic fail(input string message);
    begin
      failures = failures + 1;
      $display("PPA_FAIL %s t=%0.3f", message, $realtime);
    end
  endtask

`ifdef GEOM_C2_P2
  SyncCmrRouter dut (
`include "sync_ports_c2_p2.vi"
  );
`else
  SyncCmrRouter dut (
`include "sync_ports_c1_p1.vi"
  );
`endif

  task automatic prepare_packet(input integer pkt, input [1:0] id);
    integer f;
    integer idx;
    begin
      for (f = 0; f < NUM_FLITS; f = f + 1) begin
        idx = pkt * NUM_FLITS + f;
        expected_flit[idx] = make_flit(f == 0, f == (NUM_FLITS - 1), id);
        expected_seen[idx] = 1'b0;
        event_packet[idx] = pkt;
        event_flit[idx] = f;
      end
    end
  endtask

  task automatic drive_port(input integer port, input integer pkt, input bit wait_rx);
    integer f;
    integer idx;
    integer guard;
    begin
      for (f = 0; f < NUM_FLITS; f = f + 1) begin
        idx = pkt * NUM_FLITS + f;
        if (wait_rx && idx > 0)
          while (expected_seen[idx - 1] !== 1'b1) @rx_activity;
        @(posedge clock);
        guard = 0;
        while (!tb_in_ready[port] && guard < 10000) begin
          @(posedge clock);
          guard = guard + 1;
        end
        if (!tb_in_ready[port]) fail("input ready timeout");
        tb_in_data[port*FLIT_W +: FLIT_W] = expected_flit[idx];
        tb_in_valid[port] = 1'b1;
        @(posedge clock);
        input_time[idx] = $realtime;
        tb_in_valid[port] = 1'b0;
      end
    end
  endtask

  integer rp;
  always @(posedge clock) begin
    if (running) begin
      for (rp = 0; rp < NUM_PORTS; rp = rp + 1) begin
        if (tb_out_valid[rp] === 1'bx || tb_out_ready[rp] === 1'bx)
          fail("boundary X/Z");
        if (tb_out_valid[rp] && (^tb_out_data[rp*FLIT_W +: FLIT_W] === 1'bx))
          fail("boundary X/Z");
        tb_out_ready[rp] <= running;
      end
    end
  end

  integer scan;
  integer matched;
  integer out_p;
  reg [FLIT_W-1:0] captured;
  always @(posedge clock) begin
    if (running) begin
      for (out_p = 0; out_p < NUM_PORTS; out_p = out_p + 1) begin
        if (tb_out_valid[out_p] && tb_out_ready[out_p]) begin
          captured = tb_out_data[out_p*FLIT_W +: FLIT_W];
          if (out_p < PARENT_BASE) begin
            fail("packet left on a child port");
          end else begin
            matched = 0;
            for (scan = 0; scan < expected_total; scan = scan + 1)
              if (!matched && !expected_seen[scan] && captured === expected_flit[scan]) begin
                expected_seen[scan] = 1'b1;
                matched = 1;
                if (selected_out < 0) selected_out = out_p;
                output_time[scan] = $realtime;
                hop_latency[scan] = output_time[scan] - input_time[scan];
                $fdisplay(event_fd, "%0d,%0d,%0.3f,%0.3f,%0.3f,%0d,%h",
                  event_packet[scan], event_flit[scan],
                  input_time[scan], output_time[scan], hop_latency[scan],
                  out_p, captured);
                delivered = delivered + 1;
                -> rx_activity;
              end
            if (!matched) fail("output data mismatch");
          end
        end
      end
    end
  end

  initial begin
    integer i;
    integer pkt;
    real head_ns, body_ns, tail_ns, cycle_ns, mflit_s;
    if (!$value$plusargs("CLOCK_NS=%f", clock_ns)) clock_ns = 1.0;
    if (!$value$plusargs("EVENT_CSV=%s", event_csv)) event_csv = "hop_events.csv";
    if (!$value$plusargs("VCD=%s", vcd_file)) vcd_file = "hop_ppa.vcd";
    if (!$value$plusargs("HOP_KIND=%s", hop_kind)) hop_kind = "unknown";
    if (!$value$plusargs("HOP_MODE=%s", hop_mode)) hop_mode = "isolated";
    if (!$value$plusargs("NUM_PACKETS=%d", num_packets)) num_packets = 1;
    if (hop_mode == "stream" && num_packets < 2) num_packets = 4;
    if (hop_mode == "idle") num_packets = 0;
    if (hop_mode == "contention") num_packets = 2;
    if (hop_mode == "isolated") num_packets = 1;
    expected_total = num_packets * NUM_FLITS;
    event_fd = $fopen(event_csv, "w");
    if (event_fd == 0) begin $display("PPA_FAIL cannot open EVENT_CSV"); $finish(2); end
    $fdisplay(event_fd, "packet,flit,input_req_ns,output_req_ns,hop_latency_ns,out_port,data_hex");
    $dumpfile(vcd_file);
    $dumpvars(0, tb_sync_cmr_router_hop_ppa);
    for (i = 0; i < MAX_EVENTS; i = i + 1) expected_seen[i] = 1'b0;
    for (pkt = 0; pkt < num_packets; pkt = pkt + 1)
      prepare_packet(pkt, pkt[1:0] + 2'd1);
    $display("PPA_INFO mode=%s clock_ns=%0.3f ports=%0d packets=%0d",
      hop_mode, clock_ns, NUM_PORTS, num_packets);
    repeat (8) @(posedge clock);
    reset = 1'b0;
    repeat (4) @(posedge clock);
    running = 1'b1;
    if (hop_mode == "idle") begin
      repeat (50) @(posedge clock);
    end else begin
      fork
        begin
          if (hop_mode == "contention") begin
            fork
              drive_port(0, 0, 1'b1);
              drive_port(CHILD_LANES, 1, 1'b1);
            join
          end else begin
            for (pkt = 0; pkt < num_packets; pkt = pkt + 1)
              drive_port(0, pkt, hop_mode != "stream");
          end
          while (delivered < expected_total) @rx_activity;
        end
        begin
          repeat (200000) @(posedge clock);
          if (delivered < expected_total) fail("output timeout");
        end
      join_any
      disable fork;
    end
    repeat (4) @(posedge clock);
    $display("PPA_WINDOW start=%0.3f end=%0.3f", 8.0 * clock_ns, $realtime);
    $fclose(event_fd);
    if (hop_mode == "idle") begin
      if (failures == 0 && delivered == 0)
        $display("PPA_RESULT PASS geometry=%s mode=idle", hop_kind);
      else
        $display("PPA_RESULT FAIL failures=%0d delivered=%0d mode=idle", failures, delivered);
    end else if (failures == 0 && delivered == expected_total) begin
      head_ns = hop_latency[0];
      body_ns = (hop_latency[1] + hop_latency[2] + hop_latency[3]) / 3.0;
      tail_ns = hop_latency[NUM_FLITS - 1];
      cycle_ns = clock_ns;
      mflit_s = 1000.0 / clock_ns;
      $display("PPA_RESULT PASS geometry=%s mode=%s lane=%0d head_ns=%0.3f body_ns=%0.3f tail_ns=%0.3f cycle_ns=%0.3f mflit_s=%0.3f",
        hop_kind, hop_mode, selected_out, head_ns, body_ns, tail_ns, cycle_ns, mflit_s);
    end else
      $display("PPA_RESULT FAIL failures=%0d delivered=%0d expected=%0d",
        failures, delivered, expected_total);
    $finish(failures);
  end
endmodule
