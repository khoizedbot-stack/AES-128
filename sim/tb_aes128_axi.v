/*
 * AXI4-Lite Interface Testbench for Optimized AES-128
 * Tests the complete system with AXI wrapper
 */

`timescale 1ns/1ps

module tb_aes128_axi_optimized;

    //==========================================================================
    // AXI4-Lite Signals
    //==========================================================================
    reg         S_AXI_ACLK;
    reg         S_AXI_ARESETN;
    
    // Write Address Channel
    reg  [5:0]  S_AXI_AWADDR;
    reg  [2:0]  S_AXI_AWPROT;
    reg         S_AXI_AWVALID;
    wire        S_AXI_AWREADY;
    
    // Write Data Channel
    reg  [31:0] S_AXI_WDATA;
    reg  [3:0]  S_AXI_WSTRB;
    reg         S_AXI_WVALID;
    wire        S_AXI_WREADY;
    
    // Write Response Channel
    wire [1:0]  S_AXI_BRESP;
    wire        S_AXI_BVALID;
    reg         S_AXI_BREADY;
    
    // Read Address Channel
    reg  [5:0]  S_AXI_ARADDR;
    reg  [2:0]  S_AXI_ARPROT;
    reg         S_AXI_ARVALID;
    wire        S_AXI_ARREADY;
    
    // Read Data Channel
    wire [31:0] S_AXI_RDATA;
    wire [1:0]  S_AXI_RRESP;
    wire        S_AXI_RVALID;
    reg         S_AXI_RREADY;
    
    // Interrupt
    wire        irq_done;
    
    // Test variables
    reg  [31:0] read_data;
    integer     test_pass;
    integer     test_fail;
    integer     cycle_count;

    integer i;


    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    aes128_axi_top dut (
        .S_AXI_ACLK    (S_AXI_ACLK),
        .S_AXI_ARESETN (S_AXI_ARESETN),
        .S_AXI_AWADDR  (S_AXI_AWADDR),
        .S_AXI_AWPROT  (S_AXI_AWPROT),
        .S_AXI_AWVALID (S_AXI_AWVALID),
        .S_AXI_AWREADY (S_AXI_AWREADY),
        .S_AXI_WDATA   (S_AXI_WDATA),
        .S_AXI_WSTRB   (S_AXI_WSTRB),
        .S_AXI_WVALID  (S_AXI_WVALID),
        .S_AXI_WREADY  (S_AXI_WREADY),
        .S_AXI_BRESP   (S_AXI_BRESP),
        .S_AXI_BVALID  (S_AXI_BVALID),
        .S_AXI_BREADY  (S_AXI_BREADY),
        .S_AXI_ARADDR  (S_AXI_ARADDR),
        .S_AXI_ARPROT  (S_AXI_ARPROT),
        .S_AXI_ARVALID (S_AXI_ARVALID),
        .S_AXI_ARREADY (S_AXI_ARREADY),
        .S_AXI_RDATA   (S_AXI_RDATA),
        .S_AXI_RRESP   (S_AXI_RRESP),
        .S_AXI_RVALID  (S_AXI_RVALID),
        .S_AXI_RREADY  (S_AXI_RREADY),
        .irq_done      (irq_done)
    );

    //==========================================================================
    // Clock Generation (100 MHz)
    //==========================================================================
    initial S_AXI_ACLK = 0;
    always #5 S_AXI_ACLK = ~S_AXI_ACLK;

    //==========================================================================
    // AXI Write Task
    //==========================================================================
    task axi_write;
        input [5:0]  addr;
        input [31:0] data;
        begin
            @(posedge S_AXI_ACLK);
            S_AXI_AWADDR  <= addr;
            S_AXI_AWPROT  <= 3'b000;
            S_AXI_AWVALID <= 1'b1;
            S_AXI_WDATA   <= data;
            S_AXI_WSTRB   <= 4'hF;
            S_AXI_WVALID  <= 1'b1;
            S_AXI_BREADY  <= 1'b1;
            
            @(posedge S_AXI_ACLK);
            while (!(S_AXI_AWREADY && S_AXI_WREADY)) @(posedge S_AXI_ACLK);
            
            S_AXI_AWVALID <= 1'b0;
            S_AXI_WVALID  <= 1'b0;
            
            while (!S_AXI_BVALID) @(posedge S_AXI_ACLK);
            @(posedge S_AXI_ACLK);
            S_AXI_BREADY <= 1'b0;
        end
    endtask

    //==========================================================================
    // AXI Read Task
    //==========================================================================
    task axi_read;
        input  [5:0]  addr;
        output [31:0] data;
        begin
            @(posedge S_AXI_ACLK);
            S_AXI_ARADDR  <= addr;
            S_AXI_ARPROT  <= 3'b000;
            S_AXI_ARVALID <= 1'b1;
            S_AXI_RREADY  <= 1'b1;
            
            @(posedge S_AXI_ACLK);
            while (!S_AXI_ARREADY) @(posedge S_AXI_ACLK);
            S_AXI_ARVALID <= 1'b0;
            
            while (!S_AXI_RVALID) @(posedge S_AXI_ACLK);
            data = S_AXI_RDATA;
            @(posedge S_AXI_ACLK);
            S_AXI_RREADY <= 1'b0;
        end
    endtask

    //==========================================================================
    // Wait for Done (poll STATUS register)
    //==========================================================================
    task wait_done;
        reg [31:0] status;
        begin
            cycle_count = 0;
            status = 32'h0;
            while ((status & 32'h2) == 0) begin  // Check done bit
                axi_read(6'h04, status);
                cycle_count = cycle_count + 1;
                if (cycle_count > 100) begin
                    $display("ERROR: Timeout waiting for done!");
                    $finish;
                end
            end
        end
    endtask

    task wait_key_ready;
        reg [31:0] status;
        begin
            cycle_count = 0;
            status = 32'h0;
            while ((status & 32'h4) == 0) begin  // Check key_ready bit
                axi_read(6'h04, status);
                cycle_count = cycle_count + 1;
                if (cycle_count > 150) begin
                    $display("ERROR: Timeout waiting for key_ready!");
                    $finish;
                end
            end
        end
    endtask

    //==========================================================================
    // Main Test
    //==========================================================================
    initial begin
        $display("");
        $display("================================================================");
        $display("  AES-128 Optimized - AXI4-Lite Interface Testbench");
        $display("================================================================");
        $display("");
        
        // Initialize
        test_pass = 0;
        test_fail = 0;
        S_AXI_ARESETN = 0;
        S_AXI_AWADDR  = 0;
        S_AXI_AWPROT  = 0;
        S_AXI_AWVALID = 0;
        S_AXI_WDATA   = 0;
        S_AXI_WSTRB   = 0;
        S_AXI_WVALID  = 0;
        S_AXI_BREADY  = 0;
        S_AXI_ARADDR  = 0;
        S_AXI_ARPROT  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_RREADY  = 0;
        
        // Reset sequence
        repeat(10) @(posedge S_AXI_ACLK);
        S_AXI_ARESETN = 1;
        repeat(5) @(posedge S_AXI_ACLK);
        
        //======================================================================
        // Test 1: NIST Test Vector via AXI
        //======================================================================
        $display("[Test 1] NIST FIPS-197 Test Vector");
        $display("  Key:       000102030405060708090a0b0c0d0e0f");
        $display("  Plaintext: 00112233445566778899aabbccddeeff");
        $display("  Expected:  69c4e0d86a7b0430d8cdb78070b4c55a");
        
        // Write Key (little-endian word order for ARM)
        // Key = 00010203 04050607 08090a0b 0c0d0e0f
        axi_write(6'h08, 32'h0c0d0e0f);  // KEY_0: bytes 0-3
        axi_write(6'h0C, 32'h08090a0b);  // KEY_1: bytes 4-7
        axi_write(6'h10, 32'h04050607);  // KEY_2: bytes 8-11
        axi_write(6'h14, 32'h00010203);  // KEY_3: bytes 12-15

        // Trigger key expansion and wait for key_ready
        axi_write(6'h00, 32'h00000004);
        wait_key_ready();
        
        // Write Plaintext
        // PT = 00112233 44556677 8899aabb ccddeeff
        axi_write(6'h18, 32'hccddeeff);  // PT_0
        axi_write(6'h1C, 32'h8899aabb);  // PT_1
        axi_write(6'h20, 32'h44556677);  // PT_2
        axi_write(6'h24, 32'h00112233);  // PT_3
        
        // Start encryption
        axi_write(6'h00, 32'h00000001);
        
        // Wait for completion
        wait_done();
        $display("  Encryption completed in %0d polling cycles", cycle_count);
        
        // Read and verify ciphertext
        // Expected CT = 69c4e0d8 6a7b0430 d8cdb780 70b4c55a
        axi_read(6'h28, read_data);
        $display("  CT_0 = 0x%08X (expected 0x70b4c55a)", read_data);
        if (read_data !== 32'h70b4c55a) test_fail = test_fail + 1;
        else test_pass = test_pass + 1;
        
        axi_read(6'h2C, read_data);
        $display("  CT_1 = 0x%08X (expected 0xd8cdb780)", read_data);
        if (read_data !== 32'hd8cdb780) test_fail = test_fail + 1;
        else test_pass = test_pass + 1;
        
        axi_read(6'h30, read_data);
        $display("  CT_2 = 0x%08X (expected 0x6a7b0430)", read_data);
        if (read_data !== 32'h6a7b0430) test_fail = test_fail + 1;
        else test_pass = test_pass + 1;
        
        axi_read(6'h34, read_data);
        $display("  CT_3 = 0x%08X (expected 0x69c4e0d8)", read_data);
        if (read_data !== 32'h69c4e0d8) test_fail = test_fail + 1;
        else test_pass = test_pass + 1;
        
        //======================================================================
        // Test 2: All Zeros
        //======================================================================
        $display("");
        $display("[Test 2] All Zeros");
        
        // Write Key = 0
        axi_write(6'h08, 32'h00000000);
        axi_write(6'h0C, 32'h00000000);
        axi_write(6'h10, 32'h00000000);
        axi_write(6'h14, 32'h00000000);

        // Trigger key expansion and wait for key_ready
        axi_write(6'h00, 32'h00000004);
        wait_key_ready();
        
        // Write Plaintext = 0
        axi_write(6'h18, 32'h00000000);
        axi_write(6'h1C, 32'h00000000);
        axi_write(6'h20, 32'h00000000);
        axi_write(6'h24, 32'h00000000);
        
        // Start & Wait
        axi_write(6'h00, 32'h00000001);
        wait_done();
        
        // Expected: 66e94bd4ef8a2c3b884cfa59ca342b2e
        axi_read(6'h28, read_data);
        $display("  CT_0 = 0x%08X (expected 0xca342b2e)", read_data);
        if (read_data !== 32'hca342b2e) test_fail = test_fail + 1;
        else test_pass = test_pass + 1;
        
        axi_read(6'h2C, read_data);
        $display("  CT_1 = 0x%08X (expected 0x884cfa59)", read_data);
        if (read_data !== 32'h884cfa59) test_fail = test_fail + 1;
        else test_pass = test_pass + 1;
        
        axi_read(6'h30, read_data);
        $display("  CT_2 = 0x%08X (expected 0xef8a2c3b)", read_data);
        if (read_data !== 32'hef8a2c3b) test_fail = test_fail + 1;
        else test_pass = test_pass + 1;
        
        axi_read(6'h34, read_data);
        $display("  CT_3 = 0x%08X (expected 0x66e94bd4)", read_data);
        if (read_data !== 32'h66e94bd4) test_fail = test_fail + 1;
        else test_pass = test_pass + 1;
        
        //======================================================================
        // Test 3: Check Interrupt Signal
        //======================================================================
        $display("");
        $display("[Test 3] Interrupt Signal Check");
        
        // Reuse previous setup, just start new encryption
        axi_write(6'h08, 32'h0c0d0e0f);
        axi_write(6'h0C, 32'h08090a0b);
        axi_write(6'h10, 32'h04050607);
        axi_write(6'h14, 32'h00010203);
        axi_write(6'h00, 32'h00000004);
        wait_key_ready();
        axi_write(6'h18, 32'hccddeeff);
        axi_write(6'h1C, 32'h8899aabb);
        axi_write(6'h20, 32'h44556677);
        axi_write(6'h24, 32'h00112233);
        
        // Check irq_done is low before start
        if (irq_done == 1'b0) begin
            $display("  IRQ before start: LOW (correct)");
        end else begin
            $display("  IRQ before start: HIGH (unexpected)");
        end
        
        // Start with IRQ enabled (bit 3 = 1, bit 0 = 1 -> 0x09)
        axi_write(6'h00, 32'h00000009);
        
        // Wait for IRQ
        while (!irq_done) @(posedge S_AXI_ACLK);
        $display("  IRQ after done: HIGH (correct)");
        test_pass = test_pass + 1;
        
        //======================================================================
        // Test 4: Back-to-back Encryptions
        //======================================================================
        $display("");
        $display("[Test 4] Back-to-back Encryptions (5x)");
        begin
            for (i = 0; i < 5; i = i + 1) begin
                // Modify plaintext slightly
                axi_write(6'h18, 32'hccddeeff + i);
                axi_write(6'h00, 32'h00000001);
                wait_done();
                $display("  Encryption %0d complete", i+1);
            end
            test_pass = test_pass + 1;
        end
        
        //======================================================================
        // Summary
        //======================================================================
        $display("");
        $display("================================================================");
        $display("  Test Summary");
        $display("================================================================");
        $display("  Passed: %0d", test_pass);
        $display("  Failed: %0d", test_fail);
        
        if (test_fail == 0) begin
            $display("");
            $display("  *** ALL TESTS PASSED ***");
        end else begin
            $display("");
            $display("  *** SOME TESTS FAILED ***");
        end
        
        $display("================================================================");
        $display("");
        
        #100;
        $finish;
    end

    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #500000;
        $display("ERROR: Global timeout!");
        $finish;
    end

endmodule
