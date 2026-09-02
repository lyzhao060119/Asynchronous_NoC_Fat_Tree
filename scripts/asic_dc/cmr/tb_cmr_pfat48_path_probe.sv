`timescale 1ns/1ps

// Read-only PFAT L3 (4,8) R-U5 hot-path probe.  Compiled as a second -top
// with GEOM_C4_P8.  Names match post-synthesis CMRRouter_post.v:
//   InputPortModules_0  = IPM (ingress port 0)
//   selector_3          = parent-direction ContinuousLaneSelector (8)
//   adapter_3           = LanePhaseAdapter LANES=8
//   OutputPortModules_23 = parent lane 7 OPM (fan-in 16)
module tb_cmr_pfat48_path_probe;
`ifdef GEOM_C4_P8
  `define TB  $root.tb_cmr_router_hop_ppa
  `define DUT `TB.dut
  `define IPM `DUT.InputPortModules_0
  `define SEL `DUT.selector_3
  `define ADP `DUT.adapter_3
  `define OPM `DUT.OutputPortModules_23

  function automatic offer;
    input req;
    input ack;
    begin
      offer = ((req === 1'b0) || (req === 1'b1)) &&
              ((ack === 1'b0) || (ack === 1'b1)) &&
              (req !== ack);
    end
  endfunction

  wire in_req = `TB.tb_in_req[0];
  wire in_ack = `TB.tb_in_ack[0];
  wire out_req = `TB.tb_out_req[23];
  wire out_ack = `TB.tb_out_ack[23];

  wire ipm_ackout = `IPM.io_Ackout;
  wire pe3 = `IPM.io_PathEnabled_3;
  wire r3 = `IPM.io_Reqout_3;
  wire a3 = `IPM.io_Ackin_3;
  wire tp3 = `IPM.io_TailPassed_3;

  wire [7:0] lsel = {
    `SEL.io_LaneSelect_7, `SEL.io_LaneSelect_6, `SEL.io_LaneSelect_5,
    `SEL.io_LaneSelect_4, `SEL.io_LaneSelect_3, `SEL.io_LaneSelect_2,
    `SEL.io_LaneSelect_1, `SEL.io_LaneSelect_0
  };

  wire adp_reqin = `ADP.Reqin;
  wire adp_ackout = `ADP.Ackout;
  wire [7:0] adp_lsel = `ADP.LaneSelect;
  wire [7:0] adp_cmt = `ADP.Commit;
  wire [7:0] adp_ackin = `ADP.Ackin;
  wire [7:0] adp_reqout = `ADP.Reqout;
  wire assigned = `ADP.Assigned;
  wire offset = `ADP.PhaseOffset;
  wire adp_req7 = `ADP.Reqout[7];
  wire adp_ackin7 = `ADP.Ackin[7];

  wire ppe0 = `OPM.io_PktPathEnable_0;
  wire gnt0 = `OPM.io_Grant_0;
  wire opm_reqin0 = `OPM.io_Reqin_0;
  wire opm_ackout0 = `OPM.io_Ackout_0;
  wire opm_reqout = `OPM.io_Reqout;
  wire opm_tp0 = `OPM.io_TailPassed_0;

  integer edge_count;
  integer classified;
  integer saw_pe3;
  string last_site;
  realtime last_edge_ns;

  task automatic snapshot;
    input string tag;
    begin
      $display(
        "PFAT48_SNAP tag=%0s t=%0.3f delivered=%0d in=%b/%b out=%b/%b ipm_ack=%b pe3=%b r3=%b a3=%b tp3=%b lsel=%b assigned=%b offset=%b cmt=%b adp_r/a=%b/%b reqout7=%b ackin7=%b ppe0=%b gnt0=%b opm_ri0=%b opm_ao0=%b opm_ro=%b tp0=%b",
        tag, $realtime, `TB.delivered, in_req, in_ack, out_req, out_ack,
        ipm_ackout, pe3, r3, a3, tp3, lsel, assigned, offset, adp_cmt,
        adp_reqin, adp_ackout, adp_req7, adp_ackin7, ppe0, gnt0,
        opm_reqin0, opm_ackout0, opm_reqout, opm_tp0
      );
    end
  endtask

  task automatic classify;
    input string when;
    string site;
    string why;
    begin
      if (classified) begin
      end else begin
      classified = 1;
      site = "UNKNOWN";
      why = "no rule matched";
      if ((in_req !== in_ack) && (ipm_ackout !== in_req) &&
          ((ipm_ackout === 1'b0) || (ipm_ackout === 1'b1))) begin
        site = "IPM_BUFFER_WRITE";
        why = "port0 req pending and IPM Ackout does not follow";
      end else if (saw_pe3 && (pe3 === 1'b0)) begin
        site = "RCU_PATHLATCH";
        why = "PathEnabled_3 dropped after Head opened the parent branch";
      end else if ((pe3 === 1'b1) && (lsel !== 8'h80) && (lsel !== 8'hxx) &&
                   (lsel !== 8'hzz)) begin
        site = "LANE_SELECTOR_MUTEX8";
        why = "PathEnabled_3=1 but LaneSelect is not parent-lane-7 one-hot";
      end else if ((pe3 === 1'b1) && (gnt0 === 1'b0)) begin
        site = "OPM_MUTEX16";
        why = "PathEnabled_3=1 but parent OPM Grant_0 is 0";
      end else if ((assigned === 1'b1) && (r3 !== adp_ackout)) begin
        site = "ADAPTER_ACKLATCH";
        why = "Assigned=1 but IPM Reqout_3 !== adapter Ackout";
      end else if (offer(adp_req7, adp_ackin7) && (opm_reqout === out_ack)) begin
        site = "OPM_MERGE_ACKIN";
        why = "adapter Reqout[7] offers but OPM Reqout is idle vs TB ack";
      end else if ((in_req !== in_ack)) begin
        site = "IPM_BUFFER_WRITE";
        why = "port0 input handshake still pending";
      end else if (offer(out_req, out_ack)) begin
        site = "TB_OUTPUT_UNACKED";
        why = "output offer present; TB has not acked yet";
      end
      $display("PFAT48_STUCK when=%0s t=%0.3f site=%0s why=%0s last_edge=%0s last_edge_t=%0.3f",
               when, $realtime, site, why, last_site, last_edge_ns);
      snapshot("stuck");
      end
    end
  endtask

  task automatic edge_emit;
    input string site;
    begin
      last_site = site;
      last_edge_ns = $realtime;
      edge_count = edge_count + 1;
      $display(
        "PFAT48_EDGE site=%0s t=%0.3f n=%0d delivered=%0d in=%b/%b out=%b/%b pe3=%b r3=%b a3=%b lsel=%b assigned=%b cmt7=%b req7=%b ackin7=%b ppe0=%b gnt0=%b opm_ro=%b",
        site, $realtime, edge_count, `TB.delivered, in_req, in_ack, out_req,
        out_ack, pe3, r3, a3, lsel, assigned, adp_cmt[7], adp_req7, adp_ackin7,
        ppe0, gnt0, opm_reqout
      );
    end
  endtask

  initial begin
    edge_count = 0;
    classified = 0;
    saw_pe3 = 0;
    last_site = "none";
    last_edge_ns = 0.0;
    wait (`TB.running === 1'b1);
    $display("PFAT48_PROBE_ARMED t=%0.3f", $realtime);
    snapshot("armed");
    fork
      begin
        wait ((`TB.delivered >= 5) || (`TB.failures != 0));
        #0.01;
        if (`TB.delivered >= 5)
          $display("PFAT48_STUCK when=delivered t=%0.3f site=NONE why=five_flits_complete last_edge=%0s last_edge_t=%0.3f",
                   $realtime, last_site, last_edge_ns);
        else
          classify("tb_fail");
      end
      begin
        #(499990.0);
        if (`TB.delivered < 5)
          classify("pre_timeout");
      end
    join
  end

  always @(pe3)
    if (pe3 === 1'b1)
      saw_pe3 = 1;

  always @(in_req or in_ack)
    if (`TB.running && ($realtime >= 210.0))
      edge_emit("L0_IN");
  always @(out_req or out_ack)
    if (`TB.running && ($realtime >= 210.0))
      edge_emit("L0_OUT");
  always @(ipm_ackout or r3 or a3 or pe3 or tp3)
    if (`TB.running && ($realtime >= 210.0))
      edge_emit("L1_IPM");
  always @(lsel)
    if (`TB.running && ($realtime >= 210.0))
      edge_emit("L2_SEL");
  always @(adp_ackout or assigned or offset or adp_cmt or adp_req7 or adp_ackin7)
    if (`TB.running && ($realtime >= 210.0))
      edge_emit("L3_ADP");
  always @(ppe0 or gnt0 or opm_reqin0 or opm_ackout0 or opm_reqout or opm_tp0)
    if (`TB.running && ($realtime >= 210.0))
      edge_emit("L4_OPM");

  final begin
    if (!classified && (`TB.delivered < 5))
      classify("final");
    else if (!classified)
      $display("PFAT48_STUCK when=final t=%0.3f site=NONE why=exited_with_delivery last_edge=%0s last_edge_t=%0.3f",
               $realtime, last_site, last_edge_ns);
  end
`else
  initial $display("PFAT48_PROBE skipped (not GEOM_C4_P8)");
`endif
endmodule
