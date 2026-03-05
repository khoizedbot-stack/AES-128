//==============================================================================
// Testbench: aes128_datapath
// Description: Test FSM + state register module (10-cycle design)
//              Verify control signals and state transitions
//              Module interface: combinational key_load/key_next, 3 FSM states
//==============================================================================

`timescale 1ns/1ps

module tb_aes128_datapath;

    //==========================================================================
    // Signals
    //==========================================================================
    reg         clk;
    reg         rst_n;
    
    // External control
    reg         start;
        
    // Status outputs
    wire        busy;
    wire        done;
    
    // Key Gen control (combinational outputs from DUT)
    wire        key_load;
    wire        key_next;
    
    // Simulated inputs from encrypt modules
    reg  [127:0] round_out;
    reg  [127:0] final_out;
    
    // Data outputs
    wire [127:0] state_out;
    wire [127:0] ciphertext;
    
    // Test tracking
    integer cycle_count;
    integer pass_count;
    integer fail_count;
    
    //==========================================================================
    // DUT
    //==========================================================================
    aes128_datapath dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .busy           (busy),
        .done           (done),
        .key_load       (key_load),
        .key_next       (key_next),
        .round_out      (round_out),
        .final_out      (final_out),
        .state_out      (state_out),
        .ciphertext     (ciphertext)
    );
    
    //==========================================================================
    // Clock: 100 MHz
    //==========================================================================
    initial clk = 0;
    always #5 clk = ~clk;
    
    //==========================================================================
    // Simulate encrypt_round/final_round output (combinational)
    //==========================================================================
    always @(*) begin
        round_out = state_out ^ 128'hAAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA_AAAA;
        final_out = state_out ^ 128'hBBBB_BBBB_BBBB_BBBB_BBBB_BBBB_BBBB_BBBB;
    end
    
    //==========================================================================
    // Tasks
    //==========================================================================
    task reset;
        begin
            rst_n = 0;
            start = 0;
            repeat(5) @(posedge clk);
            rst_n = 1;
            repeat(2) @(posedge clk);
        end
    endtask
    
    task check(input [255:0] name, input cond);
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
    
    //==========================================================================
    // Main Test
    //==========================================================================
    initial begin
        $display("");
        $display("============================================================");
        $display("  AES128_DATAPATH Module Testbench (10-cycle design)");
        $display("============================================================");
        $display("  Testing FSM states and control signals");
        $display("  key_load, key_next are COMBINATIONAL outputs");
        $display("============================================================");
        $display("");
        
        pass_count = 0;
        fail_count = 0;
        
        // Reset
        reset();
        
        //----------------------------------------------------------------------
        // Test 1: Initial state (IDLE)
        //----------------------------------------------------------------------
        $display("--- Test 1: Initial State ---");
        check("busy=0 at idle", busy === 1'b0);
        check("done=0 at idle", done === 1'b0);
        check("key_load=0 at idle (no start)", key_load === 1'b0);
        check("key_next=0 at idle", key_next === 1'b0);
        
        //----------------------------------------------------------------------
        // Test 2: key_load is combinational with start
        //----------------------------------------------------------------------
        $display("");
        $display("--- Test 2: Combinational key_load ---");
        
        
        // Before clock edge, assert start and check key_load immediately
        start = 1;
        #1; // tiny delay for combinational propagation
        check("key_load=1 when IDLE+start (combinational)", key_load === 1'b1);
        
        //----------------------------------------------------------------------
        // Test 3: Start encryption - cycle count
        // NOTE: Use #1 after @(posedge clk) to let NBA settle before
        //       checking registered outputs (done, busy, state_out, etc.)
        //----------------------------------------------------------------------
        $display("");
        $display("--- Test 3: Start Encryption (10 cycles) ---");
        
        @(posedge clk); // Cycle 1: IDLE+start -> ROUNDS
        start = 0;
        #1; // Let NBA settle
        
        // After cycle 1: should be busy, in ROUNDS
        check("busy=1 after start", busy === 1'b1);
        check("key_load=0 after start cleared", key_load === 1'b0);
        check("key_next=1 in ROUNDS (cnt=2)", key_next === 1'b1);
        
        // Count remaining cycles until done
        cycle_count = 1; // already did cycle 1
        while (!done && cycle_count < 50) begin
            @(posedge clk);
            #1; // Let NBA settle so 'done' reflects this cycle's update
            cycle_count = cycle_count + 1;
        end
        
        $display("  Total cycles from start to done: %0d", cycle_count);
        check("Latency = 10 cycles", cycle_count == 10);
        
        //----------------------------------------------------------------------
        // Test 4: Done state
        //----------------------------------------------------------------------
        $display("");
        $display("--- Test 4: Done State ---");
        check("done=1", done === 1'b1);
        check("busy=0", busy === 1'b0);
        check("ciphertext valid (non-zero)", ciphertext !== 128'h0);
        
        // done pulse: S_DONE sets done=1 for 1 cycle, then S_IDLE clears it
        // After 2 posedges done will be 0 (S_DONE->S_IDLE->done=0 NBA)
        repeat(2) @(posedge clk);
        #1;
        check("done clears after S_DONE->S_IDLE", done === 1'b0);
        
        //----------------------------------------------------------------------
        // Test 5: key_next during ROUNDS
        //----------------------------------------------------------------------
        $display("");
        $display("--- Test 5: key_next during ROUNDS ---");
        
        // Start new encryption from IDLE (S_DONE already transitioned)
        start = 1;
        @(posedge clk); // Cycle 1
        start = 0;
        #1; // Let NBA settle: state -> ROUNDS, done -> 0
        
        begin : key_next_check
            integer next_count;
            next_count = 0;
            
            // Count key_next pulses (sample at negedge for stable combinational)
            while (!done) begin
                @(negedge clk);
                if (key_next) next_count = next_count + 1;
                @(posedge clk);
                #1; // Let NBA settle before re-checking done
            end
            
            $display("  key_next asserted %0d times", next_count);
            // key_next should be 1 for rounds 2-9 (cnt=2..9) = 8 times
            check("key_next count = 8 (rounds 2-9)", next_count == 8);
        end
        
        //----------------------------------------------------------------------
        // Test 6: Back-to-back encryption from DONE
        //----------------------------------------------------------------------
        $display("");
        $display("--- Test 6: Back-to-back Encryption ---");
        
        // After Test 5 loop: done=1 (S_DONE). Wait for S_DONE->S_IDLE->done=0
        repeat(2) @(posedge clk);
        #1;
        check("In IDLE state (done cleared)", done === 1'b0);
        
        // Start from IDLE
        start = 1;
        #1;
        check("key_load=1 from IDLE+start", key_load === 1'b1);
        
        @(posedge clk);
        start = 0;
        #1; // Let NBA settle
        
        // Count cycles
        cycle_count = 1;
        while (!done && cycle_count < 50) begin
            @(posedge clk);
            #1; // Let NBA settle
            cycle_count = cycle_count + 1;
        end
        
        $display("  Back-to-back cycles: %0d", cycle_count);
        check("Back-to-back latency = 10 cycles", cycle_count == 10);
        check("done=1 after back-to-back", done === 1'b1);
        
        //----------------------------------------------------------------------
        // Test 7: Reset mid-operation
        //----------------------------------------------------------------------
        $display("");
        $display("--- Test 7: Reset Mid-operation ---");
        
        start = 1;
        @(posedge clk);
        start = 0;
        
        repeat(3) @(posedge clk); // mid-encryption
        
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        check("busy=0 after reset", busy === 1'b0);
        check("done=0 after reset", done === 1'b0);
        
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
        #10000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule