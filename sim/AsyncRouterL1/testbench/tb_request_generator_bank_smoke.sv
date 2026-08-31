`timescale 1ns/1ps

module tb_request_generator_bank_smoke;
  reg reset = 1'b1;
  reg [3:0] rs = 4'b0;
  reg req_x = 1'b0;
  reg [3:0] ack = 4'b0;
  reg [3:0] grant = 4'b0;
  reg [3:0] mg = 4'b0;
  wire [3:0] req;
  wire [3:0] ppe;
  wire [3:0] done;

  RequestGeneratorBank dut (
    .reset(reset),
    .io_RS_0(rs[0]), .io_RS_1(rs[1]),
    .io_RS_2(rs[2]), .io_RS_3(rs[3]),
    .io_ReqX(req_x),
    .io_Ack_0(ack[0]), .io_Ack_1(ack[1]), .io_Ack_2(ack[2]), .io_Ack_3(ack[3]),
    .io_Grant_0(grant[0]), .io_Grant_1(grant[1]),
    .io_Grant_2(grant[2]), .io_Grant_3(grant[3]),
    .io_MG_0(mg[0]), .io_MG_1(mg[1]), .io_MG_2(mg[2]), .io_MG_3(mg[3]),
    .io_Req_0(req[0]), .io_Req_1(req[1]), .io_Req_2(req[2]), .io_Req_3(req[3]),
    .io_PPE_0(ppe[0]), .io_PPE_1(ppe[1]), .io_PPE_2(ppe[2]), .io_PPE_3(ppe[3]),
    .io_Done_0(done[0]), .io_Done_1(done[1]),
    .io_Done_2(done[2]), .io_Done_3(done[3])
  );

  task automatic check(input condition, input [8*160-1:0] message);
    begin
      if (!condition) begin
        $display("TB_RESULT FAIL %0s t=%0t RS=%b ReqX=%b req=%b ack=%b ppe=%b grant=%b mg=%b done=%b",
          message, $time, rs, req_x, req, ack, ppe, grant, mg, done);
        $finish(1);
      end
    end
  endtask

  initial begin
    #1;
    reset = 1'b0;
    #1;
    check(req == ack && ppe == 4'b0 && done == 4'b0,
      "bank reset state must be idle");

    // A multicast Head admits branches 1 and 3 together.
    req_x = 1'b1;
    rs = 4'b1010;
    #1;
    check(req == 4'b1010 && done == 4'b1010 && ppe == 4'b1010,
      "admitted Head did not establish exactly both selected branches");
    grant = ppe;
    mg = ppe;
    rs = 4'b0000;
    #1;
    check(req == 4'b1010 && ppe == 4'b1010,
      "PPE did not retain the packet route after Head RS disappeared");

    ack[3] = req[3];
    #0.2;
    check(done == 4'b0010, "first completed branch incorrectly finished multicast");
    ack[1] = req[1];
    #0.2;
    check(done == 4'b0000 && ppe == 4'b1010,
      "Head completion must retain both PPE paths");

    // Body bypasses PRS/RS and uses retained PPE.
    req_x = 1'b0;
    #0.3;
    check(req == 4'b0000 && done == 4'b1010,
      "Body did not reuse both retained branches");
    ack = req;
    #0.2;
    check(done == 4'b0000 && ppe == 4'b1010,
      "Body completion released the packet path");

    // Tail has the same ReqGenerator behavior; local OPM TP subsequently
    // withdraws MG, which clears PPE only after Done is low.
    req_x = 1'b1;
    #0.3;
    check(req == 4'b1010 && done == 4'b1010,
      "Tail phase did not traverse retained branches");
    ack = req;
    #0.2;
    mg = 4'b0000;
    #0.5;
    check(ppe == 4'b0000, "MG withdrawal did not release all Tail branches");
    grant = 4'b0000;
    check(req == ack && done == 4'b0000, "released bank did not return idle");

    // A following Head starts only after the previous Tail has completed the
    // Done/MG-driven PPE release and a new admitted RS edge is produced.
    reset = 1'b1;
    #0.1;
    reset = 1'b0;
    req_x = 1'b1;
    rs = 4'b0010;
    #0.5;
    grant = ppe;
    mg = ppe;
    rs = 4'b0000;
    ack = req;
    #0.2;
    mg = 4'b0000;
    #0.2;
    grant = 4'b0000;
    #0.2;
    check(req == ack && done == 4'b0000 && ppe == 4'b0000,
      "previous Tail did not release PPE before the next Head");
    req_x = 1'b0;
    rs = 4'b0010;
    #0.2;
    check(req[1] != ack[1] && ppe == 4'b0010,
      "new Head did not start from its admitted RS edge");
    ack = req;
    rs = 4'b0000;
    mg = ppe;
    #0.2;
    mg = 4'b0000;
    #0.5;
    grant = 4'b0000;

    // Exercise each generator independently after asynchronous reset.
    reset = 1'b1;
    #0.1;
    check(ppe == 4'b0000, "asynchronous reset did not clear PPE");
    reset = 1'b0;
    req_x = 1'b0;
    ack = 4'b0;
    for (integer branch = 0; branch < 4; branch = branch + 1) begin
      req_x = ~req_x;
      rs = 4'b0001 << branch;
      #0.5;
      check(ppe == (4'b0001 << branch),
        "single Atomic-approved RS activated the wrong ReqGenerator");
      grant = ppe;
      mg = ppe;
      rs = 4'b0;
      ack[branch] = req[branch];
      #0.2;
      mg[branch] = 1'b0;
      #0.2;
      grant[branch] = 1'b0;
      #0.3;
      check(ppe == 4'b0, "single branch did not release cleanly");
    end

    $display("TB_RESULT PASS RequestGeneratorBank Head Body Tail retention");
    $finish;
  end
endmodule
