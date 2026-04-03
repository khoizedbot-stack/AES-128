`timescale 1ns/1ps

module tb_key_schedule;

    localparam CLK_HALF = 5; // 10 ns clock period

    reg         clk;
    reg         rst_n;
    reg         start_expand;
    reg  [127:0] key_in;
    wire         key_ready;
    wire         busy;
    reg  [3:0]   round_idx;
    wire [127:0] round_key;

    integer pass_count;
    integer fail_count;
    integer test_num;

    key_schedule dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .start_expand   (start_expand),
        .key_in         (key_in),
        .key_ready      (key_ready),
        .busy           (busy),
        .round_idx      (round_idx),
        .round_key      (round_key)
    );

    initial clk = 0;
    always #CLK_HALF clk = ~clk;

    task check_round_key;
        input [3:0]   idx;
        input [127:0] expected;
        input [255:0] name;
        begin
            @(negedge clk);
            test_num  = test_num + 1;
            round_idx = idx;
            #1; // combinational settle delay
            if (round_key === expected) begin
                $display("[Test %0d] %s - PASS", test_num, name);
                pass_count = pass_count + 1;
            end else begin
                $display("[Test %0d] %s - FAIL", test_num, name);
                $display("         round_idx=%0d  Expected: %h", idx, expected);
                $display("         Got:      %h", round_key);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // init_round_key check removed as it is now handled by datapath (K0 or K10 lookup)

    task expand_key;
        input [127:0] k;
        integer tmo;
        begin
            @(negedge clk);
            key_in       = k;
            start_expand = 1'b1;
            @(negedge clk);
            start_expand = 1'b0;

            // Wait until key_ready asserts for the new expansion.
            tmo = 0;
            while (!key_ready && (tmo < 50)) begin
                @(posedge clk);
                tmo = tmo + 1;
            end

            if (!key_ready) begin
                $display("  ERROR: key_ready timeout in expand_key task");
                $finish;
            end
        end
    endtask

    initial begin
        $display("");
        $display("============================================================");
        $display("  KEY_SCHEDULE Testbench");
        $display("============================================================");
        $display("  NIST FIPS-197 Key = 000102030405060708090a0b0c0d0e0f");
        $display("============================================================");
        $display("");

        test_num   = 0;
        pass_count = 0;
        fail_count = 0;

        // Init
        rst_n        = 0;
        start_expand = 0;
        key_in       = 128'h0;
        round_idx    = 4'd1;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // ==================================================================
        // Test 1: NIST FIPS-197 key expansion
        // ==================================================================
        $display("--- Expanding NIST key ---");
        expand_key(128'h000102030405060708090a0b0c0d0e0f);
        $display("  key_ready=%b  busy=%b", key_ready, busy);

        // Port B: round keys K0..K10
        check_round_key(4'd0,  128'h000102030405060708090a0b0c0d0e0f, "K0");
        check_round_key(4'd1,  128'hd6aa74fdd2af72fadaa678f1d6ab76fe, "K1");
        check_round_key(4'd2,  128'hb692cf0b643dbdf1be9bc5006830b3fe, "K2");
        check_round_key(4'd3,  128'hb6ff744ed2c2c9bf6c590cbf0469bf41, "K3");
        check_round_key(4'd4,  128'h47f7f7bc95353e03f96c32bcfd058dfd, "K4");
        check_round_key(4'd5,  128'h3caaa3e8a99f9deb50f3af57adf622aa, "K5");
        check_round_key(4'd6,  128'h5e390f7df7a69296a7553dc10aa31f6b, "K6");
        check_round_key(4'd7,  128'h14f9701ae35fe28c440adf4d4ea9c026, "K7");
        check_round_key(4'd8,  128'h47438735a41c65b9e016baf4aebf7ad2, "K8");
        check_round_key(4'd9,  128'h549932d1f08557681093ed9cbe2c974e, "K9");
        check_round_key(4'd10, 128'h13111d7fe3944a17f307a78b4d2b30c5, "K10");

        // ==================================================================
        // Test 3: Second NIST vector — all-zeros key
        //   K0 = 00000000000000000000000000000000
        //   K1 = 62636363626363636263636362636363
        //   K2 = 9b9898c9f9fbfbaa9b9898c9f9fbfbaa
        //   K10= b4ef5bcb3e92e21123e951cf6f8f188e
        // ==================================================================
        $display("--- All-zeros key expansion ---");
        expand_key(128'h00000000000000000000000000000000);

        @(negedge clk);
        check_round_key(4'd0, 128'h00000000000000000000000000000000, "zeros enc: K0=0");
        check_round_key(4'd1, 128'h62636363626363636263636362636363, "zeros enc: K1");
        check_round_key(4'd2, 128'h9b9898c9f9fbfbaa9b9898c9f9fbfbaa, "zeros enc: K2");
        check_round_key(4'd10, 128'hb4ef5bcb3e92e21123e951cf6f8f188e, "zeros enc: K10");

        // ==================================================================
        // Test 4: busy signal clears after expansion
        // ==================================================================
        $display("");
        $display("--- busy/key_ready signal check ---");
        test_num = test_num + 1;
        if (!busy && key_ready) begin
            $display("[Test %0d] busy=0 key_ready=1 after expansion - PASS", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("[Test %0d] busy=%b key_ready=%b (expected 0/1) - FAIL", test_num, busy, key_ready);
            fail_count = fail_count + 1;
        end

        // ==================================================================
        // Summary
        // ==================================================================
        $display("");
        $display("============================================================");
        $display("  Summary: Passed=%0d  Failed=%0d", pass_count, fail_count);
        $display("============================================================");
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        $display("");
        #20 $finish;
    end

    initial begin
        #5000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule
