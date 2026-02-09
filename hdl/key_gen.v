//==============================================================================
// Module: key_gen
// Description: AES-128 Key Generation Module
//              Mỗi cycle tạo 1 key mới khi next=1
//              Quản lý rcon_index nội bộ để đảm bảo timing chính xác
//
// Operation:
//   - load=1: Bypass key_in → expanded_key = K1 (combinational)
//             Store K1 into current_key, set rcon=2
//   - next=1: current_key <= expanded_key, rcon++
//
// IMPORTANT:
//   - expanded_key luôn = expand(key_source, rcon) [combinational]
//   - key_source = key_in khi load=1 (bypass), = current_key khi bình thường
//   - Dùng expanded_key cho encryption (không phải current_key)
//==============================================================================

`timescale 1ns / 1ps

module key_gen (
    input  wire         clk,
    input  wire         rst_n,
    
    // Control
    input  wire         load,           // Load K0, reset rcon
    input  wire         next,           // Advance to next key
    
    // Data
    input  wire [127:0] key_in,         // Initial key (K0)
    
    // Outputs
         // Stored key K[n-1]
    output wire [127:0] expanded_key    // Next key K[n] = expand(K[n-1], rcon)
);
    reg  [127:0] current_key;
    //==========================================================================
    // Internal rcon register
    //==========================================================================
    reg [3:0] rcon_index;
    
    //==========================================================================
    // Bypass mux: load=1 → expand from key_in (K0), else from current_key
    // Cho phép cycle đầu tiên (IDLE+start) tính K1 combinationally
    //==========================================================================
    wire [127:0] key_source = load ? key_in : current_key;
    
    //==========================================================================
    // Rcon bypass: load=1 → rcon=1 (start from scratch), else current rcon
    //==========================================================================
    wire [3:0] rcon_for_expand = load ? 4'd1 : rcon_index;
    
    //==========================================================================
    // Key Expansion Core (purely combinational)
    // expanded_key = expand(key_source, rcon_for_expand)
    //==========================================================================
    expand_key_core_fix u_expand (
        .key_in         (key_source),
        .rcon_index_in  ({4'b0000, rcon_for_expand}),
        .expanded_key_out(expanded_key)
    );
    
    //==========================================================================
    // Key & Rcon Registers
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_key <= 128'b0;
            rcon_index  <= 4'd1;
        end else if (load) begin
            current_key <= expanded_key; // K1 (bypass: expand(key_in, rcon=1))
            rcon_index  <= 4'd2;         // Ready for K2 next cycle
        end else if (next) begin
            current_key <= expanded_key; // K[n-1] -> K[n]
            rcon_index  <= rcon_index + 4'd1;  // rcon for K[n+1]
        end
    end

endmodule