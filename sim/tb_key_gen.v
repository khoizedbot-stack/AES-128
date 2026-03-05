//==============================================================================
// Testbench: key_gen
// Description: Test key expansion module (10-cycle design)
//              - rcon_index managed internally (no external rcon input)
//              - load=1: bypass key_in → expanded_key = K1 (combinational)
//                        stores K1 into current_key, rcon=2
//              - next=1: current_key <= expanded_key, rcon++
//              - expanded_key is always a combinational output
//==============================================================================

`timescale 1ns/1ps

module tb_key_gen;

    //==========================================================================
    // Signals
    //==========================================================================
    reg         clk;
    reg         rst_n;
    reg         load;
    reg         next;
    reg  [127:0] key_in;
    wire [127:0] current_key;
    wire [127:0] expanded_key;
    
    // Access internal current_key register via hierarchical path
    assign current_key = dut.current_key;
    
    // Test tracking
    integer pass_count;
    integer fail_count;
    
    //==========================================================================
    // DUT
    //==========================================================================
    key_gen dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .load         (load),
        .next         (next),
        .key_in       (key_in),
        .expanded_key (expanded_key)
    );
    
    //==========================================================================
    // Clock: 100 MHz
    //==========================================================================
    initial clk = 0;
    always #5 clk = ~clk;
    
    //==========================================================================
    // Expected Round Keys (NIST FIPS-197 Appendix A.1)
    // Key = 000102030405060708090a0b0c0d0e0f
    //==========================================================================
    reg [127:0] expected_keys [0:10];
    
    initial begin
        expected_keys[0]  = 128'h000102030405060708090a0b0c0d0e0f;  // K0 (original)
        expected_keys[1]  = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe;  // K1
        expected_keys[2]  = 128'hb692cf0b643dbdf1be9bc5006830b3fe;  // K2
        expected_keys[3]  = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41;  // K3
        expected_keys[4]  = 128'h47f7f7bc95353e03f96c32bcfd058dfd;  // K4
        expected_keys[5]  = 128'h3caaa3e8a99f9deb50f3af57adf622aa;  // K5
        expected_keys[6]  = 128'h5e390f7df7a69296a7553dc10aa31f6b;  // K6
        expected_keys[7]  = 128'h14f9701ae35fe28c440adf4d4ea9c026;  // K7
        expected_keys[8]  = 128'h47438735a41c65b9e016baf4aebf7ad2;  // K8
        expected_keys[9]  = 128'h549932d1f08557681093ed9cbe2c974e;  // K9
        expected_keys[10] = 128'h13111d7fe3944a17f307a78b4d2b30c5;  // K10
    end
    
    //==========================================================================
    // Tasks
    //==========================================================================
    task reset;
        begin
            rst_n = 0;
            load = 0;
            next = 0;
            key_in = 128'h0;
            repeat(5) @(posedge clk);
            rst_n = 1;
            repeat(2) @(posedge clk);
        end
    endtask
    
    task check;
        input [255:0] name;
        input cond;
        begin
            if (cond) begin
                $display("  %0s - PASS", name);
                pass_count = pass_count + 1;
            end else begin
                $display("  %0s - FAIL", name);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    task check_key_current;
        input [3:0] key_num;
        begin
            if (current_key === expected_keys[key_num]) begin
                $display("  current_key = K%0d: %h - PASS", key_num, current_key);
                pass_count = pass_count + 1;
            end else begin
                $display("  current_key = K%0d: %h - FAIL", key_num, current_key);
                $display("       Expected: %h", expected_keys[key_num]);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    task check_key_expanded;
        input [3:0] key_num;
        begin
            if (expanded_key === expected_keys[key_num]) begin
                $display("  expanded_key = K%0d: %h - PASS", key_num, expanded_key);
                pass_count = pass_count + 1;
            end else begin
                $display("  expanded_key = K%0d: %h - FAIL", key_num, expanded_key);
                $display("       Expected: %h", expected_keys[key_num]);
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
        $display("  KEY_GEN Module Testbench (10-cycle bypass design)");
        $display("============================================================");
        $display("  Testing NIST FIPS-197 Key Expansion");
        $display("  Input Key: 000102030405060708090a0b0c0d0e0f");
        $display("  rcon managed internally, expanded_key is combinational");
        $display("============================================================");
        $display("");
        
        pass_count = 0;
        fail_count = 0;
        
        // Reset
        reset();
        
        //----------------------------------------------------------------------
        // Test 1: Combinational expanded_key during load (bypass)
        //         load=1: key_source = key_in → expanded_key = expand(K0, rcon=1) = K1
        //----------------------------------------------------------------------
        $display("--- Test 1: expanded_key bypass during load ---");
        
        key_in = expected_keys[0]; // K0
        load = 1;
        #1; // combinational propagation
        check_key_expanded(1); // expanded_key should be K1 (bypass)
        
        //----------------------------------------------------------------------
        // Test 2: After load posedge → current_key = K1, rcon = 2
        //         expanded_key = expand(K1, rcon=2) = K2
        //----------------------------------------------------------------------
        $display("");
        $display("--- Test 2: After load → current_key=K1, expanded_key=K2 ---");
        
        @(posedge clk); // load takes effect
        load = 0;
        #1; // wait for combinational settle
        check_key_current(1);  // current_key = K1
        check_key_expanded(2); // expanded_key = K2 (expand(K1, rcon=2))
        
        //----------------------------------------------------------------------
        // Test 3: Generate K2-K10 via next
        //----------------------------------------------------------------------
        $display("");
        $display("--- Test 3: Sequence K2-K10 via next ---");
        
        begin : gen_keys
            integer i;
            for (i = 2; i <= 10; i = i + 1) begin
                next = 1;
                @(posedge clk); // current_key <= expanded_key = K[i], rcon++
                next = 0;
                #1;
                check_key_current(i); // current_key = K[i]
                
                // expanded_key should be K[i+1] if i < 10
                if (i < 10) begin
                    check_key_expanded(i + 1);
                end
            end
        end
        
        // After all rounds: current_key = K10
        $display("");
        $display("--- Verify final: current_key = K10 ---");
        check_key_current(10);
        
        //----------------------------------------------------------------------
        // Test 4: Hold (no load, no next) → key should stay K10
        //----------------------------------------------------------------------
        $display("");
        $display("--- Test 4: Hold State ---");
        
        repeat(5) @(posedge clk);
        check_key_current(10);
        check("Key held after 5 idle cycles", current_key === expected_keys[10]);
        
        //----------------------------------------------------------------------
        // Test 5: Load new key → rcon resets, bypass works again
        //----------------------------------------------------------------------
        $display("");
        $display("--- Test 5: Reload Key (rcon reset) ---");
        
        key_in = expected_keys[0]; // reload same K0
        load = 1;
        #1;
        check_key_expanded(1); // should be K1 again (rcon bypass = 1)
        
        @(posedge clk);
        load = 0;
        #1;
        check_key_current(1);  // current_key = K1
        check_key_expanded(2); // expanded_key = K2
        
        // Quick verify K2 via next
        next = 1;
        @(posedge clk);
        next = 0;
        #1;
        check_key_current(2);
        
        //----------------------------------------------------------------------
        // Test 6: Reset clears state
        //----------------------------------------------------------------------
        $display("");
        $display("--- Test 6: Reset ---");
        
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        #1;
        check("current_key=0 after reset", current_key === 128'h0);
        
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
    
    //==========================================================================
    // Timeout
    //==========================================================================
    initial begin
        #5000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule