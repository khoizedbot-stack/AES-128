//==============================================================================
// Testbench: encrypt_final_round
// Description: Test final encryption round (SubBytes, ShiftRows, AddRoundKey)
//              NO MixColumns in final round!
//==============================================================================

`timescale 1ns/1ps

module tb_encrypt_final_round;

    //==========================================================================
    // Signals
    //==========================================================================
    reg  [127:0] round_key;
    reg  [127:0] state_in;
    wire [127:0] state_round;
    
    // Test tracking
    integer test_num;
    integer pass_count;
    integer fail_count;
    
    //==========================================================================
    // DUT
    //==========================================================================
    encrypt_final_round dut (
        .round_key  (round_key),
        .state_in   (state_in),
        .state_round(state_round)
    );
    
    //==========================================================================
    // Task: Check result
    //==========================================================================
    task check_final;
        input [127:0] s_in;
        input [127:0] key;
        input [127:0] expected_out;
        input [255:0] test_name;
        begin
            test_num = test_num + 1;
            state_in = s_in;
            round_key = key;
            
            #10; // Wait for combinational logic
            
            if (state_round === expected_out) begin
                $display("[Test %0d] %s - PASS", test_num, test_name);
                pass_count = pass_count + 1;
            end else begin
                $display("[Test %0d] %s - FAIL", test_num, test_name);
                $display("         Input:    %h", s_in);
                $display("         Key:      %h", key);
                $display("         Expected: %h", expected_out);
                $display("         Got:      %h", state_round);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    //==========================================================================
    // Main Test
    //==========================================================================
    initial begin
        $display("");
        $display("============================================================");
        $display("  ENCRYPT_FINAL_ROUND Module Testbench");
        $display("============================================================");
        $display("  Testing: SubBytes -> ShiftRows -> AddRoundKey");
        $display("  NOTE: NO MixColumns in final round!");
        $display("============================================================");
        $display("");
        
        test_num = 0;
        pass_count = 0;
        fail_count = 0;
        
        //----------------------------------------------------------------------
        // NIST FIPS-197 - Round 10 (Final Round)
        //----------------------------------------------------------------------
        $display("--- NIST FIPS-197 Final Round ---");
        
        // Input to Round 10: bd6e7c3df2b5779e0b61216e8b10b689
        // K10 = 13111d7fe3944a17f307a78b4d2b30c5
        // Expected output (ciphertext): 69c4e0d86a7b0430d8cdb78070b4c55a
        check_final(
            128'hbd6e7c3df2b5779e0b61216e8b10b689,
            128'h13111d7fe3944a17f307a78b4d2b30c5,
            128'h69c4e0d86a7b0430d8cdb78070b4c55a,
            "NIST Round 10 (Final)"
        );
        
        //----------------------------------------------------------------------
        // Additional Tests
        //----------------------------------------------------------------------
        $display("");
        $display("--- Additional Tests ---");
        
        // All zeros input with zero key
        // SubBytes(0x00) = 0x63
        // ShiftRows doesn't change if all same
        // AddRoundKey with 0 = 0x63
        check_final(
            128'h00000000000000000000000000000000,
            128'h00000000000000000000000000000000,
            128'h63636363636363636363636363636363,
            "All Zeros"
        );
        
        // All ones (0xFF)
        // SubBytes(0xFF) = 0x16
        check_final(
            128'hffffffffffffffffffffffffffffffff,
            128'h00000000000000000000000000000000,
            128'h16161616161616161616161616161616,
            "All Ones with Zero Key"
        );
        
        // Test with NIST vector: Key=000102030405060708090a0b0c0d0e0f
        // Round 9 output state → Final round → Ciphertext
        check_final(
            128'hbd6e7c3df2b5779e0b61216e8b10b689,
            128'h13111d7fe3944a17f307a78b4d2b30c5,
            128'h69c4e0d86a7b0430d8cdb78070b4c55a,
            "NIST Round 10 (from R9 state)"
        );
        
        //----------------------------------------------------------------------
        // Verify NO MixColumns
        //----------------------------------------------------------------------
        $display("");
        $display("--- Verify NO MixColumns ---");
        
        // If MixColumns were applied, result would be different
        // This is a sanity check
        state_in = 128'hbd6e7c3df2b5779e0b61216e8b10b689;
        round_key = 128'h13111d7fe3944a17f307a78b4d2b30c5;
        #10;
        
        // Expected with NO MixColumns (correct): 69c4e0d86a7b0430d8cdb78070b4c55a
        // If MixColumns was applied (wrong): would be different
        if (state_round === 128'h69c4e0d86a7b0430d8cdb78070b4c55a) begin
            $display("  Final round correctly skips MixColumns: PASS");
            pass_count = pass_count + 1;
        end else begin
            $display("  Final round may have MixColumns: FAIL");
            fail_count = fail_count + 1;
        end
        
        //----------------------------------------------------------------------
        // Summary
        //----------------------------------------------------------------------
        $display("");
        $display("============================================================");
        $display("  Summary");
        $display("============================================================");
        $display("  Passed: %0d", pass_count);
        $display("  Failed: %0d", fail_count);
        $display("============================================================");
        
        if (fail_count == 0) begin
            $display("");
            $display("  *** ALL TESTS PASSED ***");
            $display("");
        end
        
        #100;
        $finish;
    end

endmodule
