`timescale 1ns / 1ps

// ==============================================================================
// Testbench: axil_aes128_rd (Registered Ready pattern)
// Tests: single read, back-to-back reads, RREADY stall, RRESP error
// ==============================================================================
module tb_axil_aes128_rd;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 6;
    parameter CLK_PERIOD = 10;

    reg                    clk = 0;
    reg                    aresetn = 0;
    reg  [ADDR_WIDTH-1:0]  araddr;
    reg                    arvalid;
    reg                    rready;
    wire                   arready;
    wire [DATA_WIDTH-1:0]  rdata;
    wire [1:0]             rresp;
    wire                   rvalid;
    wire [ADDR_WIDTH-1:0]  rd_addr;
    wire                   rd_en;
    reg  [DATA_WIDTH-1:0]  rd_data_comb;
    reg                    rd_err;

    integer pass_count = 0;
    integer fail_count = 0;

    always #(CLK_PERIOD/2) clk = ~clk;

    axil_aes128_rd #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk), .aresetn(aresetn),
        .s_axil_araddr(araddr), .s_axil_arvalid(arvalid), .s_axil_arready(arready),
        .s_axil_rdata(rdata), .s_axil_rresp(rresp), .s_axil_rvalid(rvalid), .s_axil_rready(rready),
        .rd_addr(rd_addr), .rd_en(rd_en), .rd_data(rd_data_comb), .rd_err(rd_err)
    );

    // Mock register file read output
    always @(*) begin
        case (rd_addr)
            6'h04: rd_data_comb = 32'h0000_0007; // Status
            6'h28: rd_data_comb = 32'h1111_2222; // Cipher 0
            6'h2C: rd_data_comb = 32'h3333_4444; // Cipher 1
            6'h30: rd_data_comb = 32'h5555_6666; // Cipher 2
            6'h34: rd_data_comb = 32'h7777_8888; // Cipher 3
            default: rd_data_comb = 32'hDEAD_BEEF;
        endcase
    end

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

    task axi_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);

            araddr = addr;
            arvalid = 1;
            
            while (!arready) begin
                @(posedge clk);

            end
            arvalid = 0;
            
            while (!rvalid) begin
                @(posedge clk);

            end
            data = rdata;
        end
    endtask

    initial begin
        $display("============================================================");
        $display("  AXIL_AES128_RD Testbench (Registered Ready)");
        $display("============================================================");

        aresetn = 0;
        rd_err  = 0;
        rready  = 1;
        arvalid = 0;
        araddr  = 0;
        repeat(3) @(posedge clk);
        aresetn = 1;
        @(posedge clk);

        // ==================================================================
        // Test 1: Single read
        // ==================================================================
        $display("");
        $display("--- Test 1: Single read ---");
        @(posedge clk);
        araddr = 6'h04; arvalid = 1;

        while (!arready) @(posedge clk);

        check("T1 ARREADY=1", arready === 1'b1);
        check("T1 rd_en=1", rd_en === 1'b1);
        check("T1 rd_addr=0x04", rd_addr === 6'h04);
        
        arvalid = 0;

        while (!rvalid) @(posedge clk);

        check("T1 RVALID=1", rvalid === 1'b1);
        check("T1 RDATA=0x7", rdata === 32'h0000_0007);

        while (rvalid) @(posedge clk);

        check("T1 RVALID=0", rvalid === 1'b0);

        repeat(2) @(posedge clk);

        // ==================================================================
        // Test 2: Back-to-back reads (4x)
        // ==================================================================
        $display("");
        $display("--- Test 2: Back-to-back reads (4x) ---");
        
        begin : test2
            reg [31:0] rdata_out;
            axi_read(6'h28, rdata_out);
            check("T2 Read 1 Data", rdata_out === 32'h1111_2222);
            
            axi_read(6'h2C, rdata_out);
            check("T2 Read 2 Data", rdata_out === 32'h3333_4444);
            
            axi_read(6'h30, rdata_out);
            check("T2 Read 3 Data", rdata_out === 32'h5555_6666);
            
            axi_read(6'h34, rdata_out);
            check("T2 Read 4 Data", rdata_out === 32'h7777_8888);
        end

        repeat(2) @(posedge clk);

        // ==================================================================
        // Test 3: RREADY stall
        // ==================================================================
        $display("");
        $display("--- Test 3: RREADY stall ---");
        rready = 0;

        @(posedge clk);
        araddr = 6'h04; arvalid = 1;

        while (!arready) @(posedge clk);
        arvalid = 0;

        while (!rvalid) @(posedge clk);
        check("T3 RVALID=1 (stalled)", rvalid === 1'b1);

        // Try another read
        @(posedge clk);
        araddr = 6'h28; arvalid = 1;

        @(posedge clk);
        check("T3 ARREADY=0 (waiting)", arready === 1'b0);

        @(posedge clk);
        rready = 1; // Release
        
        while (rvalid) @(posedge clk);
        check("T3 RVALID=0", rvalid === 1'b0);

        while (!arready) @(posedge clk);
        arvalid = 0;
        
        while (!rvalid) @(posedge clk);

        repeat(2) @(posedge clk);

        // ==================================================================
        // Test 4: RRESP error
        // ==================================================================
        $display("");
        $display("--- Test 4: RRESP error ---");
        rd_err = 1;
        
        @(posedge clk);
        araddr = 6'h3C; arvalid = 1;
        
        while (!arready) @(posedge clk);
        arvalid = 0;
        
        while (!rvalid) @(posedge clk);
        check("T4 RRESP=SLVERR", rresp === 2'b10);
        rd_err = 0;
        
        @(posedge clk);

        $display("");
        $display("============================================================");
        $display("  Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("============================================================");
        #500;
        $finish;
    end

endmodule
