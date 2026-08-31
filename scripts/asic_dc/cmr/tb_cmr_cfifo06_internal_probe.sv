`timescale 1ns/1ps
module tb_cmr_cfifo06_internal_probe;
`define F $root.tb_cmr_noc16_async_boundary_failfast.core.g_behavioral_noc.noc.dut.downwardLinkFifos_0.bb
  wire [3:0] wp=`F.DebugWritePointer, rp=`F.DebugReadPointer, full=`F.DebugFull, empty=`F.DebugEmpty, cr=`F.DebugCellReq, en=`F.DebugEn;
  wire rq=`F.Reqout, ak=`F.Ackin; wire [27:0] din=`F.Data_in, dout=`F.Data_out;
  wire [27:0] s0=`F.\slot[0].data_reg .q, s1=`F.\slot[1].data_reg .q, s2=`F.\slot[2].data_reg .q, s3=`F.\slot[3].data_reg .q;
  reg fired;
  initial fired=0;
  always @(rq or ak or dout or wp or rp or full or empty or cr or en or s0 or s1 or s2 or s3) begin
    if (!fired && (rq^ak) && dout===28'b0) begin
      fired=1;
      $display("CFIFO06_FIRST_ZERO t_ns=%0.3f reqack=%b/%b wp=%b rp=%b full=%b empty=%b cellreq=%b en=%b din=%h dout=%h slots=%h,%h,%h,%h",$realtime,rq,ak,wp,rp,full,empty,cr,en,din,dout,s0,s1,s2,s3);
    end
  end
endmodule
