`timescale 1ns/1ps
module wide_mutex_check #(parameter WIDTH=64)(output reg done=0);
  reg reset=1;
  reg [WIDTH-1:0] req=0;
  wire [WIDTH-1:0] grant;
  reg [WIDTH-1:0] waiting;
  integer round, i, count, watchdog;
  CMRMutexN #(.WIDTH(WIDTH)) dut(.reset(reset),.req(req),.grant(grant));
  initial begin
    #5; reset=0; #5;
    // Every input separately, then overlapping persistent request cohorts.
    for(i=0;i<WIDTH;i=i+1) begin
      req=0; req[i]=1; #2;
      if(grant !== req) $fatal(1,"WIDE_MUTEX_FAIL singleton width=%0d input=%0d",WIDTH,i);
      req=0; #2;
      if(grant !== 0) $fatal(1,"WIDE_MUTEX_FAIL withdraw width=%0d",WIDTH);
    end
    for(round=0;round<8;round=round+1) begin
      waiting=0;
      // Stagger 1ps to avoid claiming a zero-delay model proves analog
      // metastability resolution for perfectly simultaneous contenders.
      for(i=0;i<WIDTH;i=i+1) begin
        if(round==0 || ((i+round)%3)!=0) begin req[i]=1; waiting[i]=1; end
        #0.001;
      end
      count=0; watchdog=0;
      while(waiting!=0 && watchdog<WIDTH*4) begin
        #2; watchdog=watchdog+1;
        if($isunknown(grant) || !$onehot0(grant))
          $fatal(1,"WIDE_MUTEX_FAIL onehot width=%0d grant=%h",WIDTH,grant);
        if(grant!=0) begin
          if((grant & waiting)!=grant) $fatal(1,"WIDE_MUTEX_FAIL stale width=%0d",WIDTH);
          waiting=waiting & ~grant; req=waiting; count=count+1;
        end
      end
      if(waiting!=0) $fatal(1,"WIDE_MUTEX_FAIL timeout width=%0d",WIDTH);
      #2;
      if(grant!==0) $fatal(1,"WIDE_MUTEX_FAIL pending width=%0d",WIDTH);
    end
    $display("CMR_WIDE_MUTEX_PASS width=%0d",WIDTH);done=1;
  end
endmodule
module tb_cmr_wide_mutex;
  wire d16,d28,d64;
  wide_mutex_check #(.WIDTH(16)) a(d16);
  wide_mutex_check #(.WIDTH(28)) b(d28);
  wide_mutex_check #(.WIDTH(64)) c(d64);
  initial begin wait(d16 && d28 && d64); $display("TB_RESULT PASS wide_mutex"); $finish; end
  initial begin #10000; $fatal(1,"TB_RESULT FAIL wide_mutex timeout"); end
endmodule
