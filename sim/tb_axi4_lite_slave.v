`timescale 1ns/1ps

module tb_axi4_lite_slave;

    localparam C_ADDR_W = 6;
    localparam C_DATA_W = 32;
    localparam CLK_HALF = 5; // 100 MHz

    // Register addresses (mirror DUT)
    localparam ADDR_CTRL        = 6'h00;
    localparam ADDR_STATUS      = 6'h04;
    localparam ADDR_KEY_0       = 6'h08;
    localparam ADDR_KEY_1       = 6'h0C;
    localparam ADDR_KEY_2       = 6'h10;
    localparam ADDR_KEY_3       = 6'h14;
    localparam ADDR_PLAINTEXT_0 = 6'h18;
    localparam ADDR_PLAINTEXT_1 = 6'h1C;
    localparam ADDR_PLAINTEXT_2 = 6'h20;
    localparam ADDR_PLAINTEXT_3 = 6'h24;
    localparam ADDR_CIPHER_0    = 6'h28;
    localparam ADDR_CIPHER_1    = 6'h2C;
    localparam ADDR_CIPHER_2    = 6'h30;
    localparam ADDR_CIPHER_3    = 6'h34;

    reg                    clk;
    reg                    rst_n;

    // Write Address
    reg  [C_ADDR_W-1:0]   awaddr;
    reg  [2:0]             awprot;
    reg                    awvalid;
    wire                   awready;

    // Write Data
    reg  [C_DATA_W-1:0]   wdata;
    reg  [C_DATA_W/8-1:0] wstrb;
    reg                    wvalid;
    wire                   wready;

    // Write Response
    wire [1:0]             bresp;
    wire                   bvalid;
    reg                    bready;

    // Read Address
    reg  [C_ADDR_W-1:0]   araddr;
    reg  [2:0]             arprot;
    reg                    arvalid;
    wire                   arready;

    // Read Data
    wire [C_DATA_W-1:0]   rdata;
    wire [1:0]             rresp;
    wire                   rvalid;
    reg                    rready;

    // User-side (AES core stubs)
    wire [127:0]           data_bus;
    wire                   start;
    wire                   new_key;
    wire                   enc_dec;

    reg                    busy;
    reg                    done;
    reg                    key_ready;
    reg  [127:0]           ciphertext;

    assign data_bus = done ? ciphertext : 128'hZ;

    // Test counters
    integer pass_count;
    integer fail_count;
    integer test_num;
    reg  [C_DATA_W-1:0]   rd_data;

    axi4_lite_slave #(
        .C_S_AXI_ADDR_WIDTH (C_ADDR_W),
        .C_S_AXI_DATA_WIDTH (C_DATA_W)
    ) dut (
        .S_AXI_ACLK    (clk),
        .S_AXI_ARESETN (rst_n),
        .S_AXI_AWADDR  (awaddr),
        .S_AXI_AWPROT  (awprot),
        .S_AXI_AWVALID (awvalid),
        .S_AXI_AWREADY (awready),
        .S_AXI_WDATA   (wdata),
        .S_AXI_WSTRB   (wstrb),
        .S_AXI_WVALID  (wvalid),
        .S_AXI_WREADY  (wready),
        .S_AXI_BRESP   (bresp),
        .S_AXI_BVALID  (bvalid),
        .S_AXI_BREADY  (bready),
        .S_AXI_ARADDR  (araddr),
        .S_AXI_ARPROT  (arprot),
        .S_AXI_ARVALID (arvalid),
        .S_AXI_ARREADY (arready),
        .S_AXI_RDATA   (rdata),
        .S_AXI_RRESP   (rresp),
        .S_AXI_RVALID  (rvalid),
        .S_AXI_RREADY  (rready),
        // User-side
        .data_bus      (data_bus),
        .start         (start),
        .new_key       (new_key),
        .enc_dec       (enc_dec),
        .busy          (busy),
        .done          (done),
        .key_ready     (key_ready)
    );

    initial clk = 0;
    always #CLK_HALF clk = ~clk;

    task axi_write;
        input [C_ADDR_W-1:0] addr;
        input [C_DATA_W-1:0] data;
        begin
            axi_write_strb(addr, data, 4'hF);
        end
    endtask

    task axi_write_strb;
        input [C_ADDR_W-1:0]   addr;
        input [C_DATA_W-1:0]   data;
        input [C_DATA_W/8-1:0] strb;
        begin
            @(posedge clk);
            awaddr  <= addr;
            awprot  <= 3'b000;
            awvalid <= 1'b1;
            wdata   <= data;
            wstrb   <= strb;
            wvalid  <= 1'b1;
            bready  <= 1'b1;

            @(posedge clk);
            while (!(awready && wready)) @(posedge clk);

            awvalid <= 1'b0;
            wvalid  <= 1'b0;

            while (!bvalid) @(posedge clk);
            @(posedge clk);
            bready  <= 1'b0;
        end
    endtask

    task axi_read;
        input  [C_ADDR_W-1:0] addr;
        output [C_DATA_W-1:0] data;
        begin
            @(posedge clk);
            araddr  <= addr;
            arprot  <= 3'b000;
            arvalid <= 1'b1;
            rready  <= 1'b1;

            @(posedge clk);
            while (!arready) @(posedge clk);
            arvalid <= 1'b0;

            while (!rvalid) @(posedge clk);
            data = rdata;
            @(posedge clk);
            rready  <= 1'b0;
        end
    endtask

    task check;
        input [C_DATA_W-1:0] actual;
        input [C_DATA_W-1:0] expected;
        input [40*8-1:0]     label; // up to 40 chars
        begin
            test_num = test_num + 1;
            if (actual === expected) begin
                $display("[Test %0d] PASS  %0s  (0x%08X)", test_num, label, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("[Test %0d] FAIL  %0s  got=0x%08X  exp=0x%08X",
                         test_num, label, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check1;
        input           actual;
        input           expected;
        input [40*8-1:0] label;
        begin
            test_num = test_num + 1;
            if (actual === expected) begin
                $display("[Test %0d] PASS  %0s  (%0b)", test_num, label, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("[Test %0d] FAIL  %0s  got=%0b  exp=%0b",
                         test_num, label, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $display("");
        $display("================================================================");
        $display("  AXI4-Lite Slave — Standalone Testbench");
        $display("================================================================");
        $display("");

        // Initialise
        pass_count = 0;
        fail_count = 0;
        test_num   = 0;

        rst_n      = 0;
        awaddr     = 0;  awprot  = 0; awvalid = 0;
        wdata      = 0;  wstrb   = 0; wvalid  = 0; bready = 0;
        araddr     = 0;  arprot  = 0; arvalid = 0; rready = 0;
        busy       = 0;
        done       = 0;
        key_ready  = 0;
        ciphertext = 128'h0;

        //======================================================================
        // Test 1: Reset clears all outputs
        //======================================================================
        $display("--- Test Group 1: Reset ---");
        repeat (10) @(posedge clk);
        // While in reset — user-side outputs should be 0
        check1(start,   1'b0, "start=0 in reset");
        check1(new_key, 1'b0, "new_key=0 in reset");
        check1(enc_dec, 1'b0, "enc_dec=0 in reset");

        // Release reset
        rst_n = 1;
        repeat (5) @(posedge clk);

        //======================================================================
        // Test 2: Write KEY registers and read back
        //======================================================================
        $display("");
        $display("--- Test Group 2: KEY register R/W ---");
        axi_write(ADDR_KEY_0, 32'h0c0d0e0f);
        axi_write(ADDR_KEY_1, 32'h08090a0b);
        axi_write(ADDR_KEY_2, 32'h04050607);
        axi_write(ADDR_KEY_3, 32'h00010203);

        axi_read(ADDR_KEY_0, rd_data); check(rd_data, 32'h0c0d0e0f, "KEY_0 readback");
        axi_read(ADDR_KEY_1, rd_data); check(rd_data, 32'h08090a0b, "KEY_1 readback");
        axi_read(ADDR_KEY_2, rd_data); check(rd_data, 32'h04050607, "KEY_2 readback");
        axi_read(ADDR_KEY_3, rd_data); check(rd_data, 32'h00010203, "KEY_3 readback");

        //======================================================================
        // Test 3: Write PLAINTEXT registers and read back
        //======================================================================
        $display("");
        $display("--- Test Group 3: PLAINTEXT register R/W ---");
        axi_write(ADDR_PLAINTEXT_0, 32'hccddeeff);
        axi_write(ADDR_PLAINTEXT_1, 32'h8899aabb);
        axi_write(ADDR_PLAINTEXT_2, 32'h44556677);
        axi_write(ADDR_PLAINTEXT_3, 32'h00112233);

        axi_read(ADDR_PLAINTEXT_0, rd_data); check(rd_data, 32'hccddeeff, "PT_0 readback");
        axi_read(ADDR_PLAINTEXT_1, rd_data); check(rd_data, 32'h8899aabb, "PT_1 readback");
        axi_read(ADDR_PLAINTEXT_2, rd_data); check(rd_data, 32'h44556677, "PT_2 readback");
        axi_read(ADDR_PLAINTEXT_3, rd_data); check(rd_data, 32'h00112233, "PT_3 readback");

        //======================================================================
        // Test 4: CTRL — start auto-clear + pulse output
        //======================================================================
        $display("");
        $display("--- Test Group 4: CTRL start auto-clear ---");
        // Write start bit
        axi_write(ADDR_CTRL, 32'h0000_0001);
        // After the write completes, reg_ctrl[0] should auto-clear next cycle.
        // The start output is delayed one cycle from reg_ctrl[0].
        // Wait for start pulse to appear and then disappear.
        repeat (3) @(posedge clk);
        // By now start_r should have pulsed and returned to 0
        check1(start, 1'b0, "start returns to 0 (auto-clear)");

        // Read CTRL — bit0 should be cleared
        axi_read(ADDR_CTRL, rd_data);
        check(rd_data & 32'h1, 32'h0, "CTRL[0] auto-cleared");

        //======================================================================
        // Test 5: CTRL — new_key auto-clear
        //======================================================================
        $display("");
        $display("--- Test Group 5: CTRL new_key auto-clear ---");
        axi_write(ADDR_CTRL, 32'h0000_0004);
        repeat (3) @(posedge clk);
        check1(new_key, 1'b0, "new_key returns to 0");

        axi_read(ADDR_CTRL, rd_data);
        check(rd_data & 32'h4, 32'h0, "CTRL[2] auto-cleared");

        //======================================================================
        // Test 6: CTRL — enc_dec sticky
        //======================================================================
        $display("");
        $display("--- Test Group 6: CTRL enc_dec sticky ---");
        // Set enc_dec = 1 (bit1 = 1)
        axi_write(ADDR_CTRL, 32'h0000_0002);
        repeat (2) @(posedge clk);
        check1(enc_dec, 1'b1, "enc_dec=1 sticky");

        // Read CTRL — bit1 should persist
        axi_read(ADDR_CTRL, rd_data);
        check(rd_data & 32'h2, 32'h2, "CTRL[1] stays set");

        // Clear enc_dec
        axi_write(ADDR_CTRL, 32'h0000_0000);
        repeat (2) @(posedge clk);
        check1(enc_dec, 1'b0, "enc_dec=0 after clear");

        //======================================================================
        // Test 7: STATUS reflects busy/done/key_ready inputs
        //======================================================================
        $display("");
        $display("--- Test Group 7: STATUS register ---");

        // Drive busy
        busy = 1; done = 0; key_ready = 0;
        @(posedge clk); @(posedge clk);  // let it register
        axi_read(ADDR_STATUS, rd_data);
        check(rd_data & 32'h1, 32'h1, "STATUS[0] busy=1");

        // Drive done (clears busy, sets done)
        busy = 0; done = 1;
        @(posedge clk); @(posedge clk);
        axi_read(ADDR_STATUS, rd_data);
        check(rd_data & 32'h3, 32'h2, "STATUS busy=0 done=1");

        done = 0; // release pulse

        // Drive key_ready
        key_ready = 1;
        @(posedge clk); @(posedge clk);
        axi_read(ADDR_STATUS, rd_data);
        check(rd_data & 32'h4, 32'h4, "STATUS[2] key_ready=1");
        key_ready = 0;

        //======================================================================
        // Test 8: STATUS clear on new operation (CTRL[0]=start)
        //======================================================================
        $display("");
        $display("--- Test Group 8: STATUS cleared on start ---");
        // STATUS currently has done=1 and key_ready=1 from above.
        // Writing start should clear status[1:0]
        axi_write(ADDR_CTRL, 32'h0000_0001);
        repeat (2) @(posedge clk);
        axi_read(ADDR_STATUS, rd_data);
        check(rd_data & 32'h3, 32'h0, "STATUS[1:0] cleared by start");

        //======================================================================
        // Test 9: Ciphertext read-only from input port
        //======================================================================
        $display("");
        $display("--- Test Group 9: Ciphertext read-only ---");
        ciphertext = 128'h69c4e0d8_6a7b0430_d8cdb780_70b4c55a;
        // Pulse done to latch ciphertext into AXI reg file
        done = 1;
        @(posedge clk);
        done = 0;
        repeat (2) @(posedge clk);

        axi_read(ADDR_CIPHER_0, rd_data); check(rd_data, 32'h70b4c55a, "CIPHER_0");
        axi_read(ADDR_CIPHER_1, rd_data); check(rd_data, 32'hd8cdb780, "CIPHER_1");
        axi_read(ADDR_CIPHER_2, rd_data); check(rd_data, 32'h6a7b0430, "CIPHER_2");
        axi_read(ADDR_CIPHER_3, rd_data); check(rd_data, 32'h69c4e0d8, "CIPHER_3");

        //======================================================================
        // Test 10: Default address returns DEAD_BEEF
        //======================================================================
        $display("");
        $display("--- Test Group 10: Unmapped address ---");
        axi_read(6'h38, rd_data); check(rd_data, 32'hDEAD_BEEF, "Addr 0x38 DEAD_BEEF");
        axi_read(6'h3C, rd_data); check(rd_data, 32'hDEAD_BEEF, "Addr 0x3C DEAD_BEEF");

        //======================================================================
        // Test 11: WSTRB partial write
        //======================================================================
        $display("");
        $display("--- Test Group 11: WSTRB partial write ---");
        // First write full word to KEY_0
        axi_write(ADDR_KEY_0, 32'hAABBCCDD);
        // Now partial write: only byte-0 (bits 7:0) with WSTRB=0001
        axi_write_strb(ADDR_KEY_0, 32'h11223344, 4'b0001);
        axi_read(ADDR_KEY_0, rd_data);
        check(rd_data, 32'hAABBCC44, "WSTRB byte0 only");

        // Partial write: upper half (WSTRB=1100)
        axi_write_strb(ADDR_KEY_0, 32'hFFEEDDCC, 4'b1100);
        axi_read(ADDR_KEY_0, rd_data);
        check(rd_data, 32'hFFEECC44, "WSTRB upper half");

        //======================================================================
        // Test 12: Write response BRESP = OKAY
        //======================================================================
        $display("");
        $display("--- Test Group 12: AXI response codes ---");
        axi_write(ADDR_KEY_0, 32'h12345678);
        test_num = test_num + 1;
        if (bresp === 2'b00) begin
            $display("[Test %0d] PASS  BRESP=OKAY", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("[Test %0d] FAIL  BRESP=%b (exp=00)", test_num, bresp);
            fail_count = fail_count + 1;
        end

        axi_read(ADDR_KEY_0, rd_data);
        test_num = test_num + 1;
        if (rresp === 2'b00) begin
            $display("[Test %0d] PASS  RRESP=OKAY", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("[Test %0d] FAIL  RRESP=%b (exp=00)", test_num, rresp);
            fail_count = fail_count + 1;
        end

        //======================================================================
        // Test 13: Back-to-back writes (stress)
        //======================================================================
        $display("");
        $display("--- Test Group 13: Back-to-back writes ---");
        begin : b2b_block
            integer i;
            for (i = 0; i < 4; i = i + 1) begin
                axi_write(ADDR_KEY_0 + i*4, 32'hDEAD_0000 + i);
            end
            axi_read(ADDR_KEY_0, rd_data); check(rd_data, 32'hDEAD_0000, "B2B KEY_0");
            axi_read(ADDR_KEY_1, rd_data); check(rd_data, 32'hDEAD_0001, "B2B KEY_1");
            axi_read(ADDR_KEY_2, rd_data); check(rd_data, 32'hDEAD_0002, "B2B KEY_2");
            axi_read(ADDR_KEY_3, rd_data); check(rd_data, 32'hDEAD_0003, "B2B KEY_3");
        end

        //======================================================================
        // Test 14: STATUS cleared on new_key (CTRL[2])
        //======================================================================
        $display("");
        $display("--- Test Group 14: STATUS cleared by new_key ---");
        // First set some status bits
        busy = 1; @(posedge clk); @(posedge clk); busy = 0;
        done = 1; @(posedge clk); @(posedge clk); done = 0;
        key_ready = 1; @(posedge clk); @(posedge clk); key_ready = 0;

        axi_read(ADDR_STATUS, rd_data);
        $display("  STATUS before new_key: 0x%08X", rd_data);

        // Trigger new_key — should clear entire STATUS
        axi_write(ADDR_CTRL, 32'h0000_0004);
        repeat (2) @(posedge clk);
        axi_read(ADDR_STATUS, rd_data);
        check(rd_data, 32'h0, "STATUS all clear after new_key");

        //======================================================================
        // Test 15: SLVERR for Write to Read-Only register
        //======================================================================
        $display("");
        $display("--- Test Group 15: SLVERR for Read-Only write ---");
        axi_write(ADDR_STATUS, 32'hFFFFFFFF); // Writing to STATUS (ReadOnly)
        test_num = test_num + 1;
        if (bresp === 2'b10) begin
            $display("[Test %0d] PASS  BRESP=SLVERR (correct)", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("[Test %0d] FAIL  BRESP=%b (exp=10)", test_num, bresp);
            fail_count = fail_count + 1;
        end

        axi_write(ADDR_CIPHER_0, 32'hCAFEBABE); // Writing to CIPHER (ReadOnly)
        test_num = test_num + 1;
        if (bresp === 2'b10) begin
            $display("[Test %0d] PASS  BRESP=SLVERR (correct)", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("[Test %0d] FAIL  BRESP=%b (exp=10)", test_num, bresp);
            fail_count = fail_count + 1;
        end

        //======================================================================
        // Test 16: SLVERR for Read from Unmapped address
        //======================================================================
        $display("");
        $display("--- Test Group 16: SLVERR for Unmapped read ---");
        axi_read(6'h3C, rd_data); // Beyond ADDR_CIPHER_3 (0x34)
        test_num = test_num + 1;
        if (rresp === 2'b10) begin
            $display("[Test %0d] PASS  RRESP=SLVERR (correct)", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("[Test %0d] FAIL  RRESP=%b (exp=10)", test_num, rresp);
            fail_count = fail_count + 1;
        end

        //======================================================================
        // Summary
        //======================================================================
        $display("");
        $display("================================================================");
        $display("  Summary: Passed = %0d   Failed = %0d", pass_count, fail_count);
        $display("================================================================");
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** SOME TESTS FAILED ***");
        $display("================================================================");
        $display("");

        #100;
        $finish;
    end

    initial begin
        #200000;
        $display("ERROR: Global timeout!");
        $finish;
    end

endmodule
