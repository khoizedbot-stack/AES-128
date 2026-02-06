`timescale 1ns / 1ps


module shift_rows(  
    input wire [127:0] state_sr_in,
    output wire [127:0] state_sr_out
	);
	
	
     wire [7:0] s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16;

	assign {s1,s5,s9 ,s13,
	        s2,s6,s10,s14,
		s3,s7,s11,s15,
		s4,s8,s12,s16}  = state_sr_in;
			
	assign state_sr_out = {s1,s6,s11,s16,
			       s2,s7,s12,s13,
			       s3,s8,s9 ,s14,
			       s4,s5,s10,s15};
//no dich doc 	
	
    
endmodule
