//==============================================================================
// Module: aes128_fsm_core
// Description: AES-128 Encryption Core with FSM
//              Modified from original FSM_count.v to add proper status signals
//              
// Latency: 11 clock cycles (1 initial + 9 rounds + 1 final)
// Interface: 
//   - start pulse -> busy high -> done HIGH (latched until next start)
//   - done stays HIGH until next start (not just a pulse!)
//==============================================================================

`timescale 1ns / 1ps

module aes128_fsm_core (
    input  wire         clk,
    input  wire         rst_n,          // Active-low reset (AXI style)
    
    // Control
    input  wire [127:0] key,
    input  wire [127:0] plain_text,
    input  wire         start,          // Start pulse
    
    // Status
    output reg          busy,           // High during processing
    output reg          done,           // HIGH when complete (latched!)
    
    // Output
    output reg  [127:0] cipher_text
);

    //==========================================================================
    // FSM States
    //==========================================================================
    localparam S_IDLE     = 2'b00;
    localparam S_PROGRESS = 2'b01;
    localparam S_FINAL    = 2'b10;
    localparam S_DONE     = 2'b11;
    
    reg [1:0]   state;
    reg [3:0]   round_counter;
    
    //==========================================================================
    // Internal Signals
    //==========================================================================
    reg  [127:0] state_in;
    wire [127:0] state_out;
    wire [127:0] final_out;
    reg  [127:0] state_in_final;
    
    // Round keys
    wire [127:0] round1_key, round2_key, round3_key, round4_key, round5_key;
    wire [127:0] round6_key, round7_key, round8_key, round9_key, round10_key;
    wire [127:0] sel_round_key;
    
    // Round key array for mux
    wire [127:0] round_keys [0:10];
    assign round_keys[0]  = key;
    assign round_keys[1]  = round1_key;
    assign round_keys[2]  = round2_key;
    assign round_keys[3]  = round3_key;
    assign round_keys[4]  = round4_key;
    assign round_keys[5]  = round5_key;
    assign round_keys[6]  = round6_key;
    assign round_keys[7]  = round7_key;
    assign round_keys[8]  = round8_key;
    assign round_keys[9]  = round9_key;
    assign round_keys[10] = round10_key;
    
    assign sel_round_key = round_keys[round_counter];
    
    //==========================================================================
    // Submodule Instances
    //==========================================================================
    
    // Key Expansion
    expand_key_top u_expand_key (
        .key        (key),
        .round1_key (round1_key),
        .round2_key (round2_key),
        .round3_key (round3_key),
        .round4_key (round4_key),
        .round5_key (round5_key),
        .round6_key (round6_key),
        .round7_key (round7_key),
        .round8_key (round8_key),
        .round9_key (round9_key),
        .round10_key(round10_key)
    );
    
    // Standard Round (SubBytes, ShiftRows, MixColumns, AddRoundKey)
    encrypt_round u_encrypt_round (
        .round_key      (sel_round_key),
        .enc_state_in   (state_in),
        .enc_state_round(state_out)
    );
    
    // Final Round (SubBytes, ShiftRows, AddRoundKey - no MixColumns)
    encrypt_final_round u_final_round (
        .round_key  (sel_round_key),
        .state_in   (state_in_final),
        .state_round(final_out)
    );
    
    //==========================================================================
    // FSM - Sequential Logic
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            round_counter  <= 4'd0;
            state_in       <= 128'h0;
            state_in_final <= 128'h0;
            cipher_text    <= 128'h0;
            busy           <= 1'b0;
            done           <= 1'b0;
        end else begin
            case (state)
                //--------------------------------------------------------------
                // IDLE: Wait for start
                //--------------------------------------------------------------
                S_IDLE: begin
                    if (start) begin
                        // Clear done, set busy
                        done          <= 1'b0;
                        busy          <= 1'b1;
                        // Initial AddRoundKey
                        state_in      <= key ^ plain_text;
                        round_counter <= 4'd1;
                        state         <= S_PROGRESS;
                    end
                    // else: keep done latched (don't clear it!)
                end
                
                //--------------------------------------------------------------
                // PROGRESS: Rounds 1-9
                //--------------------------------------------------------------
                S_PROGRESS: begin
                    if (round_counter == 4'd9) begin
                        // Prepare for final round
                        state_in_final <= state_out;
                        round_counter  <= 4'd10;
                        state          <= S_FINAL;
                    end else begin
                        // Continue rounds
                        state_in      <= state_out;
                        round_counter <= round_counter + 4'd1;
                    end
                end
                
                //--------------------------------------------------------------
                // FINAL: Round 10 (no MixColumns)
                //--------------------------------------------------------------
                S_FINAL: begin
                    cipher_text   <= final_out;
                    state         <= S_DONE;
                end
                
                //--------------------------------------------------------------
                // DONE: Set done flag and go back to IDLE
                // done stays HIGH until next start!
                //--------------------------------------------------------------
                S_DONE: begin
                    done          <= 1'b1;   // LATCH - stays high!
                    busy          <= 1'b0;
                    round_counter <= 4'd0;
                    state         <= S_IDLE;
                end
                
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule