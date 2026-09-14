`timescale 1ns/1ps

// Single c1p4 router, fixed child-0 to parent-3 route. The next flit is
// offered as soon as the preceding input acknowledgement returns; packet
// boundaries receive exactly the same data setup as intra-packet boundaries.
module tb_cmr_router_hop_ppa;
  localparam integer FLIT_W = 28;
  localparam integer NUM_PORTS = 8;
  localparam integer INPUT_PORT = 0;
  localparam integer OUTPUT_PORT = 7;
  localparam integer FLITS_PER_PACKET = 5;
  localparam integer PACKETS = 10000;
  localparam integer TOTAL_FLITS = PACKETS * FLITS_PER_PACKET;

  wire unused_clock = 1'b0;
  reg reset = 1'b1;
  reg running = 1'b0;
  reg [NUM_PORTS-1:0] tb_in_req = '0;
  wire [NUM_PORTS-1:0] tb_in_ack;
  reg [NUM_PORTS*FLIT_W-1:0] tb_in_data = '0;
  wire [NUM_PORTS-1:0] tb_out_req;
  reg [NUM_PORTS-1:0] tb_out_ack = '0;
  wire [NUM_PORTS*FLIT_W-1:0] tb_out_data;
  integer sent = 0;
  integer received = 0;
  integer failures = 0;
  integer first_req_ps = -1;
  integer last_req_ps = -1;
  integer csv_fd;
  string event_csv;
  real setup_ns;
  real capture_ns;
  real span_ns;
  real throughput_mflit_s;
  real interval_rate_mflit_s;

  CMRRouter dut (
`include "async_ports_c1_p4.vi"
  );

  function integer now_ps;
    real t;
    begin
      t = $realtime * 1000.0;
      now_ps = $rtoi(t + 0.5);
    end
  endfunction

  function automatic [FLIT_W-1:0] flit_for(input integer flit_index);
    integer packet;
    integer position;
    reg [FLIT_W-1:0] value;
    begin
      packet = flit_index / FLITS_PER_PACKET;
      position = flit_index % FLITS_PER_PACKET;
      value = 28'b0;
      value[27] = position == 0;
      value[26] = position == FLITS_PER_PACKET - 1;
      // All flits retain the accepted stream case's source/destination fields.
      value[25:20] = 6'd8;
      value[19:14] = 6'd8;
      value[13:8] = 6'd8;
      value[7:2] = 6'd8;
      value[1:0] = packet[1:0] + 2'd1;
      flit_for = value;
    end
  endfunction

  task automatic fail(input string reason);
    begin
      failures = failures + 1;
      $display("SUSTAINED_FAIL reason=%s sent=%0d received=%0d t=%0.3f",
               reason, sent, received, $realtime);
    end
  endtask

  task automatic receive_port(input integer port);
    reg [FLIT_W-1:0] captured;
    integer req_ps;
    begin
      forever begin
        wait (running && tb_out_req[port] !== tb_out_ack[port]);
        req_ps = now_ps();
        // One picosecond permits SDF output data to settle. Ack follows
        // immediately thereafter; there is no downstream throttling.
        #(capture_ns);
        captured = tb_out_data[port*FLIT_W +: FLIT_W];
        if (port != OUTPUT_PORT)
          fail("unexpected output port");
        else if (received >= TOTAL_FLITS)
          fail("extra output flit");
        else if ((^captured === 1'bx) || captured !== flit_for(received))
          fail("X or wrong flit/order");
        else begin
          if (received == 0) first_req_ps = req_ps;
          last_req_ps = req_ps;
          received = received + 1;
        end
        tb_out_ack[port] = tb_out_req[port];
      end
    end
  endtask

  genvar p;
  generate
    for (p = 0; p < NUM_PORTS; p = p + 1) begin : g_receivers
      initial receive_port(p);
    end
  endgenerate

  initial begin : watchdog
    #500000;
    fail("full-drain timeout");
    $display("PPA_RESULT FAIL mode=sustained");
    $finish(2);
  end

  initial begin : stimulus
    integer i;
    if (!$value$plusargs("EVENT_CSV=%s", event_csv)) event_csv = "hop_events.csv";
    if (!$value$plusargs("TX_SETUP_NS=%f", setup_ns)) setup_ns = 0.05;
    if (!$value$plusargs("RX_CAPTURE_NS=%f", capture_ns)) capture_ns = 0.001;
    if (setup_ns < 0.0 || capture_ns < 0.001) begin
      fail("invalid setup/capture delay");
      $finish(2);
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
    $display("SUSTAINED_INFO packets=%0d flits=%0d input=%0d output=%0d tx_setup_ns=%0.3f rx_ack_ns=%0.3f",
             PACKETS, TOTAL_FLITS, INPUT_PORT, OUTPUT_PORT, setup_ns, capture_ns);
    #200 reset = 1'b0;
    #10 running = 1'b1;
    for (i = 0; i < TOTAL_FLITS; i = i + 1) begin
      wait (tb_in_req[INPUT_PORT] === tb_in_ack[INPUT_PORT]);
      tb_in_data[INPUT_PORT*FLIT_W +: FLIT_W] = flit_for(i);
      #(setup_ns);
      tb_in_req[INPUT_PORT] = ~tb_in_req[INPUT_PORT];
      sent = sent + 1;
      wait (tb_in_req[INPUT_PORT] === tb_in_ack[INPUT_PORT]);
    end
    wait (received == TOTAL_FLITS || failures != 0);
    #5;
    if (failures == 0 && sent == TOTAL_FLITS && received == TOTAL_FLITS &&
        tb_out_req[OUTPUT_PORT] === tb_out_ack[OUTPUT_PORT] &&
        last_req_ps > first_req_ps) begin
      span_ns = (last_req_ps - first_req_ps) / 1000.0;
      throughput_mflit_s = 1000.0 * TOTAL_FLITS / span_ns;
      interval_rate_mflit_s = 1000.0 * (TOTAL_FLITS - 1) / span_ns;
      $fdisplay(csv_fd, "packets,sent_flits,received_flits,first_output_req_ps,last_output_req_ps,span_ns,throughput_mflit_s,interval_rate_mflit_s,failures");
      $fdisplay(csv_fd, "%0d,%0d,%0d,%0d,%0d,%0.3f,%0.6f,%0.6f,%0d",
                PACKETS, sent, received, first_req_ps, last_req_ps, span_ns,
                throughput_mflit_s, interval_rate_mflit_s, failures);
      $display("SUSTAINED_RESULT PASS packets=%0d sent=%0d received=%0d first_req_ps=%0d last_req_ps=%0d span_ns=%0.3f throughput_mflit_s=%0.6f interval_rate_mflit_s=%0.6f",
               PACKETS, sent, received, first_req_ps, last_req_ps, span_ns,
               throughput_mflit_s, interval_rate_mflit_s);
      $display("PPA_RESULT PASS geometry=async_fat_1x4 mode=sustained");
    end else begin
      $display("PPA_RESULT FAIL geometry=async_fat_1x4 mode=sustained sent=%0d received=%0d failures=%0d",
               sent, received, failures);
    end
    $fclose(csv_fd);
    $finish(failures);
  end
endmodule
