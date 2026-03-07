//==============================================================================
// Testbench: encrypt_round
// Description: Test normal encryption round (SubBytes, ShiftRows, MixColumns, AddRoundKey)
//              Using NIST FIPS-197 intermediate values
//==============================================================================

`timescale 1ns/1ps

module tb_encrypt_round;

    //==========================================================================
    // Signals
    //==========================================================================
    reg             final_round;
    reg  [127:0] round_key;
    reg  [127:0] enc_state_in;
    wire [127:0] enc_state_round;
    
    // Test tracking
    integer test_num;
    integer pass_count;
    integer fail_count;
    
    //==========================================================================
    // DUT
    //==========================================================================
    encrypt_round dut (
        .final_round    (final_round),
        .round_key      (round_key),
        .enc_state_in   (enc_state_in),
        .enc_state_round(enc_state_round)
    );
    
    //==========================================================================
    // Task: Check result
    //==========================================================================
    task check_round;
        input [127:0] state_in;
        input [127:0] key;
        input [127:0] expected_out;
        input [255:0] test_name;
        begin
            test_num = test_num + 1;
            final_round = 1'b0; // All current tests are for normal rounds
            enc_state_in = state_in;
            round_key = key;
            
            #10; // Wait for combinational logic
            
            if (enc_state_round === expected_out) begin
                $display("[Test %0d] %s - PASS", test_num, test_name);
                pass_count = pass_count + 1;
            end else begin
                $display("[Test %0d] %s - FAIL", test_num, test_name);
                $display("         Input:    %h", state_in);
                $display("         Key:      %h", key);
                $display("         Expected: %h", expected_out);
                $display("         Got:      %h", enc_state_round);
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
        $display("  ENCRYPT_ROUND Module Testbench");
        $display("============================================================");
        $display("  Testing: SubBytes -> ShiftRows -> MixColumns -> AddRoundKey");
        $display("============================================================");
        $display("");
        
        test_num = 0;
        pass_count = 0;
        fail_count = 0;
        
        //----------------------------------------------------------------------
        // NIST FIPS-197 Appendix B - Round by Round Values
        // Plaintext: 00112233445566778899aabbccddeeff
        // Key:       000102030405060708090a0b0c0d0e0f
        //----------------------------------------------------------------------
        $display("--- NIST FIPS-197 Round Values ---");
        
        // After AddRoundKey (initial): 00102030405060708090a0b0c0d0e0f0
        // This is input to Round 1
        
        // Round 1
        // Input (after initial XOR): 00102030405060708090a0b0c0d0e0f0
        // K1 = d6aa74fdd2af72fadaa678f1d6ab76fe
        // Output: 89d810e8855ace682d1843d8cb128fe4
        check_round(
            128'h00102030405060708090a0b0c0d0e0f0,
            128'hd6aa74fdd2af72fadaa678f1d6ab76fe,
            128'h89d810e8855ace682d1843d8cb128fe4,
            "Round 1"
        );
        
        // Round 2
        // Input: 89d810e8855ace682d1843d8cb128fe4
        // K2 = b692cf0b643dbdf1be9bc5006830b3fe
        // Output: 4915598f55e5d7a0daca94fa1f0a63f7
        check_round(
            128'h89d810e8855ace682d1843d8cb128fe4,
            128'hb692cf0b643dbdf1be9bc5006830b3fe,
            128'h4915598f55e5d7a0daca94fa1f0a63f7,
            "Round 2"
        );
        
        // Round 3
        // Input: 4915598f55e5d7a0daca94fa1f0a63f7
        // K3 = b6ff744ed2c2c9bf6c590cbf0469bf41
        // Output: fa636a2825b339c940668a3157244d17
        check_round(
            128'h4915598f55e5d7a0daca94fa1f0a63f7,
            128'hb6ff744ed2c2c9bf6c590cbf0469bf41,
            128'hfa636a2825b339c940668a3157244d17,
            "Round 3"
        );
        
        // Round 4
        // Input: fa636a2825b339c940668a3157244d17
        // K4 = 47f7f7bc95353e03f96c32bcfd058dfd
        // Output: 247240236966b3fa6ed2753288425b6c
        check_round(
            128'hfa636a2825b339c940668a3157244d17,
            128'h47f7f7bc95353e03f96c32bcfd058dfd,
            128'h247240236966b3fa6ed2753288425b6c,
            "Round 4"
        );
        
        // Round 5
        // Input: 247240236966b3fa6ed2753288425b6c
        // K5 = 3caaa3e8a99f9deb50f3af57adf622aa
        // Output: c81677bc9b7ac93b25027992b0261996
        check_round(
            128'h247240236966b3fa6ed2753288425b6c,
            128'h3caaa3e8a99f9deb50f3af57adf622aa,
            128'hc81677bc9b7ac93b25027992b0261996,
            "Round 5"
        );
        
        // Round 6
        // Input: c81677bc9b7ac93b25027992b0261996
        // K6 = 5e390f7df7a69296a7553dc10aa31f6b
        // Output: c62fe109f75eedc3cc79395d84f9cf5d
        check_round(
            128'hc81677bc9b7ac93b25027992b0261996,
            128'h5e390f7df7a69296a7553dc10aa31f6b,
            128'hc62fe109f75eedc3cc79395d84f9cf5d,
            "Round 6"
        );
        
        // Round 7
        // Input: c62fe109f75eedc3cc79395d84f9cf5d
        // K7 = 14f9701ae35fe28c440adf4d4ea9c026
        // Output: d1876c0f79c4300ab45594add66ff41f
        check_round(
            128'hc62fe109f75eedc3cc79395d84f9cf5d,
            128'h14f9701ae35fe28c440adf4d4ea9c026,
            128'hd1876c0f79c4300ab45594add66ff41f,
            "Round 7"
        );
        
        // Round 8
        // Input: d1876c0f79c4300ab45594add66ff41f
        // K8 = 47438735a41c65b9e016baf4aebf7ad2
        // Output: fde3bad205e5d0d73547964ef1fe37f1
        check_round(
            128'hd1876c0f79c4300ab45594add66ff41f,
            128'h47438735a41c65b9e016baf4aebf7ad2,
            128'hfde3bad205e5d0d73547964ef1fe37f1,
            "Round 8"
        );
        
        // Round 9
        // Input: fde3bad205e5d0d73547964ef1fe37f1
        // K9 = 549932d1f08557681093ed9cbe2c974e
        // Output: bd6e7c3df2b5779e0b61216e8b10b689
        check_round(
            128'hfde3bad205e5d0d73547964ef1fe37f1,
            128'h549932d1f08557681093ed9cbe2c974e,
            128'hbd6e7c3df2b5779e0b61216e8b10b689,
            "Round 9"
        );
        
        //----------------------------------------------------------------------
        // Additional Tests
        //----------------------------------------------------------------------
        $display("");
        $display("--- Additional Tests ---");
        
        // All zeros
        check_round(
            128'h00000000000000000000000000000000,
            128'h00000000000000000000000000000000,
            128'h63636363636363636363636363636363,  // S-Box(0) = 0x63, then mix
            "All Zeros"
        );
        
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
