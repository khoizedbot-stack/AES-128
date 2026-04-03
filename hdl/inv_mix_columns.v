//==============================================================================
// Module: inv_mix_columns
// Description: Inverse MixColumns over GF(2^8) - LUT-BASED OPTIMIZED VERSION
//   Applies Resource Sharing & Decomposition to reduce logic depth and routing.
//==============================================================================
`timescale 1ns / 1ps

module inv_mix_columns (
    input  wire [127:0] state_imc_in,
    output wire [127:0] state_imc_out
);
    wire [7:0] s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16;
    wire [7:0] m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13,m14,m15,m16;

    assign {s1 ,s5 ,s9 ,s13,
            s2 ,s6 ,s10,s14,
            s3 ,s7 ,s11,s15,
            s4 ,s8 ,s12,s16} = state_imc_in;

    // Inverse MixColumns matrix in GF(2^8):
    // [0e 0b 0d 09]
    // [09 0e 0b 0d]
    // [0d 09 0e 0b]
    // [0b 0d 09 0e]
    assign m1  = mul_by_0e(s1)  ^ mul_by_0b(s5)  ^ mul_by_0d(s9)  ^ mul_by_09(s13);
    assign m5  = mul_by_09(s1)  ^ mul_by_0e(s5)  ^ mul_by_0b(s9)  ^ mul_by_0d(s13);
    assign m9  = mul_by_0d(s1)  ^ mul_by_09(s5)  ^ mul_by_0e(s9)  ^ mul_by_0b(s13);
    assign m13 = mul_by_0b(s1)  ^ mul_by_0d(s5)  ^ mul_by_09(s9)  ^ mul_by_0e(s13);

    assign m2  = mul_by_0e(s2)  ^ mul_by_0b(s6)  ^ mul_by_0d(s10) ^ mul_by_09(s14);
    assign m6  = mul_by_09(s2)  ^ mul_by_0e(s6)  ^ mul_by_0b(s10) ^ mul_by_0d(s14);
    assign m10 = mul_by_0d(s2)  ^ mul_by_09(s6)  ^ mul_by_0e(s10) ^ mul_by_0b(s14);
    assign m14 = mul_by_0b(s2)  ^ mul_by_0d(s6)  ^ mul_by_09(s10) ^ mul_by_0e(s14);

    assign m3  = mul_by_0e(s3)  ^ mul_by_0b(s7)  ^ mul_by_0d(s11) ^ mul_by_09(s15);
    assign m7  = mul_by_09(s3)  ^ mul_by_0e(s7)  ^ mul_by_0b(s11) ^ mul_by_0d(s15);
    assign m11 = mul_by_0d(s3)  ^ mul_by_09(s7)  ^ mul_by_0e(s11) ^ mul_by_0b(s15);
    assign m15 = mul_by_0b(s3)  ^ mul_by_0d(s7)  ^ mul_by_09(s11) ^ mul_by_0e(s15);

    assign m4  = mul_by_0e(s4)  ^ mul_by_0b(s8)  ^ mul_by_0d(s12) ^ mul_by_09(s16);
    assign m8  = mul_by_09(s4)  ^ mul_by_0e(s8)  ^ mul_by_0b(s12) ^ mul_by_0d(s16);
    assign m12 = mul_by_0d(s4)  ^ mul_by_09(s8)  ^ mul_by_0e(s12) ^ mul_by_0b(s16);
    assign m16 = mul_by_0b(s4)  ^ mul_by_0d(s8)  ^ mul_by_09(s12) ^ mul_by_0e(s16);

    //==========================================================================
    // OUTPUT PACKING
    //==========================================================================
    assign state_imc_out = {m1 ,m5 ,m9 ,m13,
                            m2 ,m6 ,m10,m14,
                            m3 ,m7 ,m11,m15,
                            m4 ,m8 ,m12,m16};

    // GF(2^8) helper function
    function [7:0] xtime;
        input [7:0] b;
        xtime = b[7] ? (b << 1) ^ 8'h1B : (b << 1);
    endfunction

    function [7:0] mul_by_09;
        input [7:0] x;
        begin
            mul_by_09 = xtime(xtime(xtime(x))) ^ x;
        end
    endfunction

    function [7:0] mul_by_0b;
        input [7:0] x;
        begin
            mul_by_0b = xtime(xtime(xtime(x))) ^ xtime(x) ^ x;
        end
    endfunction

    function [7:0] mul_by_0d;
        input [7:0] x;
        begin
            mul_by_0d = xtime(xtime(xtime(x))) ^ xtime(xtime(x)) ^ x;
        end
    endfunction

    function [7:0] mul_by_0e;
        input [7:0] x;
        begin
            mul_by_0e = xtime(xtime(xtime(x))) ^ xtime(xtime(x)) ^ xtime(x);
        end
    endfunction

endmodule