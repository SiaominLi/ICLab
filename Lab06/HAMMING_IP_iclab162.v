//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2024/10
//		Version		: v1.0
//   	File Name   : HAMMING_IP.v
//   	Module Name : HAMMING_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module HAMMING_IP #(parameter IP_BIT = 8) (
    // Input signals
    IN_code,
    // Output signals
    OUT_code
);

// ===============================================================
// Input & Output
// ===============================================================
input [IP_BIT+4-1:0]  IN_code;

output reg [IP_BIT-1:0] OUT_code;

// ===============================================================
// Design
// ===============================================================
// reg [3:0] parity; 
reg [IP_BIT+4-1:0] result; 
reg [3:0] parity;
reg p1, p2, p4, p8;
reg [0:14] extended_bits;

integer i, j;

always @(*) begin
    
    extended_bits = 15'b0;
    for (i = 0 ; i < 15 ; i = i + 1) begin
        // extended_bits[i] = IN_code[IP_BIT+3-i];
        if( i < (IP_BIT+4) )    extended_bits[i] = IN_code[IP_BIT+3-i];
        else    extended_bits[i] = 1'b0;
    end

    p1 = extended_bits[0] ^ extended_bits[2] ^ extended_bits[4] ^ extended_bits[6] ^ extended_bits[8] ^ extended_bits[10] ^ extended_bits[12] ^ extended_bits[14];
    p2 = extended_bits[1] ^ extended_bits[2] ^ extended_bits[5] ^ extended_bits[6] ^ extended_bits[9] ^ extended_bits[10] ^ extended_bits[13] ^ extended_bits[14];
    p4 = extended_bits[3] ^ extended_bits[4] ^ extended_bits[5] ^ extended_bits[6] ^ extended_bits[11] ^ extended_bits[12] ^ extended_bits[13] ^ extended_bits[14];
    p8 = extended_bits[7] ^ extended_bits[8] ^ extended_bits[9] ^ extended_bits[10] ^ extended_bits[11] ^ extended_bits[12] ^ extended_bits[13] ^ extended_bits[14];

    parity = {p8, p4, p2, p1};
    if (parity != 4'b000) extended_bits[parity-1] = ~extended_bits[parity-1];
    
    OUT_code[IP_BIT-1] = extended_bits[2];
    OUT_code[IP_BIT-2] = extended_bits[4];
    OUT_code[IP_BIT-3] = extended_bits[5];
    OUT_code[IP_BIT-4] = extended_bits[6];
    OUT_code[IP_BIT-5] = extended_bits[8];

    for (j = 6 ; j <= IP_BIT ; j = j + 1) begin
        OUT_code[IP_BIT-j] = extended_bits[j+3];
    end
end

endmodule