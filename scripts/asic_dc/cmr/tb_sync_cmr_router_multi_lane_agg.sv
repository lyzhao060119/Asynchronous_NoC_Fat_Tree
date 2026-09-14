`timescale 1ns/1ps

// Synchronous counterpart of tb_cmr_router_multi_lane_agg: four concurrent
// child-side sources requesting parent, valid/ready, 1.0 ns clock.
module tb_sync_cmr_router_hop_ppa;
`ifdef GEOM_C1_P4
  localparam integer CHILD_LANES = 1;
  localparam integer PARENT_LANES = 4;
`elsif GEOM_C1_P2
  localparam integer CHILD_LANES = 1;
  localparam integer PARENT_LANES = 2;
`else
  localparam integer CHILD_LANES = 1;
  localparam integer PARENT_LANES = 1;
`endif
  localparam integer NUM_PORTS = 4 * CHILD_LANES + PARENT_LANES;
  localparam integer PARENT_BASE = 4 * CHILD_LANES;
  localparam integer NUM_SOURCES = 4;
  localparam integer FLIT_W = 28;
  localparam integer FLITS_PER_PACKET = 5;
  localparam integer DEFAULT_PACKETS = 1000;

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

  integer packets_per_source;
  integer total_flits;
  integer sent = 0;
  integer received = 0;
  integer failures = 0;
  integer first_cycle = -1;
  integer last_cycle = -1;
  integer cycle_count = 0;
  integer expect_phase [0:NUM_SOURCES-1];
  integer expect_pkt [0:NUM_SOURCES-1];
  integer sent_src [0:NUM_SOURCES-1];
  integer csv_fd;
  string event_csv;
  string hop_kind;
  real span_ns;
  real throughput_mflit_s;
  real throughput_gflit_s;

  always #(clock_ns / 2.0) clock = ~clock;

`ifdef GEOM_C1_P4
  SyncCmrRouter dut (
`include "sync_ports_c1_p4.vi"
  );
`elsif GEOM_C1_P2
  SyncCmrRouter dut (
`include "sync_ports_c1_p2.vi"
  );
`else
  SyncCmrRouter dut (
`include "sync_ports_c1_p1.vi"
  );
`endif

  function automatic [FLIT_W-1:0] flit_for(
    input integer src, input integer pkt, input integer flit
  );
    reg [FLIT_W-1:0] value;
    begin
      value = 28'b0;
      value[27] = (flit == 0);
      value[26] = (flit == FLITS_PER_PACKET - 1);
      if (flit == 0) begin
        value[25:20] = 6'd8;
        value[19:14] = 6'd8;
        value[13:8] = 6'd8;
        value[7:2] = 6'd8;
      end else begin
        value[25:12] = pkt[13:0];
        value[11:9] = flit[2:0];
        value[8:6] = 3'b101;
        value[5] = 1'b0;
      end
      value[1:0] = src[1:0];
      flit_for = value;
    end
  endfunction

  task automatic fail(input string reason);
    begin
      failures = failures + 1;
      $display("AGG_FAIL reason=%s sent=%0d received=%0d t=%0.3f",
               reason, sent, received, $realtime);
    end
  endtask

  task automatic drive_source(input integer src);
    integer pkt;
    integer flit;
    integer port;
    integer guard;
    begin
      port = src * CHILD_LANES;
      for (pkt = 0; pkt < packets_per_source; pkt = pkt + 1) begin
        for (flit = 0; flit < FLITS_PER_PACKET; flit = flit + 1) begin
          @(posedge clock);
          guard = 0;
          while (!tb_in_ready[port] && guard < 100000) begin
            @(posedge clock);
            guard = guard + 1;
          end
          if (!tb_in_ready[port]) begin
            fail("input ready timeout");
            disable drive_source;
          end
          tb_in_data[port*FLIT_W +: FLIT_W] = flit_for(src, pkt, flit);
          tb_in_valid[port] = 1'b1;
          @(posedge clock);
          tb_in_valid[port] = 1'b0;
          sent_src[src] = sent_src[src] + 1;
        end
      end
    end
  endtask

  integer rp;
  always @(posedge clock) begin
    if (!reset)
      cycle_count = cycle_count + 1;
    if (running) begin
      for (rp = 0; rp < NUM_PORTS; rp = rp + 1)
        tb_out_ready[rp] <= 1'b1;
    end
  end

  integer out_p;
  integer src;
  integer ph;
  integer pk;
  reg [FLIT_W-1:0] captured;
  always @(posedge clock) begin
    if (running) begin
      for (out_p = 0; out_p < NUM_PORTS; out_p = out_p + 1) begin
        if (tb_out_valid[out_p] && tb_out_ready[out_p]) begin
          captured = tb_out_data[out_p*FLIT_W +: FLIT_W];
          if (out_p < PARENT_BASE)
            fail("unexpected child output");
          else if ((^captured === 1'bx))
            fail("X on parent egress");
          else begin
            src = captured[1:0];
            if (src < 0 || src >= NUM_SOURCES)
              fail("bad source id");
            else begin
              ph = expect_phase[src];
              pk = expect_pkt[src];
              if (captured !== flit_for(src, pk, ph))
                fail("data/order mismatch");
              else begin
                if (received == 0) first_cycle = cycle_count;
                last_cycle = cycle_count;
                received = received + 1;
                if (ph == FLITS_PER_PACKET - 1) begin
                  expect_phase[src] = 0;
                  expect_pkt[src] = pk + 1;
                end else
                  expect_phase[src] = ph + 1;
              end
            end
          end
        end
      end
    end
  end

  initial begin : stimulus
    integer i;
    if (!$value$plusargs("CLOCK_NS=%f", clock_ns)) clock_ns = 1.0;
    if (!$value$plusargs("EVENT_CSV=%s", event_csv)) event_csv = "hop_events.csv";
    if (!$value$plusargs("HOP_KIND=%s", hop_kind)) hop_kind = "unknown";
    if (!$value$plusargs("NUM_PACKETS=%d", packets_per_source))
      packets_per_source = DEFAULT_PACKETS;
    if (packets_per_source < 1) packets_per_source = DEFAULT_PACKETS;
    total_flits = NUM_SOURCES * packets_per_source * FLITS_PER_PACKET;
    for (i = 0; i < NUM_SOURCES; i = i + 1) begin
      expect_phase[i] = 0;
      expect_pkt[i] = 0;
      sent_src[i] = 0;
    end
    csv_fd = $fopen(event_csv, "w");
    if (csv_fd == 0) begin
      fail("cannot open summary CSV");
      $finish(2);
    end
    $display("AGG_INFO sources=%0d packets_per_source=%0d total_flits=%0d parent_lanes=%0d clock_ns=%0.3f kind=%s",
             NUM_SOURCES, packets_per_source, total_flits, PARENT_LANES,
             clock_ns, hop_kind);
    repeat (8) @(posedge clock);
    reset = 1'b0;
    repeat (4) @(posedge clock);
    running = 1'b1;
    fork
      drive_source(0);
      drive_source(1);
      drive_source(2);
      drive_source(3);
      begin
        while (received < total_flits && failures == 0)
          @(posedge clock);
      end
      begin
        repeat (5000000) @(posedge clock);
        if (received < total_flits) fail("full-drain timeout");
      end
    join_any
    disable fork;
    sent = sent_src[0] + sent_src[1] + sent_src[2] + sent_src[3];
    repeat (4) @(posedge clock);
    if (failures == 0 && sent == total_flits && received == total_flits &&
        last_cycle > first_cycle) begin
      span_ns = (last_cycle - first_cycle) * clock_ns;
      throughput_mflit_s = 1000.0 * total_flits / span_ns;
      throughput_gflit_s = throughput_mflit_s / 1000.0;
      $fdisplay(csv_fd, "sources,packets_per_source,sent_flits,received_flits,parent_lanes,first_cycle,last_cycle,span_ns,throughput_mflit_s,throughput_gflit_s,failures");
      $fdisplay(csv_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.3f,%0.6f,%0.6f,%0d",
                NUM_SOURCES, packets_per_source, sent, received, PARENT_LANES,
                first_cycle, last_cycle, span_ns,
                throughput_mflit_s, throughput_gflit_s, failures);
      $display("AGG_RESULT PASS sources=%0d packets_per_source=%0d sent=%0d received=%0d parent_lanes=%0d first_cycle=%0d last_cycle=%0d span_ns=%0.3f throughput_mflit_s=%0.6f throughput_gflit_s=%0.6f",
               NUM_SOURCES, packets_per_source, sent, received, PARENT_LANES,
               first_cycle, last_cycle, span_ns,
               throughput_mflit_s, throughput_gflit_s);
      $display("PPA_RESULT PASS geometry=%s mode=multi_lane_agg", hop_kind);
    end else begin
      $display("PPA_RESULT FAIL geometry=%s mode=multi_lane_agg sent=%0d received=%0d failures=%0d",
               hop_kind, sent, received, failures);
    end
    $fclose(csv_fd);
    $finish(failures);
  end
endmodule
