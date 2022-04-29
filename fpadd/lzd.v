// V. G. Oklobdzija, "Algorithmic design of a hierarchical and modular
//   leading zero detector circuit," in Electronics Letters, vol. 29,
//   no. 3, pp. 283-284, 4 Feb. 1993, doi: 10.1049/el:19930193.
      
module lz2 (P, V, B0, B1);

   input B0;
   input B1;

   output P;
   output V;

   assign V = B0 | B1;
   assign P = B0 & ~B1;
   
endmodule // lz2

// Note: This module is not made out of two lz2's - why not? (MJS)

module lz4 (ZP, ZV, B0, B1, V0, V1);
   
   input B0;
   input B1;
   input V0;
   input V1;

   output [1:0] ZP;
   output 	ZV;

   assign ZP[0] = V0 ? B0 : B1;
   assign ZP[1] = ~V0;
   assign ZV = V0 | V1;

endmodule // lz4

// Note: This module is not made out of two lz4's - why not? (MJS)

module lz8 (ZP, ZV, B);
   
   input [7:0] B;

   wire        s1p0;
   wire        s1v0;
   wire        s1p1;
   wire        s1v1;
   wire        s2p0;
   wire        s2v0;
   wire        s2p1;
   wire        s2v1;
   wire [1:0]  ZPa;
   wire [1:0]  ZPb;
   wire        ZVa;
   wire        ZVb;
   
   output [2:0] ZP;
   output       ZV;
   
   lz2 l1(s1p0, s1v0, B[2], B[3]);
   lz2 l2(s1p1, s1v1, B[0], B[1]);
   lz4 l3(ZPa, ZVa, s1p0, s1p1, s1v0, s1v1);

   lz2 l4(s2p0, s2v0, B[6], B[7]);
   lz2 l5(s2p1, s2v1, B[4], B[5]);
   lz4 l6(ZPb, ZVb, s2p0, s2p1, s2v0, s2v1);

   assign ZP[1:0] = ZVb ? ZPb : ZPa;
   assign ZP[2]   = ~ZVb;
   assign ZV = ZVa | ZVb;

endmodule // lz8

module lz16 (ZP, ZV, B);

   input [15:0] B;

   wire [2:0] 	ZPa;
   wire [2:0] 	ZPb;
   wire 	ZVa;
   wire 	ZVb;   

   output [3:0] ZP;
   output 	ZV;

   lz8 l1(ZPa, ZVa, B[7:0]);
   lz8 l2(ZPb, ZVb, B[15:8]);

   assign ZP[2:0] = ZVb ? ZPb : ZPa;
   assign ZP[3]   = ~ZVb;
   assign ZV = ZVa | ZVb;

endmodule // lz16

module lz32 (ZP, ZV, B);

   input [31:0] B;

   wire [3:0] 	ZPa;
   wire [3:0] 	ZPb;
   wire 	ZVa;
   wire 	ZVb;

   output [4:0] ZP;
   output 	ZV;

   lz16 l1(ZPa, ZVa, B[15:0]);
   lz16 l2(ZPb, ZVb, B[31:16]);

   assign ZP[3:0] = ZVb ? ZPb : ZPa;
   assign ZP[4]   = ~ZVb;
   assign ZV = ZVa | ZVb;

endmodule // lz32

// This module returns the number of leading zeros ZP in the 64-bit 
// number B. If there are no ones in B, then ZP and ZV are both 0.

module lz64 (ZP, ZV, B);

   input [63:0] B;

   wire [4:0] 	ZPa;
   wire [4:0] 	ZPb;
   wire 	ZVa;
   wire 	ZVb;   

   output [5:0] ZP;
   output 	ZV;

   lz32 l1(ZPa, ZVa, B[31:0]);
   lz32 l2(ZPb, ZVb, B[63:32]);

   assign ZV = ZVa | ZVb;
   assign ZP[4:0] = (ZVb ? ZPb : ZPa) & {5{ZV}};
   assign ZP[5]   = ~ZVb & ZV;

endmodule // lz64

