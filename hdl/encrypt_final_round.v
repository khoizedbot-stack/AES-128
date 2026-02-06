`timescale 1ns / 1ps
module encrypt_final_round(   
    input wire [127:0] round_key,
    input wire [127:0] state_in,
    output wire [127:0] state_round
	);
	wire [127:0] state_sb;
	wire [127:0] state_sr;
	wire [127:0] state_ark;

	
	sub_bytes i_sub_bytes(
		.state_sb_in(state_in),
		.state_sb_out(state_sb)
		);
		
	shift_rows i_shift_rows(
		.state_sr_in(state_sb),
		.state_sr_out(state_sr)
		);
		
	add_round_key i_add_round_key(
		.round_key(round_key),
		.state_ark_in(state_sr),
		.state_ark_out(state_ark)
		);
	
	

    assign state_round = state_ark;
	
endmodule