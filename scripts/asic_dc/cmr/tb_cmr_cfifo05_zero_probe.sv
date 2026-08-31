`timescale 1ns/1ps
// Read-only CFIFO-05 first-zero backtrace.  No DUT/testbench signal is driven.
module tb_cmr_cfifo05_zero_probe;
`define DUT $root.tb_cmr_noc16_async_boundary_failfast.core.g_behavioral_noc.noc.dut
  wire [7:0] er = {`DUT.downwardLinkFifos_3.io_enq_HS_Req,`DUT.downwardLinkFifos_2.io_enq_HS_Req,`DUT.downwardLinkFifos_1.io_enq_HS_Req,`DUT.downwardLinkFifos_0.io_enq_HS_Req,`DUT.upwardLinkFifos_3.io_enq_HS_Req,`DUT.upwardLinkFifos_2.io_enq_HS_Req,`DUT.upwardLinkFifos_1.io_enq_HS_Req,`DUT.upwardLinkFifos_0.io_enq_HS_Req};
  wire [7:0] ea = {`DUT.downwardLinkFifos_3.io_enq_HS_Ack,`DUT.downwardLinkFifos_2.io_enq_HS_Ack,`DUT.downwardLinkFifos_1.io_enq_HS_Ack,`DUT.downwardLinkFifos_0.io_enq_HS_Ack,`DUT.upwardLinkFifos_3.io_enq_HS_Ack,`DUT.upwardLinkFifos_2.io_enq_HS_Ack,`DUT.upwardLinkFifos_1.io_enq_HS_Ack,`DUT.upwardLinkFifos_0.io_enq_HS_Ack};
  wire [7:0] dr = {`DUT.downwardLinkFifos_3.io_deq_HS_Req,`DUT.downwardLinkFifos_2.io_deq_HS_Req,`DUT.downwardLinkFifos_1.io_deq_HS_Req,`DUT.downwardLinkFifos_0.io_deq_HS_Req,`DUT.upwardLinkFifos_3.io_deq_HS_Req,`DUT.upwardLinkFifos_2.io_deq_HS_Req,`DUT.upwardLinkFifos_1.io_deq_HS_Req,`DUT.upwardLinkFifos_0.io_deq_HS_Req};
  wire [7:0] da = {`DUT.downwardLinkFifos_3.io_deq_HS_Ack,`DUT.downwardLinkFifos_2.io_deq_HS_Ack,`DUT.downwardLinkFifos_1.io_deq_HS_Ack,`DUT.downwardLinkFifos_0.io_deq_HS_Ack,`DUT.upwardLinkFifos_3.io_deq_HS_Ack,`DUT.upwardLinkFifos_2.io_deq_HS_Ack,`DUT.upwardLinkFifos_1.io_deq_HS_Ack,`DUT.upwardLinkFifos_0.io_deq_HS_Ack};
  wire [27:0] ed[0:7]; wire [27:0] dd[0:7];
  assign ed[0]=`DUT.upwardLinkFifos_0.io_enq_Data_flit; assign dd[0]=`DUT.upwardLinkFifos_0.io_deq_Data_flit;
  assign ed[1]=`DUT.upwardLinkFifos_1.io_enq_Data_flit; assign dd[1]=`DUT.upwardLinkFifos_1.io_deq_Data_flit;
  assign ed[2]=`DUT.upwardLinkFifos_2.io_enq_Data_flit; assign dd[2]=`DUT.upwardLinkFifos_2.io_deq_Data_flit;
  assign ed[3]=`DUT.upwardLinkFifos_3.io_enq_Data_flit; assign dd[3]=`DUT.upwardLinkFifos_3.io_deq_Data_flit;
  assign ed[4]=`DUT.downwardLinkFifos_0.io_enq_Data_flit; assign dd[4]=`DUT.downwardLinkFifos_0.io_deq_Data_flit;
  assign ed[5]=`DUT.downwardLinkFifos_1.io_enq_Data_flit; assign dd[5]=`DUT.downwardLinkFifos_1.io_deq_Data_flit;
  assign ed[6]=`DUT.downwardLinkFifos_2.io_enq_Data_flit; assign dd[6]=`DUT.downwardLinkFifos_2.io_deq_Data_flit;
  assign ed[7]=`DUT.downwardLinkFifos_3.io_enq_Data_flit; assign dd[7]=`DUT.downwardLinkFifos_3.io_deq_Data_flit;
  integer i; reg reported; realtime ez[0:7], dz[0:7]; reg [7:0] ezv,dzv;
  initial begin reported=0; ezv=0; dzv=0; end
  always @(er or ea or dr or da or ed[0] or ed[1] or ed[2] or ed[3] or ed[4] or ed[5] or ed[6] or ed[7] or dd[0] or dd[1] or dd[2] or dd[3] or dd[4] or dd[5] or dd[6] or dd[7]) begin
    for(i=0;i<8;i=i+1) begin
      if ((er[i]^ea[i]) && ed[i]===28'b0) begin ez[i]=$realtime; ezv[i]=1; end
      if ((dr[i]^da[i]) && dd[i]===28'b0) begin dz[i]=$realtime; dzv[i]=1; end
    end
  end
  always @( $root.tb_cmr_noc16_async_boundary_failfast.core.rx_count[4]) begin
    if (!reported && $root.tb_cmr_noc16_async_boundary_failfast.core.rx_count[4] >= 51 &&
        $root.tb_cmr_noc16_async_boundary_failfast.core.rx_flit[4][50] === 28'b0) begin
      reported=1;
      $display("CFIFO05_TRIGGER t_ns=%0.3f endpoint=4 slot=50 flit=0000000",$realtime);
      for(i=0;i<8;i=i+1)
        $display("CFIFO05_EVT fifo=%0d last_zero_enq_valid=%b t_ns=%0.3f last_zero_deq_valid=%b t_ns=%0.3f now_enq=%b/%b/%h now_deq=%b/%b/%h",i,ezv[i],ez[i],dzv[i],dz[i],er[i],ea[i],ed[i],dr[i],da[i],dd[i]);
    end
  end
endmodule
