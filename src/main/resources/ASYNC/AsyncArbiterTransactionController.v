`timescale 1ns / 1ps

// Transaction front end for AtomicMulticastArbiterV2.  It owns only the
// asynchronous round protocol and frozen transaction payload; packetActive
// and outputOwner are intentionally outside this block and change only on the
// ACG fire edge.
module AsyncArbiterTransactionController #(
    parameter AnchorDelayValue = 1,
    parameter AnchorDelayUnitPs = 250,
    parameter RoundCloseDelayValue = 1,
    parameter RoundCloseDelayUnitPs = 250,
    parameter MembershipDelayValue = 1,
    parameter MembershipDelayUnitPs = 250,
    parameter FinalBuilderDelayValue = 1,
    parameter FinalBuilderDelayUnitPs = 250,
    parameter ReturnDelayValue = 1,
    parameter ReturnDelayUnitPs = 250
) (
    input  wire       reset,
    input  wire       fire,
    input  wire [4:0] packet_present,
    input  wire [4:0] packet_active,
    input  wire [4:0] all_tail_passed,
    input  wire [4:0] output_tail_busy,
    input  wire [2:0] owner0,
    input  wire [2:0] owner1,
    input  wire [2:0] owner2,
    input  wire [2:0] owner3,
    input  wire [2:0] owner4,
    input  wire [4:0] mask0,
    input  wire [4:0] mask1,
    input  wire [4:0] mask2,
    input  wire [4:0] mask3,
    input  wire [4:0] mask4,
    output wire       tx_valid,
    output wire       tx_release,
    output wire [4:0] tx_winner,
    output wire [4:0] tx_mask0,
    output wire [4:0] tx_mask1,
    output wire [4:0] tx_mask2,
    output wire [4:0] tx_mask3,
    output wire [4:0] tx_mask4
);
    localparam [2:0] NONE = 3'd5;

    wire [4:0] free;
    wire [4:0] admission_req;
    wire [4:0] release_req;
    wire [4:0] arb_req;
    wire [4:0] anchor_grant;
    wire [4:0] admit_set;
    wire [4:0] release_set;
    wire [4:0] admit_q;
    wire [4:0] release_q;
    wire       anchor_captured;
    wire       anchor_start;
    wire       round_busy;
    wire       round_reset;
    wire [4:0] anchor_q;
    wire       anchor_release_q;
    wire [4:0] anchor_mask;
    wire       commit_seen;
    wire       request_any;
    wire       set_round;
    wire       clear_round;
    wire       build_enable;
    wire       release_ready;
    wire       commit_visible;
    wire       clear_busy_req;
    wire       busy_cleared;
    wire       cleanup_done;
    wire       request_cone_start;
    wire       request_cone_ready;
    wire       return_done;
    wire       return_ack;
    wire       return_ack_set;
    wire       return_ack_clear;
    wire       seen1, seen2, seen3, seen4;
    wire       member_ack1, member_ack2, member_ack3, member_ack4;
    wire       close_ready1, close_ready2, close_ready3, close_ready4;
    wire       skip_set1, skip_set2, skip_set3, skip_set4;
    wire       empty_skip1, empty_skip2, empty_skip3, empty_skip4;
    wire       member_closed1, member_closed2, member_closed3, member_closed4;
    wire       close_pair01, close_pair23, membership_join_all_z;
    wire       all_empty_skip, all_membership_closed;
    wire       round_close;
    wire       final_builder_ready;

    assign free[0] = (owner0 == NONE) & ~output_tail_busy[0];
    assign free[1] = (owner1 == NONE) & ~output_tail_busy[1];
    assign free[2] = (owner2 == NONE) & ~output_tail_busy[2];
    assign free[3] = (owner3 == NONE) & ~output_tail_busy[3];
    assign free[4] = (owner4 == NONE) & ~output_tail_busy[4];

    function all_free;
        input [4:0] m;
        input [4:0] f;
        begin all_free = &(~m | f); end
    endfunction

    assign admission_req[0] = packet_present[0] & ~packet_active[0] & (|mask0) & all_free(mask0, free);
    assign admission_req[1] = packet_present[1] & ~packet_active[1] & (|mask1) & all_free(mask1, free);
    assign admission_req[2] = packet_present[2] & ~packet_active[2] & (|mask2) & all_free(mask2, free);
    assign admission_req[3] = packet_present[3] & ~packet_active[3] & (|mask3) & all_free(mask3, free);
    assign admission_req[4] = packet_present[4] & ~packet_active[4] & (|mask4) & all_free(mask4, free);
    assign release_req = packet_present & packet_active & all_tail_passed;
    // SELECT is !round_busy && request_any: Mutex still sees req until
    // sticky capture raises occupancy and withdraws arb_req.
    assign request_any = |(admission_req | release_req);
    // RETURN owns the Mutex boundary until the committed state, captured
    // anchor and request cone have all returned.  round_busy intentionally
    // falls before the rest of RETURN, so it cannot be the only gate here.
    assign arb_req = (admission_req | release_req) &
                     {5{~round_busy & ~commit_seen & ~clear_busy_req & ~return_ack}};

    Mutex5Anchor anchor_mutex(.reset(reset), .req(arb_req), .grant(anchor_grant));
    // Sticky dual-rail capture.  AdmitSet/ReleaseSet fire while grant is
    // still high; Q holds after busy drops arb_req.  The ANC0 transparent
    // latch (en=~round_busy, d=grant) plus grant→DEL→busy sampled an empty
    // grant once that DEL was removed.
    assign admit_set = anchor_grant & admission_req;
    assign release_set = anchor_grant & release_req;
    DLatchBank #(.WIDTH(5)) admit_q_latch (
        .reset(reset), .en(round_reset | (|admit_set)),
        .d(round_reset ? 5'b0 : (admit_q | admit_set)),
        .q(admit_q)
    );
    DLatchBank #(.WIDTH(5)) release_q_latch (
        .reset(reset), .en(round_reset | (|release_set)),
        .d(round_reset ? 5'b0 : (release_q | release_set)),
        .q(release_q)
    );
    assign anchor_q = admit_q | release_q;
    assign anchor_release_q = |release_q;
    assign anchor_captured = |anchor_q;
    // Named hierarchy retained as a DelayValue=0 buffer of the sticky
    // capture.  Busy is set from captured, not from DEL(OR(grant)).
    DelayElement #(.DelayValue(AnchorDelayValue), .DelayUnitPs(AnchorDelayUnitPs)) anchor_margin (
        .I(anchor_captured), .Z(anchor_start)
    );
    // Return matched delay now covers the *post-cleanup request cone*, rather
    // than directly resetting every round latch from DEL(fire).  The next
    // Mutex request is exposed only after this level has become valid.
    DelayElement #(.DelayValue(ReturnDelayValue), .DelayUnitPs(ReturnDelayUnitPs)) return_margin (
        .I(request_cone_start), .Z(request_cone_ready)
    );
    // Single occupancy bit (roundActive).  clear_busy_req is asserted before
    // anchor cleanup and held until RETURN completes.  The data input is tied
    // to the real set condition, so when clear_busy_req falls after cleanup,
    // D remains 0 while E closes.  This avoids the proven R3d/R3e gate-level
    // setup failure caused by D=~clearBusyReq (D rose as E fell).
    // Decoded phases (not stored):
    //   IDLE   = !round_busy && !request_any
    //   SELECT = !round_busy &&  request_any
    //   BUILD  = build_enable
    //   ARMED  = round_busy && tx_valid && !commit_seen
    //   RETURN = round_busy && commit_seen
    assign set_round = anchor_captured;
    assign clear_round = clear_busy_req;
    DLatchBank #(.WIDTH(1)) busy_latch (
        .reset(reset), .en(set_round | clear_round | anchor_start),
        .d(set_round & ~clear_round),
        .q(round_busy)
    );
    // Sticky fire is this round's returnReq.  It freezes transaction Q and
    // forbids BUILD/SELECT until the complete four-phase RETURN acknowledges.
    DLatchBank #(.WIDTH(1)) commit_seen_latch (
        .reset(reset), .en(fire | return_done),
        .d(return_done ? 1'b0 : (commit_seen | fire)),
        .q(commit_seen)
    );
    // BUILD is occupancy plus an admission anchor, before the transaction
    // latch and before RETURN.
    assign build_enable = round_busy & ~anchor_release_q & ~tx_valid & ~commit_seen & ~fire & ~round_reset;
    assign release_ready = round_busy & anchor_release_q & anchor_captured & ~commit_seen & ~fire & ~round_reset;

    // Commit visibility is evaluated only from the frozen transaction Q and
    // the fire-domain state bank.  It is deliberately stronger than merely
    // observing fire: admission requires every won output owner to match;
    // release requires Active/Present and every released owner to be clear.
    wire [4:0] owner_none;
    wire [4:0] owner_is0, owner_is1, owner_is2, owner_is3, owner_is4;
    assign owner_none = {(owner4 == NONE), (owner3 == NONE), (owner2 == NONE),
                         (owner1 == NONE), (owner0 == NONE)};
    assign owner_is0 = {(owner4 == 3'd0), (owner3 == 3'd0), (owner2 == 3'd0),
                        (owner1 == 3'd0), (owner0 == 3'd0)};
    assign owner_is1 = {(owner4 == 3'd1), (owner3 == 3'd1), (owner2 == 3'd1),
                        (owner1 == 3'd1), (owner0 == 3'd1)};
    assign owner_is2 = {(owner4 == 3'd2), (owner3 == 3'd2), (owner2 == 3'd2),
                        (owner1 == 3'd2), (owner0 == 3'd2)};
    assign owner_is3 = {(owner4 == 3'd3), (owner3 == 3'd3), (owner2 == 3'd3),
                        (owner1 == 3'd3), (owner0 == 3'd3)};
    assign owner_is4 = {(owner4 == 3'd4), (owner3 == 3'd4), (owner2 == 3'd4),
                        (owner1 == 3'd4), (owner0 == 3'd4)};

    wire admit_visible0 = ~tx_winner[0] | (packet_present[0] & packet_active[0] & (&(~tx_mask0 | owner_is0)));
    wire admit_visible1 = ~tx_winner[1] | (packet_present[1] & packet_active[1] & (&(~tx_mask1 | owner_is1)));
    wire admit_visible2 = ~tx_winner[2] | (packet_present[2] & packet_active[2] & (&(~tx_mask2 | owner_is2)));
    wire admit_visible3 = ~tx_winner[3] | (packet_present[3] & packet_active[3] & (&(~tx_mask3 | owner_is3)));
    wire admit_visible4 = ~tx_winner[4] | (packet_present[4] & packet_active[4] & (&(~tx_mask4 | owner_is4)));
    wire release_visible0 = ~tx_winner[0] | (~packet_present[0] & ~packet_active[0] & (&(~tx_mask0 | owner_none)));
    wire release_visible1 = ~tx_winner[1] | (~packet_present[1] & ~packet_active[1] & (&(~tx_mask1 | owner_none)));
    wire release_visible2 = ~tx_winner[2] | (~packet_present[2] & ~packet_active[2] & (&(~tx_mask2 | owner_none)));
    wire release_visible3 = ~tx_winner[3] | (~packet_present[3] & ~packet_active[3] & (&(~tx_mask3 | owner_none)));
    wire release_visible4 = ~tx_winner[4] | (~packet_present[4] & ~packet_active[4] & (&(~tx_mask4 | owner_none)));
    assign commit_visible = tx_release ?
        (release_visible0 & release_visible1 & release_visible2 & release_visible3 & release_visible4) :
        (admit_visible0 & admit_visible1 & admit_visible2 & admit_visible3 & admit_visible4);

    // Four-phase RETURN:
    //   fire/commit_seen -> visible state -> clearBusyReq -> busy cleared
    //   -> clear round payload -> delayed request-cone ready -> returnAck
    //   -> clear requests -> returnAck returns last.
    wire clear_busy_set = commit_seen & commit_visible & ~fire;
    DLatchBank #(.WIDTH(1)) clear_busy_req_latch (
        .reset(reset), .en(clear_busy_set | return_ack),
        .d(return_ack ? 1'b0 : (clear_busy_req | clear_busy_set)),
        .q(clear_busy_req)
    );
    assign busy_cleared = clear_busy_req & ~round_busy;
    // This level clears all per-round builder/anchor state while the Mutex
    // boundary remains closed by clear_busy_req/commit_seen.
    assign round_reset = clear_busy_req & busy_cleared;
    assign cleanup_done = round_reset & ~anchor_captured & ~tx_valid &
                          ~(|anchor_grant) & ~seen1 & ~seen2 & ~seen3 & ~seen4 &
                          ~empty_skip1 & ~empty_skip2 & ~empty_skip3 & ~empty_skip4 &
                          ~close_pair01 & ~close_pair23 & ~membership_join_all_z;
    assign request_cone_start = cleanup_done & commit_seen & ~fire;
    assign return_ack_set = request_cone_ready & cleanup_done & clear_busy_req & commit_seen & ~fire;
    assign return_ack_clear = return_ack & ~clear_busy_req & ~commit_seen;
    DLatchBank #(.WIDTH(1)) return_ack_latch (
        .reset(reset), .en(return_ack_set | return_ack_clear),
        .d(return_ack_clear ? 1'b0 : (return_ack | return_ack_set)),
        .q(return_ack)
    );
    assign return_done = return_ack;

    // Keep the mask muxes as explicit one-hot logic.  The builder's candidate
    // mask is bundled data, so it must not depend on a procedural function
    // evaluation at the same delta cycle as a rotating one-hot update.
    assign anchor_mask = ({5{anchor_q[0]}} & mask0) |
                         ({5{anchor_q[1]}} & mask1) |
                         ({5{anchor_q[2]}} & mask2) |
                         ({5{anchor_q[3]}} & mask3) |
                         ({5{anchor_q[4]}} & mask4);

    function [4:0] rot_onehot;
        input [4:0] anchor;
        input [2:0] rank;
        reg [2:0] base;
        reg [2:0] idx;
        begin
            case(anchor)
                5'b00001: base=0;
                5'b00010: base=1;
                5'b00100: base=2;
                5'b01000: base=3;
                default:   base=4;
            endcase
            idx = base + rank;
            if (idx >= 5) idx = idx - 5;
            if (idx >= 5) idx = idx - 5;
            rot_onehot = (5'b00001 << idx);
        end
    endfunction
    wire [4:0] cand1 = rot_onehot(anchor_q, 3'd1);
    wire [4:0] cand2 = rot_onehot(anchor_q, 3'd2);
    wire [4:0] cand3 = rot_onehot(anchor_q, 3'd3);
    wire [4:0] cand4 = rot_onehot(anchor_q, 3'd4);
    wire [4:0] cand1_mask = ({5{cand1[0]}} & mask0) | ({5{cand1[1]}} & mask1) |
                             ({5{cand1[2]}} & mask2) | ({5{cand1[3]}} & mask3) | ({5{cand1[4]}} & mask4);
    wire [4:0] cand2_mask = ({5{cand2[0]}} & mask0) | ({5{cand2[1]}} & mask1) |
                             ({5{cand2[2]}} & mask2) | ({5{cand2[3]}} & mask3) | ({5{cand2[4]}} & mask4);
    wire [4:0] cand3_mask = ({5{cand3[0]}} & mask0) | ({5{cand3[1]}} & mask1) |
                             ({5{cand3[2]}} & mask2) | ({5{cand3[3]}} & mask3) | ({5{cand3[4]}} & mask4);
    wire [4:0] cand4_mask = ({5{cand4[0]}} & mask0) | ({5{cand4[1]}} & mask1) |
                             ({5{cand4[2]}} & mask2) | ({5{cand4[3]}} & mask3) | ({5{cand4[4]}} & mask4);
    wire cand1_req = (cand1[0] & admission_req[0]) | (cand1[1] & admission_req[1]) |
                     (cand1[2] & admission_req[2]) | (cand1[3] & admission_req[3]) | (cand1[4] & admission_req[4]);
    wire cand2_req = (cand2[0] & admission_req[0]) | (cand2[1] & admission_req[1]) |
                     (cand2[2] & admission_req[2]) | (cand2[3] & admission_req[3]) | (cand2[4] & admission_req[4]);
    wire cand3_req = (cand3[0] & admission_req[0]) | (cand3[1] & admission_req[1]) |
                     (cand3[2] & admission_req[2]) | (cand3[3] & admission_req[3]) | (cand3[4] & admission_req[4]);
    wire cand4_req = (cand4[0] & admission_req[0]) | (cand4[1] & admission_req[1]) |
                     (cand4[2] & admission_req[2]) | (cand4[3] & admission_req[3]) | (cand4[4] & admission_req[4]);
    // Membership races open only in BUILD.  Release skips BUILD (SELECT +
    // ReleaseQ freezes tx).  RoundClose matches from the BUILD edge;
    // DelayValue is profile-controlled.
    DelayElement #(.DelayValue(RoundCloseDelayValue), .DelayUnitPs(RoundCloseDelayUnitPs)) round_close_margin (
        .I(build_enable), .Z(round_close)
    );

    AsyncRoundMembershipCell #(.DelayValue(MembershipDelayValue), .DelayUnitPs(MembershipDelayUnitPs)) member1(
        .reset(reset), .round_reset(round_reset), .candidate_req(cand1_req & build_enable), .round_close(round_close),
        .candidate_ack(member_ack1), .member_seen(seen1), .close_ready(close_ready1));
    AsyncRoundMembershipCell #(.DelayValue(MembershipDelayValue), .DelayUnitPs(MembershipDelayUnitPs)) member2(
        .reset(reset), .round_reset(round_reset), .candidate_req(cand2_req & build_enable), .round_close(round_close),
        .candidate_ack(member_ack2), .member_seen(seen2), .close_ready(close_ready2));
    AsyncRoundMembershipCell #(.DelayValue(MembershipDelayValue), .DelayUnitPs(MembershipDelayUnitPs)) member3(
        .reset(reset), .round_reset(round_reset), .candidate_req(cand3_req & build_enable), .round_close(round_close),
        .candidate_ack(member_ack3), .member_seen(seen3), .close_ready(close_ready3));
    AsyncRoundMembershipCell #(.DelayValue(MembershipDelayValue), .DelayUnitPs(MembershipDelayUnitPs)) member4(
        .reset(reset), .round_reset(round_reset), .candidate_req(cand4_req & build_enable), .round_close(round_close),
        .candidate_ack(member_ack4), .member_seen(seen4), .close_ready(close_ready4));

    // All membership bits must be frozen before a single combinational
    // rotated-greedy fold computes the transaction winner bundle.  A rank
    // with no live candidate at round_close is a late contender by protocol
    // (seen stays 0), so its close-path Mutex/C handshake only reconfirms
    // that; skip it.  skip_set is qualified by build_enable: round_close is
    // a DEL0 buffer of BUILD and lags after BUILD falls.  Without the
    // qualifier the latch re-arms between rounds (the 20260814_memskip_router
    // SDF failure).  Release never enters BUILD.
    assign skip_set1 = round_close & build_enable & ~cand1_req;
    assign skip_set2 = round_close & build_enable & ~cand2_req;
    assign skip_set3 = round_close & build_enable & ~cand3_req;
    assign skip_set4 = round_close & build_enable & ~cand4_req;

    // Sticky: a request that rises after skip is late and must not drop the
    // bypass.  Combinational (~cand_req & round_close) would glitch the C-tree.
    DLatchBank #(.WIDTH(1)) empty_skip1_latch (
        .reset(reset), .en(round_reset | skip_set1),
        .d(round_reset ? 1'b0 : 1'b1), .q(empty_skip1));
    DLatchBank #(.WIDTH(1)) empty_skip2_latch (
        .reset(reset), .en(round_reset | skip_set2),
        .d(round_reset ? 1'b0 : 1'b1), .q(empty_skip2));
    DLatchBank #(.WIDTH(1)) empty_skip3_latch (
        .reset(reset), .en(round_reset | skip_set3),
        .d(round_reset ? 1'b0 : 1'b1), .q(empty_skip3));
    DLatchBank #(.WIDTH(1)) empty_skip4_latch (
        .reset(reset), .en(round_reset | skip_set4),
        .d(round_reset ? 1'b0 : 1'b1), .q(empty_skip4));

    assign member_closed1 = close_ready1 | empty_skip1;
    assign member_closed2 = close_ready2 | empty_skip2;
    assign member_closed3 = close_ready3 | empty_skip3;
    assign member_closed4 = close_ready4 | empty_skip4;

    MullerC2 membership_join01(.reset(reset | round_reset), .A(member_closed1), .B(member_closed2), .Z(close_pair01));
    MullerC2 membership_join23(.reset(reset | round_reset), .A(member_closed3), .B(member_closed4), .Z(close_pair23));
    MullerC2 membership_join_all(.reset(reset | round_reset), .A(close_pair01), .B(close_pair23), .Z(membership_join_all_z));
    // The C-tree still costs its mapped delay on four already-1 inputs; an
    // all-empty round (typical unicast) closes as soon as the skips set.
    assign all_empty_skip = empty_skip1 & empty_skip2 & empty_skip3 & empty_skip4;
    assign all_membership_closed = membership_join_all_z | all_empty_skip;

    wire take1 = seen1 & ~(|(cand1_mask & anchor_mask));
    wire [4:0] acc1 = take1 ? (anchor_mask | cand1_mask) : anchor_mask;
    wire [4:0] win1 = take1 ? (anchor_q | cand1) : anchor_q;
    wire take2 = seen2 & ~(|(cand2_mask & acc1));
    wire [4:0] acc2 = take2 ? (acc1 | cand2_mask) : acc1;
    wire [4:0] win2 = take2 ? (win1 | cand2) : win1;
    wire take3 = seen3 & ~(|(cand3_mask & acc2));
    wire [4:0] acc3 = take3 ? (acc2 | cand3_mask) : acc2;
    wire [4:0] win3 = take3 ? (win2 | cand3) : win2;
    wire take4 = seen4 & ~(|(cand4_mask & acc3));
    wire [4:0] win4 = take4 ? (win3 | cand4) : win3;

    // This replaces the four serial data-close margins with one final DEL250
    // after the complete membership snapshot.  It protects the final greedy
    // fold and transaction-latch D setup without changing any DEL setting.
    DelayElement #(.DelayValue(FinalBuilderDelayValue), .DelayUnitPs(FinalBuilderDelayUnitPs)) final_builder_margin (
        .I(all_membership_closed), .Z(final_builder_ready)
    );

    // ARMED is tx_valid.  Admission freezes after the builder; Release
    // freezes from sticky capture without BUILD.  commit_seen forbids a
    // second arming after fire and before round_reset.
    wire payload_ready = (anchor_release_q ? release_ready : (final_builder_ready & build_enable)) & ~commit_seen;
    wire [4:0] live_winner = anchor_release_q ? anchor_q : win4;
    DLatchBank #(.WIDTH(1)) valid_latch (
        .reset(reset), .en(payload_ready | fire),
        .d(fire ? 1'b0 : (tx_valid | payload_ready)),
        .q(tx_valid)
    );
    // The transaction payload is consumed on fire's rising edge.  It must
    // remain frozen through the complete RETURN handshake: tx_valid is
    // cleared by fire, but commit_visible still compares the live state bank
    // against these Q values until return_done.
    DLatchBank #(.WIDTH(1)) release_latch (
        .reset(reset), .en(~tx_valid & ~fire & ~commit_seen & ~return_ack), .d(anchor_release_q), .q(tx_release)
    );
    DLatchBank #(.WIDTH(5)) winner_latch (
        .reset(reset), .en(~tx_valid & ~fire & ~commit_seen & ~return_ack), .d(live_winner), .q(tx_winner)
    );
    DLatchBank #(.WIDTH(5)) txm0(.reset(reset), .en(~tx_valid & ~fire & ~commit_seen & ~return_ack), .d(mask0), .q(tx_mask0));
    DLatchBank #(.WIDTH(5)) txm1(.reset(reset), .en(~tx_valid & ~fire & ~commit_seen & ~return_ack), .d(mask1), .q(tx_mask1));
    DLatchBank #(.WIDTH(5)) txm2(.reset(reset), .en(~tx_valid & ~fire & ~commit_seen & ~return_ack), .d(mask2), .q(tx_mask2));
    DLatchBank #(.WIDTH(5)) txm3(.reset(reset), .en(~tx_valid & ~fire & ~commit_seen & ~return_ack), .d(mask3), .q(tx_mask3));
    DLatchBank #(.WIDTH(5)) txm4(.reset(reset), .en(~tx_valid & ~fire & ~commit_seen & ~return_ack), .d(mask4), .q(tx_mask4));
endmodule
