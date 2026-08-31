`default_nettype none
`timescale 1ns/1ps

module tb_noc16_async;
  localparam integer FLIT_W = 28;
  localparam integer NUM_PORTS = 20;
  localparam integer MAX_INPUT_FLITS = 131072;
  localparam integer MAX_EXPECT_FLITS = 262144;
  localparam integer MAX_RX_FLITS = NUM_PORTS * 8192;
  localparam integer RESET_CYCLES = 20;
  localparam integer RUN_TIMEOUT_CYCLES = 5000000;

  reg clock;
  reg reset;

  wire in_req [0:NUM_PORTS-1];
  wire in_ack [0:NUM_PORTS-1];
  wire [FLIT_W-1:0] in_data [0:NUM_PORTS-1];
  wire out_req [0:NUM_PORTS-1];
  wire out_ack [0:NUM_PORTS-1];
  wire [FLIT_W-1:0] out_data [0:NUM_PORTS-1];

  reg send_pulse [0:NUM_PORTS-1];
  reg [FLIT_W-1:0] send_data [0:NUM_PORTS-1];
  wire sender_busy [0:NUM_PORTS-1];
  wire got_pulse [0:NUM_PORTS-1];
  wire [FLIT_W-1:0] got_data [0:NUM_PORTS-1];

  NoC_16nodes dut (
    .clock(clock),
    .reset(reset),
    .io_core_inputs_0_HS_Req(in_req[0]),
    .io_core_inputs_0_HS_Ack(in_ack[0]),
    .io_core_inputs_0_Data_flit(in_data[0]),
    .io_core_inputs_1_HS_Req(in_req[1]),
    .io_core_inputs_1_HS_Ack(in_ack[1]),
    .io_core_inputs_1_Data_flit(in_data[1]),
    .io_core_inputs_2_HS_Req(in_req[2]),
    .io_core_inputs_2_HS_Ack(in_ack[2]),
    .io_core_inputs_2_Data_flit(in_data[2]),
    .io_core_inputs_3_HS_Req(in_req[3]),
    .io_core_inputs_3_HS_Ack(in_ack[3]),
    .io_core_inputs_3_Data_flit(in_data[3]),
    .io_core_inputs_4_HS_Req(in_req[4]),
    .io_core_inputs_4_HS_Ack(in_ack[4]),
    .io_core_inputs_4_Data_flit(in_data[4]),
    .io_core_inputs_5_HS_Req(in_req[5]),
    .io_core_inputs_5_HS_Ack(in_ack[5]),
    .io_core_inputs_5_Data_flit(in_data[5]),
    .io_core_inputs_6_HS_Req(in_req[6]),
    .io_core_inputs_6_HS_Ack(in_ack[6]),
    .io_core_inputs_6_Data_flit(in_data[6]),
    .io_core_inputs_7_HS_Req(in_req[7]),
    .io_core_inputs_7_HS_Ack(in_ack[7]),
    .io_core_inputs_7_Data_flit(in_data[7]),
    .io_core_inputs_8_HS_Req(in_req[8]),
    .io_core_inputs_8_HS_Ack(in_ack[8]),
    .io_core_inputs_8_Data_flit(in_data[8]),
    .io_core_inputs_9_HS_Req(in_req[9]),
    .io_core_inputs_9_HS_Ack(in_ack[9]),
    .io_core_inputs_9_Data_flit(in_data[9]),
    .io_core_inputs_10_HS_Req(in_req[10]),
    .io_core_inputs_10_HS_Ack(in_ack[10]),
    .io_core_inputs_10_Data_flit(in_data[10]),
    .io_core_inputs_11_HS_Req(in_req[11]),
    .io_core_inputs_11_HS_Ack(in_ack[11]),
    .io_core_inputs_11_Data_flit(in_data[11]),
    .io_core_inputs_12_HS_Req(in_req[12]),
    .io_core_inputs_12_HS_Ack(in_ack[12]),
    .io_core_inputs_12_Data_flit(in_data[12]),
    .io_core_inputs_13_HS_Req(in_req[13]),
    .io_core_inputs_13_HS_Ack(in_ack[13]),
    .io_core_inputs_13_Data_flit(in_data[13]),
    .io_core_inputs_14_HS_Req(in_req[14]),
    .io_core_inputs_14_HS_Ack(in_ack[14]),
    .io_core_inputs_14_Data_flit(in_data[14]),
    .io_core_inputs_15_HS_Req(in_req[15]),
    .io_core_inputs_15_HS_Ack(in_ack[15]),
    .io_core_inputs_15_Data_flit(in_data[15]),
    .io_top_input_0_HS_Req(in_req[16]),
    .io_top_input_0_HS_Ack(in_ack[16]),
    .io_top_input_0_Data_flit(in_data[16]),
    .io_top_input_1_HS_Req(in_req[17]),
    .io_top_input_1_HS_Ack(in_ack[17]),
    .io_top_input_1_Data_flit(in_data[17]),
    .io_top_input_2_HS_Req(in_req[18]),
    .io_top_input_2_HS_Ack(in_ack[18]),
    .io_top_input_2_Data_flit(in_data[18]),
    .io_top_input_3_HS_Req(in_req[19]),
    .io_top_input_3_HS_Ack(in_ack[19]),
    .io_top_input_3_Data_flit(in_data[19]),
    .io_top_output_0_HS_Req(out_req[16]),
    .io_top_output_0_HS_Ack(out_ack[16]),
    .io_top_output_0_Data_flit(out_data[16]),
    .io_top_output_1_HS_Req(out_req[17]),
    .io_top_output_1_HS_Ack(out_ack[17]),
    .io_top_output_1_Data_flit(out_data[17]),
    .io_top_output_2_HS_Req(out_req[18]),
    .io_top_output_2_HS_Ack(out_ack[18]),
    .io_top_output_2_Data_flit(out_data[18]),
    .io_top_output_3_HS_Req(out_req[19]),
    .io_top_output_3_HS_Ack(out_ack[19]),
    .io_top_output_3_Data_flit(out_data[19]),
    .io_core_outputs_0_HS_Req(out_req[0]),
    .io_core_outputs_0_HS_Ack(out_ack[0]),
    .io_core_outputs_0_Data_flit(out_data[0]),
    .io_core_outputs_1_HS_Req(out_req[1]),
    .io_core_outputs_1_HS_Ack(out_ack[1]),
    .io_core_outputs_1_Data_flit(out_data[1]),
    .io_core_outputs_2_HS_Req(out_req[2]),
    .io_core_outputs_2_HS_Ack(out_ack[2]),
    .io_core_outputs_2_Data_flit(out_data[2]),
    .io_core_outputs_3_HS_Req(out_req[3]),
    .io_core_outputs_3_HS_Ack(out_ack[3]),
    .io_core_outputs_3_Data_flit(out_data[3]),
    .io_core_outputs_4_HS_Req(out_req[4]),
    .io_core_outputs_4_HS_Ack(out_ack[4]),
    .io_core_outputs_4_Data_flit(out_data[4]),
    .io_core_outputs_5_HS_Req(out_req[5]),
    .io_core_outputs_5_HS_Ack(out_ack[5]),
    .io_core_outputs_5_Data_flit(out_data[5]),
    .io_core_outputs_6_HS_Req(out_req[6]),
    .io_core_outputs_6_HS_Ack(out_ack[6]),
    .io_core_outputs_6_Data_flit(out_data[6]),
    .io_core_outputs_7_HS_Req(out_req[7]),
    .io_core_outputs_7_HS_Ack(out_ack[7]),
    .io_core_outputs_7_Data_flit(out_data[7]),
    .io_core_outputs_8_HS_Req(out_req[8]),
    .io_core_outputs_8_HS_Ack(out_ack[8]),
    .io_core_outputs_8_Data_flit(out_data[8]),
    .io_core_outputs_9_HS_Req(out_req[9]),
    .io_core_outputs_9_HS_Ack(out_ack[9]),
    .io_core_outputs_9_Data_flit(out_data[9]),
    .io_core_outputs_10_HS_Req(out_req[10]),
    .io_core_outputs_10_HS_Ack(out_ack[10]),
    .io_core_outputs_10_Data_flit(out_data[10]),
    .io_core_outputs_11_HS_Req(out_req[11]),
    .io_core_outputs_11_HS_Ack(out_ack[11]),
    .io_core_outputs_11_Data_flit(out_data[11]),
    .io_core_outputs_12_HS_Req(out_req[12]),
    .io_core_outputs_12_HS_Ack(out_ack[12]),
    .io_core_outputs_12_Data_flit(out_data[12]),
    .io_core_outputs_13_HS_Req(out_req[13]),
    .io_core_outputs_13_HS_Ack(out_ack[13]),
    .io_core_outputs_13_Data_flit(out_data[13]),
    .io_core_outputs_14_HS_Req(out_req[14]),
    .io_core_outputs_14_HS_Ack(out_ack[14]),
    .io_core_outputs_14_Data_flit(out_data[14]),
    .io_core_outputs_15_HS_Req(out_req[15]),
    .io_core_outputs_15_HS_Ack(out_ack[15]),
    .io_core_outputs_15_Data_flit(out_data[15])
  );

  genvar pj;
  generate
    for (pj = 0; pj < NUM_PORTS; pj = pj + 1) begin : gen_ports
      async_hs_sender #(.FLIT_W(FLIT_W)) u_sender (
        .clk(clock),
        .rst(reset),
        .req(in_req[pj]),
        .ack(in_ack[pj]),
        .data(in_data[pj]),
        .send_pulse(send_pulse[pj]),
        .send_data(send_data[pj]),
        .busy(sender_busy[pj])
      );
      async_hs_receiver #(.FLIT_W(FLIT_W)) u_receiver (
        .clk(clock),
        .rst(reset),
        .req(out_req[pj]),
        .ack(out_ack[pj]),
        .data(out_data[pj]),
        .got_pulse(got_pulse[pj]),
        .got_data(got_data[pj])
      );
    end
  endgenerate

  integer input_count;
  integer input_cycle [0:MAX_INPUT_FLITS-1];
  integer input_port [0:MAX_INPUT_FLITS-1];
  integer input_pkt_seq [0:MAX_INPUT_FLITS-1];
  reg [FLIT_W-1:0] input_flit [0:MAX_INPUT_FLITS-1];

  integer expected_count;
  reg [NUM_PORTS-1:0] expected_mask [0:MAX_EXPECT_FLITS-1];
  integer expected_pkt_seq [0:MAX_EXPECT_FLITS-1];
  reg expected_is_tail [0:MAX_EXPECT_FLITS-1];
  reg [FLIT_W-1:0] expected_flit [0:MAX_EXPECT_FLITS-1];

  integer rx_count;
  integer rx_port [0:MAX_RX_FLITS-1];
  reg [FLIT_W-1:0] rx_flit [0:MAX_RX_FLITS-1];

  reg [1023:0] case_file;
  reg [1023:0] csv_file;
  reg [1023:0] case_name;
  reg [1023:0] case_group;
  integer cycle_counter;
  integer inject_idx;
  integer pass_count;
  integer fail_count;
  integer i;
  integer p;
  integer e;
  integer matched;

  initial clock = 1'b0;
  always #5 clock = ~clock;

  task automatic load_xsim_case_cfg;
    integer cfg_fd;
    integer n;
    reg [1023:0] line;
    reg [63:0] tag;
    reg [1023:0] value;
    begin
      cfg_fd = $fopen("noc16_xsim_case.cfg", "r");
      if (cfg_fd != 0) begin
        while (!$feof(cfg_fd)) begin
          line = "";
          if ($fgets(line, cfg_fd) != 0) begin
            tag = "";
            value = "";
            n = $sscanf(line, "%s %s", tag, value);
            if (n == 2) begin
              if ((tag == "CASE") && (case_file == "")) case_file = value;
              else if ((tag == "CSV") && (csv_file == "")) csv_file = value;
            end
          end
        end
        $fclose(cfg_fd);
      end
    end
  endtask

  task automatic load_case;
    input [1023:0] path;
    integer fd;
    integer line_no;
    reg [1023:0] line;
    reg [63:0] tag;
    integer cyc;
    integer pkt_seq;
    integer tmp;
    reg [FLIT_W-1:0] flit;
    reg [31:0] mask;
    begin
      input_count = 0;
      expected_count = 0;
      case_name = "unnamed";
      case_group = "misc";
      fd = $fopen(string'(path), "r");
      if (fd == 0) begin
        $display("TB_FATAL cannot open case file: %s", path);
        $finish;
      end
      line_no = 0;
      while (!$feof(fd)) begin
        if ($fgets(line, fd) != 0) begin
          line_no = line_no + 1;
          if (line == "") continue;
          if (line[0] == "#") continue;
          if ($sscanf(line, "%s", tag) != 1) continue;
        if (tag == "case") begin
          if ($sscanf(line, "%s %s", tag, case_name) != 2) begin
            $display("TB_FATAL malformed case at line %0d", line_no);
            $finish;
          end
        end else if (tag == "group") begin
          if ($sscanf(line, "%s %s", tag, case_group) != 2) begin
            $display("TB_FATAL malformed group at line %0d", line_no);
            $finish;
          end
        end else if (tag == "input") begin
          if ($sscanf(line, "%s %d %d %d %h", tag, cyc, p, pkt_seq, flit) != 5) begin
            $display("TB_FATAL malformed input at line %0d", line_no);
            $finish;
          end
          input_cycle[input_count] = cyc;
          input_port[input_count] = p;
          input_pkt_seq[input_count] = pkt_seq;
          input_flit[input_count] = flit;
          input_count = input_count + 1;
        end else if (tag == "expect") begin
          if ($sscanf(line, "%s %h %d %d %h", tag, mask, pkt_seq, tmp, flit) != 5) begin
            $display("TB_FATAL malformed expect at line %0d", line_no);
            $finish;
          end
          expected_mask[expected_count] = mask[NUM_PORTS-1:0];
          expected_pkt_seq[expected_count] = pkt_seq;
          expected_is_tail[expected_count] = (tmp == 1);
          expected_flit[expected_count] = flit;
          expected_count = expected_count + 1;
        end
        end
      end
      $fclose(fd);
      $display("TB_INFO loaded case %s inputs=%0d expects=%0d", path, input_count, expected_count);
    end
  endtask

  task automatic write_result_csv_and_finish;
    integer fd_csv;
    integer csv_pos;
    reg write_header;
    begin
      fd_csv = $fopen(string'(csv_file), "a+");
      if (fd_csv == 0) begin
        $display("TB_FATAL cannot open CSV file: %s", csv_file);
        $finish;
      end

      csv_pos = $fseek(fd_csv, 0, 2);
      csv_pos = $ftell(fd_csv);
      write_header = (csv_pos == 0);
      if (write_header) begin
        $fwrite(fd_csv, "group,case,expected_flits,matched_flits,missing_flits,received_flits,pass_fail\n");
      end

      if (fail_count == 0) begin
        $fwrite(fd_csv, "%0s,%0s,%0d,%0d,%0d,%0d,PASS\n",
                case_group, case_name, expected_count, pass_count, fail_count, rx_count);
        $display("TB_RESULT PASS group=%0s case=%0s expected=%0d matched=%0d missing=%0d rx=%0d",
                 case_group, case_name, expected_count, pass_count, fail_count, rx_count);
      end else begin
        $fwrite(fd_csv, "%0s,%0s,%0d,%0d,%0d,%0d,FAIL\n",
                case_group, case_name, expected_count, pass_count, fail_count, rx_count);
        $display("TB_RESULT FAIL group=%0s case=%0s expected=%0d matched=%0d missing=%0d rx=%0d",
                 case_group, case_name, expected_count, pass_count, fail_count, rx_count);
      end
      $fclose(fd_csv);
      $finish;
    end
  endtask

  initial begin
    case_file = "";
    csv_file = "";
    void'($value$plusargs("CASE_FILE=%s", case_file));
    void'($value$plusargs("CSV=%s", csv_file));
    load_xsim_case_cfg();
    if (case_file == "") case_file = "testbench/generated_cases/VCTM_16/VCTM-NoMC-1f-r0p02.case";
    if (csv_file == "") csv_file = "summary/noc16_async_summary.csv";
    load_case(case_file);

    reset = 1'b1;
    inject_idx = 0;
    rx_count = 0;
    cycle_counter = 0;
    for (i = 0; i < NUM_PORTS; i = i + 1) begin
      send_pulse[i] = 1'b0;
      send_data[i] = {FLIT_W{1'b0}};
    end
    repeat (RESET_CYCLES) @(posedge clock);
    reset = 1'b0;

    fork
      begin : inject_loop
        while (inject_idx < input_count) begin
          @(posedge clock);
          if (input_cycle[inject_idx] == cycle_counter) begin
            p = input_port[inject_idx];
            while (sender_busy[p]) @(posedge clock);
            send_data[p] = input_flit[inject_idx];
            send_pulse[p] = 1'b1;
            @(posedge clock);
            send_pulse[p] = 1'b0;
            inject_idx = inject_idx + 1;
          end
          cycle_counter = cycle_counter + 1;
          if (cycle_counter > RUN_TIMEOUT_CYCLES) begin
            $display("TB_FATAL inject timeout");
            $finish;
          end
        end
      end
      begin : capture_loop
        forever begin
          @(posedge clock);
          for (p = 0; p < NUM_PORTS; p = p + 1) begin
            if (got_pulse[p]) begin
              if (rx_count < MAX_RX_FLITS) begin
                rx_port[rx_count] = p;
                rx_flit[rx_count] = got_data[p];
                rx_count = rx_count + 1;
              end
            end
          end
        end
      end
    join_none

    repeat (RUN_TIMEOUT_CYCLES / 4) @(posedge clock);

    pass_count = 0;
    fail_count = 0;
    for (e = 0; e < expected_count; e = e + 1) begin
      matched = 0;
      for (i = 0; i < rx_count; i = i + 1) begin
        if (!matched &&
            expected_mask[e][rx_port[i]] &&
            (rx_flit[i] == expected_flit[e])) begin
          matched = 1;
        end
      end
      if (matched != 0) pass_count = pass_count + 1;
      else fail_count = fail_count + 1;
    end

    write_result_csv_and_finish();
  end
endmodule

`default_nettype wire
