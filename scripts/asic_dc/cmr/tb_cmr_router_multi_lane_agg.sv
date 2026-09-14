`timescale 1ns/1ps

// Four concurrent child-side sources, all requesting the parent logical
// direction.  Selector chooses physical parent lanes.  No artificial inter-
// packet gaps beyond handshake completion.  Reports aggregate parent-egress
// throughput after full drain.
module tb_cmr_router_hop_ppa;
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

  wire unused_clock = 1'b0;
  reg reset = 1'b1;
  reg running = 1'b0;
  reg [NUM_PORTS-1:0] tb_in_req = '0;
  wire [NUM_PORTS-1:0] tb_in_ack;
  reg [NUM_PORTS*FLIT_W-1:0] tb_in_data = '0;
  wire [NUM_PORTS-1:0] tb_out_req;
  reg [NUM_PORTS-1:0] tb_out_ack = '0;
  wire [NUM_PORTS*FLIT_W-1:0] tb_out_data;

  integer packets_per_source;
  integer total_flits;
  integer sent = 0;
  integer received = 0;
  integer failures = 0;
  integer first_req_ps = -1;
  integer last_req_ps = -1;
  integer expect_phase [0:NUM_SOURCES-1];
  integer expect_pkt [0:NUM_SOURCES-1];
  integer sent_src [0:NUM_SOURCES-1];
  integer csv_fd;
  string event_csv;
  string hop_kind;
  real setup_ns;
  real capture_ns;
  real span_ns;
  real throughput_mflit_s;
  real throughput_gflit_s;

`ifdef GEOM_C1_P4
  CMRRouter dut (
`include "async_ports_c1_p4.vi"
  );
`elsif GEOM_C1_P2
  CMRRouter dut (
`include "async_ports_c1_p2.vi"
  );
`else
  CMRRouter dut (
`include "async_ports_c1_p1.vi"
  );
`endif

  function integer now_ps;
    real t;
    begin
      t = $realtime * 1000.0;
      now_ps = $rtoi(t + 0.5);
    end
  endfunction

  // Header keeps (8,8) so RCU selects parent.  Body/Tail carry self-identifying
  // payload so interleaved parent-lane arrivals remain checkable.
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

  // Single sequential receiver avoids races on received/expect_* when multiple
  // parent lanes fire in the same timestep.
  task automatic receive_scan;
    reg [FLIT_W-1:0] captured;
    integer req_ps;
    integer src;
    integer ph;
    integer pk;
    integer port;
    integer pending;
    begin
      forever begin
        wait (running);
        pending = 0;
        for (port = 0; port < NUM_PORTS; port = port + 1)
          if (tb_out_req[port] !== tb_out_ack[port]) pending = 1;
        if (!pending) begin
          @(tb_out_req or tb_out_ack or running);
        end else begin
          for (port = 0; port < NUM_PORTS; port = port + 1) begin
            if (tb_out_req[port] !== tb_out_ack[port]) begin
              req_ps = now_ps();
              #(capture_ns);
              captured = tb_out_data[port*FLIT_W +: FLIT_W];
              if (port < PARENT_BASE)
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
                    if (first_req_ps < 0) first_req_ps = req_ps;
                    if (req_ps > last_req_ps) last_req_ps = req_ps;
                    received = received + 1;
                    if (ph == FLITS_PER_PACKET - 1) begin
                      expect_phase[src] = 0;
                      expect_pkt[src] = pk + 1;
                    end else
                      expect_phase[src] = ph + 1;
                  end
                end
              end
              tb_out_ack[port] = tb_out_req[port];
            end
          end
        end
      end
    end
  endtask

  task automatic drive_source(input integer src);
    integer pkt;
    integer flit;
    integer port;
    begin
      port = src * CHILD_LANES;
      for (pkt = 0; pkt < packets_per_source; pkt = pkt + 1) begin
        for (flit = 0; flit < FLITS_PER_PACKET; flit = flit + 1) begin
          wait (tb_in_req[port] === tb_in_ack[port]);
          tb_in_data[port*FLIT_W +: FLIT_W] = flit_for(src, pkt, flit);
          #(setup_ns);
          tb_in_req[port] = ~tb_in_req[port];
          sent_src[src] = sent_src[src] + 1;
          wait (tb_in_req[port] === tb_in_ack[port]);
        end
      end
    end
  endtask

  initial receive_scan;

  initial begin : watchdog
    #5000000;
    fail("full-drain timeout");
    $display("PPA_RESULT FAIL mode=multi_lane_agg");
    $finish(2);
  end

  initial begin : stimulus
    integer i;
    integer parent_idle;
    if (!$value$plusargs("EVENT_CSV=%s", event_csv)) event_csv = "hop_events.csv";
    if (!$value$plusargs("TX_SETUP_NS=%f", setup_ns)) setup_ns = 0.05;
    if (!$value$plusargs("RX_CAPTURE_NS=%f", capture_ns)) capture_ns = 0.09;
    if (!$value$plusargs("HOP_KIND=%s", hop_kind)) hop_kind = "unknown";
    if (!$value$plusargs("NUM_PACKETS=%d", packets_per_source))
      packets_per_source = DEFAULT_PACKETS;
    if (packets_per_source < 1) packets_per_source = DEFAULT_PACKETS;
    if (setup_ns < 0.0 || capture_ns < 0.001) begin
      fail("invalid setup/capture delay");
      $finish(2);
    end
    total_flits = NUM_SOURCES * packets_per_source * FLITS_PER_PACKET;
    for (i = 0; i < NUM_SOURCES; i = i + 1) begin
      expect_phase[i] = 0;
      expect_pkt[i] = 0;
      sent_src[i] = 0;
    end
    if (!$test$plusargs("NO_FULL_VCD")) begin
      $dumpfile("hop_ppa.vcd");
      $dumpvars(0, tb_cmr_router_hop_ppa);
    end
    csv_fd = $fopen(event_csv, "w");
    if (csv_fd == 0) begin
      fail("cannot open summary CSV");
      $finish(2);
    end
    $display("AGG_INFO sources=%0d packets_per_source=%0d total_flits=%0d parent_lanes=%0d tx_setup_ns=%0.3f rx_ack_ns=%0.3f kind=%s",
             NUM_SOURCES, packets_per_source, total_flits, PARENT_LANES,
             setup_ns, capture_ns, hop_kind);
    #200 reset = 1'b0;
    #10 running = 1'b1;
    fork
      drive_source(0);
      drive_source(1);
      drive_source(2);
      drive_source(3);
    join
    sent = sent_src[0] + sent_src[1] + sent_src[2] + sent_src[3];
    wait (received == total_flits || failures != 0);
    #5;
    parent_idle = 1;
    for (i = PARENT_BASE; i < NUM_PORTS; i = i + 1)
      if (tb_out_req[i] !== tb_out_ack[i]) parent_idle = 0;
    if (failures == 0 && sent == total_flits && received == total_flits &&
        parent_idle && last_req_ps > first_req_ps) begin
      span_ns = (last_req_ps - first_req_ps) / 1000.0;
      throughput_mflit_s = 1000.0 * total_flits / span_ns;
      throughput_gflit_s = throughput_mflit_s / 1000.0;
      $fdisplay(csv_fd, "sources,packets_per_source,sent_flits,received_flits,parent_lanes,first_output_req_ps,last_output_req_ps,span_ns,throughput_mflit_s,throughput_gflit_s,failures");
      $fdisplay(csv_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.3f,%0.6f,%0.6f,%0d",
                NUM_SOURCES, packets_per_source, sent, received, PARENT_LANES,
                first_req_ps, last_req_ps, span_ns,
                throughput_mflit_s, throughput_gflit_s, failures);
      $display("AGG_RESULT PASS sources=%0d packets_per_source=%0d sent=%0d received=%0d parent_lanes=%0d first_req_ps=%0d last_req_ps=%0d span_ns=%0.3f throughput_mflit_s=%0.6f throughput_gflit_s=%0.6f",
               NUM_SOURCES, packets_per_source, sent, received, PARENT_LANES,
               first_req_ps, last_req_ps, span_ns,
               throughput_mflit_s, throughput_gflit_s);
      $display("PPA_RESULT PASS geometry=%s mode=multi_lane_agg", hop_kind);
    end else begin
      $display("PPA_RESULT FAIL geometry=%s mode=multi_lane_agg sent=%0d received=%0d parent_idle=%0d failures=%0d",
               hop_kind, sent, received, parent_idle, failures);
    end
    $fclose(csv_fd);
    $finish(failures);
  end
endmodule
