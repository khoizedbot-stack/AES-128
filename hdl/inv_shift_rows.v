//==============================================================================
// Module: inv_shift_rows
// Description: Inverse ShiftRows — shift each row RIGHT by i positions
//   Row 0: no shift | Row 1: right 1 | Row 2: right 2 | Row 3: right 3
//   Derived by inverting shift_rows.v permutation
//==============================================================================
`timescale 1ns / 1ps

module inv_shift_rows (
    input  wire [127:0] state_isr_in,
    output wire [127:0] state_isr_out
);
    // Unpack column-major (same convention as shift_rows.v)
    wire [7:0] s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16;

    assign {s1,s5,s9 ,s13,
            s2,s6,s10,s14,
            s3,s7,s11,s15,
            s4,s8,s12,s16} = state_isr_in;

    // After InvShiftRows (shift row i right by i):
    //   col0: (s1,s8,s11,s14)  col1: (s2,s5,s12,s15)
    //   col2: (s3,s6, s9,s16)  col3: (s4,s7,s10,s13)
    assign state_isr_out = {s1, s8, s11, s14,
                            s2, s5, s12, s15,
                            s3, s6, s9,  s16,
                            s4, s7, s10, s13};

endmodule
