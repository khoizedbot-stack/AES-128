`timescale 1ns/1ps

module tb_mix_columns_simple;

    reg  [127:0] state_in;
    wire [127:0] state_out;
    
    mix_columns dut (
        .state_mc_in(state_in),
        .state_mc_out(state_out)
    );
    
    initial begin
        $display("Testing MixColumns");
        
        // NIST FIPS-197 Appendix B - After ShiftRows, before MixColumns
        // Input:  63cab7040953d051cd60e0e7ba70e18c
        // Output: 5f72641557f5bc92f7be3b291db9f91a
        
        state_in = 128'h63cab7040953d051cd60e0e7ba70e18c;
        #10;
        
        $display("Input:    %h", state_in);
        $display("Output:   %h", state_out);
        $display("Expected: 5f72641557f5bc92f7be3b291db9f91a");
        
        if (state_out === 128'h5f72641557f5bc92f7be3b291db9f91a) begin
            $display("PASS!");
        end else begin
            $display("FAIL!");
        end
        
        $finish;
    end

endmodule
