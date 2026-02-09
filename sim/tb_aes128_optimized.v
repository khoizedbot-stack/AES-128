/*
 * Comprehensive Testbench for AES-128 with On-the-fly Key Generation
 * 
 * Tests:
 *   1. NIST FIPS-197 test vector
 *   2. All-zeros test
 *   3. All-ones test
 *   4. Multiple consecutive encryptions
 *   5. Latency measurement
 */

`timescale 1ns/1ps

module tb_aes128_optimized;

    //==========================================================================
    // Signals
    //==========================================================================
    reg         clk;
    reg         rst_n;
    reg  [127:0] key;
    reg  [127:0] plain_text;
    reg         start;
    wire        busy;
    wire        done;
    wire [127:0] cipher_text;
    
    // Test counters
    integer test_num;
    integer pass_count;
    integer fail_count;
    integer cycle_count;
    integer total_cycles;

    integer i;
    reg [127:0] stress_key;
    reg [127:0] stress_pt;

    
    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    aes128_fsm_core dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .key        (key),
        .plain_text (plain_text),
        .start      (start),
        .busy       (busy),
        .done       (done),
        .cipher_text(cipher_text)
    );
    
    //==========================================================================
    // Clock Generation (100 MHz)
    //==========================================================================
    initial clk = 0;
    always #5 clk = ~clk;  // 10ns period
    
    //==========================================================================
    // Tasks
    //==========================================================================
    
    // Reset task
    task do_reset;
        begin
            rst_n = 0;
            start = 0;
            key = 128'h0;
            plain_text = 128'h0;
            repeat(10) @(posedge clk);
            rst_n = 1;
            repeat(2) @(posedge clk);
        end
    endtask
    
// Encrypt and check result
    task encrypt_and_check;
        input [127:0] test_key;
        input [127:0] test_pt;
        input [127:0] expected_ct;
        input [255:0] test_name;
        begin
            test_num = test_num + 1;
            
            // 1. Setup Data
            key = test_key;
            plain_text = test_pt;
            cycle_count = 0;
            
            // 2. Pulse Start
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;
            
            // 3. [CRITICAL FIX] Synchronization
            // First, wait for BUSY to go HIGH (confirm start)
            while (busy == 0) @(posedge clk);

            // Then, wait for DONE to go HIGH (confirm finish)
            while (done == 0) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
                if (cycle_count > 50) begin
                    $display("[Test %0d] %s - TIMEOUT!", test_num, test_name);
                    fail_count = fail_count + 1;
                    disable encrypt_and_check;
                end
            end
            
            total_cycles = total_cycles + cycle_count;
            
            // 4. Check Result (Add small delay to ensure data stability)
            #1; 
            if (cipher_text === expected_ct) begin
                $display("[Test %0d] %s - PASS (%0d cycles)", test_num, test_name, cycle_count);
                pass_count = pass_count + 1;
            end else begin
                $display("[Test %0d] %s - FAIL", test_num, test_name);
                $display("          Key:      %h", test_key);
                $display("          PT:       %h", test_pt);
                $display("          Expected: %h", expected_ct);
                $display("          Got:      %h", cipher_text);
                fail_count = fail_count + 1;
            end
            
            // 5. Cleanup
            repeat(2) @(posedge clk);
        end
    endtask
            
    task encrypt_only;
        input [127:0] test_key;
        input [127:0] test_pt;
        begin
            key = test_key;
            plain_text = test_pt;
            
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;
            
            // Robust Wait
            while (busy == 0) @(posedge clk); // Wait for start
            while (done == 0) @(posedge clk); // Wait for finish
            
            repeat(2) @(posedge clk);
        end
    endtask
            
    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        $display("");
        $display("================================================================");
        $display("  AES-128 On-the-fly Key Generation - Comprehensive Testbench");
        $display("================================================================");
        $display("");
        
        // Initialize counters
        test_num = 0;
        pass_count = 0;
        fail_count = 0;
        total_cycles = 0;
        
        // Reset
        do_reset();
        
        //======================================================================
        // Test 1: NIST FIPS-197 Test Vector (Appendix B)
        //======================================================================
        $display("--- NIST FIPS-197 Test Vector ---");
        encrypt_and_check(
            128'h000102030405060708090a0b0c0d0e0f,  // Key
            128'h00112233445566778899aabbccddeeff,  // Plaintext
            128'h69c4e0d86a7b0430d8cdb78070b4c55a,  // Expected Ciphertext
            "NIST FIPS-197"
        );
        
        //======================================================================
        // Test 2: All Zeros
        //======================================================================
        $display("");
        $display("--- Zero Key/Plaintext Tests ---");
        encrypt_and_check(
            128'h00000000000000000000000000000000,  // Key = 0
            128'h00000000000000000000000000000000,  // PT = 0
            128'h66e94bd4ef8a2c3b884cfa59ca342b2e,  // Expected
            "All Zeros"
        );
        
        //======================================================================
        // Test 3: All Ones
        //======================================================================
        encrypt_and_check(
            128'hffffffffffffffffffffffffffffffff,  // Key = all 1s
            128'hffffffffffffffffffffffffffffffff,  // PT = all 1s
            128'hbcbf217cb280cf30b2517052193ab979,  // Expected (verified with PyCryptodome)
            "All Ones"
        );
        
        //======================================================================
        // Test 4: NIST Test Vector #2 (from FIPS-197 Appendix C.1)
        //======================================================================
        $display("");
        $display("--- Additional NIST Vectors ---");
        encrypt_and_check(
            128'h2b7e151628aed2a6abf7158809cf4f3c,  // Key
            128'h6bc1bee22e409f96e93d7e117393172a,  // Plaintext
            128'h3ad77bb40d7a3660a89ecaf32466ef97,  // Expected
            "NIST Vector #2"
        );
        
        //======================================================================
        // Test 5: Another NIST Vector
        //======================================================================
        encrypt_and_check(
            128'h2b7e151628aed2a6abf7158809cf4f3c,  // Same Key
            128'hae2d8a571e03ac9c9eb76fac45af8e51,  // Different Plaintext
            128'hf5d3d58503b9699de785895a96fdbaaf,  // Expected
            "NIST Vector #3"
        );
        
        //======================================================================
        // Test 6-10: Consecutive Encryptions (same key, different PT)
        //======================================================================
        $display("");
        $display("--- Consecutive Encryption Tests ---");
        
        encrypt_and_check(
            128'h0f1571c947d9e8590cb7add6af7f6798,
            128'h0123456789abcdeffedcba9876543210,
            128'hff0b844a0853bf7c6934ab4364148fb9,
            "Consecutive #1"
        );
        
        encrypt_and_check(
            128'h0f1571c947d9e8590cb7add6af7f6798,  // Same key
            128'h1123456789abcdeffedcba9876543210,  // PT + 1
            128'h68e88a7a56317f4de425c695f9bb2901,  // Verified with PyCryptodome
            "Consecutive #2"
        );
        
        encrypt_and_check(
            128'h0f1571c947d9e8590cb7add6af7f6798,  // Same key
            128'h2123456789abcdeffedcba9876543210,  // PT + 2
            128'h3f2d67a3760955591476dd99124424e4,  // Verified with PyCryptodome
            "Consecutive #3"
        );
        
        //======================================================================
        // Test 11: Key Change Test
        //======================================================================
        $display("");
        $display("--- Key Change Test ---");
        encrypt_and_check(
            128'hdeadbeefdeadbeefdeadbeefdeadbeef,  // New key
            128'h00112233445566778899aabbccddeeff,  // Same PT as NIST
            128'h7c4e65a317da376f71052f0a7366ad64,  // Verified with PyCryptodome
            "Key Change"
        );
        
        //======================================================================
        // Summary
        //======================================================================
        $display("");
        $display("================================================================");
        $display("  Test Summary");
        $display("================================================================");
        $display("  Total Tests:    %0d", test_num);
        $display("  Passed:         %0d", pass_count);
        $display("  Failed:         %0d", fail_count);
        $display("  Avg Latency:    %0d cycles", total_cycles / test_num);
        $display("================================================================");
        
        if (fail_count == 0) begin
            $display("");
            $display("  *** ALL TESTS PASSED ***");
            $display("");
        end else begin
            $display("");
            $display("  *** SOME TESTS FAILED ***");
            $display("");
        end
        
        //======================================================================
        // Stress Test: 100 consecutive encryptions
        //======================================================================
        $display("--- Stress Test: 100 Consecutive Encryptions ---");
        begin            
            stress_key = 128'h000102030405060708090a0b0c0d0e0f;
            stress_pt = 128'h00112233445566778899aabbccddeeff;
            
            for (i = 0; i < 100; i = i + 1) begin
                encrypt_only(stress_key, stress_pt + i);
            end
            $display("  100 encryptions completed successfully");
        end
        
        $display("");
        $display("================================================================");
        $display("  Testbench Complete");
        $display("================================================================");
        
        #100;
        $finish;
    end
    
    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #100000;  // 100us timeout
        $display("ERROR: Global timeout reached!");
        $finish;
    end
    
    //==========================================================================
    // Optional: Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("aes128_optimized.vcd");
        $dumpvars(0, tb_aes128_optimized);
    end

endmodule
