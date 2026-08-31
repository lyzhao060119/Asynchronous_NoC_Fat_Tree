`timescale 1ns/1ps

// #region agent log — RouterL1 DUT probe (session 93667c)
module fanin_debug_probe #(
  parameter integer FLIT_W = 28
)(
  input  wire              clk,
  input  wire              rst,
  input  wire              enable,
  input  integer           cycle_count,
  input  wire [5:0]        tb_in_req,
  input  wire [5:0]        tb_in_ack,
  input  wire [5:0]        tb_out_req,
  input  wire [5:0]        tb_out_ack,
  input  wire [3:0]        in_valid,
  input  wire [3:0]        is_head,
  input  wire [3:0]        head_alloc_ok,
  input  wire [3:0]        route_parent,
  input  wire [3:0]        elig_dm_p0,
  input  wire [3:0]        elig_dm_p1,
  input  wire [3:0]        fork_p0_full,
  input  wire [3:0]        fork_p1_full,
  input  wire [2:0]        holder_p0,
  input  wire [2:0]        holder_p1,
  input  wire [7:0]        edge_p0_full,
  input  wire [7:0]        edge_p1_full,
  input  wire [3:0]        op4_in_full,
  input  wire [3:0]        op4_fv,
  input  wire              op4_ov,
  input  wire              op4_or,
  input  wire              op4_start,
  input  wire              op4_oreq,
  input  wire              op4_oack,
  input  wire [3:0]        op5_in_full,
  input  wire [3:0]        op5_fv,
  input  wire              op5_ov,
  input  wire              op5_or,
  input  wire              op5_start,
  input  wire              op5_oreq,
  input  wire              op5_oack,
  input  wire [5:0]        iv6,
  input  wire [5:0]        ih6,
  input  wire [5:0]        ha6,
  input  wire [5:0]        ed6,
  input  wire [5:0]        h6,
  input  integer           inj,
  input  integer           del
);
  integer fd;
  reg [63:0] prev_key;
  reg [63:0] cur_key;
  reg first_log;
  reg [5:0] tin_full;
  reg [5:0] tout_full;
  reg [5:0] tin_stall;
  integer stall_age [0:5];
  integer p;

  initial begin
    fd = $fopen("../../debug-93667c.log", "w");
    first_log = 1'b1;
    prev_key = 64'hFFFFFFFFFFFFFFFF;
    for (p = 0; p < 6; p = p + 1) stall_age[p] = 0;
  end

  final begin
    if (fd != 0) $fclose(fd);
  end

  always @(posedge clk) begin
    if (!enable || rst || fd == 0) begin
      // no-op
    end else begin
      tin_full = tb_in_req ^ tb_in_ack;
      tout_full = tb_out_req ^ tb_out_ack;

      for (p = 0; p < 6; p = p + 1) begin
        if (tin_full[p]) begin
          stall_age[p] = stall_age[p] + 1;
        end else begin
          stall_age[p] = 0;
        end
      end

      tin_stall = 6'b0;
      for (p = 0; p < 6; p = p + 1) begin
        if (stall_age[p] >= 20) tin_stall[p] = 1'b1;
      end

      cur_key = {
        iv6, ih6, ha6, ed6, h6,
        tin_full, tout_full,
        op4_fv, op4_start, op4_oreq, op4_oack,
        op5_fv, op5_start, op5_oreq, op5_oack
      };

      if (first_log ||
          (cycle_count >= 10 && cycle_count <= 500 && (cycle_count % 25 == 0)) ||
          (cycle_count > 500 && (cycle_count % 200 == 0)) ||
          (cur_key != prev_key) ||
          (|tin_stall) ||
          (tb_out_req[4] !== tb_out_ack[4]) ||
          (tb_out_req[5] !== tb_out_ack[5])) begin

        $fwrite(
          fd,
          "{\"sessionId\":\"93667c\",\"runId\":\"mixed\",\"hypothesisId\":\"probe\",\"location\":\"fanin_debug_probe.sv\",\"message\":\"snap\",\"timestamp\":%0d,\"data\":{\"cyc\":%0d,\"iv6\":%0d,\"ih6\":%0d,\"ha6\":%0d,\"ed6\":%0d,\"h6\":%0d,\"tin\":%0d,\"tout\":%0d,\"stall\":%0d,\"sa0\":%0d,\"sa1\":%0d,\"sa2\":%0d,\"sa3\":%0d,\"sa4\":%0d,\"sa5\":%0d,\"inj\":%0d,\"del\":%0d,\"o4fv\":%0d,\"o4ov\":%0d,\"o4or\":%0d,\"o4st\":%0d,\"o4rq\":%0d,\"o4ak\":%0d,\"o5fv\":%0d,\"o5ov\":%0d,\"o5or\":%0d,\"o5st\":%0d,\"o5rq\":%0d,\"o5ak\":%0d}}\n",
          $time,
          cycle_count,
          iv6, ih6, ha6, ed6, h6,
          tin_full, tout_full, tin_stall,
          stall_age[0], stall_age[1], stall_age[2], stall_age[3], stall_age[4], stall_age[5],
          inj, del,
          op4_fv, op4_ov, op4_or, op4_start, op4_oreq, op4_oack,
          op5_fv, op5_ov, op5_or, op5_start, op5_oreq, op5_oack
        );
        first_log = 1'b0;
        prev_key = cur_key;
      end
    end
  end
endmodule
// #endregion
