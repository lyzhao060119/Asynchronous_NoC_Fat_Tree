`timescale 1ns/1ps

module tb_mutex5_anchor_smoke;
  reg reset;
  reg [4:0] req;
  wire [4:0] grant;

  Mutex5Anchor dut (
    .reset(reset), .req(req), .grant(grant)
  );

  function automatic integer pop5(input [4:0] value);
    pop5 = value[0] + value[1] + value[2] + value[3] + value[4];
  endfunction

  task automatic check(input condition, input [8*180-1:0] message);
    begin
      if (!condition) begin
        $display("TB_RESULT FAIL %0s t=%0t req=%b grant=%b", message, $time, req, grant);
        $finish(1);
      end
    end
  endtask

  task automatic settle_and_check_onehot(input [4:0] value);
    begin
      req = 5'b0;
      #2;
      check(grant == 5'b0, "grant did not clear between request sets");
      req = value;
      #5;
      check(pop5(grant) == 1, "nonempty request set did not resolve to exactly one grant");
      check((grant & ~req) == 5'b0, "grant asserted for a non-requesting input");
    end
  endtask

  initial begin
    reset = 1'b1; req = 5'b0;
    #2;
    check(grant === 5'b0, "reset mutex5 must have known zero grant");
    reset = 1'b0;
    #2;
    check(grant === 5'b0, "idle mutex5 must have no grant");

    // Each input can traverse its local/root path alone.
    for (integer input_index = 0; input_index < 5; input_index = input_index + 1) begin
      settle_and_check_onehot(5'b00001 << input_index);
      check(grant == (5'b00001 << input_index), "single requester did not receive its own grant");
    end

    // Group-local conflicts and the three root groups.
    settle_and_check_onehot(5'b00011);
    check(grant[1:0] != 2'b00, "TAC-A did not return a local child grant");
    settle_and_check_onehot(5'b01100);
    check(grant[3:2] != 2'b00, "TAC-B did not return a local child grant");
    settle_and_check_onehot(5'b10101);

    // Exhaust every nonempty request bitmap.  The desired parent bias affects
    // long-run win rate only; every individual arbitration remains one-hot.
    for (integer request_set = 1; request_set < 32; request_set = request_set + 1)
      settle_and_check_onehot(request_set[4:0]);

    req = 5'b0;
    #3;
    check(grant == 5'b0, "final release did not clear all grants");
    $display("TB_RESULT PASS Mutex5Anchor structural 2+2+1 grants");
    $finish;
  end
endmodule
