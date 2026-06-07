//==============================================================================
// Testbench: aes128_top - one encryption only, hold testbench bus drive
// Description:
//   1) Send AES key with new_key pulse.
//   2) Keep tb_bus_oe = 1 after key so data_bus does not become High-Z.
//   3) Wait for key expansion/key_ready.
//   4) Send plaintext with start pulse.
//   5) Keep tb_bus_oe = 1 during encryption so data_bus does not become High-Z.
//   6) Automatically release testbench driver only while done=1 so DUT can drive
//      ciphertext onto data_bus without contention.
//
// Notes:
//   - If testbench drives data_bus while DUT also drives ciphertext at done,
//     data_bus can become X because of bus contention.
//   - Therefore tb_bus_oe remains logically 1, but the actual assignment uses
//     !done to release bus exactly when DUT returns result.
//==============================================================================
`timescale 1ns/1ps

module tb_aes128_top;

    localparam CLK_HALF = 5;

    localparam [127:0] KEY_NIST =
        128'h000102030405060708090a0b0c0d0e0f;
    localparam [127:0] PT_NIST =
        128'h00112233445566778899aabbccddeeff;
    localparam [127:0] CT_NIST =
        128'h69c4e0d86a7b0430d8cdb78070b4c55a;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg         new_key;
    reg         enc_dec;

    reg  [127:0] tb_bus_drive;
    reg          tb_bus_oe;

    wire [127:0] data_bus;
    wire         busy;
    wire         done;
    wire         key_ready;

    reg  [127:0] captured_out;
    reg  [127:0] data_bus_last;
    wire [127:0] data_bus_view;

    integer timeout_cnt;

    //=========================================================================
    // DUT
    //=========================================================================
    aes128_top dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .new_key   (new_key),
        .enc_dec   (enc_dec),
        .data_bus  (data_bus),
        .busy      (busy),
        .done      (done),
        .key_ready (key_ready)
    );

    //=========================================================================
    // Clock
    //=========================================================================
    initial clk = 1'b0;
    always #CLK_HALF clk = ~clk;

    //=========================================================================
    // data_bus driver
    //=========================================================================
    // tb_bus_oe is kept high after key/plaintext, so the bus keeps showing the
    // last key/plaintext value instead of Z.
    //
    // But when done=1, DUT needs to drive ciphertext onto data_bus. Therefore
    // testbench releases the bus only during done to avoid contention.
    assign data_bus = (tb_bus_oe && !done) ? tb_bus_drive : 128'hZ;

    // Optional waveform helper. If data_bus ever becomes Z, this view keeps the
    // last non-Z value.
    assign data_bus_view = (data_bus === 128'hZ) ? data_bus_last : data_bus;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_bus_last <= 128'h0;
            captured_out  <= 128'h0;
        end else begin
            if (data_bus !== 128'hZ)
                data_bus_last <= data_bus;

            if (done)
                captured_out <= data_bus;
        end
    end

    //=========================================================================
    // Task: send key and keep bus ownership
    //=========================================================================
    task send_key_hold_bus;
        input [127:0] key_value;
        begin
            @(posedge clk);
            #1;
            tb_bus_drive = key_value;
            tb_bus_oe    = 1'b1;   // keep driving after this task
            new_key      = 1'b1;

            @(posedge clk);
            #1;
            new_key      = 1'b0;
            // DO NOT clear tb_bus_oe here.
            // data_bus keeps KEY_NIST during key expansion instead of Z.
        end
    endtask

    //=========================================================================
    // Task: wait for key expansion done
    //=========================================================================
    task wait_key_expand_done;
        begin
            timeout_cnt = 0;

            // If key_ready is still high from a previous key, wait for it to drop.
            // In this one-test TB it is usually 0 after reset, but this makes the
            // task safer.
            while (key_ready && timeout_cnt < 20) begin
                @(posedge clk);
                timeout_cnt = timeout_cnt + 1;
            end

            timeout_cnt = 0;
            while (!key_ready && timeout_cnt < 100) begin
                @(posedge clk);
                timeout_cnt = timeout_cnt + 1;
            end

            if (!key_ready) begin
                $display("ERROR: Timeout waiting for key_ready!");
                $finish;
            end

            @(posedge clk);
        end
    endtask

    //=========================================================================
    // Task: send plaintext and keep bus ownership
    //=========================================================================
    task send_plaintext_hold_bus;
        input [127:0] plaintext_value;
        begin
            @(posedge clk);
            #1;
            enc_dec      = 1'b0;   // encrypt
            tb_bus_drive = plaintext_value;
            tb_bus_oe    = 1'b1;   // keep driving during AES rounds
            start        = 1'b1;

            @(posedge clk);
            #1;
            start        = 1'b0;
            // DO NOT clear tb_bus_oe here.
            // data_bus keeps PT_NIST during encryption instead of Z.
            // It is automatically released while done=1 by the assign above.
        end
    endtask

    //=========================================================================
    // Task: wait done and check ciphertext
    //=========================================================================
    task wait_done_and_check;
        begin
            timeout_cnt = 0;
            while (!done && timeout_cnt < 100) begin
                @(posedge clk);
                timeout_cnt = timeout_cnt + 1;
            end

            if (!done) begin
                $display("[ENC] FAIL: Timeout waiting for done!");
                $finish;
            end

            // At done=1, TB driver is released and DUT should drive ciphertext.
            #1;
            captured_out = data_bus;

            if (captured_out === CT_NIST) begin
                $display("[ENC] PASS");
                $display("      Expected: %h", CT_NIST);
                $display("      Got:      %h", captured_out);
            end else begin
                $display("[ENC] FAIL");
                $display("      Expected: %h", CT_NIST);
                $display("      Got:      %h", captured_out);
            end

            @(posedge clk);
        end
    endtask

    //=========================================================================
    // Main
    //=========================================================================
    initial begin
        $display("");
        $display("============================================================");
        $display("  AES128_TOP - One Encryption Test, Hold data_bus");
        $display("============================================================");
        $display("KEY = %h", KEY_NIST);
        $display("PT  = %h", PT_NIST);
        $display("EXP = %h", CT_NIST);
        $display("");

        rst_n        = 1'b0;
        start        = 1'b0;
        new_key      = 1'b0;
        enc_dec      = 1'b0;
        tb_bus_drive = 128'h0;
        tb_bus_oe    = 1'b0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // 1) Send key and keep data_bus driven with key.
        $display("Send key, keep data_bus driven by TB...");
        send_key_hold_bus(KEY_NIST);

        // 2) Wait for expansion.
        $display("Wait key expansion...");
        wait_key_expand_done();
        $display("key_ready = %b", key_ready);

        // 3) Send plaintext and keep data_bus driven with plaintext during rounds.
        $display("Send plaintext, keep data_bus driven by TB during rounds...");
        send_plaintext_hold_bus(PT_NIST);

        // 4) During done, TB releases bus for DUT result and checks ciphertext.
        $display("Wait done and check ciphertext...");
        wait_done_and_check();

        repeat (5) @(posedge clk);
        $display("============================================================");
        $finish;
    end

    //=========================================================================
    // Global timeout
    //=========================================================================
    initial begin
        #20000;
        $display("GLOBAL TIMEOUT!");
        $finish;
    end

endmodule
