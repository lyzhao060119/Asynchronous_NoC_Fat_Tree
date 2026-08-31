`timescale 1ns/1ps

// DATE V3 R-U5 hop: 5-flit unicast, empty router, no contention, fixed
// input -> output.  Plusargs:
//   HOP_MODE=isolated|stream|idle|contention
//   MESH=1  dest (1,0) East from router (0,0); default tree dest (8,8) parent
module tb_cmr_router_hop_ppa;
`ifdef GEOM_C4_P8
  localparam integer CHILD_LANES = 4;
  localparam integer PARENT_LANES = 8;
`elsif GEOM_C2_P4
  localparam integer CHILD_LANES = 2;
  localparam integer PARENT_LANES = 4;
`elsif GEOM_C2_P2
  localparam integer CHILD_LANES = 2;
  localparam integer PARENT_LANES = 2;
`elsif GEOM_C1_P2
  localparam integer CHILD_LANES = 1;
  localparam integer PARENT_LANES = 2;
`elsif FAT_22
  localparam integer CHILD_LANES = 2;
  localparam integer PARENT_LANES = 2;
`elsif FAT_L1
  localparam integer CHILD_LANES = 1;
  localparam integer PARENT_LANES = 2;
`else
  localparam integer CHILD_LANES = 1;
  localparam integer PARENT_LANES = 1;
