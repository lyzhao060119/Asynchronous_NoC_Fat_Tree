`timescale 1ns/1ps

module tb_lane_select_toy;
    reg reset = 1'b1;
    reg [3:0] lane_is_empty = 4'b1111;
    reg ppe = 1'b0;
    wire [3:0] lane_select;
    integer failures = 0;

    LaneSelectToyModuleHarness dut (
        .reset(reset), .LaneIsEmpty(lane_is_empty), .PPE(ppe),
        .LaneSelect(lane_select)
    );

    task automatic check_onehot(input [8*32-1:0] tag);
        begin
            #5.0;
            if (lane_select !== 4'b0001 && lane_select !== 4'b0010 &&
                lane_select !== 4'b0100 && lane_select !== 4'b1000) begin
                failures = failures + 1;
                $display("TB_RESULT FAIL %0s select=%b", tag, lane_select);
            end else $display("TB_CHECK PASS %0s select=%b", tag, lane_select);
        end
    endtask

    task automatic check_zero(input [8*32-1:0] tag);
        begin
            #5.0;
            if (lane_select !== 4'b0000) begin
                failures = failures + 1;
                $display("TB_RESULT FAIL %0s select=%b", tag, lane_select);
            end else $display("TB_CHECK PASS %0s select=0000", tag);
        end
    endtask

    task automatic burst_patterns;
        reg [3:0] patterns [0:7];
        integer k;
        begin
            patterns[0] = 4'b1111;
            patterns[1] = 4'b0001;
            patterns[2] = 4'b0010;
            patterns[3] = 4'b0100;
            patterns[4] = 4'b1000;
            patterns[5] = 4'b1010;
            patterns[6] = 4'b0101;
            patterns[7] = 4'b0000;
            for (k = 0; k < 8; k = k + 1) begin
                lane_is_empty = patterns[k];
                #0.35;
                check_onehot("burst_pattern");
            end
        end
    endtask

    initial begin
        $dumpfile("lane_select_toy.vcd");
        $dumpvars(0, tb_lane_select_toy);
        #1.0; reset = 1'b0; #1.0; ppe = 1'b1;
        check_onehot("all_empty_enable");
        lane_is_empty = 4'b0000;
        check_onehot("all_nonempty_hold");
        ppe = 1'b0;
        check_zero("ppe_withdraw");
        lane_is_empty = 4'b1010; ppe = 1'b1;
        check_onehot("re_enable_sparse_empty");

        // Continuous traffic-like control activity: change the empty mask
        // while PPE remains asserted, then withdraw/re-admit the producer.
        burst_patterns();
        ppe = 1'b0;
        check_zero("burst_withdraw");
        #0.7;
        ppe = 1'b1;
        lane_is_empty = 4'b0110;
        check_onehot("burst_readmit");

        // Reset and re-enter from a non-default lane mask.
        reset = 1'b1;
        ppe = 1'b0;
        lane_is_empty = 4'b0011;
        #1.0;
        reset = 1'b0;
        #0.5;
        ppe = 1'b1;
        check_onehot("reset_reentry");
        if (failures == 0) begin
            $display("TB_RESULT PASS LaneSelectToyModule failures=0");
            $finish;
        end else begin
            $display("TB_RESULT FAIL LaneSelectToyModule failures=%0d", failures);
            $finish(1);
        end
    end

    initial begin
        #200.0;
        $display("TB_RESULT FAIL LaneSelectToyModule timeout");
        $finish(1);
    end
endmodule
