`timescale 1ns / 1ps

module aes128_datapath (
    input  wire         clk,
    input  wire         rst_n,

    // Từ AXI
    input  wire         start,
    input  wire         new_key,
    input  wire         enc_dec,

    // Bus chung
    inout  wire [127:0] data_bus,
    output wire [127:0] key_out_fsm,
    output wire [127:0] pt_out_fsm,

    // Status
    output reg          busy,
    output reg          done,
    output reg          key_ready,

    // Key schedule
    output reg          start_expand,
    input  wire         ks_busy,
    input  wire         ks_key_ready,
    output reg  [3:0]   round_idx,

    // Latched mode
    output reg          enc_dec_r,

    // Round control
    output reg          use_initial,
    output reg          final_round,

    // Data
    input  wire [127:0] next_state_in,
    output reg  [127:0] state_out,
    output reg  [127:0] data_out
);

    reg [127:0] bus_out_r;
    reg         bus_oe_r;
    assign data_bus = (bus_oe_r && !start && !new_key) ? bus_out_r : 128'bz;
    
    localparam [1:0] S_IDLE    = 2'd0,
                     S_KEY_EXP = 2'd1,
                     S_ROUNDS  = 2'd2,
                     S_DONE    = 2'd3;

    reg [1:0] state;
    reg [3:0] round_cnt;

    // Enc: round 1→10: K1→K10 | Dec: round 1→10: K9→K0
    function [3:0] calc_idx;
        input       mode;
        input [3:0] cnt;
        calc_idx = mode ? (4'd10 - cnt) : cnt;
    endfunction

    reg [127:0] reg_key_in;
    reg [127:0] reg_pt_in;

    assign key_out_fsm = reg_key_in;
    assign pt_out_fsm  = reg_pt_in;


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            busy         <= 1'b0;
            done         <= 1'b0;
            key_ready    <= 1'b0;
            start_expand <= 1'b0;
            enc_dec_r    <= 1'b0;
            round_idx    <= 4'd0;
            round_cnt    <= 4'd0;
            use_initial  <= 1'b0;
            final_round  <= 1'b0;
            state_out    <= 128'b0;
            data_out     <= 128'b0;
            reg_key_in   <= 128'b0;
            reg_pt_in    <= 128'b0;
            bus_out_r    <= 128'b0;
            bus_oe_r     <= 1'b0;
        end else begin

            if (new_key || start) bus_oe_r <= 1'b0;
            if (new_key) reg_key_in <= data_bus;
            if (start)   reg_pt_in  <= data_bus;

            start_expand <= 1'b0;

            case (state)

            // =============================================================
            // S_IDLE
            //   new_key              / start_expand=1, busy=1, key_ready=0  → S_KEY_EXP
            //   start && key_ready   / latch enc_dec_r, busy=1 → S_ROUNDS
            //   else                 / Λ                       → S_IDLE
            // =============================================================
            S_IDLE: begin
                done <= 1'b0;
                busy <= 1'b0;

                if (new_key) begin
                    start_expand <= 1'b1;
                    key_ready    <= 1'b0;
                    busy         <= 1'b1;
                    state        <= S_KEY_EXP;
                end
                else if (start && key_ready) begin
                    enc_dec_r   <= enc_dec;
                    busy        <= 1'b1;
                    use_initial <= 1'b1;
                    round_idx   <= enc_dec ? 4'd10 : 4'd0;
                    round_cnt   <= 4'd0;
                    state       <= S_ROUNDS;
                end
            end

            // =============================================================
            // S_KEY_EXP
            //   !ks_busy && ks_key_ready / busy=0, key_ready=1 → S_IDLE
            //   else                     / Λ                   → S_KEY_EXP
            // =============================================================
            S_KEY_EXP: begin
                if (!ks_busy && ks_key_ready) begin
                    busy      <= 1'b0;
                    key_ready <= 1'b1;
                    state     <= S_IDLE;
                end
            end

            // =============================================================
            // S_ROUNDS
            //   round_cnt == 0  / latch initial AddRoundKey    → (cnt=1)
            //   round_cnt == 10 / data_out=round_out, done=1   → S_DONE
            //   1 ≤ cnt < 10    / state_out=round_out, cnt++   → S_ROUNDS
            // =============================================================
            S_ROUNDS: begin
                state_out <= next_state_in;

                if (round_cnt == 4'd0) begin
                    // Initial AddRoundKey done (use_initial was set in S_IDLE)
                    use_initial <= 1'b0;
                    round_cnt   <= 4'd1;
                    round_idx   <= calc_idx(enc_dec_r, 4'd1);
                    final_round <= 1'b0;
                end
                else if (round_cnt == 4'd10) begin
                    data_out  <= next_state_in;
                    bus_out_r <= next_state_in; // Drive result to bus
                    bus_oe_r  <= 1'b1;          // Bắt đầu chiếm bus để giữ kết quả
                    busy      <= 1'b0;
                    done      <= 1'b1;
                    state     <= S_DONE;
                end else begin
                    round_cnt   <= round_cnt + 4'd1;
                    round_idx   <= calc_idx(enc_dec_r, round_cnt + 4'd1);
                    final_round <= (round_cnt + 4'd1 == 4'd10);
                end
            end

            // =============================================================
            // S_DONE
            //   always / done=0 → S_IDLE
            // =============================================================
            S_DONE: begin
                done  <= 1'b0;
                state <= S_IDLE;
            end

            default: state <= S_IDLE;

            endcase
        end
    end

endmodule