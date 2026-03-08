//==============================================================================
// Module: aes128_datapath
// Description: AES-128 Datapath FSM Controller
//              Quản lý FSM và control signals cho key_gen
//              Không thực hiện computation - chỉ điều khiển data flow
//
// TIMING:
//   - key_load, key_next là COMBINATIONAL → tác dụng ngay trong cycle
//   - expanded_key luôn sẵn sàng (combinational)
//   - Round N dùng expanded_key = K[N]
//   - Cycle đầu (IDLE/DONE+start): bypass key_in → K1, encrypt R1 ngay
//
// Latency: 10 clock cycles
//==============================================================================

`timescale 1ns / 1ps

module aes128_datapath (
    input  wire         clk,
    input  wire         rst_n,
    
    //==========================================================================
    // External Control
    //==========================================================================
    input  wire         start,
      // Plaintext XOR Key (computed externally)
    
    //==========================================================================
    // Status Outputs
    //==========================================================================
    output reg          busy,
    output reg          done,
    
    //==========================================================================
    // Key Gen Control (COMBINATIONAL - tác dụng ngay trong cycle)
    //==========================================================================
    output wire         key_load,       // Bypass + Load K1 (IDLE/DONE + start)
    output wire         key_next,       // Advance to next key (ROUNDS, cnt!=10)
    
    //==========================================================================
    // Data from encrypt modules (combinational)
    //==========================================================================
    input  wire [127:0] round_out,      // From encrypt_round (all rounds)

    //==========================================================================
    // Data Outputs
    //==========================================================================
    output wire         final_round,    // To encrypt_round: skip MixColumns
    output reg  [127:0] state_out,      // To encrypt modules
    output reg  [127:0] ciphertext      // Final output
);

    //==========================================================================
    // FSM States
    //==========================================================================
    localparam S_IDLE     = 2'd0;   // Wait for start (done=0)
    localparam S_ROUNDS   = 2'd1;   // Rounds 1-10 (counter: 2-10)
    localparam S_DONE     = 2'd2;   // Done, waiting for next start (done=1)
    
    reg [1:0]  state;
    reg [3:0]  round_cnt;  // Counter: 2-10
    
    //==========================================================================
    // Combinational Control Signals
    // key_load: bypass key_in → K1 và feed initial_state cho encrypt
    // key_next: advance key trong ROUNDS (trừ final round)
    //==========================================================================
    assign key_load    = ((state == S_IDLE) || (state == S_DONE)) && start;
    assign key_next    = (state == S_ROUNDS) && (round_cnt != 4'd10);
    assign final_round = (state == S_ROUNDS) && (round_cnt == 4'd10);
    
    //==========================================================================
    // FSM Logic
    //
    // TIMING (10 cycles):
    //   Cycle 1:  IDLE/DONE+start → key_load=1 (bypass: K1 ready),
    //             encrypt R1 with initial_state+K1 (combinational),
    //             state_out=round_out → ROUNDS cnt=2
    //   Cycles 2-8: ROUNDS → encrypt R2-R8, key_next=1
    //   Cycle 9:  ROUNDS cnt=9 → encrypt R9, key_next=1
    //   Cycle 10: ROUNDS cnt=10 → use final_out, done=1 → DONE
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            busy        <= 1'b0;
            done        <= 1'b0;
            state_out   <= 128'b0;
            ciphertext  <= 128'b0;
            round_cnt   <= 4'd0;
            
        end else begin
            case (state)
                //--------------------------------------------------------------
                // IDLE: Wait for start, execute R1 immediately via bypass
                // key_load=1 (combinational) triggers bypass in key_gen + top
                //--------------------------------------------------------------
                S_IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    
                    if (start) begin
                        busy      <= 1'b1;
                        state_out <= round_out;      // R1 = encrypt(initial_state, K1)
                        round_cnt <= 4'd2;           // Next round is R2
                        state     <= S_ROUNDS;
                    end
                end
                
                //--------------------------------------------------------------
                // ROUNDS (Rounds 2-10): Counter-based loop
                // key_next=1 (combinational) khi cnt!=10
                // R2-R9: use round_out, R10: use final_out
                //--------------------------------------------------------------
                S_ROUNDS: begin
                    if (round_cnt == 4'd10) begin
                        // Final round - output ready (MixColumns bypassed via final_round)
                        ciphertext <= round_out;
                        busy       <= 1'b0;
                        done       <= 1'b1;
                        state      <= S_DONE;
                    end else begin
                        // Normal rounds R2-R9
                        state_out <= round_out;
                        round_cnt <= round_cnt + 4'd1;
                    end
                end
                
                //--------------------------------------------------------------
                // DONE: Persist done=1 cho AXI polling
                // Khi start mới đến, bắt đầu encryption mới ngay (bypass)
                //--------------------------------------------------------------
                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    
                    state <= S_IDLE;
                end
                
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule