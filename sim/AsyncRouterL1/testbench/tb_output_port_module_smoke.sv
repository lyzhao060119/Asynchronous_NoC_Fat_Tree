`timescale 1ns/1ps

module tb_output_port_module_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg [3:0] req = 4'b0;
  reg [3:0] ppe = 4'b0;
  reg [27:0] data [0:3];
  reg ack_out = 1'b0;

  wire [3:0] ack;
  wire [3:0] grant;
  wire [3:0] mg;
  wire req_out;
  wire [27:0] data_out;
  wire [3:0] tail_passed;

  OutputPortModule dut (
    .clock(clock), .reset(reset),
    .io_Req_0(req[0]), .io_Req_1(req[1]), .io_Req_2(req[2]), .io_Req_3(req[3]),
    .io_PPE_0(ppe[0]), .io_PPE_1(ppe[1]), .io_PPE_2(ppe[2]), .io_PPE_3(ppe[3]),
    .io_DataX_0_flit(data[0]), .io_DataX_1_flit(data[1]),
    .io_DataX_2_flit(data[2]), .io_DataX_3_flit(data[3]),
    .io_AckOut(ack_out),
    .io_Ack_0(ack[0]), .io_Ack_1(ack[1]), .io_Ack_2(ack[2]), .io_Ack_3(ack[3]),
    .io_Grant_0(grant[0]), .io_Grant_1(grant[1]), .io_Grant_2(grant[2]), .io_Grant_3(grant[3]),
    .io_MG_0(mg[0]), .io_MG_1(mg[1]), .io_MG_2(mg[2]), .io_MG_3(mg[3]),
    .io_ReqOut(req_out), .io_DataOut_flit(data_out),
    .io_TailPassed_0(tail_passed[0]), .io_TailPassed_1(tail_passed[1]),
    .io_TailPassed_2(tail_passed[2]), .io_TailPassed_3(tail_passed[3])
  );

  // The OPM is asynchronous. Its inherited Chisel clock is intentionally
  // irrelevant, but toggling it proves that no functional state depends on it.
  always #5 clock = ~clock;

  task automatic fail(input [8*120-1:0] message);
    begin
      $display("TB_RESULT FAIL %0s at %0t", message, $time);
      $display("  req=%b ppe=%b ack=%b grant=%b mg=%b req_out=%b ack_out=%b tail=%b data_out=%h",
        req, ppe, ack, grant, mg, req_out, ack_out, tail_passed, data_out);
      $finish(1);
    end
  endtask

  task automatic check(input condition, input [8*120-1:0] message);
    begin
      if (!condition)
        fail(message);
    end
  endtask

  task automatic set_flit(
    input integer source,
    input is_head,
    input is_tail,
    input [7:0] payload
  );
    begin
      data[source] = 28'b0;
      data[source][27] = is_head;
      data[source][26] = is_tail;
      data[source][7:0] = payload;
    end
  endtask

  task automatic select_source(input integer source);
    begin
      ppe = 4'b0001 << source;
      #1;
      check(grant === ppe, "Grant must directly monitor pre-arbitrated PPE");
      check(mg === ppe, "MG must pass Grant while TP is clear");
      check(tail_passed === 4'b0000, "a new owner must start with TP clear");
    end
  endtask

  task automatic launch_flit(
    input integer source,
    input is_head,
    input is_tail,
    input [7:0] payload
  );
    reg old_req;
    begin
      set_flit(source, is_head, is_tail, payload);
      old_req = req[source];
      #1;
      req[source] = ~old_req;
      #1;
      check(req_out === req[source], "L1-L4 XOR and L5 did not forward the selected request");
      check(data_out === data[source], "one-hot Xbar and data latch selected the wrong flit");
      check(ack[source] === req[source], "Ack DFF did not sample the selected request");
      check((ack & ~(4'b0001 << source)) === 4'b0000,
        "an unselected source received an acknowledgement");
    end
  endtask

  task automatic complete_downstream;
    begin
      ack_out = req_out;
      #1;
      check(req_out === ack_out, "RegEnable did not reopen after downstream acknowledgement");
    end
  endtask

  task automatic release_source(input integer source);
    begin
      ppe[source] = 1'b0;
      #1;
      check(grant[source] === 1'b0, "Grant did not follow PPE release");
      check(tail_passed[source] === 1'b0, "low Grant did not asynchronously clear TP");
      check(mg[source] === 1'b0, "released source retained MG");
    end
  endtask

  integer source;
  reg [27:0] held_data;
  reg held_req;
  reg held_ack;

  initial begin
    data[0] = 28'b0;
    data[1] = 28'b0;
    data[2] = 28'b0;
    data[3] = 28'b0;

    #2;
    reset = 1'b0;
    #2;
    check(ack === 4'b0000, "Ack reset state mismatch");
    check(grant === 4'b0000 && mg === 4'b0000, "Grant/MG reset state mismatch");
    check(req_out === 1'b0 && data_out === 28'b0, "V2 reset state mismatch");
    check(tail_passed === 4'b0000, "TP reset state mismatch");

    // Source 0: Head followed by two Body flits and a Tail. Atomic admission
    // keeps PPE one-hot for the complete packet.
    select_source(0);
    launch_flit(0, 1'b1, 1'b0, 8'h11);
    check(tail_passed === 4'b0000 && mg === 4'b0001,
      "Head must not set TP or withdraw MG");

    // While downstream is busy, L5 and the data latch must remain opaque.
    held_data = data_out;
    held_req = req_out;
    held_ack = ack[0];
    set_flit(0, 1'b0, 1'b0, 8'h22);
    req[0] = ~req[0];
    #2;
    check(req_out === held_req && data_out === held_data && ack[0] === held_ack,
      "Body crossed V2 while AckOut was pending");

    // AckOut reopens V2; the already waiting Body passes and closes it again.
    ack_out = held_req;
    #2;
    check(req_out === req[0] && data_out === data[0] && data_out[7:0] === 8'h22,
      "first Body did not pass when RegEnable reopened");
    check(ack[0] === req[0] && tail_passed === 4'b0000 && mg === 4'b0001,
      "first Body acknowledgement or TP/MG state mismatch");

    // Queue a second Body under backpressure and release it in the same way.
    held_req = req_out;
    set_flit(0, 1'b0, 1'b0, 8'h23);
    req[0] = ~req[0];
    #2;
    check(req_out === held_req && data_out[7:0] === 8'h22,
      "second Body crossed V2 before AckOut");
    ack_out = held_req;
    #2;
    check(req_out === req[0] && data_out[7:0] === 8'h23 && ack[0] === req[0],
      "second Body did not pass after AckOut");
    check(tail_passed === 4'b0000 && mg === 4'b0001,
      "Body incorrectly changed TP or MG");

    // Queue Tail while V2 is opaque. On the next reopen/capture edge the TP
    // DFF samples isTail=1, masks MG, and reports TailPassed.
    held_req = req_out;
    set_flit(0, 1'b0, 1'b1, 8'h33);
    req[0] = ~req[0];
    #2;
    check(req_out === held_req && tail_passed === 4'b0000,
      "Tail passed before downstream accepted the previous Body");
    ack_out = held_req;
    #2;
    check(req_out === req[0] && data_out === data[0] && ack[0] === req[0],
      "Tail request/data/Ack capture mismatch");
    check(tail_passed === 4'b0001, "Tail capture did not set the winning TP DFF");
    check(grant === 4'b0001 && mg === 4'b0000,
      "TP must mask MG before the Request Generator releases PPE");

    complete_downstream;
    check(tail_passed === 4'b0001,
      "TailPassed must remain high until the source releases PPE");
    release_source(0);

    // A request transition on an unselected input remains behind its opaque
    // Request Selection latch.
    set_flit(1, 1'b1, 1'b1, 8'h41);
    req[1] = ~req[1];
    held_req = req_out;
    held_data = data_out;
    #2;
    check(req_out === held_req && data_out === held_data && ack[1] === 1'b0,
      "unselected source crossed Request Selection");
    // Return the external two-phase wire to its original phase while its
    // Request Selection latch is still opaque, leaving no queued transaction.
    req[1] = ~req[1];
    #1;
    check(req_out === held_req && ack[1] === 1'b0,
      "unselected phase restoration crossed Request Selection");

    // Exercise every physical source as a new one-flit packet owner.
    for (source = 1; source < 4; source = source + 1) begin
      set_flit(source, 1'b1, 1'b1, 8'h40 + source);
      select_source(source);
      req[source] = ~req[source];
      #2;
      check(req_out !== ack_out && data_out === data[source],
        "new source did not create an output transition through XOR4/L5");
      check(ack[source] === req[source], "new source did not receive its Ack");
      check(tail_passed === (4'b0001 << source),
        "TailPassed identified the wrong source");
      check(mg === 4'b0000, "one-flit Tail must mask MG");
      complete_downstream;
      release_source(source);
    end

    check(ppe === 4'b0000 && grant === 4'b0000 && mg === 4'b0000,
      "final OPM state is not idle");
    $display("TB_RESULT PASS paper-faithful OPM latch/head-body-tail smoke");
    $finish;
  end
endmodule
