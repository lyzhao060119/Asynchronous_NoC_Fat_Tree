`timescale 1ns/1ps

module tb_cmr_flattened_tac_smoke;
  reg reset = 1'b1;
  reg root3 = 1'b0;
  reg root4 = 1'b0;
  reg [2:0] r3 = 0; wire [2:0] g3; wire u3;
  reg [3:0] r4 = 0; wire [3:0] g4; wire u4;
  reg [4:0] r5 = 0; wire [4:0] g5;
  reg [6:0] r7 = 0; wire [6:0] g7;
  reg [7:0] r8 = 0; wire [7:0] g8;
  reg [9:0] r10 = 0; wire [9:0] g10;
  integer failures = 0;

  CMRTAC3 t3(.reset(reset),.req(r3),.root_grant(root3),.req_up(u3),.grant(g3));
  CMRTAC4 t4(.reset(reset),.req(r4),.root_grant(root4),.req_up(u4),.grant(g4));
  CMRFlatArbiter5 a5(.reset(reset),.req(r5),.grant(g5));
  CMRFlatArbiter7 a7(.reset(reset),.req(r7),.grant(g7));
  CMRFlatArbiter8 a8(.reset(reset),.req(r8),.grant(g8));
  CMRFlatArbiter10 a10(.reset(reset),.req(r10),.grant(g10));

  task check(input bit ok, input string why); begin
    if(!ok) begin failures++; $display("TB_CHECK_FAIL %s t=%0t",why,$time); end
  end endtask
  function automatic bit onehot8(input [7:0] v);
    onehot8 = v != 0 && ((v & (v-1'b1)) == 0);
  endfunction

  initial begin
    #2 reset=0;
    r3=3'b010; r4=4'b1000; r5=5'b00100; r7=7'b1000000; r8=8'b01000000; r10=10'b0001000000; #2;
    root3=1; root4=1; #6;
    check(g3==r3 && u3,"TAC3 single request");
    check(g4==r4 && u4,"TAC4 single request");
    check(g5==r5,"flat5 single request");
    check(g7==r7,"flat7 single request");
    check(g8==r8,"flat8 single request");
    check(g10==r10,"flat10 single request");
    r3=0; r4=0; root3=0; root4=0; r5=0; r7=0; r8=0; r10=0; #8;
    check(g3==0 && g4==0 && g5==0 && g7==0 && g8==0 && g10==0,"release to idle");

    r3=3'b111; r4=4'b1111; r5=5'b11111; r7=7'b1111111; r8=8'b11111111; r10=10'b1111111111; #2;
    root3=1; root4=1; #10;
    check(onehot8({5'b0,g3}),"TAC3 full contention onehot");
    check(onehot8({4'b0,g4}),"TAC4 full contention onehot");
    check(onehot8({3'b0,g5}),"flat5 full contention onehot");
    check(onehot8({1'b0,g7}),"flat7 full contention onehot");
    check(onehot8(g8),"flat8 full contention onehot");
    check(onehot8({6'b0,g10}),"flat10 full contention onehot");
    check((g3&r3)==g3 && (g4&r4)==g4 && (g5&r5)==g5 && (g7&r7)==g7 && (g8&r8)==g8 && (g10&r10)==g10,
          "grant selected inactive requester");
    r3=0; r4=0; root3=0; root4=0; r5=0; r7=0; r8=0; r10=0; #8;
    check(g3==0 && g4==0 && g5==0 && g7==0 && g8==0 && g10==0,"contention release");
    if(failures==0) $display("TB_RESULT PASS CMR Fig5 TAC3/TAC4 flattened arbiters");
    else $display("TB_RESULT FAIL CMR flattened TAC failures=%0d",failures);
    $finish;
  end
endmodule