`endif
  localparam integer NUM_PORTS = 4 * CHILD_LANES + PARENT_LANES;
  localparam integer PARENT_BASE = 4 * CHILD_LANES;
  localparam integer EAST_BASE = 2 * CHILD_LANES;
  localparam integer FLIT_W = 28;
  localparam integer NUM_FLITS = 5;
  localparam integer MAX_EVENTS = 64;

  wire unused_clock = 1'b0;
  reg reset = 1'b1;
  reg running = 1'b0;

  reg [NUM_PORTS-1:0] tb_in_req = '0;
  wire [NUM_PORTS-1:0] tb_in_ack;
  reg [NUM_PORTS*FLIT_W-1:0] tb_in_data = '0;
  wire [NUM_PORTS-1:0] tb_out_req;
  reg [NUM_PORTS-1:0] tb_out_ack = '0;
  wire [NUM_PORTS*FLIT_W-1:0] tb_out_data;

  real tx_setup_ns, rx_capture_ns, ack_to_next_req_guard_ns;
  integer event_fd;
  integer failures = 0;
  integer selected_out = -1;
  integer delivered = 0;
  integer last_egress_ps [0:NUM_PORTS-1];
  integer num_packets;
  integer expected_total;
  integer mesh_mode;
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

  function automatic [FLIT_W-1:0] make_flit(
    input bit head, input bit tail, input [1:0] id
  );
    begin
      make_flit = {FLIT_W{1'b0}};
      make_flit[27] = head;
      make_flit[26] = tail;
      if (mesh_mode) begin
        make_flit[7:2] = 6'd1;
        make_flit[13:8] = 6'd0;
        make_flit[19:14] = 6'd1;
        make_flit[25:20] = 6'd0;
      end else begin
        make_flit[25:20] = 6'd8;
        make_flit[19:14] = 6'd8;
        make_flit[13:8] = 6'd8;
        make_flit[7:2] = 6'd8;
      end
      make_flit[1:0] = id;
    end
  endfunction

  function integer now_ps;
    real t;
    begin
      t = $realtime * 1000.0;
      now_ps = $rtoi(t + 0.5);
    end
  endfunction

  function automatic bit is_legal_out(input integer port);
    begin
      if (mesh_mode)
        is_legal_out = (port >= EAST_BASE) && (port < EAST_BASE + CHILD_LANES);
      else
        is_legal_out = (port >= PARENT_BASE) && (port < NUM_PORTS);
    end
  endfunction

  task automatic fail(input string message);
    begin
      failures = failures + 1;
      $display("PPA_FAIL %s t=%0.3f", message, $realtime);
    end
  endtask

`ifdef GEOM_C4_P8
  CMRRouter dut (
`include "async_ports_c4_p8.vi"
  );
`elsif GEOM_C2_P4
  CMRRouter dut (
`include "async_ports_c2_p4.vi"
  );
`elsif GEOM_C2_P2
  CMRRouter dut (
`include "async_ports_c2_p2.vi"
  );
`elsif GEOM_C1_P2
  CMRRouter dut (
`include "async_ports_c1_p2.vi"
  );
`elsif FAT_22
  CMRRouter dut (
`include "async_ports_c2_p2.vi"
  );
`elsif FAT_L1
  CMRRouter dut (
`include "async_ports_c1_p2.vi"
  );
`else
  CMRRouter dut (
`include "async_ports_c1_p1.vi"
  );
`endif

  task automatic wait_outputs_idle;
    integer p;
    begin
      for (p = 0; p < NUM_PORTS; p = p + 1)
        if (is_legal_out(p))
          wait (tb_out_req[p] === tb_out_ack[p]);
    end
  endtask

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
    begin
      for (f = 0; f < NUM_FLITS; f = f + 1) begin
        idx = pkt * NUM_FLITS + f;
        if (f > 0 || pkt > 0) begin
          if (wait_rx)
            while (expected_seen[idx - 1] !== 1'b1) @rx_activity;
          wait (tb_in_req[port] === tb_in_ack[port]);
          if (wait_rx)
            wait_outputs_idle();
          if (ack_to_next_req_guard_ns > 0.0) #(ack_to_next_req_guard_ns);
        end else begin
          wait (tb_in_req[port] === tb_in_ack[port]);
        end
        tb_in_data[port*FLIT_W +: FLIT_W] = expected_flit[idx];
        #(tx_setup_ns);
        input_time[idx] = $realtime;
        tb_in_req[port] = ~tb_in_req[port];
        wait (tb_in_req[port] === tb_in_ack[port]);
      end
    end
  endtask

  task automatic receive_port(input integer port);
    integer scan;
    integer matched;
    reg [FLIT_W-1:0] captured;
    begin
      forever begin
        wait (running && (tb_out_req[port] !== tb_out_ack[port]));
        if ((tb_out_req[port] === 1'bx) || (tb_out_ack[port] === 1'bx) ||
            (^tb_out_data[port*FLIT_W +: FLIT_W] === 1'bx))
          fail("boundary X/Z");
        #(rx_capture_ns);
        captured = tb_out_data[port*FLIT_W +: FLIT_W];
        if (!is_legal_out(port)) begin
          fail("packet left on an unexpected port");
          $display("PPA_DEBUG bad_port=%0d data=%h", port, captured);
        end else begin
          matched = 0;
          for (scan = 0; scan < expected_total; scan = scan + 1)
            if (!matched && !expected_seen[scan] && captured === expected_flit[scan]) begin
              expected_seen[scan] = 1'b1;
              matched = 1;
              if (selected_out < 0) selected_out = port;
              else if (hop_mode != "contention" && selected_out != port)
                fail("packet migrated between output lanes");
              output_time[scan] = last_egress_ps[port] / 1000.0;
              hop_latency[scan] = output_time[scan] - input_time[scan];
              $fdisplay(event_fd, "%0d,%0d,%0.3f,%0.3f,%0.3f,%0d,%h",
                event_packet[scan], event_flit[scan],
                input_time[scan], output_time[scan], hop_latency[scan],
                port, captured);
              delivered = delivered + 1;
            end
          if (!matched) fail("output data mismatch");
        end
        tb_out_ack[port] = tb_out_req[port];
        -> rx_activity;
      end
    end
  endtask

  genvar gp;
  generate
    for (gp = 0; gp < NUM_PORTS; gp = gp + 1) begin : g_node_monitors
      always @(tb_out_req[gp])
        if (running && (tb_out_req[gp] !== tb_out_ack[gp]))
          last_egress_ps[gp] = now_ps();
      initial receive_port(gp);
    end
  endgenerate

  initial begin
    integer i;
    integer pkt;
    real head_ns, body_ns, tail_ns, cycle_ns, mflit_s;
    if (!$value$plusargs("RX_CAPTURE_NS=%f", rx_capture_ns)) rx_capture_ns = 0.09;
    if (!$value$plusargs("TX_SETUP_NS=%f", tx_setup_ns)) tx_setup_ns = 0.05;
    if (!$value$plusargs("ACK_TO_NEXT_REQ_GUARD_NS=%f", ack_to_next_req_guard_ns))
      ack_to_next_req_guard_ns = 0.20;
    if (!$value$plusargs("EVENT_CSV=%s", event_csv)) event_csv = "hop_events.csv";
    if (!$value$plusargs("VCD=%s", vcd_file)) vcd_file = "hop_ppa.vcd";
    if (!$value$plusargs("HOP_KIND=%s", hop_kind)) hop_kind = "unknown";
    if (!$value$plusargs("HOP_MODE=%s", hop_mode)) hop_mode = "isolated";
    if (!$value$plusargs("NUM_PACKETS=%d", num_packets)) num_packets = 1;
    if (!$value$plusargs("MESH=%d", mesh_mode)) mesh_mode = 0;
    if (hop_mode == "stream" && num_packets < 2) num_packets = 4;
    if (hop_mode == "idle") num_packets = 0;
    if (hop_mode == "contention") num_packets = 2;
    if (hop_mode == "isolated") num_packets = 1;
    expected_total = num_packets * NUM_FLITS;
    if (expected_total > MAX_EVENTS) begin
      $display("PPA_FAIL too many events");
      $finish(2);
    end
    event_fd = $fopen(event_csv, "w");
    if (event_fd == 0) begin $display("PPA_FAIL cannot open EVENT_CSV"); $finish(2); end
    $fdisplay(event_fd, "packet,flit,input_req_ns,output_req_ns,hop_latency_ns,out_port,data_hex");
    $dumpfile(vcd_file);
    $dumpvars(0, tb_cmr_router_hop_ppa);
    for (i = 0; i < MAX_EVENTS; i = i + 1) expected_seen[i] = 1'b0;
    for (i = 0; i < NUM_PORTS; i = i + 1) last_egress_ps[i] = -1;
    for (pkt = 0; pkt < num_packets; pkt = pkt + 1)
      prepare_packet(pkt, pkt[1:0] + 2'd1);
    $display("PPA_INFO mode=%s mesh=%0d ports=%0d parent_base=%0d east_base=%0d packets=%0d",
      hop_mode, mesh_mode, NUM_PORTS, PARENT_BASE, EAST_BASE, num_packets);
    $display("PPA_INFO geometry=%s child=%0d parent=%0d", hop_kind, CHILD_LANES, PARENT_LANES);
    #200 reset = 1'b0;
    #10;
    running = 1'b1;
    if (hop_mode == "idle") begin
      #50;
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
          #(200000.0);
          if (delivered < expected_total) fail("output request timeout");
        end
      join_any
      disable fork;
    end
    #20;
    $display("PPA_WINDOW start=%0.3f end=%0.3f", 210.0, $realtime);
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
      if (hop_mode == "stream" && num_packets > 1 &&
          input_time[(num_packets - 1) * NUM_FLITS] > input_time[0])
        cycle_ns = (input_time[(num_packets - 1) * NUM_FLITS] - input_time[0]) /
          (num_packets - 1);
      else
        cycle_ns = (output_time[expected_total - 1] - input_time[0]) / expected_total;
      mflit_s = (cycle_ns > 0.0) ? (1000.0 / cycle_ns) : 0.0;
      $display("PPA_RESULT PASS geometry=%s mode=%s lane=%0d head_ns=%0.3f body_ns=%0.3f tail_ns=%0.3f cycle_ns=%0.3f mflit_s=%0.3f",
        hop_kind, hop_mode, selected_out, head_ns, body_ns, tail_ns, cycle_ns, mflit_s);
    end else
      $display("PPA_RESULT FAIL failures=%0d delivered=%0d expected=%0d",
        failures, delivered, expected_total);
    $finish(failures);
  end
endmodule
