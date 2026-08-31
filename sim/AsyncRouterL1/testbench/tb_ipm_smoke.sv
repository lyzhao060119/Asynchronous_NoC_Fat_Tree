`timescale 1ns/1ps

module tb_ipm_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg req_in = 1'b0;
  reg [27:0] data_in = 28'b0;
  reg [3:0] done = 4'b0;
  reg tail_release_ready = 1'b1;

  wire ack_in;
  wire req_x;
  wire [27:0] data_x;
  wire [3:0] rs;

  IPM dut (
    .reset(reset),
    .io_ReqIn(req_in), .io_DataIn_flit(data_in),
    .io_Done_0(done[0]), .io_Done_1(done[1]),
    .io_Done_2(done[2]), .io_Done_3(done[3]),
    .io_tailReleaseReady(tail_release_ready),
    .io_AckIn(ack_in), .io_ReqX(req_x), .io_DataX_flit(data_x),
    .io_RS_0(rs[0]), .io_RS_1(rs[1]), .io_RS_2(rs[2]), .io_RS_3(rs[3])
  );

  always #5 clock = ~clock;

  task automatic check(input condition, input [8*160-1:0] message);
    begin
      if (!condition) begin
        $display("TB_RESULT FAIL %0s t=%0t req=%b ack=%b reqX=%b data=%h rs=%b done=%b",
          message, $time, req_in, ack_in, req_x, data_x, rs, done);
        $finish(1);
      end
    end
  endtask

  initial begin
    #2;
    reset = 1'b0;
    #2;
    check(req_x == 1'b0 && ack_in == 1'b0 && data_x == 28'b0 && rs == 4'b0,
      "reset must clear both V1 latches and route selection");

    // Parent ingress, rectangle (0,0)-(1,0): legal branches 1 and 3.
    data_in = 28'h8004000;
    req_in = 1'b1;
    #2;
    check(req_x == 1'b1 && ack_in == 1'b1,
      "V1 request latch must capture and acknowledge the input phase");
    check(data_x == 28'h8004000, "V1 data latch must capture the Head");
    check(rs == 4'b1010, "PRS must expose the raw two-target Head route");

    // V1 is opaque while PRS is active; a queued Body cannot overwrite Head.
    data_in = 28'h0000055;
    req_in = 1'b0;
    #1;
    check(req_x == 1'b1 && ack_in == 1'b1 && data_x == 28'h8004000,
      "queued Body crossed the opaque request/data latches");

    // Ultra Fig. 5(a)'s completion signal is already high while Done=0.
    // It is an event clock, so this steady level must not sample ReqX or
    // release V1 before any branch activity occurs.
    #3;
    check(req_x == 1'b1 && data_x == 28'h8004000 && rs == 4'b1010,
      "steady Done=0 level incorrectly triggered AckGenerator");

    // The selected ReqGenerators make Done nonzero, producing the falling
    // half of the completion event. A falling edge cannot sample the Ack DFF.
    done = 4'b1010;
    #1;
    check(req_x == 1'b1 && data_x == 28'h8004000 && rs == 4'b1010,
      "Done rising incorrectly advanced AckGenerator");

    // One branch finishing is insufficient.
    done = 4'b1000;
    #1;
    check(req_x == 1'b1 && data_x == 28'h8004000,
      "partial multicast completion reopened V1");

    // All branches complete: AckGenerator catches ReqX, PRS becomes idle and
    // the already waiting Body becomes visible through both V1 latches.
    done = 4'b0000;
    #1;
    check(req_x == 1'b0 && ack_in == 1'b0,
      "all Done=0 did not release the queued input phase");
    check(data_x == 28'h0000055, "V1 data latch did not advance to queued Body");
    check(rs == 4'b0000, "Body must bypass PRS rather than compute a new route");

    // Tail is different: all branches may finish, but the input front end
    // remains closed until Atomic has released the packet's full output set.
    reset = 1'b1; done = 4'b0; tail_release_ready = 1'b0; #1;
    reset = 1'b0; #1;
    data_in = 28'h4400055; // isTail=1, isHead=0
    req_in = 1'b1; #1;
    check(req_x == 1'b1 && ack_in == 1'b1 && data_x == 28'h4400055,
      "Tail did not enter V1");
    done = 4'b0001; #1;
    done = 4'b0000; #1;
    check(req_x == 1'b1 && ack_in == 1'b1,
      "Tail completion bypassed Atomic release barrier");
    req_in = 1'b0; data_in = 28'h0000066; #1;
    check(req_x == 1'b1 && data_x == 28'h4400055,
      "next packet crossed V1 before Tail release");
    tail_release_ready = 1'b1; #1;
    check(req_x == 1'b0 && ack_in == 1'b0 && data_x == 28'h0000066,
      "Tail release did not reopen V1 for the next packet");

    // Reset is asynchronous to every event clock used in the front end.
    reset = 1'b1;
    #0.2;
    check(req_x == 1'b0 && ack_in == 1'b0 && data_x == 28'b0 && rs == 4'b0,
      "mid-transaction reset did not clear IPM state");

    $display("TB_RESULT PASS IPM V1 latches raw-RS paper Ack edge");
    $finish;
  end
endmodule
