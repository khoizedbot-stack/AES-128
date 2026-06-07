`timescale 1ns/1ps

module tb_aes128_datapath;

    // ============================================================
    // Clock / Reset
    // ============================================================
    reg clk;
    reg rst_n;
    localparam CLK_HALF = 5;

    initial begin
        clk = 1'b0;
    end

    always #CLK_HALF clk = ~clk;

    // ============================================================
    // DUT inputs
    // ============================================================
    reg         start;
    reg         new_key;
    reg         enc_dec;
    reg         ks_busy;
    reg         ks_key_ready;
    reg [127:0] next_state_in;

    // ============================================================
    // DUT outputs
    // ============================================================
    wire [127:0] key_out_fsm;
    wire [127:0] pt_out_fsm;
    wire         busy;
    wire         done;
    wire         key_ready;
    wire         start_expand;
    wire [3:0]   round_idx;
    wire         enc_dec_r;
    wire         use_initial;
    wire         final_round;
    wire [127:0] state_out;
    wire [127:0] data_out;

    // ============================================================
    // Shared tri-state data_bus
    // ============================================================
    wire [127:0] data_bus;
    reg  [127:0] tb_bus_drive;
    reg          tb_bus_oe;

    // TB drives key/plaintext when done=0.
    // When done=1, TB releases bus so DUT can drive result.
    assign data_bus = (tb_bus_oe && !done) ? tb_bus_drive : 128'bz;

    // Waveform helper: hold last valid value
    reg  [127:0] data_bus_last;
    wire [127:0] data_bus_view;
    reg  [127:0] captured_result;

    assign data_bus_view = (data_bus === 128'bz) ? data_bus_last : data_bus;

    // Capture valid bus values.
    // Use nonblocking assignments so TB does not race with DUT at posedge.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_bus_last   <= 128'b0;
            captured_result <= 128'b0;
        end else begin
            if ((data_bus !== 128'bz) && (^data_bus !== 1'bx)) begin
                data_bus_last <= data_bus;
            end

            // This captures the result on the posedge while done was already high
            // for the previous full cycle.
            if (done && (data_bus !== 128'bz) && (^data_bus !== 1'bx)) begin
                captured_result <= data_bus;
                tb_bus_drive    <= data_bus;   // after done falls, TB holds result
                tb_bus_oe       <= 1'b1;
            end
        end
    end

    // ============================================================
    // DUT
    // ============================================================
    aes128_datapath dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .new_key       (new_key),
        .enc_dec       (enc_dec),
        .data_bus      (data_bus),
        .key_out_fsm   (key_out_fsm),
        .pt_out_fsm    (pt_out_fsm),
        .busy          (busy),
        .done          (done),
        .key_ready     (key_ready),
        .start_expand  (start_expand),
        .ks_busy       (ks_busy),
        .ks_key_ready  (ks_key_ready),
        .round_idx     (round_idx),
        .enc_dec_r     (enc_dec_r),
        .use_initial   (use_initial),
        .final_round   (final_round),
        .next_state_in (next_state_in),
        .state_out     (state_out),
        .data_out      (data_out)
    );

    // ============================================================
    // Test vectors
    // ============================================================
    localparam [127:0] KEY_NIST = 128'h000102030405060708090a0b0c0d0e0f;
    localparam [127:0] PT_NIST  = 128'h00112233445566778899aabbccddeeff;
    localparam [127:0] CT_NIST  = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

    // Because this is datapath-only TB, next_state_in is emulated by TB.
    localparam [127:0] R0_INITIAL = 128'h00102030405060708090a0b0c0d0e0f0;
    localparam [127:0] R1         = 128'h89d810e8855ace682d1843d8cb128fe4;
    localparam [127:0] R2         = 128'h4915598f55e5d7a0daca94fa1f0a63f7;
    localparam [127:0] R3         = 128'hfa636a2825b339c940668a3157244d17;
    localparam [127:0] R4         = 128'h247240236966b3fa6ed2753288425b6c;
    localparam [127:0] R5         = 128'hc81677bc9b7ac93b25027992b0261996;
    localparam [127:0] R6         = 128'hc62fe109f75eedc3cc79395d84f9cf5d;
    localparam [127:0] R7         = 128'hd1876c0f79c4300ab45594add66ff41f;
    localparam [127:0] R8         = 128'hfde3bad205e5d0d73547964ef1fe37f1;
    localparam [127:0] R9         = 128'hbd6e7c3df2b5779e0b61216e8b10b689;
    localparam [127:0] R10_FINAL  = CT_NIST;

    integer i;

    // ============================================================
    // Utility: tick at posedge only
    // ============================================================
    task tick;
        begin
            @(posedge clk);
        end
    endtask

    task set_round_value;
        input [3:0] idx;
        begin
            case (idx)
                4'd0:  next_state_in <= R0_INITIAL;
                4'd1:  next_state_in <= R1;
                4'd2:  next_state_in <= R2;
                4'd3:  next_state_in <= R3;
                4'd4:  next_state_in <= R4;
                4'd5:  next_state_in <= R5;
                4'd6:  next_state_in <= R6;
                4'd7:  next_state_in <= R7;
                4'd8:  next_state_in <= R8;
                4'd9:  next_state_in <= R9;
                4'd10: next_state_in <= R10_FINAL;
                default: next_state_in <= 128'b0;
            endcase
        end
    endtask

    // ============================================================
    // Main stimulus
    // Important rule:
    //   All TB signal changes at posedge use <= nonblocking assignment.
    //   No #1 is needed.
    // ============================================================
    initial begin
        $display("");
        $display("============================================================");
        $display(" AES128_DATAPATH TB - POSEDGE ONLY, NO #1, NO X BUS");
        $display("============================================================");
        $display("");

        // Initial values at time 0 are okay with blocking assignment
        rst_n           = 1'b0;
        start           = 1'b0;
        new_key         = 1'b0;
        enc_dec         = 1'b0;
        ks_busy         = 1'b0;
        ks_key_ready    = 1'b0;
        next_state_in   = 128'b0;
        tb_bus_drive    = 128'b0;
        tb_bus_oe       = 1'b0;
        captured_result = 128'b0;

        // Reset
        repeat (4) tick;
        rst_n <= 1'b1;
        repeat (2) tick;

        // ========================================================
        // 1. Send key
        // These assignments happen after this posedge, so DUT sees them
        // at the next posedge.
        // ========================================================
        $display("[1] Send key");
        tb_bus_drive <= KEY_NIST;
        tb_bus_oe    <= 1'b1;
        new_key      <= 1'b1;

        tick;
        new_key      <= 1'b0;

        // ========================================================
        // 2. Emulate key expansion
        // ========================================================
        $display("[2] Emulate key expansion");

        // Give datapath one clock to enter S_KEY_EXP / assert start_expand
        tick;

        ks_busy      <= 1'b1;
        ks_key_ready <= 1'b0;

        for (i = 0; i < 10; i = i + 1) begin
            tick;
        end

        ks_busy      <= 1'b0;
        ks_key_ready <= 1'b1;

        // Because ks_key_ready is assigned with NBA, datapath sees it next clock
        tick;
        tick;

        // ========================================================
        // 3. Send plaintext
        // ========================================================
        $display("[3] Send plaintext");
        tb_bus_drive <= PT_NIST;
        tb_bus_oe    <= 1'b1;
        enc_dec      <= 1'b0;
        start        <= 1'b1;

        tick;

        // At this posedge, DUT sampled start=1 and plaintext.
        // Now prepare initial next_state_in for the first S_ROUNDS cycle.
        start        <= 1'b0;
        set_round_value(4'd0);

        // ========================================================
        // 4. Feed next_state_in for each round
        // Values are set one posedge before DUT needs them.
        // ========================================================
        $display("[4] Feed round values");
        for (i = 1; i <= 10; i = i + 1) begin
            tick;
            set_round_value(i[3:0]);
        end

        // Wait for done pulse and result capture.
        // The always block captures on the clock where done was already high.
        while (done == 1'b0) begin
            tick;
        end

        // done is high now. Tick once more so capture always block samples data_bus.
        tick;

        // After this clock, DUT leaves done; TB now holds captured result.
        tick;

        $display("[5] Captured result = %h", captured_result);
        $display("[5] Expected result = %h", CT_NIST);

        repeat (5) tick;

        $display("");
        $display("============================================================");
        $display(" DONE");
        $display("============================================================");
        $display("");

        $finish;
    end

    initial begin
        #3000;
        $display("GLOBAL TIMEOUT");
        $finish;
    end

endmodule
