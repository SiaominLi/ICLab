module sum_mod(
    input [8:0] card_sum,
    output reg card_valid
);

always@(*)begin
    case(card_sum)
        8'd10, 8'd20, 8'd30, 8'd40, 8'd50, 8'd60, 8'd70, 8'd80,
        8'd90, 8'd100, 8'd110, 8'd120, 8'd130, 8'd140: card_valid = 1'b1;
        default: card_valid = 1'b0;
    endcase
end

endmodule