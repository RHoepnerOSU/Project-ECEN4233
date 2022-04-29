//
// File name : fpadd
// Title     : Floating-Point Adder/Subtractor
// project   : FPU
// Library   : fpadd
// Author(s) : James E. Stine, Jr.
// Purpose   : definition of main unit to floating-point add/sub
// notes :   
//
// Copyright Oklahoma State University
//
// Basic Operations
//
// Step 1: Load operands, set flags, and convert SP to DP
// Step 2: Check for special inputs ( +/- Infinity,  NaN)
// Step 3: Compare exponents.  Swap the operands of exp1 < exp2
//         or of (exp1 = exp2 AND mnt1 < mnt2)
// Step 4: Shift the mantissa corresponding to the smaller exponent, 
//          and extend precision by three bits to the right.
// Step 5: Add or subtract the mantissas.
// Step 6: Normalize the result.//
//   Shift left until normalized.  Normalized when the value to the 
//   left of the binrary point is 1.
// Step 7: Round the result.// 
// Step 8: Put sum onto output.
//


module fpadd (AS_Result, Flags, Denorm, op1, op2, rm, op_type, P, OvEn, UnEn);

   input [63:0] op1;		// 1st input operand (A)
   input [63:0] op2;		// 2nd input operand (B)
   input [2:0] 	rm;		// Rounding mode - specify values 
   input [2:0]	op_type;	// Function opcode
   input 	P;   		// Result Precision (0 for double, 1 for single)
   input 	OvEn;		// Overflow trap enabled
   input 	UnEn;   	// Underflow trap enabled

   output [63:0] AS_Result;	// Result of operation
   output [4:0]  Flags;   	// IEEE exception flags 
   output 	 Denorm;   	// Denorm on input or output   

   wire [63:0] 	 Float1; 
   wire [63:0] 	 Float2;
   wire [63:0] 	 IntValue;
   wire [11:0] 	 exp1, exp2;
   wire [11:0] 	 exp_diff1, exp_diff2;
   wire [10:0] 	 exponent, exp_pre;
   wire [11:0] 	 exp_shift;
   wire [63:0] 	 Result;   
   wire [51:0] 	 mantissaA;
   wire [56:0] 	 mantissaA1;
   wire [63:0] 	 mantissaA3;
   wire [51:0] 	 mantissaB; 
   wire [56:0] 	 mantissaB1, mantissaB2;
   wire [63:0] 	 mantissaB3;
   wire [63:0] 	 sum, sum_tc, sum_corr, sum_norm;
   wire [5:0] 	 align_shift;
   wire [5:0] 	 norm_shift;
   wire [3:0] 	 sel_inv;
   wire		 op1_Norm, op2_Norm;
   wire		 opA_Norm, opB_Norm;
   wire		 Invalid;
   wire 	 DenormIn, DenormIO;
   wire [4:0] 	 FlagsIn;   	
   wire 	 exp_valid;
   wire 	 exp_gt63;
   wire 	 Sticky_out;
   wire 	 signA, sign_corr;
   wire          corr_sign;
   wire 	 zeroB;         
   wire 	 convert;
   wire          swap;
   wire          sub;

   // Convert the input operands to their appropriate forms based on 
   // the orignal operands, the op_type , and their precision P. 
   // Single precision inputs are converted to double precision 
   // and the sign of the first operand is set appropratiately based on
   // if the operation is absolute value or negation. 

   convert_inputs conv1 (Float1, Float2, op1, op2, op_type, P);

   // Test for exceptions and return the "Invalid Operation" and
   // "Denormalized" Input Flags. The "sel_inv" is used in
   // the third pipeline stage to select the result. Also, op1_Norm
   // and op2_Norm are one if op1 and op2 are not zero or denormalized.
   // sub is one if the effective operation is subtaction. 

   exception exc1 (sel_inv, Invalid, DenormIn, op1_Norm, op2_Norm, sub, 
		   Float1, Float2, op_type);

   // Perform Exponent Subtraction (used for alignment). For performance
   // both exponent subtractions are performed in parallel. This was 
   // changed to a behavior level to allow the tools to  try to optimize
   // the two parallel additions. The input values are zero-extended to 12 
   // bits prior to performing the addition. 

   assign exp1 = {1'b0, Float1[62:52]};
   assign exp2 = {1'b0, Float2[62:52]};
   assign exp_diff1 = exp1 - exp2;
   assign exp_diff2 = exp2 - exp1;

   // The second operand (B) should be set to zero, if op_type does not
   // specify addition or subtraction
   assign zeroB = op_type[2] | op_type[1];

   // Swapped operands if zeroB is not one and exp1 < exp2. 
   // Swapping causes exp2 to be used for the result exponent. 
   // Only the exponent of the larger operand is used to determine
   // the final result. 
   assign swap = exp_diff1[11] & ~zeroB;
   assign exponent = swap ? exp2[10:0] : exp1[10:0];
   assign mantissaA = swap ? Float2[51:0] : Float1[51:0];
   assign mantissaB = swap ? Float1[51:0] : Float2[51:0];
   assign signA     = swap ? Float2[63] : Float1[63];   

   // Determine the alignment shift and limit it to 63. If any bit from 
   // exp_shift[6] to exp_shift[11] is one, then shift is set to all ones. 
   assign exp_shift = swap ? exp_diff2 : exp_diff1;
   assign exp_gt63 = exp_shift[11] | exp_shift[10] | exp_shift[9] 
     | exp_shift[8] | exp_shift[7] | exp_shift[6];
   assign align_shift = exp_shift | {6{exp_gt63}};

   // Unpack the 52-bit mantissas to 57-bit numbers of the form.
   //    001.M[51]M[50] ... M[1]M[0]00
   // Unless the number has an exponent of zero, in which case it
   // is unpacked as
   //    000.00 ... 00
   // This effectively flushes denormalized values to zero. 
   // The three bits of to the left of the binary point prevent overflow
   // and loss of sign information. The two bits to the right of the 
   // original mantissa form the "guard" and "round" bits that are used
   // to round the result. 
   assign opA_Norm = swap ? op2_Norm : op1_Norm;
   assign opB_Norm = swap ? op1_Norm : op2_Norm;
   assign mantissaA1 = {2'h0, opA_Norm, mantissaA[51:0]&{52{opA_Norm}}, 2'h0};
   assign mantissaB1 = {2'h0, opB_Norm, mantissaB[51:0]&{52{opB_Norm}}, 2'h0};

   // Perform mantissa alignment using a 57-bit barrel shifter 
   // If any of the bits shifted out are one, Sticky_out is set. 
   // The size of the barrel shifter could be reduced by two bits
   // by not adding the leading two zeros until after the shift. 
   barrel_shifter_r57 bs1 (mantissaB2, Sticky_out, mantissaB1, align_shift);

   // Place either the sign-extened 32-bit value or the original 64-bit value 
   // into IntValue (to be used for integer to floating point conversion)
   assign IntValue [31:0] = op1[31:0];
   assign IntValue [63:32] = op_type[0] ? {32{op1[31]}} : op1[63:32];

   // If doing an integer to floating point conversion, mantissaA3 is set to 
   // IntVal and the prenomalized exponent is set to 1084. Otherwise, 
   // mantissaA3 is simply extended to 64-bits by setting the 7 LSBs to zero, 
   // and the exponent value is left unchanged. 
   assign convert       = ~op_type[2] & op_type[1];
   assign mantissaA3    = convert ? IntValue : {mantissaA1, 7'h0};
   assign exp_pre       = convert ? 11'b10000111100 : exponent;

   // Put zero in for mantissaB3, if zeroB is one. Otherwise, B is extended to 
   // 64-bits by setting the 7 LSBs to the Sticky_out bit followed by six  
   // zeros. 
   assign mantissaB3[63:7] = mantissaB2 & {57{~zeroB}};
   assign mantissaB3[6]    = Sticky_out & ~zeroB;
   assign mantissaB3[5:0]  = 6'h0;

   // The sign of the result needs to be corrected if the true
   // operation is subtraction and the input operands were swapped. 
   assign corr_sign = ~op_type[2]&~op_type[1]&op_type[0]&swap;
   
   // 64-bit Mantissa Adder/Subtractor
   assign sum = sub ? mantissaA3 - mantissaB3 : mantissaA3 + mantissaB3;   

   // 64-bit Mantissa Subtractor - to get the two's complement of the 
   // result when the sign from the adder/subtractor is negative.
   assign sum_tc = mantissaB3 - mantissaA3;   

   // Determine the correct sign of the result
   assign sign_corr = ((corr_sign ^ signA) & ~convert) ^ sum[63];   
   
   // If the sum is negative, use its two complement instead. 
   // This value has to be 64-bits to correctly handle the 
   // case 10...00
   assign sum_corr = sum[63] ? sum_tc : sum;

   // Leading-Zero Detector. Determine the size of the shift needed for
   // normalization. If sum_corrected is all zeros, the exp_valid is 
   // zero; otherwise, it is one. 
   lz64 lzd1 (norm_shift, exp_valid, sum_corr);

   // Barell shifter used for normalization. It takes as inputs the 
   // the corrected sum and the amount by which the sum should 
   // be right shifted. It outputs the normalized sum. 
   barrel_shifter_l64 bs2 (sum_norm, sum_corr, norm_shift);
   
   // Round the mantissa to a 52-bit value, with the leading one
   // removed. If the result is a single precision number, the actual 
   // mantissa is in the upper 23 bits and the lower 29 bits are zero. 
   // At this point, normalization has already been performed, so we know 
   // exactly where the rounding point is. The rounding units also
   // handles special cases and set the exception flags.

   // Changed DenormIO -> Denorm and FlagsIn -> Flags in order to
   // help in processor reservation station detection of load/stores. In
   // other words, the processor would like to know ahead of time that
   // if the result is an exception then don't load or store.
   rounder round1 (Result, DenormIO, FlagsIn, rm, P, OvEn, UnEn, exp_valid, 
		   sel_inv, Invalid, DenormIn, convert, sign_corr, exp_pre, 
		   norm_shift, sum_norm);

   // Store the final result and the exception flags in registers.
   assign AS_Result = Result;
   assign {Denorm, Flags} = {DenormIO, FlagsIn};
   
endmodule // fpadd


