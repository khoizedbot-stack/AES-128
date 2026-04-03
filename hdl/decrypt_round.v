`timescale 1ns / 1ps

module decrypt_round (
    input  wire         final_round,     // 1 = skip InvMixColumns
    input  wire [127:0] round_key,
    input  wire [127:0] dec_state_in,
    output wire [127:0] dec_state_round
);
    wire [127:0] isr_out, isb_out, ark_out, imc_out;

    inv_shift_rows  i_isr (.state_isr_in (dec_state_in), .state_isr_out (isr_out));
    inv_sub_bytes   i_isb (.state_isb_in (isr_out),      .state_isb_out (isb_out));
    add_round_key   i_ark (.round_key    (round_key),
                           .state_ark_in (isb_out),      .state_ark_out (ark_out));
    inv_mix_columns i_imc (.state_imc_in (ark_out),      .state_imc_out (imc_out));

    assign dec_state_round = final_round ? ark_out : imc_out;

endmodule
