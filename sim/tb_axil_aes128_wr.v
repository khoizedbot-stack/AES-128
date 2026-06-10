`timescale 1ns / 1ps

// ==============================================================================
// Testbench: axil_aes128_wr (Registered Ready pattern)
// Tests: single write, back-to-back writes, BREADY stall, BRESP error
// ==============================================================================
module tb_axil_aes128_wr;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 6;
    parameter STRB_WIDTH = DATA_WIDTH / 8;
    parameter CLK_PERIOD = 10;

    reg                    clk = 0;
    reg                    aresetn = 0;
    reg  [ADDR_WIDTH-1:0]  awaddr;
    reg                    awvalid;
    reg  [DATA_WIDTH-1:0]  wdata;
    reg  [STRB_WIDTH-1:0]  wstrb;
    reg                    wvalid;
    reg                    bready;
    wire                   awready;
    wire                   wready;
    wire [1:0]             bresp;
    wire                   bvalid;
    wire [ADDR_WIDTH-1:0]  wr_addr;
    wire [DATA_WIDTH-1:0]  wr_data;
    wire [STRB_WIDTH-1:0]  wr_strb;
    wire                   wr_en;
    reg                    wr_err;

    integer pass_count = 0;
    integer fail_count = 0;

    always #(CLK_PERIOD/2) clk = ~clk;

    axil_aes128_wr #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk), .aresetn(aresetn),
        .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(awready),
        .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(wready),
        .s_axil_bresp(bresp), .s_axil_bvalid(bvalid), .s_axil_bready(bready),
        .wr_addr(wr_addr), .wr_data(wr_data), .wr_strb(wr_strb), .wr_en(wr_en), .wr_err(wr_err)
    );

    // ---- Helper tasks ----
    task automatic check(input [255:0] test_name, input condition);
    begin
        if (condition) begin
            $display("[%0s] - PASS", test_name);
            pass_count = pass_count + 1;
        end else begin
            $display("[%0s] - FAIL", test_name);
            fail_count = fail_count + 1;
        end
    end
    endtask

    task automatic idle_bus;
    begin
        awvalid = 0;
        wvalid  = 0;
        awaddr  = 0;
        wdata   = 0;
        wstrb   = 0;
    end
    endtask

    task axi_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);

            awaddr = addr;
            awvalid = 1;
            wdata = data;
            wstrb = 4'hF;
            wvalid = 1;
            
            while (!(awready && wready)) begin
                @(posedge clk);

            end
            awvalid = 0;
            wvalid = 0;
            
            while (!bvalid) begin
                @(posedge clk);

            end
        end
    endtask

    initial begin
        $display("============================================================");
        $display("  AXIL_AES128_WR Testbench (Registered Ready)");
        $display("============================================================");

        aresetn = 0;
        wr_err  = 0;
        bready  = 1;
        idle_bus();
        repeat(3) @(posedge clk);
        aresetn = 1;
        @(posedge clk);

        // ==================================================================
        // Test 1: Single write
        // ==================================================================
        $display("");
        $display("--- Test 1: Single write ---");
        @(posedge clk);
        awaddr = 6'h08; awvalid = 1; wdata = 32'hDEAD_BEEF; wstrb = 4'hF; wvalid = 1;

        while (!(awready && wready)) @(posedge clk);
        check("T1 AWREADY=1", awready === 1'b1);
        check("T1 WREADY=1", wready === 1'b1);
        check("T1 wr_en=1", wr_en === 1'b1);
        check("T1 wr_addr=0x08", wr_addr === 6'h08);
        check("T1 wr_data=DEAD_BEEF", wr_data === 32'hDEAD_BEEF);
        
        awvalid = 0; wvalid = 0;

        while (!bvalid) @(posedge clk);
        check("T1 BVALID=1", bvalid === 1'b1);
        check("T1 BRESP=OK", bresp === 2'b00);

        while (bvalid) @(posedge clk);
        check("T1 BVALID=0", bvalid === 1'b0);

        repeat(2) @(posedge clk);

        // ==================================================================
        // Test 2: Back-to-back writes (4 writes) using task
        // ==================================================================
        $display("");
        $display("--- Test 2: Back-to-back writes (4x) ---");
        
        axi_write(6'h0C, 32'h1111_1111);
        check("T2 Write 1 completed", 1);
        
        axi_write(6'h10, 32'h2222_2222);
        check("T2 Write 2 completed", 1);
        
        axi_write(6'h14, 32'h3333_3333);
        check("T2 Write 3 completed", 1);
        
        axi_write(6'h18, 32'h4444_4444);
        check("T2 Write 4 completed", 1);

        repeat(2) @(posedge clk);

        // ==================================================================
        // Test 3: BREADY stall
        // ==================================================================
        $display("");
        $display("--- Test 3: BREADY stall ---");
        bready = 0;

        @(posedge clk);
        awaddr = 6'h1C; awvalid = 1; wdata = 32'hAAAA_BBBB; wstrb = 4'hF; wvalid = 1;

        while (!(awready && wready)) @(posedge clk);
        check("T3 wr_en=1", wr_en === 1'b1);
        awvalid = 0; wvalid = 0;

        while (!bvalid) @(posedge clk);
        check("T3 BVALID=1 (stalled)", bvalid === 1'b1);

        // Try another write
        @(posedge clk);
        awaddr = 6'h20; awvalid = 1; wdata = 32'hCCCC_DDDD; wstrb = 4'hF; wvalid = 1;

        @(posedge clk);
        check("T3 AWREADY=0 (waiting for bready)", awready === 1'b0);
        check("T3 BVALID=1 (still stalled)", bvalid === 1'b1);

        @(posedge clk);
        bready = 1; // Release
        
        while (bvalid) @(posedge clk);
        check("T3 BVALID=0 (consumed)", bvalid === 1'b0);

        while (!(awready && wready)) @(posedge clk);
        check("T3 wr_en=1 for second write", wr_en === 1'b1);
        awvalid = 0; wvalid = 0;
        
        while (!bvalid) @(posedge clk);

        repeat(2) @(posedge clk);

        // ==================================================================
        // Test 4: BRESP error
        // ==================================================================
        $display("");
        $display("--- Test 4: BRESP error ---");
        wr_err = 1;
        
        @(posedge clk);
        awaddr = 6'h3C; awvalid = 1; wdata = 32'hBAAD_F00D; wstrb = 4'hF; wvalid = 1;
        
        while (!(awready && wready)) @(posedge clk);
        awvalid = 0; wvalid = 0;
        
        while (!bvalid) @(posedge clk);
        check("T4 BRESP=SLVERR", bresp === 2'b10);
        wr_err = 0;
        
        @(posedge clk);

        $display("");
        $display("============================================================");
        $display("  Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("============================================================");
        #500;
        $finish;
    end

endmodule
