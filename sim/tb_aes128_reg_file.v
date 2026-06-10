`timescale 1ns / 1ps

module tb_aes128_reg_file;

    parameter ADDR_WIDTH = 6;
    parameter DATA_WIDTH = 32;

    reg clk;
    reg rst_n;
    
    // Write Ctrl
    reg wr_en;
    reg [ADDR_WIDTH-1:0] wr_addr;
    reg [DATA_WIDTH-1:0] wr_data;
    reg [(DATA_WIDTH/8)-1:0] wr_strb;
    wire wr_error;
    
    // Read Ctrl
    reg rd_en; 
    reg [ADDR_WIDTH-1:0] rd_addr;
    wire [DATA_WIDTH-1:0] rd_data;
    wire rd_error;
    
    // User App (Crypto)
    wire [127:0] data_bus;
    wire start;
    wire new_key;
    wire enc_dec;
    reg busy;
    reg done;
    reg key_ready;
    wire irq_out;

    reg [127:0] core_data_drive;
    reg core_drive_en;

    integer pass_count = 0;
    integer fail_count = 0;

    assign data_bus = core_drive_en ? core_data_drive : 128'bz;

    crypto_reg_file #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_strb(wr_strb),
        .wr_error(wr_error),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .rd_error(rd_error),
        .data_bus(data_bus),
        .start(start),
        .new_key(new_key),
        .enc_dec(enc_dec),
        .busy(busy),
        .done(done),
        .key_ready(key_ready),
        .irq_out(irq_out)
    );

    always #5 clk = ~clk;

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

    task write_reg(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
    begin
        @(posedge clk);
        wr_addr <= addr;
        wr_data <= data;
        wr_strb <= 4'hF;
        wr_en   <= 1;
        @(posedge clk);
        wr_en   <= 0;
    end
    endtask

    task read_reg(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
    begin
        @(posedge clk);
        rd_addr <= addr;
        rd_en   <= 1;
        @(posedge clk);
        data = rd_data;
        rd_en   <= 0;
    end
    endtask

    reg [31:0] rdata_temp;

    initial begin
        $display("============================================================");
        $display("  tb_aes128_reg_file");
        $display("============================================================");

        clk = 0;
        rst_n = 0;
        wr_en = 0;
        wr_addr = 0;
        wr_data = 0;
        wr_strb = 0;
        rd_en = 0;
        rd_addr = 0;
        busy = 0;
        done = 0;
        key_ready = 0;
        core_data_drive = 0;
        core_drive_en = 0;

        #20;
        rst_n = 1;

        // --- Test 1: Write Key and check New Key trigger ---
        write_reg(6'h08, 32'h09cf4f3c); // Key 0
        write_reg(6'h0C, 32'habf71588); // Key 1
        write_reg(6'h10, 32'h28aed2a6); // Key 2
        write_reg(6'h14, 32'h2b7e1516); // Key 3

        write_reg(6'h00, 32'h00000004); // CTRL[2] = 1 (new_key)
        
        @(posedge clk);
        @(posedge clk);
        check("T1 New Key Triggered", new_key === 1'b1);
        check("T1 Bus Data (Key) correct", data_bus === 128'h2b7e151628aed2a6abf7158809cf4f3c);
        busy <= 1; // Mock core becomes busy during key expansion
        
        @(posedge clk);
        check("T1 New Key Cleared", new_key === 1'b0);

        // Core responds with key_ready
        repeat(10) @(posedge clk); // Simulate key schedule delay
        busy <= 0;
        key_ready <= 1; // Mimic datapath: key_ready stays 1 until next new_key


        // --- Test 2: Write Plaintext and check Start trigger ---
        write_reg(6'h18, 32'he0370734); // PT 0
        write_reg(6'h1C, 32'h313198a2); // PT 1
        write_reg(6'h20, 32'h885a308d); // PT 2
        write_reg(6'h24, 32'h3243f6a8); // PT 3

        write_reg(6'h00, 32'h00000001); // CTRL[0] = 1 (start), CTRL[1] = 0 (enc)
        
        @(posedge clk);
        @(posedge clk);
        check("T2 Start Triggered", start === 1'b1);
        check("T2 Enc_Dec mode 0", enc_dec === 1'b0);
        check("T2 Bus Data (PT) correct", data_bus === 128'h3243f6a8885a308d313198a2e0370734);
        busy <= 1; // Core is busy

        // --- Test 3: Core Done and Read Ciphertext ---
        // Core finishes and drives data_bus, asserts done
        repeat(10) @(posedge clk); // Simulate encryption delay
        busy <= 0;
        core_drive_en <= 1;
        core_data_drive <= 128'h3925841d02dc09fbdc118597196a0b32;
        done <= 1;
        @(posedge clk);
        done <= 0;
        // Keep core_drive_en = 1 to mimic real datapath which holds the bus

        // Read Ciphertext
        read_reg(6'h28, rdata_temp);
        check("T3 Cipher 0", rdata_temp === 32'h196a0b32);
        read_reg(6'h2C, rdata_temp);
        check("T3 Cipher 1", rdata_temp === 32'hdc118597);
        read_reg(6'h30, rdata_temp);
        check("T3 Cipher 2", rdata_temp === 32'h02dc09fb);
        read_reg(6'h34, rdata_temp);
        check("T3 Cipher 3", rdata_temp === 32'h3925841d);

        $display("============================================================");
        $display("  Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("============================================================");
        #500;
        $finish;
    end

endmodule
