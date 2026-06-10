`timescale 1ns / 1ps

module mix_columns (
    input  wire [127:0] state_mc_in,
    output wire [127:0] state_mc_out
);

    // Split state into 16 bytes
    // s1..s4: Column 0 | s5..s8: Column 1 | s9..s12: Column 2 | s13..s16: Column 3
    wire [7:0] s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16;
    wire [7:0] m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16;

    // Unpack as Column-Major (AES Standard)
    // Column 1 (s1,s5,s9,s13) taken from corresponding input bytes
    assign {s1 ,s5 ,s9  ,s13,
            s2 ,s6 ,s10 ,s14,
            s3 ,s7 ,s11 ,s15,
            s4 ,s8 ,s12 ,s16} = state_mc_in;

    //========================================================
    // MixColumns Matrix (GF(2^8))
    // Row 0: 2 3 1 1
    // Row 1: 1 2 3 1
    // Row 2: 1 1 2 3
    // Row 3: 3 1 1 2
    //========================================================
    
    // Calculate Row 0 for all 4 columns (m1, m2, m3, m4)
    assign m1  = mul_by_2(s1)  ^ mul_by_3(s5)  ^ s9         ^ s13;
    assign m2  = mul_by_2(s2)  ^ mul_by_3(s6)  ^ s10        ^ s14;
    assign m3  = mul_by_2(s3)  ^ mul_by_3(s7)  ^ s11        ^ s15;
    assign m4  = mul_by_2(s4)  ^ mul_by_3(s8)  ^ s12        ^ s16;

    // Calculate Row 1 for all 4 columns (m5, m6, m7, m8)
    assign m5  = s1            ^ mul_by_2(s5)  ^ mul_by_3(s9)  ^ s13;
    assign m6  = s2            ^ mul_by_2(s6)  ^ mul_by_3(s10) ^ s14;
    assign m7  = s3            ^ mul_by_2(s7)  ^ mul_by_3(s11) ^ s15;
    assign m8  = s4            ^ mul_by_2(s8)  ^ mul_by_3(s12) ^ s16;

    // Calculate Row 2 for all 4 columns (m9, m10, m11, m12)
    assign m9  = s1            ^ s5            ^ mul_by_2(s9)  ^ mul_by_3(s13);
    assign m10 = s2            ^ s6            ^ mul_by_2(s10) ^ mul_by_3(s14);
    assign m11 = s3            ^ s7            ^ mul_by_2(s11) ^ mul_by_3(s15);
    assign m12 = s4            ^ s8            ^ mul_by_2(s12) ^ mul_by_3(s16);

    // Calculate Row 3 for all 4 columns (m13, m14, m15, m16)
    assign m13 = mul_by_3(s1)  ^ s5            ^ s9            ^ mul_by_2(s13);
    assign m14 = mul_by_3(s2)  ^ s6            ^ s10           ^ mul_by_2(s14);
    assign m15 = mul_by_3(s3)  ^ s7            ^ s11           ^ mul_by_2(s15);
    assign m16 = mul_by_3(s4)  ^ s8            ^ s12           ^ mul_by_2(s16);

    // Pack back into 128-bit vector
    assign state_mc_out = {m1 ,m5 ,m9 ,m13,
                           m2 ,m6 ,m10,m14,
                           m3 ,m7 ,m11,m15,
                           m4 ,m8 ,m12,m16};

    //=============================
    //  GF(2^8) MULTIPLY FUNCTION
    //=============================
    
    // [FIX] xtime function rewritten to be more compact and safer
    // Do not use intermediate reg variable to avoid simulation errors
    function [7:0] xtime;
        input [7:0] b;
        begin
            // Check MSB BEFORE shifting
            if (b[7] == 1'b1) begin
                xtime = (b << 1) ^ 8'h1B;
            end else begin
                xtime = (b << 1);
            end
        end
    endfunction

    // multiply by 2 = xtime
    function [7:0] mul_by_2;
        input [7:0] x;
        begin
            mul_by_2 = xtime(x);
        end
    endfunction

    // multiply by 3 = 2*x ^ x
    function [7:0] mul_by_3;
        input [7:0] x;
        begin
            mul_by_3 = xtime(x) ^ x;
        end
    endfunction

endmodule