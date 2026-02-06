//==============================================================================
// Testbench: tb_aes128_axi
// Description: Testbench for AES-128 with AXI4-Lite interface
//==============================================================================

`timescale 1ns / 1ps

module tb_aes128_axi;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter CLK_PERIOD = 10;  // 100 MHz
    parameter ADDR_WIDTH = 6;
    parameter DATA_WIDTH = 32;
    
    // Register addresses
    localparam ADDR_CTRL   = 6'h00;
    localparam ADDR_STATUS = 6'h04;
    localparam ADDR_KEY_0  = 6'h08;
    localparam ADDR_KEY_1  = 6'h0C;
    localparam ADDR_KEY_2  = 6'h10;
    localparam ADDR_KEY_3  = 6'h14;
    localparam ADDR_PT_0   = 6'h18;
    localparam ADDR_PT_1   = 6'h1C;
    localparam ADDR_PT_2   = 6'h20;
    localparam ADDR_PT_3   = 6'h24;
    localparam ADDR_CT_0   = 6'h28;
    localparam ADDR_CT_1   = 6'h2C;
    localparam ADDR_CT_2   = 6'h30;
    localparam ADDR_CT_3   = 6'h34;
    
    //==========================================================================
    // Signals
    //==========================================================================
    reg                      clk;
    reg                      rst_n;
    
    // AXI Write Address
    reg  [ADDR_WIDTH-1:0]    awaddr;
    reg  [2:0]               awprot;
    reg                      awvalid;
    wire                     awready;
    
    // AXI Write Data
    reg  [DATA_WIDTH-1:0]    wdata;
    reg  [DATA_WIDTH/8-1:0]  wstrb;
    reg                      wvalid;
    wire                     wready;
    
    // AXI Write Response
    wire [1:0]               bresp;
    wire                     bvalid;
    reg                      bready;
    
    // AXI Read Address
    reg  [ADDR_WIDTH-1:0]    araddr;
    reg  [2:0]               arprot;
    reg                      arvalid;
    wire                     arready;
    
    // AXI Read Data
    wire [DATA_WIDTH-1:0]    rdata;
    wire [1:0]               rresp;
    wire                     rvalid;
    reg                      rready;
    
    // Interrupt
    wire                     irq_done;
    
    // Test variables
    reg [31:0] read_data;
    reg [127:0] test_key;
    reg [127:0] test_plaintext;
    reg [127:0] received_ciphertext;
    reg [127:0] expected_ciphertext;
    integer errors;
    
    //==========================================================================
    // DUT Instance
    //==========================================================================
    
    aes128_axi_top #(
        .C_S_AXI_ADDR_WIDTH(ADDR_WIDTH),
        .C_S_AXI_DATA_WIDTH(DATA_WIDTH)
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
        
        .irq_done      (irq_done)
    );
    
    //==========================================================================
    // Clock Generation
    //==========================================================================
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // AXI Write Task
    //==========================================================================
    
    task axi_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            awaddr  <= addr;
            awprot  <= 3'b000;
            awvalid <= 1'b1;
            wdata   <= data;
            wstrb   <= 4'hF;
            wvalid  <= 1'b1;
            bready  <= 1'b1;
            
            // Wait for address and data ready
            @(posedge clk);
            while (!(awready && wready)) @(posedge clk);
            
            @(posedge clk);
            awvalid <= 1'b0;
            wvalid  <= 1'b0;
            
            // Wait for response
            while (!bvalid) @(posedge clk);
            @(posedge clk);
            bready <= 1'b0;
            
            $display("[%0t] AXI WRITE: addr=0x%02h, data=0x%08h", $time, addr, data);
        end
    endtask
    
    //==========================================================================
    // AXI Read Task
    //==========================================================================
    
    task axi_read;
        input  [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            araddr  <= addr;
            arprot  <= 3'b000;
            arvalid <= 1'b1;
            rready  <= 1'b1;
            
            // Wait for address ready
            @(posedge clk);
            while (!arready) @(posedge clk);
            
            @(posedge clk);
            arvalid <= 1'b0;
            
            // Wait for data valid
            while (!rvalid) @(posedge clk);
            data = rdata;
            
            @(posedge clk);
            rready <= 1'b0;
            
            $display("[%0t] AXI READ:  addr=0x%02h, data=0x%08h", $time, addr, data);
        end
    endtask
    
    //==========================================================================
    // Wait for Done
    //==========================================================================
    
    task wait_done;
        reg [31:0] status;
        begin
            status = 32'h0;
            while (status[1] == 1'b0) begin
                axi_read(ADDR_STATUS, status);
                if (status[0]) $display("  Status: BUSY");
            end
            $display("  Status: DONE");
        end
    endtask
    
    //==========================================================================
    // Initialize
    //==========================================================================
    
    task init;
        begin
            awaddr  = 0;
            awprot  = 0;
            awvalid = 0;
            wdata   = 0;
            wstrb   = 0;
            wvalid  = 0;
            bready  = 0;
            araddr  = 0;
            arprot  = 0;
            arvalid = 0;
            rready  = 0;
            errors  = 0;
        end
    endtask
    
    //==========================================================================
    // Main Test
    //==========================================================================
    
    initial begin
        $display("================================================");
        $display("  AES-128 AXI4-Lite Testbench");
        $display("================================================");
        
        init();
        rst_n = 0;
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        //----------------------------------------------------------------------
        // Test 1: NIST Test Vector
        // Key:       000102030405060708090a0b0c0d0e0f
        // Plaintext: 00112233445566778899aabbccddeeff
        // Expected:  69c4e0d86a7b0430d8cdb78070b4c55a
        //----------------------------------------------------------------------
        $display("\n--- Test 1: NIST Test Vector ---");
        
        test_key       = 128'h000102030405060708090a0b0c0d0e0f;
        test_plaintext = 128'h00112233445566778899aabbccddeeff;
        expected_ciphertext = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
        
        // Write Key
        $display("Writing Key...");
        axi_write(ADDR_KEY_0, test_key[31:0]);
        axi_write(ADDR_KEY_1, test_key[63:32]);
        axi_write(ADDR_KEY_2, test_key[95:64]);
        axi_write(ADDR_KEY_3, test_key[127:96]);
        
        // Write Plaintext
        $display("Writing Plaintext...");
        axi_write(ADDR_PT_0, test_plaintext[31:0]);
        axi_write(ADDR_PT_1, test_plaintext[63:32]);
        axi_write(ADDR_PT_2, test_plaintext[95:64]);
        axi_write(ADDR_PT_3, test_plaintext[127:96]);
        
        // Start encryption
        $display("Starting encryption...");
        axi_write(ADDR_CTRL, 32'h00000001);
        
        // Wait for done
        wait_done();
        
        // Read Ciphertext
        $display("Reading Ciphertext...");
        axi_read(ADDR_CT_0, received_ciphertext[31:0]);
        axi_read(ADDR_CT_1, received_ciphertext[63:32]);
        axi_read(ADDR_CT_2, received_ciphertext[95:64]);
        axi_read(ADDR_CT_3, received_ciphertext[127:96]);
        
        // Verify
        $display("\nResults:");
        $display("  Expected:  0x%032h", expected_ciphertext);
        $display("  Received:  0x%032h", received_ciphertext);
        
        if (received_ciphertext === expected_ciphertext) begin
            $display("  PASS!");
        end else begin
            $display("  FAIL!");
            errors = errors + 1;
        end
        
        //----------------------------------------------------------------------
        // Test 2: Another test vector
        //----------------------------------------------------------------------
        $display("\n--- Test 2: Second Test Vector ---");
        
        test_key       = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        test_plaintext = 128'h3243f6a8885a308d313198a2e0370734;
        expected_ciphertext = 128'h3925841d02dc09fbdc118597196a0b32;
        
        // Write Key
        axi_write(ADDR_KEY_0, test_key[31:0]);
        axi_write(ADDR_KEY_1, test_key[63:32]);
        axi_write(ADDR_KEY_2, test_key[95:64]);
        axi_write(ADDR_KEY_3, test_key[127:96]);
        
        // Write Plaintext
        axi_write(ADDR_PT_0, test_plaintext[31:0]);
        axi_write(ADDR_PT_1, test_plaintext[63:32]);
        axi_write(ADDR_PT_2, test_plaintext[95:64]);
        axi_write(ADDR_PT_3, test_plaintext[127:96]);
        
        // Start
        axi_write(ADDR_CTRL, 32'h00000001);
        
        // Wait
        wait_done();
        
        // Read
        axi_read(ADDR_CT_0, received_ciphertext[31:0]);
        axi_read(ADDR_CT_1, received_ciphertext[63:32]);
        axi_read(ADDR_CT_2, received_ciphertext[95:64]);
        axi_read(ADDR_CT_3, received_ciphertext[127:96]);
        
        $display("\nResults:");
        $display("  Expected:  0x%032h", expected_ciphertext);
        $display("  Received:  0x%032h", received_ciphertext);
        
        if (received_ciphertext === expected_ciphertext) begin
            $display("  PASS!");
        end else begin
            $display("  FAIL!");
            errors = errors + 1;
        end
        
        //----------------------------------------------------------------------
        // Summary
        //----------------------------------------------------------------------
        repeat(10) @(posedge clk);
        
        $display("\n================================================");
        if (errors == 0) begin
            $display("  ALL TESTS PASSED!");
        end else begin
            $display("  FAILED: %0d errors", errors);
        end
        $display("================================================");
        
        $finish;
    end
    
    //==========================================================================
    // Timeout
    //==========================================================================
    
    initial begin
        #100000;
        $display("ERROR: Timeout!");
        $finish;
    end
    
    //==========================================================================
    // Waveform
    //==========================================================================
    
    initial begin
        $dumpfile("tb_aes128_axi.vcd");
        $dumpvars(0, tb_aes128_axi);
    end

endmodule
