module mul_card_num(
    input [3:0] card_num,
    output reg [3:0] card_num_cut
);

always@(*)begin
    case(card_num)
        4'b0000 :card_num_cut = 4'b0000;    //0 -> 0
        4'b0001 :card_num_cut = 4'b0010;    //1 -> 2
        4'b0010 :card_num_cut = 4'b0100;    //2 -> 4
        4'b0011 :card_num_cut = 4'b0110;    //3 -> 6
        4'b0100 :card_num_cut = 4'b1000;    //4 -> 8
        4'b0101 :card_num_cut = 4'b0001;    //5 -> 1+0 = 1
        4'b0110 :card_num_cut = 4'b0011;    //6 -> 1+2 = 3
        4'b0111 :card_num_cut = 4'b0101;    //7 -> 1+4 = 5
        4'b1000 :card_num_cut = 4'b0111;    //8 -> 1+6 = 7
        4'b1001 :card_num_cut = 4'b1001;    //9 -> 1+8 = 9
        default: card_num_cut = 4'b0000;
    endcase
end

endmodule