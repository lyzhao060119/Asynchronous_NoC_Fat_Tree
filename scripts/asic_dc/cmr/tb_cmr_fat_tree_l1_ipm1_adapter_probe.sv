`timescale 1ns/1ps

// Read-only IPM1 parent (branch 3) probe: selector_1 + adapter_1.
// Walks upstream-to-downstream and reports the first output that violates
// the two-phase / phase-offset contract for packet-2 Head 8200202.
module tb_cmr_fat_tree_l1_ipm1_adapter_probe;
  localparam [27:0] PKT1_HEAD = 28'h8200202;
  localparam [27:0] PKT1_BODY = 28'h0200202;
  localparam [27:0] PKT1_TAIL = 28'h4200202;
  localparam realtime WIN_LO = 268.0;
  localparam realtime WIN_HI = 312.0;
  localparam integer DEPTH = 1024;

`define DUT $root.tb_cmr_noc16_async_boundary_failfast.core.g_behavioral_noc.noc.dut
`define L1  `DUT.routerL1_1_1
`define IPM `L1.InputPortModules_1
`define SEL `L1.selector_1
`define ADP `L1.adapter_1

  wire trigger = $root.tb_cmr_noc16_async_boundary_failfast.diagnostic_trigger;

  wire pe3 = `L1.InputPortModules_1_io_PathEnabled_3;
  wire r3  = `L1.InputPortModules_1_io_Reqout_3;
  wire [27:0] data3 = `L1.InputPortModules_1_io_Dataout_3_flit;
  wire tp3 = `L1.InputPortModules_1_io_TailPassed_3;

  wire ackout = `ADP.Ackout;
  wire reqin  = `ADP.Reqin;
  wire [1:0] lsel = `ADP.LaneSelect;
  wire [1:0] cmt  = `ADP.Commit;
  wire [1:0] ackin = `ADP.Ackin;
  wire [1:0] reqout_adp = `ADP.Reqout;
  wire offset = `ADP.PhaseOffset;
  wire assigned = `ADP.Assigned;

  wire [1:0] ogrnt = {`SEL.io_OtherGrant_1, `SEL.io_OtherGrant_0};

  wire ppe1 = `L1.OutputPortModules_5_io_PktPathEnable_1;
  wire gnt1 = `L1.OutputPortModules_5_io_Grant_1;
  wire opm_req = `DUT.routerL1_1_1_io_outputs_parent_1_HS_Req;
  wire opm_ack = `DUT.upward_1_io_enq_HS_Ack;
  wire [27:0] opm_data = `DUT.routerL1_1_1_io_outputs_parent_1_Data_flit;

  function automatic offer;
    input req;
    input ack;
    begin
      offer = ((req === 1'b0) || (req === 1'b1)) &&
              ((ack === 1'b0) || (ack === 1'b1)) &&
              (req !== ack);
    end
  endfunction

  function automatic known01;
    input bitv;
    begin
      known01 = (bitv === 1'b0) || (bitv === 1'b1);
    end
  endfunction

  wire offer_dir = offer(r3, ackout);
  wire opm_offer = offer(opm_req, opm_ack);
  wire expected_req1 = reqin ^ offset;

  function automatic bit in_win;
    begin
      in_win = ($realtime >= WIN_LO) && ($realtime <= WIN_HI);
    end
  endfunction

  integer next_slot;
  integer count;
  integer total;
  integer dump_i;
  integer dump_slot;
  integer first_kind;
  integer pkt2_head_on_data3;
  integer pkt2_dir_offer_seen;
  integer tail_seen;
  realtime first_ns;
  realtime pe3_unsel_ns;
  realtime pe3_hold_ns;
  realtime event_time [0:DEPTH-1];
  string event_line [0:DEPTH-1];

  task automatic emit;
    input string tag;
    begin
      $display("CMR_L1ADAPT t_ns=%0.3f %0s pe3=%b r3=%b ackout=%b offer_dir=%b data3=%h tp3=%b lsel=%b ogrnt=%b offset=%b assigned=%b cmt=%b ackin=%b reqout=%b exp1=%b ppe1=%b gnt1=%b opm_r/a=%b/%b offer_opm=%b opm_data=%h",
               $realtime, tag, pe3, r3, ackout, offer_dir, data3, tp3,
               lsel, ogrnt, offset, assigned, cmt, ackin, reqout_adp, expected_req1,
               ppe1, gnt1, opm_req, opm_ack, opm_offer, opm_data);
    end
  endtask

  task automatic record;
    integer slot;
    begin
      slot = next_slot;
      event_time[slot] = $realtime;
      $sformat(event_line[slot],
               "pe3=%b r3=%b ackout=%b offer_dir=%b data3=%h lsel=%b ogrnt=%b offset=%b assigned=%b cmt=%b ackin=%b reqout=%b exp1=%b ppe1=%b gnt1=%b opm_r/a=%b/%b offer_opm=%b opm_data=%h",
               pe3, r3, ackout, offer_dir, data3, lsel, ogrnt, offset, assigned,
               cmt, ackin, reqout_adp, expected_req1, ppe1, gnt1,
               opm_req, opm_ack, opm_offer, opm_data);
      next_slot = (next_slot + 1) % DEPTH;
      count = (count < DEPTH) ? count + 1 : DEPTH;
      total = total + 1;
    end
  endtask

  task automatic first_anomaly;
    input integer kind;
    input string name;
    input string why;
    begin
      if (first_kind == 0) begin
        first_kind = kind;
        first_ns = $realtime;
        $display("CMR_L1ADAPT_FIRST t_ns=%0.3f kind=%0s %0s",
                 $realtime, name, why);
        emit("FIRST");
      end
    end
  endtask

  task automatic check;
    begin
      if (data3 === PKT1_TAIL)
        tail_seen = 1;
      if (tail_seen && (data3 === PKT1_HEAD)) begin
        if (!pkt2_head_on_data3) begin
          pkt2_head_on_data3 = 1;
          pkt2_dir_offer_seen = 0;
        end
      end
      if (pkt2_head_on_data3 && (data3 === PKT1_HEAD) && offer_dir)
        pkt2_dir_offer_seen = 1;

      if (in_win()) begin
        // 1. IPM direction request: Head on Dataout_3 must produce offer
        //    before Commit or before Head leaves the read port.
        if (pkt2_head_on_data3 && (data3 === PKT1_HEAD) &&
            (cmt[1] === 1'b1) && !pkt2_dir_offer_seen)
          first_anomaly(1, "IPM_REQOUT",
                        "Head on Dataout_3 with Commit[1] but never Reqout_3!==Ackout");
        if (pkt2_head_on_data3 && (data3 !== PKT1_HEAD) && !pkt2_dir_offer_seen)
          first_anomaly(1, "IPM_REQOUT",
                        "Head left Dataout_3 without any direction-level offer");

        // 2. Selector: allow ~1 ns for mutex resolve before calling it broken.
        if ((pe3 === 1'b1) && known01(lsel[0]) && known01(lsel[1]) &&
            (lsel !== 2'b01) && (lsel !== 2'b10)) begin
          if (pe3_unsel_ns == 0.0)
            pe3_unsel_ns = $realtime;
          else if (pkt2_head_on_data3 && (($realtime - pe3_unsel_ns) >= 1.0))
            first_anomaly(2, "SELECTOR_LANESELECT",
                          "PathEnabled_3=1 but LaneSelect not one-hot for >=1ns");
        end else
          pe3_unsel_ns = 0.0;
        if ((pe3 === 1'b0) && (lsel !== 2'b00) && known01(lsel[0]) && known01(lsel[1])) begin
          if (pe3_hold_ns == 0.0)
            pe3_hold_ns = $realtime;
          else if (($realtime - pe3_hold_ns) >= 1.0)
            first_anomaly(2, "SELECTOR_LANESELECT",
                          "PathEnabled_3=0 but LaneSelect still set for >=1ns");
        end else
          pe3_hold_ns = 0.0;

        // 3. Adapter idle: Commit=0 => Reqout[1] must equal Ackin[1].
        if (tail_seen && (cmt === 2'b00) && known01(reqout_adp[1]) &&
            known01(ackin[1]) && (reqout_adp[1] !== ackin[1]))
          first_anomaly(3, "ADAPTER_IDLE_REQOUT",
                        "Commit=0 but Reqout[1]!==Ackin[1]");

        // 4. Adapter after Commit[1]: Reqout[1] == Reqin XOR PhaseOffset,
        //    and a pending IPM offer must produce Reqout[1]!==Ackin[1].
        if ((cmt[1] === 1'b1) && known01(reqin) && known01(offset) &&
            known01(reqout_adp[1]) && (reqout_adp[1] !== expected_req1))
          first_anomaly(4, "ADAPTER_REQOUT_EQ",
                        "Commit[1]=1 but Reqout[1]!==(Reqin XOR PhaseOffset)");
        if ((cmt[1] === 1'b1) && pkt2_head_on_data3 && (data3 === PKT1_HEAD) &&
            pkt2_dir_offer_seen && known01(reqout_adp[1]) && known01(ackin[1]) &&
            (reqout_adp[1] === ackin[1]))
          first_anomaly(4, "ADAPTER_REQOUT",
                        "Commit[1]=1 with IPM offer but Reqout[1] matches Ackin (no new phase)");

        // 5. OPM only if adapter already opened a new lane phase.
        if ((cmt[1] === 1'b1) && known01(reqout_adp[1]) && known01(ackin[1]) &&
            (reqout_adp[1] !== ackin[1]) && known01(opm_req) && known01(opm_ack) &&
            (opm_req === opm_ack) && pkt2_head_on_data3 && (data3 === PKT1_HEAD))
          first_anomaly(5, "OPM_REQOUT",
                        "adapter Reqout[1]!==Ackin[1] but OPM Req==Ack while Head is on Dataout_3");
      end
    end
  endtask

  reg last_pe3, last_r3, last_ackout, last_tp3, last_offset, last_assigned;
  reg [1:0] last_lsel, last_cmt, last_ackin, last_reqout, last_ogrnt;
  reg last_ppe1, last_gnt1, last_opm_req, last_opm_ack;
  reg [27:0] last_data3, last_opm_data;

  function automatic bit changed;
    begin
      changed = (pe3 !== last_pe3) || (r3 !== last_r3) ||
                (ackout !== last_ackout) || (data3 !== last_data3) ||
                (tp3 !== last_tp3) || (lsel !== last_lsel) ||
                (ogrnt !== last_ogrnt) || (offset !== last_offset) ||
                (assigned !== last_assigned) || (cmt !== last_cmt) ||
                (ackin !== last_ackin) || (reqout_adp !== last_reqout) ||
                (ppe1 !== last_ppe1) || (gnt1 !== last_gnt1) ||
                (opm_req !== last_opm_req) || (opm_ack !== last_opm_ack) ||
                (opm_data !== last_opm_data);
    end
  endfunction

  task automatic sample;
    begin
      if (changed()) begin
        record();
        check();
        if (in_win())
          emit("LIVE");
        last_pe3 = pe3; last_r3 = r3; last_ackout = ackout;
        last_data3 = data3; last_tp3 = tp3; last_lsel = lsel;
        last_ogrnt = ogrnt; last_offset = offset; last_assigned = assigned;
        last_cmt = cmt; last_ackin = ackin; last_reqout = reqout_adp;
        last_ppe1 = ppe1; last_gnt1 = gnt1;
        last_opm_req = opm_req; last_opm_ack = opm_ack; last_opm_data = opm_data;
      end
    end
  endtask

  initial begin
    next_slot = 0; count = 0; total = 0; first_kind = 0; first_ns = 0;
    pkt2_head_on_data3 = 0; pkt2_dir_offer_seen = 0; tail_seen = 0;
    pe3_unsel_ns = 0; pe3_hold_ns = 0;
    last_pe3 = 1'bx; last_r3 = 1'bx; last_ackout = 1'bx; last_tp3 = 1'bx;
    last_offset = 1'bx; last_assigned = 1'bx;
    last_lsel = 2'bx; last_cmt = 2'bx; last_ackin = 2'bx; last_reqout = 2'bx;
    last_ogrnt = 2'bx; last_ppe1 = 1'bx; last_gnt1 = 1'bx;
    last_opm_req = 1'bx; last_opm_ack = 1'bx;
    last_data3 = 28'hx; last_opm_data = 28'hx;
    $display("CMR_L1ADAPT_MAP IPM1.parent=selector_1+adapter_1 -> OPM5/upward_1");
    $display("CMR_L1ADAPT_MAP watch head=%h body=%h tail=%h win=%0.0f-%0.0f",
             PKT1_HEAD, PKT1_BODY, PKT1_TAIL, WIN_LO, WIN_HI);
  end

  always @(pe3 or r3 or ackout or data3 or tp3 or lsel or ogrnt or offset or
           assigned or cmt or ackin or reqout_adp or ppe1 or gnt1 or
           opm_req or opm_ack or opm_data or reqin)
    sample();

  always @(posedge trigger) begin
    $display("CMR_L1ADAPT_DUMP t_ns=%0.3f retained=%0d total=%0d",
             $realtime, count, total);
    if (first_kind == 0)
      $display("CMR_L1ADAPT_FIRST t_ns=%0.3f kind=NONE no contract break in %0.0f-%0.0f (pkt2_head=%0d dir_offer=%0d)",
               $realtime, WIN_LO, WIN_HI, pkt2_head_on_data3, pkt2_dir_offer_seen);
    for (dump_i = 0; dump_i < count; dump_i = dump_i + 1) begin
      dump_slot = ((count == DEPTH) ? next_slot : 0) + dump_i;
      if (dump_slot >= DEPTH) dump_slot = dump_slot - DEPTH;
      if ((event_time[dump_slot] >= WIN_LO) && (event_time[dump_slot] <= WIN_HI))
        $display("CMR_L1ADAPT_RING seq=%0d t_ns=%0.3f %s",
                 total - count + dump_i, event_time[dump_slot],
                 event_line[dump_slot]);
    end
  end

`undef ADP
`undef SEL
`undef IPM
`undef L1
`undef DUT
endmodule
