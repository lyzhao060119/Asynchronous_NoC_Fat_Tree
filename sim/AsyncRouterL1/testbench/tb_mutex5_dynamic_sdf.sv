`timescale 1ns/1ps

// Simulation-only reproduction of the strict-SDF TAB r0p10 Mutex5 context.
// Field trace: arb_req=01110, then 105 ps later 01111, while B is selected
// at the root and TAC-B has both local contenders present.
module tb_mutex5_dynamic_sdf;
  reg reset;
  reg [4:0] req;
  wire [4:0] grant;
  integer failures;

  Mutex5Anchor dut (.reset(reset), .req(req), .grant(grant));

  task automatic snapshot(input [8*40-1:0] tag);
    begin
      $display("M5_DYNAMIC t=%0t tag=%0s req=%b grant=%b root=%b%b%b TACb={up=%b arbo=%b%b rawq=%b%b root=%b final=%b%b} TACa={up=%b arbo=%b%b root=%b final=%b%b}",
        $time, tag, req, grant,
        dut.root.grant_p, dut.root.grant_b, dut.root.grant_a,
        dut.tac_b.req_up, dut.tac_b.arbo1, dut.tac_b.arbo0,
        dut.tac_b.local_mutex.q1, dut.tac_b.local_mutex.q0,
        dut.root_b, dut.tac_b.grant1, dut.tac_b.grant0,
        dut.tac_a.req_up, dut.tac_a.arbo1, dut.tac_a.arbo0,
        dut.root_a, dut.tac_a.grant1, dut.tac_a.grant0);
    end
  endtask

  task automatic expect_onehot(input [8*48-1:0] tag);
    begin
      snapshot(tag);
      if ((grant === 5'b0) || ((grant & (grant - 1'b1)) != 5'b0) || ((grant & ~req) != 5'b0)) begin
        failures = failures + 1;
        $display("M5_DYNAMIC_FAIL tag=%0s t=%0t", tag, $time);
      end
    end
  endtask

  initial begin
    failures = 0;
    reset = 1'b1; req = 5'b00000;
    #10; reset = 1'b0;
    #2; snapshot("idle");

    // Exact field prefix.  The root must arbitrate between A and B; no fixed
    // priority is asserted, only a valid stable one-hot response.
    req = 5'b01110;
    #0.105; snapshot("field_01110_before_add_i0");
    req = 5'b01111;
    #20; expect_onehot("field_01111_settled");

    // Hold the request long enough to expose a return/masking instability.
    #20; expect_onehot("field_01111_held");
    req = 5'b00000;
    #20; snapshot("released");
    if (grant !== 5'b00000) begin
      failures = failures + 1;
      $display("M5_DYNAMIC_FAIL release t=%0t grant=%b", $time, grant);
    end
    if (failures == 0) $display("TB_RESULT PASS Mutex5 strict dynamic contention");
    else               $display("TB_RESULT FAIL Mutex5 strict dynamic contention failures=%0d", failures);
    $finish(failures != 0);
  end
endmodule
