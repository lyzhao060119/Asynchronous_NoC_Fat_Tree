`timescale 1ns/1ps

module tb_tac2_mutex3_smoke;
  reg tac_reset;
  reg tac_req0, tac_req1, tac_root_grant;
  wire tac_req_up, tac_grant0, tac_grant1, tac_arbo0, tac_arbo1;
  wire tac_masked0, tac_masked1;
  reg req_a, req_b, req_p;
  wire grant_a, grant_b, grant_p;

  TAC2 tac (
    .reset(tac_reset), .req0(tac_req0), .req1(tac_req1), .root_grant(tac_root_grant),
    .req_up(tac_req_up), .grant0(tac_grant0), .grant1(tac_grant1),
    .arbo0(tac_arbo0), .arbo1(tac_arbo1),
    .result_masked0(tac_masked0), .result_masked1(tac_masked1)
  );
  Mutex3Grant root (
    .req_a(req_a), .req_b(req_b), .req_p(req_p),
    .grant_a(grant_a), .grant_b(grant_b), .grant_p(grant_p)
  );

  function automatic integer pop3(input [2:0] value);
    pop3 = value[0] + value[1] + value[2];
  endfunction

  task automatic check(input condition, input [8*180-1:0] message);
    begin
      if (!condition) begin
        $display("TB_RESULT FAIL %0s t=%0t tacReq=%b%b tacGrant=%b%b rootReq=%b%b%b rootGrant=%b%b%b",
          message, $time, tac_req1, tac_req0, tac_grant1, tac_grant0,
          req_p, req_b, req_a, grant_p, grant_b, grant_a);
        $finish(1);
      end
    end
  endtask

  task automatic root_onehot(input [2:0] request_set);
    begin
      req_a = 0; req_b = 0; req_p = 0; #2;
      check({grant_p, grant_b, grant_a} == 3'b000, "root grant failed to release");
      {req_p, req_b, req_a} = request_set;
      #4;
      check(pop3({grant_p, grant_b, grant_a}) == 1,
        "root nonempty request set did not produce one grant");
      check(({grant_p, grant_b, grant_a} & ~request_set) == 3'b000,
        "root grant selected a non-requesting group");
    end
  endtask

  initial begin
    tac_reset = 1; tac_req0 = 0; tac_req1 = 0; tac_root_grant = 0;
    req_a = 0; req_b = 0; req_p = 0;
    #2;
    check({tac_grant1, tac_grant0} === 2'b00, "TAC2 reset did not clear grants");
    tac_reset = 0;
    #1;
    check(tac_req_up == 0 && {tac_grant1, tac_grant0} == 2'b00,
      "TAC2 idle state is not empty");

    // Eager propagation begins before the root permission arrives.
    tac_req0 = 1; #2;
    check(tac_req_up && tac_arbo0 && !tac_grant0,
      "TAC2 failed eager request propagation or root masking");
    tac_root_grant = 1; #2;
    check(tac_grant0 && !tac_grant1,
      "TAC2 did not pass local winner after root grant");
    tac_req0 = 0; tac_root_grant = 0; #2;
    tac_req1 = 1; #2;
    check(tac_req_up && tac_arbo1 && !tac_grant1,
      "TAC2 second local request did not settle while root masked");
    tac_root_grant = 1; #2;
    check(tac_grant1 && !tac_grant0, "TAC2 local one-hot grant failed");
    tac_req0 = 1; #3;
    check(!(tac_grant0 && tac_grant1), "TAC2 concurrent request grant overlap");
    tac_req0 = 0; tac_req1 = 0; tac_root_grant = 0; #2;

    // Single, pairwise, and full-root competitions.
    for (integer request_set = 1; request_set < 8; request_set = request_set + 1)
      root_onehot(request_set[2:0]);

    $display("TB_RESULT PASS TAC2 and Mutex3Grant safety");
    $finish;
  end
endmodule
