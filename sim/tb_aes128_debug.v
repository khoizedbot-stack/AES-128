`timescale 1ns/1ps

module tb_aes128_debug;

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
    
    // Monitor internal signals
    wire [3:0] state = dut.u_datapath.state;
    wire [127:0] state_out = dut.u_datapath.state_out;
    wire [127:0] round_out = dut.u_datapath.round_out;
    wire [127:0] final_out = dut.u_datapath.final_out;
    wire [127:0] expanded_key = dut.u_key_gen.expanded_key;
    wire [127:0] current_key = dut.u_key_gen.current_key;
    wire key_load = dut.u_datapath.key_load;
    wire key_next = dut.u_datapath.key_next;
    
    always @(posedge clk) begin
        if (busy || key_load || key_next) begin
            $display("[%0t] State=%0d load=%b next=%b", 
                     $time, state, key_load, key_next);
            $display("       current_key=%h", current_key);
            $display("       expanded_key=%h", expanded_key);
            $display("       state_out=%h", state_out);
        end
    end
    
    initial begin
        $display("========================================");
        $display("  AES-128 Debug Test");
        $display("========================================");
        
        // Reset
        rst_n = 0;
        start = 0;
        key = 128'h0;
        plaintext = 128'h0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        // NIST Test
        $display("\n--- NIST Test Vector ---");
        key       = 128'h000102030405060708090a0b0c0d0e0f;
        plaintext = 128'h00112233445566778899aabbccddeeff;
        
        $display("Key:       %h", key);
        $display("Plaintext: %h", plaintext);
        $display("");
        
        // Start
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Wait for done
        wait(done == 1);
        @(posedge clk);
        
        $display("");
        $display("Final round_out: %h", round_out);
        $display("Final final_out: %h", final_out);
        $display("Ciphertext:      %h", ciphertext);
        $display("Expected:        69c4e0d86a7b0430d8cdb78070b4c55a");
        
        if (ciphertext == 128'h69c4e0d86a7b0430d8cdb78070b4c55a) begin
            $display("✓ PASS!");
        end else begin
            $display("✗ FAIL!");
        end
        
        repeat(10) @(posedge clk);
        $finish;
    end

endmodule
