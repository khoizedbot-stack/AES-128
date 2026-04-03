//==============================================================================
// Testbench: decrypt_round
// Description: Verify one AES-128 decryption round block
//   Pipeline: ISR -> ISB -> ARK -> [IMC]
//==============================================================================
`timescale 1ns/1ps

module tb_decrypt_round;

    //==========================================================================
    // Signals
    //==========================================================================
    reg         final_round;
    reg  [127:0] round_key;
    reg  [127:0] dec_state_in;
    wire [127:0] dec_state_round;
    wire [127:0] isr_ref, isb_ref, ark_ref, imc_ref;

    integer pass_count;
    integer fail_count;
    integer test_num;

    //==========================================================================
    // DUT
    //==========================================================================
    decrypt_round dut (
        .final_round    (final_round),
        .round_key      (round_key),
        .dec_state_in   (dec_state_in),
        .dec_state_round(dec_state_round)
    );

    inv_shift_rows u_isr_ref (
        .state_isr_in   (dec_state_in),
        .state_isr_out  (isr_ref)
    );

    inv_sub_bytes u_isb_ref (
        .state_isb_in   (isr_ref),
        .state_isb_out  (isb_ref)
    );

    add_round_key u_ark_ref (
        .round_key      (round_key),
        .state_ark_in   (isb_ref),
        .state_ark_out  (ark_ref)
    );

    inv_mix_columns u_imc_ref (
        .state_imc_in   (ark_ref),
        .state_imc_out  (imc_ref)
    );

    //==========================================================================
    // Task: check result
    //==========================================================================
    task check;
        input         fr;
        input [127:0] state_in;
        input [127:0] key;
        input [127:0] expected;
        input [255:0] name;
        begin
            test_num     = test_num + 1;
            final_round  = fr;
            dec_state_in = state_in;
            round_key    = key;
            #10;
            if (dec_state_round === expected) begin
                $display("[Test %0d] %s - PASS", test_num, name);
                pass_count = pass_count + 1;
            end else begin
                $display("[Test %0d] %s - FAIL", test_num, name);
                $display("         State in: %h", state_in);
                $display("         Key:      %h", key);
                $display("         Expected: %h", expected);
                $display("         Got:      %h", dec_state_round);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_pipeline;
        input         fr;
        input [127:0] state_in;
        input [127:0] key;
        input [255:0] name;
        reg   [127:0] expected;
        begin
            final_round  = fr;
            dec_state_in = state_in;
            round_key    = key;
            #10;
            expected = fr ? ark_ref : imc_ref;

            test_num = test_num + 1;
            if (dec_state_round === expected) begin
                $display("[Test %0d] %s - PASS", test_num, name);
                pass_count = pass_count + 1;
            end else begin
                $display("[Test %0d] %s - FAIL", test_num, name);
                $display("         State in: %h", state_in);
                $display("         Key:      %h", key);
                $display("         Expected: %h", expected);
                $display("         Got:      %h", dec_state_round);
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
        $display("  DECRYPT_ROUND Testbench");
        $display("============================================================");
        $display("  Pipeline: ISR -> ISB -> ARK -> [IMC]");
        $display("  Testing: NIST stage vector + pipeline equivalence");
        $display("============================================================");
        $display("");

        test_num   = 0;
        pass_count = 0;
        fail_count = 0;

          // ------------------------------------------------------------------
          // NIST decryption-stage vector (first normal decryption round):
          //   input  = C ^ K10 = 7ad5fda789ef4e272bca100b3d9ff59f
          //   key    = K9      = 549932d1f08557681093ed9cbe2c974e
          //   output = 54d990a16ba09ab596bbf40ea111702f
          // ------------------------------------------------------------------
          $display("--- NIST vector: first normal decryption round ---");

          check(1'b0,
              128'h7ad5fda789ef4e272bca100b3d9ff59f,
              128'h549932d1f08557681093ed9cbe2c974e,
              128'h54d990a16ba09ab596bbf40ea111702f,
              "NIST dec round: (C^K10, K9) -> state");

          // ------------------------------------------------------------------
          // Pipeline consistency checks for both final_round settings
          // ------------------------------------------------------------------
        $display("");
          $display("--- Pipeline consistency checks ---");

          check_pipeline(1'b0,
                     128'hbd6e7c3df2b5779e0b61216e8b10b689,
                     128'h549932d1f08557681093ed9cbe2c974e,
                     "final_round=0 uses IMC path");

          check_pipeline(1'b1,
                     128'h69c4e0d86a7b0430d8cdb78070b4c55a,
                     128'h13111d7fe3944a17f307a78b4d2b30c5,
                     "final_round=1 bypasses IMC");

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
