//==============================================================================
// Module: aes128_top
// Description: AES-128 Top Module
//              Kết nối các module
//
// Key insight:
//   - encrypt modules dùng EXPANDED_KEY (không phải current_key)
//   - expanded_key = expand(key_source, rcon) là combinational
//   - key_load=1: bypass key_in → expanded_key = K1 cho Round 1
//   - encrypt_state bypass initial_state khi key_load=1 (Round 1)
//
// Latency: 10 clock cycles
//==============================================================================

`timescale 1ns / 1ps

module aes128_top (
    input  wire         clk,
    input  wire         rst_n,
    
    // Control
    input  wire         start,
    input  wire [127:0] key,
    input  wire [127:0] plaintext,
    
    // Status
    output wire         busy,
    output wire         done,
    
    // Output
    output wire [127:0] ciphertext
);

    //==========================================================================
    // Internal Wires
    //==========================================================================
    
    // Key Gen control (from datapath)
    wire        key_load;
    wire        key_next;
    
    // Key Gen outputs
    wire [127:0] current_key;       // Stored key K[n-1]
    wire [127:0] expanded_key;      // Next key K[n] (for encryption!)
    
    // Initial AddRoundKey (PT XOR K0)
    wire [127:0] initial_state;     // Plaintext XOR Key
    
    // Datapath output
    wire [127:0] state_out;         // State from datapath register
    
    // Bypass mux: Round 1 dùng initial_state (khi key_load=1)
    // Các round khác dùng state_out (registered)
    wire [127:0] encrypt_state = key_load ? initial_state : state_out;
    
    // Encrypt output (combinational) - single encrypt_round handles all rounds
    wire [127:0] round_out;
    wire         final_round;
    
    //==========================================================================
    // Module Instances
    //==========================================================================
    
    //--------------------------------------------------------------------------
    // Initial AddRoundKey: PT XOR K0
    //--------------------------------------------------------------------------
    add_round_key u_initial_xor (
        .round_key      (key),
        .state_ark_in   (plaintext),
        .state_ark_out  (initial_state)
    );
    
    //--------------------------------------------------------------------------
    // Datapath (FSM + state_out register)
    // Now only handles control flow, no computation
    //--------------------------------------------------------------------------
    aes128_datapath u_datapath (
        .clk            (clk),
        .rst_n          (rst_n),
        
        // External control
        .start          (start),
        
        
        // Status
        .busy           (busy),
        .done           (done),
        
        // Key Gen control
        .key_load       (key_load),
        .key_next       (key_next),
        
        // Data from encrypt modules
        .round_out      (round_out),

        // Data outputs
        .final_round    (final_round),
        .state_out      (state_out),
        .ciphertext     (ciphertext)
    );
    
    //--------------------------------------------------------------------------
    // Key Generation (with internal register & rcon)
    // expanded_key = expand(current_key, rcon) [combinational]
    //--------------------------------------------------------------------------
    key_gen u_key_gen (
        .clk            (clk),
        .rst_n          (rst_n),
        
        // Control
        .load           (key_load),
        .next           (key_next),
        
        // Data
        .key_in         (key),
        
        .expanded_key   (expanded_key)
    );
    
    //--------------------------------------------------------------------------
    // Encrypt Round (Rounds 1-10)
    // final_round=1 at Round 10 → MixColumns bypassed
    // expanded_key = K[N] for Round N
    // encrypt_state = initial_state (R1 bypass) or state_out (R2-R10)
    //--------------------------------------------------------------------------
    encrypt_round u_encrypt_round (
        .final_round    (final_round),      // From datapath: 1 at round 10
        .round_key      (expanded_key),     // K[N] for round N
        .enc_state_in   (encrypt_state),    // Bypass mux
        .enc_state_round(round_out)
    );

endmodule