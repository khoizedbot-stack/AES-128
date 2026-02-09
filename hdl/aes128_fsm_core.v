//==============================================================================
// Module: aes128_fsm_core
// Description: AES-128 Encryption Core with FSM
//              
// OPTIMIZATION: On-the-fly Key Generation
//   - Trước: expand_key_top tạo 10 round keys cùng lúc (10 instances)
//   - Sau:   Chỉ 1 expand_key_core_fix, cập nhật key mỗi cycle
//   - Lợi ích: Giảm ~90% area của key expansion logic
//
// Latency: 13 clock cycles (1 init + 1 initial + 9 rounds + 1 final + 1 done)
//
// FIX: Added S_INIT state to ensure current_key is stable before key expansion
//      This fixes the bug where consecutive encryptions with same/different key
//      would produce incorrect results due to current_key not being stable
//      when expand_key_core_fix reads it.
//
// Key Timing:
//   IDLE:     Load current_key = key[0]
//   INIT:     current_key stable, compute state_in = key ^ plaintext
//   Round 1:  next_key = expand(key[0]) = key[1], dùng cho encrypt
//   Round 2:  next_key = expand(key[1]) = key[2]
//   ...
//   Round 10: next_key = expand(key[9]) = key[10]
//==============================================================================

`timescale 1ns / 1ps

module aes128_fsm_core (
    input  wire         clk,
    input  wire         rst_n,          // Active-low reset
    
    // Control
    input  wire [127:0] key,
    input  wire [127:0] plain_text,
    input  wire         start,
    
    // Status
    output reg          busy,
    output reg          done,
    
    // Output
    output reg  [127:0] cipher_text
);

    //==========================================================================
    // FSM States
    //==========================================================================
    localparam S_IDLE     = 3'b000;
    localparam S_INIT     = 3'b001;  // NEW: Initialization state
    localparam S_PROGRESS = 3'b010;
    localparam S_FINAL    = 3'b011;
    localparam S_DONE     = 3'b100;
    
    reg [2:0]   state;
    reg [3:0]   round_counter;
    
    //==========================================================================
    // Internal Signals
    //==========================================================================
    reg  [127:0] state_in;          // Current encryption state
    wire [127:0] state_out;         // Output of normal round
    wire [127:0] final_out;         // Output of final round
    reg  [127:0] state_in_final;
    
    //==========================================================================
    // ON-THE-FLY KEY GENERATION
    // current_key lưu key[n-1], next_key tính key[n] cho round n
    //==========================================================================
    reg  [127:0] current_key;       // Key đã lưu từ cycle trước
    wire [127:0] next_key;          // Key tính được (combinational)
    
    //==========================================================================
    // Submodule Instances
    //==========================================================================
    
    // CHỈ 1 KEY EXPANSION MODULE (thay vì 10!)
    // Tính next_key = expand(current_key) với rcon tương ứng
    expand_key_core_fix u_key_expand (
        .key_in         (current_key),
        .rcon_index_in  ({4'b0000, round_counter}),
        .expanded_key_out(next_key)
    );
    
    // Standard Round - DÙNG next_key (key đã expand cho round hiện tại)
    encrypt_round u_encrypt_round (
        .round_key      (next_key),      // ← QUAN TRỌNG: dùng next_key!
        .enc_state_in   (state_in),
        .enc_state_round(state_out)
    );
    
    // Final Round - DÙNG next_key
    encrypt_final_round u_final_round (
        .round_key  (next_key),          // ← QUAN TRỌNG: dùng next_key!
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
            current_key    <= 128'h0;
            busy           <= 1'b0;
            done           <= 1'b0;
        end else begin
            case (state)
                //--------------------------------------------------------------
                // IDLE: Wait for start
                //--------------------------------------------------------------
                S_IDLE: begin
                    if (start) begin
                        done          <= 1'b0;
                        busy          <= 1'b1;
                        
                        // Load key[0] vào current_key TRƯỚC
                        // Cycle sau mới bắt đầu encrypt để key expand có giá trị đúng
                        current_key   <= key;
                        round_counter <= 4'd0;
                        state         <= S_INIT;
                    end
                end
                
                //--------------------------------------------------------------
                // INIT: Key loaded, now start encryption
                // current_key = key[0] (đã stable)
                // next_key = expand(key[0]) = key[1] sẽ sẵn sàng
                //--------------------------------------------------------------
                S_INIT: begin
                    // Initial AddRoundKey: plaintext XOR key[0]
                    state_in      <= current_key ^ plain_text;
                    round_counter <= 4'd1;
                    state         <= S_PROGRESS;
                end
                
                //--------------------------------------------------------------
                // PROGRESS: Rounds 1-9
                // 
                // Timing mỗi cycle (ví dụ round_counter = 1):
                //   - current_key = key[0] (từ register)
                //   - next_key = expand(key[0]) = key[1] (combinational)
                //   - encrypt_round dùng next_key = key[1] ← ĐÚNG!
                //   - Cuối cycle: current_key <= next_key = key[1]
                //--------------------------------------------------------------
                S_PROGRESS: begin
                    // Update current_key cho round tiếp theo
                    current_key <= next_key;
                    
                    if (round_counter == 4'd9) begin
                        // Round 9 xong, chuẩn bị final round
                        state_in_final <= state_out;
                        round_counter  <= 4'd10;
                        state          <= S_FINAL;
                    end else begin
                        // Continue normal rounds
                        state_in      <= state_out;
                        round_counter <= round_counter + 4'd1;
                    end
                end
                
                //--------------------------------------------------------------
                // FINAL: Round 10 (no MixColumns)
                // current_key = key[9] (từ round 9)
                // next_key = expand(key[9]) = key[10] ← dùng cho final round
                //--------------------------------------------------------------
                S_FINAL: begin
                    cipher_text   <= final_out;
                    state         <= S_DONE;
                end
                
                //--------------------------------------------------------------
                // DONE: Set done flag
                //--------------------------------------------------------------
                S_DONE: begin
                    done          <= 1'b1;
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