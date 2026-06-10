`timescale 1ns / 1ps

module aes128_top (
    input  wire         clk,
    input  wire         rst_n,

    input  wire         start,
    input  wire         new_key,
    input  wire         enc_dec,     // 0=encrypt, 1=decrypt (latch khi start)

    inout  wire [127:0] data_bus,

    output wire         busy,
    output wire         done,
    output wire         key_ready
);

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------
    wire        start_expand;
    wire [3:0]  round_idx;
    wire        ks_busy;
    wire        ks_key_ready;
    wire [127:0] round_key;

    wire        enc_dec_r;          // latched enc_dec from datapath
    wire        use_initial, final_round;
    wire [127:0] state_out;
    wire [127:0] enc_round_out, dec_round_out;
    wire [127:0] data_out_dp;

    wire [127:0] key_from_fsm;
    wire [127:0] pt_from_fsm;

    // -------------------------------------------------------------------------
    // Key schedule
    // -------------------------------------------------------------------------
    key_schedule u_key_schedule (
        .clk            (clk),
        .rst_n          (rst_n),
        .start_expand   (start_expand),
        .key_in         (key_from_fsm),
        .key_ready      (ks_key_ready),
        .busy           (ks_busy),
        .round_idx      (round_idx),
        .round_key      (round_key)
    );

    // -------------------------------------------------------------------------
    // Initial AddRoundKey
    // -------------------------------------------------------------------------
    wire [127:0] initial_state = pt_from_fsm ^ round_key;

    wire [127:0] round_out = enc_dec_r ? dec_round_out : enc_round_out;
    wire [127:0] next_state_in = use_initial ? initial_state : round_out;

    // -------------------------------------------------------------------------
    // Encrypt round
    // -------------------------------------------------------------------------
    encrypt_round u_enc_round (
        .final_round    (final_round),
        .round_key      (round_key),
        .enc_state_in   (state_out),
        .enc_state_round(enc_round_out)
    );

    // -------------------------------------------------------------------------
    // Decrypt round
    // -------------------------------------------------------------------------
    decrypt_round u_dec_round (
        .final_round    (final_round),
        .round_key      (round_key),
        .dec_state_in   (state_out),
        .dec_state_round(dec_round_out)
    );

    // -------------------------------------------------------------------------
    // Datapath FSM
    // -------------------------------------------------------------------------
    aes128_datapath u_datapath (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .new_key       (new_key),
        .enc_dec       (enc_dec),
        // Bus chung
        .data_bus      (data_bus),
        .key_out_fsm   (key_from_fsm),
        .pt_out_fsm    (pt_from_fsm),
        // Status
        .busy          (busy),
        .done          (done),
        .key_ready     (key_ready),
        // Key schedule control
        .start_expand  (start_expand),
        .ks_busy       (ks_busy),
        .ks_key_ready  (ks_key_ready),
        .round_idx     (round_idx),
        // Latched mode
        .enc_dec_r     (enc_dec_r),
        // Round control
        .use_initial   (use_initial),
        .final_round   (final_round),
        // Data
        .next_state_in (next_state_in),
        .state_out     (state_out),
        .data_out      (data_out_dp)
    );

    // (data_bus is driven directly by u_datapath)

endmodule