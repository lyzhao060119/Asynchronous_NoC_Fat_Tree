`timescale 1ns/1ps

module tb_packet_route_selector_smoke;
  reg [27:0] routing_info;
  reg req_x;
  reg ack_x;
  wire rs0;
  wire rs1;
  wire rs2;
  wire rs3;
  wire prs_ready;

  PacketRouteSelector dut (
    .io_RoutingInfo_flit(routing_info),
    .io_ReqX(req_x),
    .io_AckX(ack_x),
    .io_RS_0(rs0),
    .io_RS_1(rs1),
    .io_RS_2(rs2),
    .io_RS_3(rs3),
    .io_PRSReady(prs_ready)
  );

  function automatic [3:0] rs;
    begin
      rs = {rs3, rs2, rs1, rs0};
    end
  endfunction

  task automatic check_ok;
    input cond;
    input [256*8-1:0] msg;
    begin
      if (!cond) begin
        $display("TB_RESULT FAIL %0s t=%0t", msg, $time);
        $finish(1);
      end
    end
  endtask

  task automatic complete_flit;
    begin
      ack_x = req_x;
      #0.05;
      check_ok(prs_ready == 1'b0, "ack clears delayed-request xor window");
    end
  endtask

  initial begin
    routing_info = 28'h0000000;
    req_x = 1'b0;
    ack_x = 1'b0;
    #0.30;
    check_ok(prs_ready == 1'b0 && rs() == 4'b0000, "idle prs");

    // Router (0,0), L1, ingress parent: destination (0,0) selects child dir 3.
    routing_info = 28'h8000000;
    req_x = ~req_x;
    #0.05;
    check_ok(prs_ready == 1'b0 && rs() == 4'b0000, "head barrier blocks before delay");
    #0.20;
    check_ok(prs_ready == 1'b1 && rs() == 4'b1000, "head asserts delayed route selected");
    complete_flit;
    check_ok(rs() == 4'b0000, "head route selected clears with prs window");

    routing_info = 28'h0000000;
    req_x = ~req_x;
    #0.25;
    check_ok(prs_ready == 1'b1 && rs() == 4'b0000, "body has prs window but no new route selected");
    complete_flit;

    routing_info = 28'h4000000;
    req_x = ~req_x;
    #0.25;
    check_ok(prs_ready == 1'b1 && rs() == 4'b0000, "tail has prs window but no new route selected");
    complete_flit;

    $display("TB_RESULT PASS RS=%b PRSReady=%b", rs(), prs_ready);
    $finish;
  end
endmodule
