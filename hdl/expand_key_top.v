`timescale 1ns / 1ps

module expand_key_top(  
    input wire [127:0] key,
	
	output wire [127:0] round1_key,
	output wire [127:0] round2_key,
	output wire [127:0] round3_key,
	output wire [127:0] round4_key,
	output wire [127:0] round5_key,
	output wire [127:0] round6_key,
	output wire [127:0] round7_key,	
	output wire [127:0] round8_key,
	output wire [127:0] round9_key,
	output wire [127:0] round10_key   
	);
	//Internal signals		
wire [7:0] rcon_index_1, rcon_index_2, rcon_index_3, rcon_index_4, rcon_index_5, rcon_index_6, rcon_index_7, rcon_index_8, rcon_index_9, rcon_index_10;

wire [127:0] expanded_key_1_out, expanded_key_2_out, expanded_key_3_out, expanded_key_4_out, expanded_key_5_out, expanded_key_6_out, expanded_key_7_out, expanded_key_8_out, expanded_key_9_out, expanded_key_10_out;

wire [127:0] expanded_key_2_in, expanded_key_3_in, expanded_key_4_in, expanded_key_5_in, expanded_key_6_in, expanded_key_7_in, expanded_key_8_in,expanded_key_9_in,expanded_key_10_in; 
	
	
	
   
assign rcon_index_1 = 8'h01;
assign rcon_index_2 = 8'h02;
assign rcon_index_3 = 8'h03;
assign rcon_index_4 = 8'h04;
assign rcon_index_5 = 8'h05;
assign rcon_index_6 = 8'h06;
assign rcon_index_7 = 8'h07;
assign rcon_index_8 = 8'h08;
assign rcon_index_9 = 8'h09;
assign rcon_index_10 = 8'h0a;
	    
	    
//*********************************************************************************************************
    
assign round1_key = expanded_key_1_out;
assign expanded_key_2_in = expanded_key_1_out;

assign round2_key = expanded_key_2_out;
assign expanded_key_3_in = expanded_key_2_out;

assign round3_key = expanded_key_3_out;
assign expanded_key_4_in = expanded_key_3_out;

assign round4_key = expanded_key_4_out;
assign expanded_key_5_in = expanded_key_4_out;

assign round5_key = expanded_key_5_out;
assign expanded_key_6_in = expanded_key_5_out;

assign round6_key = expanded_key_6_out;
assign expanded_key_7_in = expanded_key_6_out;

assign round7_key = expanded_key_7_out;
assign expanded_key_8_in = expanded_key_7_out;

assign round8_key = expanded_key_8_out;
assign expanded_key_9_in = expanded_key_8_out;

assign round9_key = expanded_key_9_out;
assign expanded_key_10_in = expanded_key_9_out;

assign round10_key = expanded_key_10_out;


expand_key_core_fix i_expand_key_core_1(	  
    . key_in(key),
    . rcon_index_in(rcon_index_1),
    . expanded_key_out(expanded_key_1_out));

expand_key_core_fix i_expand_key_core_2(	   
    . key_in(expanded_key_2_in),
    . rcon_index_in(rcon_index_2),
    . expanded_key_out(expanded_key_2_out));

expand_key_core_fix i_expand_key_core_3(	   
    . key_in(expanded_key_3_in),
    . rcon_index_in(rcon_index_3),
    . expanded_key_out(expanded_key_3_out));

expand_key_core_fix i_expand_key_core_4(	   
    . key_in(expanded_key_4_in),
    . rcon_index_in(rcon_index_4),
    . expanded_key_out(expanded_key_4_out));

expand_key_core_fix i_expand_key_core_5(	  
    . key_in(expanded_key_5_in),
    . rcon_index_in(rcon_index_5),
    . expanded_key_out(expanded_key_5_out));

expand_key_core_fix i_expand_key_core_6(	  
    . key_in(expanded_key_6_in),
    . rcon_index_in(rcon_index_6),
    . expanded_key_out(expanded_key_6_out));

expand_key_core_fix i_expand_key_core_7(	  
    . key_in(expanded_key_7_in),
    . rcon_index_in(rcon_index_7),
    . expanded_key_out(expanded_key_7_out));

expand_key_core_fix i_expand_key_core_8(	    
    . key_in(expanded_key_8_in),
    . rcon_index_in(rcon_index_8),
    . expanded_key_out(expanded_key_8_out));

expand_key_core_fix i_expand_key_core_9(	   
    . key_in(expanded_key_9_in),
    . rcon_index_in(rcon_index_9),
    . expanded_key_out(expanded_key_9_out));

expand_key_core_fix i_expand_key_core_10(	  
    . key_in(expanded_key_10_in),
    . rcon_index_in(rcon_index_10),
    . expanded_key_out(expanded_key_10_out));

endmodule