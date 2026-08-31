`timescale 1ns/1ps

module tb_opm_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg [3:0] Reqin = 4'b0;
  reg [3:0] PktPathEnable = 4'b0;
  reg [27:0] Datain [0:3];
  reg Ackin = 1'b0;

  wire [3:0] Ackout;
  wire [3:0] Grant;
  wire [3:0] MG;
  wire Reqout;
  wire [27:0] Dataout;
  wire [3:0] TailPassed;

  OPM dut (
    .clock(clock), .reset(reset),
    .io_Reqin_0(Reqin[0]), .io_Reqin_1(Reqin[1]),
    .io_Reqin_2(Reqin[2]), .io_Reqin_3(Reqin[3]),
    .io_PktPathEnable_0(PktPathEnable[0]),
    .io_PktPathEnable_1(PktPathEnable[1]),
    .io_PktPathEnable_2(PktPathEnable[2]),
    .io_PktPathEnable_3(PktPathEnable[3]),
    .io_Datain_0_flit(Datain[0]), .io_Datain_1_flit(Datain[1]),
    .io_Datain_2_flit(Datain[2]), .io_Datain_3_flit(Datain[3]),
    .io_Ackin(Ackin),
    .io_Ackout_0(Ackout[0]), .io_Ackout_1(Ackout[1]),
    .io_Ackout_2(Ackout[2]), .io_Ackout_3(Ackout[3]),
    .io_Grant_0(Grant[0]), .io_Grant_1(Grant[1]),
    .io_Grant_2(Grant[2]), .io_Grant_3(Grant[3]),
    .io_MG_0(MG[0]), .io_MG_1(MG[1]),
    .io_MG_2(MG[2]), .io_MG_3(MG[3]),
    .io_Reqout(Reqout), .io_Dataout_flit(Dataout),
    .io_TailPassed_0(TailPassed[0]), .io_TailPassed_1(TailPassed[1]),
    .io_TailPassed_2(TailPassed[2]), .io_TailPassed_3(TailPassed[3])
  );

  always #5 clock = ~clock;

  task automatic fail(input [8*160-1:0] message);
    begin
      $display("TB_RESULT FAIL %0s at %0t", message, $time);
      $display(" Reqin=%b PPE=%b Grant=%b MG=%b Ackout=%b Reqout=%b Ackin=%b TP=%b Dataout=%h",
        Reqin, PktPathEnable, Grant, MG, Ackout, Reqout, Ackin, TailPassed, Dataout);
      $finish(1);
    end
  endtask

  task automatic check(input condition, input [8*160-1:0] message);
    begin if (!condition) fail(message); end
  endtask

  task automatic set_flit(input integer input_port, input Head, input Tail, input [7:0] tag);
    begin
      Datain[input_port] = 28'b0;
      Datain[input_port][27] = Head;
      Datain[input_port][26] = Tail;
      Datain[input_port][7:0] = tag;
    end
  endtask

  task automatic launch_flit(input integer input_port, input Head, input Tail, input [7:0] tag);
    reg old_Reqout;
    reg [3:0] old_Ackout;
    begin
      set_flit(input_port, Head, Tail, tag);
      old_Reqout = Reqout;
      old_Ackout = Ackout;
      Reqin[input_port] = ~Reqin[input_port];
      #0.8;
      check(Reqout !== old_Reqout, "selected Reqin transition did not toggle Reqout");
      check(Dataout === Datain[input_port], "Data Mux/Data Reg selected wrong Datain");
      check(Ackout[input_port] === Reqin[input_port], "selected Ackout phase mismatch");
      check((Ackout ^ old_Ackout) === (4'b0001 << input_port),
        "Ackout changed on an input other than the selected transaction");
    end
  endtask

  task automatic accept_output;
    begin
      Ackin = Reqout;
      #0.4;
    end
  endtask

  integer input_port;
  integer winner;
  reg [3:0] winner_mask;
  reg [3:0] loser_mask;
  reg [27:0] held_data;
  reg held_req;

  initial begin
    for (input_port = 0; input_port < 4; input_port = input_port + 1)
      Datain[input_port] = 28'b0;

    #1.0;
    reset = 1'b0;
    #1.0;
    check(Ackout === 4'b0000 && Grant === 4'b0000 && MG === 4'b0000,
      "reset control state mismatch");
    check(Reqout === 1'b0 && Dataout === 28'b0 && TailPassed === 4'b0000,
      "reset output state mismatch");

    // Head, queued Body under backpressure, then Tail through input 0.
    PktPathEnable = 4'b0001;
    #1.0;
    check(Grant === 4'b0001 && MG === 4'b0001, "Mutex4 did not grant sole request");
    launch_flit(0, 1'b1, 1'b0, 8'h11);

    held_req = Reqout;
    held_data = Dataout;
    set_flit(0, 1'b0, 1'b0, 8'h22);
    Reqin[0] = ~Reqin[0];
    #0.8;
    check(Reqout === held_req && Dataout === held_data,
      "V2 failed to hold Body under downstream backpressure");
    Ackin = held_req;
    #0.8;
    check(Reqout === Reqin[0] && Dataout[7:0] === 8'h22 && Ackout[0] === Reqin[0],
      "queued Body did not cross reopened V2");

    held_req = Reqout;
    set_flit(0, 1'b0, 1'b1, 8'h33);
    Reqin[0] = ~Reqin[0];
    #0.5;
    check(Reqout === held_req && TailPassed === 4'b0000,
      "Tail crossed before previous Body Ackin");
    Ackin = held_req;
    #0.8;
    check(Reqout === Reqin[0] && Dataout === Datain[0], "Tail data/request mismatch");
    check(TailPassed === 4'b0001 && MG === 4'b0000,
      "Tail Detector did not set TailPassed and mask Grant");
    accept_output;
    PktPathEnable = 4'b0000;
    #1.0;
    check(Grant === 4'b0000 && TailPassed === 4'b0000,
      "PktPathEnable release did not clear Grant/TailPassed");

    // Every physical input can independently acquire the OPM.
    for (input_port = 1; input_port < 4; input_port = input_port + 1) begin
      PktPathEnable = 4'b0001 << input_port;
      #1.0;
      check(Grant === (4'b0001 << input_port), "Mutex4 granted wrong sole requester");
      launch_flit(input_port, 1'b1, 1'b1, 8'h40 + input_port);
      check(TailPassed === (4'b0001 << input_port), "TailPassed identified wrong input");
      accept_output;
      PktPathEnable = 4'b0000;
      #1.0;
    end

    // Contention: both requests arrive together. The analog boundary may pick
    // either input, but only one stable Grant is legal.
    PktPathEnable = 4'b0011;
    #3.0;
    check((Grant === 4'b0001) || (Grant === 4'b0010),
      "two-request Mutex4 contention did not resolve one-hot");
    winner = Grant[0] ? 0 : 1;
    winner_mask = 4'b0001 << winner;
    loser_mask = 4'b0011 & ~winner_mask;
    PktPathEnable = loser_mask;
    #3.0;
    check(Grant === loser_mask, "waiting contender did not acquire after winner release");
    PktPathEnable = 4'b0000;
    #2.0;
    check(Grant === 4'b0000 && MG === 4'b0000,
      "OPM did not return idle after contention");

    $display("TB_RESULT PASS CMR paper OPM Mutex4/head-body-tail smoke");
    $finish;
  end
endmodule
