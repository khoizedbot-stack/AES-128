//==============================================================================
// Testbench: inv_shift_rows
// Description: Verify Inverse ShiftRows against NIST FIPS-197 known values
//   ISR shifts each row RIGHT by its index (inverse of SR which shifts LEFT).
//   inv_shift_rows is the inverse of shift_rows: ISR(SR(x)) = x
//==============================================================================
`timescale 1ns/1ps

module tb_inv_shift_rows;

    //==========================================================================
    // Signals
    //==========================================================================
    reg  [127:0] state_isr_in;
    wire [127:0] state_isr_out;

    integer pass_count;
    integer fail_count;
    integer test_num;

    //==========================================================================
    // DUT
    //==========================================================================
    inv_shift_rows dut (
        .state_isr_in  (state_isr_in),
        .state_isr_out (state_isr_out)
    );

    //==========================================================================
    // Task: check result
    //==========================================================================
    task check;
        input [127:0] in_val;
        input [127:0] expected;
        input [255:0] name;
        begin
            test_num      = test_num + 1;
            state_isr_in  = in_val;
            #10;
            if (state_isr_out === expected) begin
                $display("[Test %0d] %s - PASS", test_num, name);
                pass_count = pass_count + 1;
            end else begin
                $display("[Test %0d] %s - FAIL", test_num, name);
                $display("         Input:    %h", in_val);
                $display("         Expected: %h", expected);
                $display("         Got:      %h", state_isr_out);
                fail_count = fail_count + 1;
            end
        end
    endtask

    //==========================================================================
    // Main test
    //==========================================================================
    initial begin
        $display("");
        $display("============================================================");
        $display("  INV_SHIFT_ROWS Testbench");
        $display("============================================================");
        $display("  Verifying: ISR(SR(x)) = x  and  NIST FIPS-197 vectors");
        $display("  Column-major state layout (same as AES spec):");
        $display("    [127:120][119:112][111:104][103:96]  = col0 (r0,r1,r2,r3)");
        $display("    [95:88]  [87:80]  [79:72]  [71:64]  = col1");
        $display("    [63:56]  [55:48]  [47:40]  [39:32]  = col2");
        $display("    [31:24]  [23:16]  [15:8]   [7:0]    = col3");
        $display("============================================================");
        $display("");

        test_num   = 0;
        pass_count = 0;
        fail_count = 0;

        // ------------------------------------------------------------------
        // Identity test: uniform state is unaffected by any row shift
        // ------------------------------------------------------------------
        $display("--- Identity / uniform tests ---");

        // All zeros: ISR is identity on zero state
        check(128'h00000000000000000000000000000000,
              128'h00000000000000000000000000000000,
              "All zeros unchanged");

        // All same byte: row shifts are rotations, uniform stays uniform
        check(128'haaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
              128'haaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
              "Uniform 0xAA unchanged");

        // ------------------------------------------------------------------
        // NIST FIPS-197 Appendix B, Round 1:
        //   After SubBytes:   63cab704 0953d051 cd60e0e7 ba70e18c
        //   After ShiftRows:  6353e08c 0960e104 cd70b751 bacad0e7
        //   → ISR(ShiftRows_out) = SubBytes_out
        // ------------------------------------------------------------------
        $display("");
        $display("--- NIST FIPS-197 Appendix B ---");

        check(128'h6353e08c0960e104cd70b751bacad0e7,
              128'h63cab7040953d051cd60e0e7ba70e18c,
              "NIST Round1: ISR(SR(state)) = state");

        // ------------------------------------------------------------------
        // Manual check: distinct bytes per row to verify shift directions
        //
        // State in column-major (rows across columns):
        //   Row 0: 11 22 33 44   (no shift)
        //   Row 1: 55 66 77 88   (shift right 1 → 88 55 66 77)
        //   Row 2: 99 aa bb cc   (shift right 2 → bb cc 99 aa)
        //   Row 3: dd ee ff 00   (shift right 3 → ee ff 00 dd)
        //
        // Input (column-major):
        //   col0: r0=11, r1=55, r2=99, r3=dd → 115599dd
        //   col1: r0=22, r1=66, r2=aa, r3=ee → 2266aaee
        //   col2: r0=33, r1=77, r2=bb, r3=ff → 3377bbff
        //   col3: r0=44, r1=88, r2=cc, r3=00 → 4488cc00
        //
        // After ISR (column-major):
        //   Row 0 no shift:   r0 stays → 11 22 33 44
        //   Row 1 right 1:    r1 col0←col3, col1←col0, col2←col1, col3←col2
        //                     → 88 55 66 77
        //   Row 2 right 2:    → bb cc 99 aa
        //   Row 3 right 3:    → ee ff 00 dd
        //   col0: 11 88 bb ee → 1188bbee
        //   col1: 22 55 cc ff → 2255ccff
        //   col2: 33 66 99 00 → 336699 00
        //   col3: 44 77 aa dd → 4477aadd
        // ------------------------------------------------------------------
        $display("");
        $display("--- Manual row-shift verification ---");

        check(128'h115599dd2266aaee3377bbff4488cc00,
              128'h1188bbee2255ccff33669900_4477aadd,
              "Manual: distinct bytes per row");

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("");
        $display("============================================================");
        $display("  Summary: Passed=%0d  Failed=%0d", pass_count, fail_count);
        $display("============================================================");
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        $display("");
        #10 $finish;
    end

endmodule
