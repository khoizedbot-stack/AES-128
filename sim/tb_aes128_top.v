//==============================================================================
// Testbench: aes128_top (v3)
// Description: End-to-end encryption AND decryption tests
//
//   Interface:
//     start    — pulse to begin enc/dec (requires key_ready=1)
//     new_key  — pulse to trigger key expansion
//     enc_dec  — 0=encrypt, 1=decrypt
//     key      — 128-bit AES key
//     data_in  — plaintext (enc) or ciphertext (dec)
//     data_out — ciphertext (enc) or plaintext (dec)
//     busy     — high during operation
//     done     — pulses 1 when output is valid
//     key_ready— high after key expansion completes
//
//   NIST FIPS-197 test vectors:
//     Vector 1:
//       Key:        000102030405060708090a0b0c0d0e0f
//       Plaintext:  00112233445566778899aabbccddeeff
//       Ciphertext: 69c4e0d86a7b0430d8cdb78070b4c55a
//     Vector 2 (FIPS-197 Appendix C.1):
//       Key:        2b7e151628aed2a6abf7158809cf4f3c
//       Plaintext:  3243f6a8885a308d313198a2e0370734
//       Ciphertext: 3925841d02dc09fbdc118597196a0b32
//==============================================================================
`timescale 1ns/1ps

module tb_aes128_top;

    //==========================================================================
    // Parameters
    //==========================================================================
    localparam CLK_HALF = 5; // 10 ns clock

    //==========================================================================
    // Signals
    //==========================================================================
    reg         clk;
    reg         rst_n;
    reg         start;
    reg         new_key;
    reg         enc_dec;
    reg  [127:0] tb_data_out;
    wire [127:0] data_bus;
    reg  [127:0] captured_out;
    wire         busy;
    wire         done;
    wire         key_ready;

    integer pass_count;
    integer fail_count;
    integer test_num;
    integer timeout_cnt;

    //==========================================================================
    // DUT
    //==========================================================================
    aes128_top dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .new_key   (new_key),
        .enc_dec   (enc_dec),
        .data_bus  (data_bus),
        .busy      (busy),
        .done      (done),
        .key_ready (key_ready)
    );

    // Clock
    initial clk = 0;
    always #CLK_HALF clk = ~clk;

    // Bus mocking: AXI only drives during start or new_key
    assign data_bus = (start | new_key) ? tb_data_out : 128'hZ;

    // RTL now handles bus driving during S_DONE and persists until next command

    always @(posedge clk) begin
        if (done) captured_out <= data_bus;
    end

    //==========================================================================
    // Task: load new key and wait for expansion
    //==========================================================================
    task load_key;
        input [127:0] k;
        integer tmo;
        begin
            tb_data_out = k;
            new_key = 1'b1;
            @(posedge clk);
            new_key = 1'b0;

            // Wait for key_ready to drop (new expansion accepted), then rise.
            tmo = 0;
            while (key_ready && tmo < 10) begin
                @(posedge clk);
                tmo = tmo + 1;
            end

            timeout_cnt = 0;
            while (!key_ready && timeout_cnt < 50) begin
                @(posedge clk);
                timeout_cnt = timeout_cnt + 1;
            end
            if (!key_ready)
                $display("  WARNING: key_ready timeout!");
            @(posedge clk);
        end
    endtask

    //==========================================================================
    // Task: run enc/dec and check result
    //==========================================================================
    task run_check;
        input         ed;       // enc_dec
        input [127:0] din;
        input [127:0] expected;
        input [255:0] name;
        begin
            test_num = test_num + 1;
            enc_dec  = ed;
            tb_data_out = din;

            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            // Wait for done
            timeout_cnt = 0;
            while (!done && timeout_cnt < 40) begin
                @(posedge clk);
                timeout_cnt = timeout_cnt + 1;
            end

            if (!done) begin
                $display("[Test %0d] %s - FAIL (timeout, done never asserted)", test_num, name);
                fail_count = fail_count + 1;
            end else begin
                @(posedge clk); // wait 1 cycle for captured_out to latch
                if (captured_out === expected) begin
                    $display("[Test %0d] %s - PASS", test_num, name);
                $display("         data_out: %h", captured_out);
                pass_count = pass_count + 1;
            end else begin
                $display("[Test %0d] %s - FAIL", test_num, name);
                $display("         data_in:  %h", din);
                $display("         Expected: %h", expected);
                $display("         Got:      %h", captured_out);
                fail_count = fail_count + 1;
            end
            end

            @(posedge clk);
        end
    endtask

    //==========================================================================
    // Main test
    //==========================================================================
    initial begin
        $display("");
        $display("============================================================");
        $display("  AES128_TOP Testbench (v3 — enc + dec)");
        $display("============================================================");
        $display("");

        test_num   = 0;
        pass_count = 0;
        fail_count = 0;

        // Reset
        rst_n   = 0;
        start   = 0;
        new_key = 0;
        enc_dec = 0;
        enc_dec = 0;
        tb_data_out = 128'h0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // ==================================================================
        // NIST Vector 1
        // ==================================================================
        $display("--- NIST FIPS-197 Vector 1 ---");
        $display("  Key:       000102030405060708090a0b0c0d0e0f");
        load_key(128'h000102030405060708090a0b0c0d0e0f);
        $display("  key_ready=%b  (after expansion)", key_ready);

        // Encrypt
        $display("  >> Encrypt");
        run_check(1'b0,
                  128'h00112233445566778899aabbccddeeff,
                  128'h69c4e0d86a7b0430d8cdb78070b4c55a,
                  "V1 Encrypt");

        // Decrypt (same key, already loaded)
        $display("  >> Decrypt");
        run_check(1'b1,
                  128'h69c4e0d86a7b0430d8cdb78070b4c55a,
                  128'h00112233445566778899aabbccddeeff,
                  "V1 Decrypt");

        repeat(3) @(posedge clk);

        // ==================================================================
        // NIST Vector 2 (FIPS-197 Appendix C.1)
        // ==================================================================
        $display("");
        $display("--- NIST FIPS-197 Vector 2 ---");
        $display("  Key:       2b7e151628aed2a6abf7158809cf4f3c");
        load_key(128'h2b7e151628aed2a6abf7158809cf4f3c);

        // Encrypt
        $display("  >> Encrypt");
        run_check(1'b0,
                  128'h3243f6a8885a308d313198a2e0370734,
                  128'h3925841d02dc09fbdc118597196a0b32,
                  "V2 Encrypt");

        // Decrypt
        $display("  >> Decrypt");
        run_check(1'b1,
                  128'h3925841d02dc09fbdc118597196a0b32,
                  128'h3243f6a8885a308d313198a2e0370734,
                  "V2 Decrypt");

        repeat(3) @(posedge clk);

        // ==================================================================
        // Consecutive encryptions with same key (no new_key needed)
        // ==================================================================
        $display("");
        $display("--- Consecutive encryptions, same key ---");
        load_key(128'h000102030405060708090a0b0c0d0e0f);

        run_check(1'b0,
                  128'h00112233445566778899aabbccddeeff,
                  128'h69c4e0d86a7b0430d8cdb78070b4c55a,
                  "Consec Enc 1");

        run_check(1'b0,
                  128'h00000000000000000000000000000000,
                  128'hc6a13b37878f5b826f4f8162a1c8d879, // AES-128(000102..0f, 0)
                  "Consec Enc 2 (all-zero plaintext)");

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
        #50 $finish;
    end

    // Global timeout
    initial begin
        #10000;
        $display("GLOBAL TIMEOUT!");
        $finish;
    end

    // Cycle monitor (optional: uncomment for debug)
    // integer cyc;
    // initial cyc = 0;
    // always @(posedge clk) cyc = cyc + 1;

endmodule
