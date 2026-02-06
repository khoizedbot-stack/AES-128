`timescale 1ns / 1ps


module encrypt_round(    
    input wire [127:0] round_key,
    input wire [127:0] enc_state_in,
    output wire [127:0] enc_state_round
	);
	
	wire [127:0] state_sb_out;
	wire [127:0] state_sr_out;
	wire [127:0] state_mc_out;
	wire [127:0] state_ark_out;
	
		
	
	sub_bytes i_sub_bytes(
		.state_sb_in(enc_state_in),
		.state_sb_out(state_sb_out)
		);
	
	shift_rows i_shift_rows(
		.state_sr_in(state_sb_out),
		.state_sr_out(state_sr_out)
		);
	
	mix_columns i_mix_columns(
		.state_mc_in(state_sr_out),
		.state_mc_out(state_mc_out)
		);
	
	add_round_key i_add_round_key(
		.round_key(round_key),
		.state_ark_in(state_mc_out),
		.state_ark_out(state_ark_out)
		);

    
    assign enc_state_round = state_ark_out;
	
endmodule