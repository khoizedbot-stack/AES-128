`timescale 1ns/1ps

//==============================================================================
// Testbench: tb_key_schedule
// Purpose:
//   One AES-128 key expansion case.
//   After expansion is done, sweep round_idx from 0 to 10
//   to show round_key = keys[round_idx].
//==============================================================================

module tb_key_schedule;

    localparam CLK_HALF = 5;

    reg          clk;
    reg          rst_n;
    reg          start_expand;
    reg  [127:0] key_in;
    reg  [3:0]   round_idx;

    wire         key_ready;
    wire         busy;
    wire [127:0] round_key;

    integer timeout_cnt;
    integer i;
    integer pass_count;
    integer fail_count;

    // =========================================================================
    // DUT
    // =========================================================================
    key_schedule dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .start_expand (start_expand),
        .key_in       (key_in),
        .key_ready    (key_ready),
        .busy         (busy),
        .round_idx    (round_idx),
        .round_key    (round_key)
    );

    // =========================================================================
    // Clock
    // =========================================================================
    initial begin
        clk = 1'b0;
    end

    always #CLK_HALF clk = ~clk;

    // =========================================================================
    // Expected round keys for key = 000102030405060708090a0b0c0d0e0f
    // =========================================================================
    function [127:0] expected_key;
        input [3:0] idx;
        begin
            case (idx)
                4'd0:  expected_key = 128'h000102030405060708090a0b0c0d0e0f;
                4'd1:  expected_key = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe;
                4'd2:  expected_key = 128'hb692cf0b643dbdf1be9bc5006830b3fe;
                4'd3:  expected_key = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41;
                4'd4:  expected_key = 128'h47f7f7bc95353e03f96c32bcfd058dfd;
                4'd5:  expected_key = 128'h3caaa3e8a99f9deb50f3af57adf622aa;
                4'd6:  expected_key = 128'h5e390f7df7a69296a7553dc10aa31f6b;
                4'd7:  expected_key = 128'h14f9701ae35fe28c440adf4d4ea9c026;
                4'd8:  expected_key = 128'h47438735a41c65b9e016baf4aebf7ad2;
                4'd9:  expected_key = 128'h549932d1f08557681093ed9cbe2c974e;
                4'd10: expected_key = 128'h13111d7fe3944a17f307a78b4d2b30c5;
                default: expected_key = 128'h0;
            endcase
        end
    endfunction

    // =========================================================================
    // Main stimulus
    // =========================================================================
    initial begin
        $display("");
        $display("============================================================");
        $display(" KEY_SCHEDULE TEST - EXPAND THEN READ BY round_idx");
        $display("============================================================");

        rst_n        = 1'b0;
        start_expand = 1'b0;
        key_in       = 128'h00000000000000000000000000000000;
        round_idx    = 4'd0;
        timeout_cnt  = 0;
        pass_count   = 0;
        fail_count   = 0;

        // Reset
        repeat (2) @(posedge clk);
        
        rst_n = 1'b1;

        @(posedge clk);
        

        // ---------------------------------------------------------------------
        // 1. Send key and start expansion
        // ---------------------------------------------------------------------
        $display("");
        $display("--- Send key and start expansion ---");

        key_in       = 128'h000102030405060708090a0b0c0d0e0f;
        start_expand = 1'b1;
        round_idx    = 4'd0;

        @(posedge clk);
        
        start_expand = 1'b0;

        // ---------------------------------------------------------------------
        // 2. Wait for expansion done
        // ---------------------------------------------------------------------
        timeout_cnt = 0;
        while ((key_ready == 1'b0) && (timeout_cnt < 40)) begin
            @(posedge clk);
            timeout_cnt = timeout_cnt + 1;
        end

        if (key_ready == 1'b0) begin
            $display("FAIL: key_ready timeout");
            $finish;
        end

        $display("Expansion done: busy=%b key_ready=%b", busy, key_ready);

        @(posedge clk);
        

        // ---------------------------------------------------------------------
        // 3. Sweep round_idx after expansion to read stored keys
        // ---------------------------------------------------------------------
        $display("");
        $display("--- Sweep round_idx after expansion ---");

        for (i = 0; i <= 10; i = i + 1) begin
            round_idx = i[3:0];
            

            if (round_key === expected_key(i[3:0])) begin
                $display("K%0d PASS: round_idx=%0d round_key=%h", i, i, round_key);
                pass_count = pass_count + 1;
            end else begin
                $display("K%0d FAIL: round_idx=%0d", i, i);
                $display("  Expected: %h", expected_key(i[3:0]));
                $display("  Got:      %h", round_key);
                fail_count = fail_count + 1;
            end

            // Hold each round_idx for one full clock for waveform readability
            @(posedge clk);
            
        end

        $display("");
        $display("============================================================");
        $display(" Summary: Passed=%0d Failed=%0d", pass_count, fail_count);
        $display("============================================================");
        $display("");

        repeat (3) @(posedge clk);
        $finish;
    end

    // =========================================================================
    // Global timeout
    // =========================================================================
    initial begin
        #1000;
        $display("FAIL: global timeout");
        $finish;
    end

endmodule
