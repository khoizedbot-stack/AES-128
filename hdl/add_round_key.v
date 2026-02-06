`timescale 1ns / 1ps


module add_round_key(   
    input wire [127:0] round_key,
    input wire [127:0] state_ark_in,
    output wire [127:0] state_ark_out
	);
	
	assign state_ark_out = round_key ^ state_ark_in;

	
endmodule
