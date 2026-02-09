`timescale 1ns/1ps

module tb_aes128_top_simple;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg  [127:0] key;
    reg  [127:0] plaintext;
    wire        busy;
    wire        done;
    wire [127:0] ciphertext;
    
    // DUT
    aes128_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .key(key),
        .plaintext(plaintext),
        .busy(busy),
        .done(done),
        .ciphertext(ciphertext)
    );
    
    // Clock
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Debug signals
    integer cycle;
    
    initial begin
        $display("====================================");
        $display("  AES-128 Top Module Test");
        $display("====================================");
        
        cycle = 0;
        
        // Reset
        rst_n = 0;
        start = 0;
        key = 128'h0;
        plaintext = 128'h0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        // NIST Test Vector 1
        $display("\n--- Test 1: NIST FIPS-197 ---");
        key       = 128'h000102030405060708090a0b0c0d0e0f;
        plaintext = 128'h00112233445566778899aabbccddeeff;
        
        $display("Key:       %h", key);
        $display("Plaintext: %h", plaintext);
        
        // Start encryption
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Monitor progress
        cycle = 0;
        while (!done && cycle < 50) begin
            @(posedge clk);
            cycle = cycle + 1;
            if (cycle % 5 == 0) $display("  Cycle %0d: busy=%b done=%b", cycle, busy, done);
        end
        
        if (!done) begin
            $display("ERROR: Encryption did not complete!");
        end
        
        // Wait for done
        wait(done == 1);
        @(posedge clk);
        
        $display("Ciphertext: %h", ciphertext);
        $display("Expected:   69c4e0d86a7b0430d8cdb78070b4c55a");
        
        if (ciphertext == 128'h69c4e0d86a7b0430d8cdb78070b4c55a) begin
            $display("PASS!");
        end else begin
            $display("FAIL!");
        end
        
        // Test 2
        repeat(5) @(posedge clk);
        $display("\n--- Test 2: Second Vector ---");
        key       = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        plaintext = 128'h3243f6a8885a308d313198a2e0370734;
        
        $display("Key:       %h", key);
        $display("Plaintext: %h", plaintext);
        
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(done == 1);
        @(posedge clk);
        
        $display("Ciphertext: %h", ciphertext);
        $display("Expected:   3925841d02dc09fbdc118597196a0b32");
        
        if (ciphertext == 128'h3925841d02dc09fbdc118597196a0b32) begin
            $display("PASS!");
        end else begin
            $display("FAIL!");
        end
        
        repeat(10) @(posedge clk);
        $display("\n====================================");
        $finish;
    end
    
    // Timeout
    initial begin
        #5000;
        $display("TIMEOUT!");
        $finish;
    end

endmodule
