//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2024 Fall
//   Lab01 Exercise     : Snack Shopping Calculator
//   Author             : Hsiao-Min Li
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : SSC.v
//   Module Name : SSC
//   Release version : V1.0 (Release Date: 2024-09)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

// `include "mul_card_num.v" //using for loop is better
// `include "sorting.v"
`include "sort.v" //The sorting.v is better
// `include "sum_mod.v" // using % is better

module SSC(
    // Input signals
    card_num,
    input_money,
    snack_num,
    price, 
    // Output signals
    out_valid,
    out_change
);

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input [63:0] card_num;
input [8:0] input_money;
input [31:0] snack_num;
input [31:0] price;
output out_valid;
output [8:0] out_change;    

//================================================================
//    Wire & Registers 
//================================================================
// wire [3:0] card_num_1, card_num_2, card_num_3, card_num_4;
// wire [3:0] card_num_5, card_num_6, card_num_7, card_num_8;
// wire [3:0] card_num_9, card_num_10, card_num_11, card_num_12;
// wire [3:0] card_num_13, card_num_14, card_num_15, card_num_16;
reg [3:0] card_num_ [1:16]; 
reg [3:0] card_num_cut [1:16]; 
integer i, j, k, z;
wire [8:0] sum;
reg card_valid;

// reg [3:0] snack_num_cut [0:7]; 
// reg [3:0] price_cut [0:7]; 
reg [7:0] total [0:7]; 
reg [7:0] sorted_item [0:7]; 
// wire [3:0] sorted_0, sorted_1, sorted_2, sorted_3;
// wire [3:0] sorted_4, sorted_5, sorted_6, sorted_7;
// reg [11:0] budget;
// wire judge1, judge2, judge3, judge4, judge5, judge6, judge7, judge8;
wire [10:0] top1, top2, top3, top4, top5, top6, top7, top8;
reg [8:0] remain_money;
wire signed [10:0] remain_money0, remain_money1, remain_money2, remain_money3, remain_money4, remain_money5, remain_money6, remain_money7;

//================================================================
//    DESIGN
//================================================================

// Check card valid or not
assign card_num_[1] = card_num[3:0];
assign card_num_[2] = card_num[7:4];
assign card_num_[3] = card_num[11:8];
assign card_num_[4] = card_num[15:12];
assign card_num_[5] = card_num[19:16];
assign card_num_[6] = card_num[23:20];
assign card_num_[7]= card_num[27:24];
assign card_num_[8] = card_num[31:28];
assign card_num_[9] = card_num[35:32];
assign card_num_[10] = card_num[39:36];
assign card_num_[11] = card_num[43:40];
assign card_num_[12] = card_num[47:44];
assign card_num_[13] = card_num[51:48];
assign card_num_[14] = card_num[55:52];
assign card_num_[15] = card_num[59:56];
assign card_num_[16] = card_num[63:60];


// mul_card_num m0(.card_num(card_num_[2]), .card_num_cut(card_num_cut[2]));
// mul_card_num m1(.card_num(card_num_[4]), .card_num_cut(card_num_cut[4]));
// mul_card_num m2(.card_num(card_num_[6]), .card_num_cut(card_num_cut[6]));
// mul_card_num m3(.card_num(card_num_[8]), .card_num_cut(card_num_cut[8]));
// mul_card_num m4(.card_num(card_num_[10]), .card_num_cut(card_num_cut[10]));
// mul_card_num m5(.card_num(card_num_[12]), .card_num_cut(card_num_cut[12]));
// mul_card_num m6(.card_num(card_num_[14]), .card_num_cut(card_num_cut[14]));
// mul_card_num m7(.card_num(card_num_[16]), .card_num_cut(card_num_cut[16]));

always @(*) begin
    for (z = 2; z <= 16; z = z + 2) begin
        if( card_num_[z] < 5 ) 
            card_num_cut[z] = card_num_[z] << 1;
        else begin
            card_num_cut[z] = (card_num_[z] << 1) - 9;
        end
    end
end
// always @(*) begin
//     card_num_cut[2]  = (card_num_[2] < 5) ? (card_num_[2] << 1) : ((card_num_[2] << 1) - 9);
//     card_num_cut[4]  = (card_num_[4] < 5) ? (card_num_[4] << 1) : ((card_num_[4] << 1) - 9);
//     card_num_cut[6]  = (card_num_[6] < 5) ? (card_num_[6] << 1) : ((card_num_[6] << 1) - 9);
//     card_num_cut[8]  = (card_num_[8] < 5) ? (card_num_[8] << 1) : ((card_num_[8] << 1) - 9);
//     card_num_cut[10] = (card_num_[10] < 5) ? (card_num_[10] << 1) : ((card_num_[10] << 1) - 9);
//     card_num_cut[12] = (card_num_[12] < 5) ? (card_num_[12] << 1) : ((card_num_[12] << 1) - 9);
//     card_num_cut[14] = (card_num_[14] < 5) ? (card_num_[14] << 1) : ((card_num_[14] << 1) - 9);
//     card_num_cut[16] = (card_num_[16] < 5) ? (card_num_[16] << 1) : ((card_num_[16] << 1) - 9);
// end

// reg [4:0] add_temp1, add_temp2, add_temp3, add_temp4, add_temp5, add_temp6, add_temp7, add_temp8;
// reg [5:0] add_temp2_1, add_temp2_2, add_temp2_3, add_temp2_4;
// reg [6:0] add_temp3_1, add_temp3_2;

// always @(*) begin
//     add_temp1 = card_num_cut[2] + card_num_[1];
//     add_temp2 = card_num_cut[4] + card_num_[3];
//     add_temp3 = card_num_cut[6] + card_num_[5];
//     add_temp4 = card_num_cut[8] + card_num_[7];
//     add_temp5 = card_num_cut[10] + card_num_[9];
//     add_temp6 = card_num_cut[12] + card_num_[11];
//     add_temp7 = card_num_cut[14] + card_num_[13];
//     add_temp8 = card_num_cut[16] + card_num_[15];
// end
// always @(*) begin
//     add_temp2_1 = add_temp1 + add_temp2;
//     add_temp2_2 = add_temp3 + add_temp4;
//     add_temp2_3 = add_temp5 + add_temp6;
//     add_temp2_4 = add_temp7 + add_temp8;
// end
// always @(*) begin
//     add_temp3_1 = add_temp2_1 + add_temp2_2;
//     add_temp3_2 = add_temp2_3 + add_temp2_4;
// end
// always @(*) begin
//     sum = add_temp3_1 + add_temp3_2;
// end

assign sum = (card_num_cut[2] + card_num_[1]) + (card_num_cut[4] + card_num_[3]) + (card_num_cut[6] + card_num_[5]) + (card_num_cut[8] + card_num_[7]) 
+ (card_num_cut[10] + card_num_[9]) + (card_num_cut[12] + card_num_[11]) + (card_num_cut[14] + card_num_[13]) + (card_num_cut[16] + card_num_[15]);

// sum_mod sm0(.card_sum(sum), .card_valid(out_valid));
always @(*) begin
    // card_valid = (sum % 10 == 0) ? 1'b1 : 1'b0;
    case (sum)
        8'd50: card_valid = 1'b1;
        8'd60: card_valid = 1'b1;
        8'd70: card_valid = 1'b1;
        8'd80: card_valid = 1'b1;
        8'd90: card_valid = 1'b1;
        8'd100: card_valid = 1'b1;
        8'd110: card_valid = 1'b1;
        8'd120: card_valid = 1'b1;
        default: card_valid = 1'b0;
    endcase
end
assign out_valid = card_valid;

// assign snack_num_cut[7] = snack_num[3:0];
// assign snack_num_cut[6] = snack_num[7:4];
// assign snack_num_cut[5] = snack_num[11:8];
// assign snack_num_cut[4] = snack_num[15:12];
// assign snack_num_cut[3] = snack_num[19:16];
// assign snack_num_cut[2] = snack_num[23:20];
// assign snack_num_cut[1] = snack_num[27:24];
// assign snack_num_cut[0] = snack_num[31:28];

// assign price_cut[7] = price[3:0];
// assign price_cut[6] = price[7:4];
// assign price_cut[5] = price[11:8];
// assign price_cut[4] = price[15:12];
// assign price_cut[3] = price[19:16];
// assign price_cut[2] = price[23:20];
// assign price_cut[1] = price[27:24];
// assign price_cut[0] = price[31:28];

// always @(*) begin
//     for (i = 0; i < 8; i = i + 1) begin
//         total[i] = snack_num_cut[i] * price_cut[i];
//     end
// end

always @(*) begin
    total[0] = snack_num[31:28] * price[31:28];
    total[1] = snack_num[27:24] * price[27:24];
    total[2] = snack_num[23:20] * price[23:20];
    total[3] = snack_num[19:16] * price[19:16];
    total[4] = snack_num[15:12] * price[15:12];
    total[5] = snack_num[11:8] * price[11:8];
    total[6] = snack_num[7:4] * price[7:4];
    total[7] = snack_num[3:0] * price[3:0];
end

// genvar g;
// generate
//     for (g = 1; g < 8; g = g + 1) begin : gen_total
//         always @(*) begin
//             total[g] = snack_num_cut[g] * price_cut[g];
//         end
//     end
// endgenerate


sort s0(
    .in_0(total[0]), .in_1(total[1]), .in_2(total[2]), .in_3(total[3]),
    .in_4(total[4]), .in_5(total[5]), .in_6(total[6]), .in_7(total[7]),
    .sorted_0(sorted_item[0]), .sorted_1(sorted_item[1]), .sorted_2(sorted_item[2]), .sorted_3(sorted_item[3]),
    .sorted_4(sorted_item[4]), .sorted_5(sorted_item[5]), .sorted_6(sorted_item[6]), .sorted_7(sorted_item[7])
);


// check if remain_money is enough to buy next product
// always @(*) begin 
//     budget = input_money; 
// end
// assign budget = input_money; 

// always @(*) begin 
//     for (k = 0; k < 8; k = k + 1) begin
//         if (out_valid == 1'b0) break;
//         else if (budget >= sorted_item[k]) begin
//             $display ("++++++++++ %d item_price is : %d ", k, sorted_item[k]);
//             remain_money = budget - sorted_item[k];   
//             budget = remain_money;  
//         end
//         else break;
//     end
//     // $display ("++++++++++ remain_money is : %d ", remain_money);
// end

// Define the range checks for each judge
assign top1 = sorted_item[0];
assign top2 = top1 + sorted_item[1];
assign top3 = top2 + sorted_item[2];
assign top4 = top3 + sorted_item[3];
assign top5 = top4 + sorted_item[4];
assign top6 = top5 + sorted_item[5];
assign top8 = total[0] + total[1] + total[2] + total[3] + total[4] + total[5] + total[6] + total[7];
assign top7 = top8 - sorted_item[7];

// assign judge1 = (input_money < top1) ? 1'b1 : 1'b0;
// assign judge2 = ((input_money >= top1) && (input_money < top2)) ? 1'b1 : 1'b0;
// assign judge3 = ((input_money >= top2) && (input_money < top3)) ? 1'b1 : 1'b0;
// assign judge4 = ((input_money >= top3) && (input_money < top4)) ? 1'b1 : 1'b0;
// assign judge5 = ((input_money >= top4) && (input_money < top5)) ? 1'b1 : 1'b0;
// assign judge6 = ((input_money >= top5) && (input_money < top6)) ? 1'b1 : 1'b0;
// assign judge7 = ((input_money >= top6) && (input_money < top7)) ? 1'b1 : 1'b0;
// assign judge8 = ((input_money >= top7) && (input_money < top8)) ? 1'b1 : 1'b0;


// assign judge1 = (budget < sorted_item[0]) ? 1'b1 : 1'b0;
// assign judge2 = (!judge1) && (budget < (sorted_item[0] + sorted_item[1])) ? 1'b1 : 1'b0;
// assign judge3 = (!judge2) && (budget < (sorted_item[0] + sorted_item[1] + sorted_item[2])) ? 1'b1 : 1'b0;
// assign judge4 = (!judge3) && (budget < (sorted_item[0] + sorted_item[1] + sorted_item[2] + sorted_item[3])) ? 1'b1 : 1'b0;
// assign judge5 = (!judge4) && (budget < (sorted_item[0] + sorted_item[1] + sorted_item[2] + sorted_item[3] + sorted_item[4])) ? 1'b1 : 1'b0;
// assign judge6 = (!judge5) && (budget < (sorted_item[0] + sorted_item[1] + sorted_item[2] + sorted_item[3] + sorted_item[4] + sorted_item[5])) ? 1'b1 : 1'b0;
// assign judge7 = (!judge6) && (budget < (sorted_item[0] + sorted_item[1] + sorted_item[2] + sorted_item[3] + sorted_item[4] + sorted_item[5] + sorted_item[6])) ? 1'b1 : 1'b0;
// assign judge8 = (!judge7) && (budget < (sorted_item[0] + sorted_item[1] + sorted_item[2] + sorted_item[3] + sorted_item[4] + sorted_item[5] + sorted_item[6] + sorted_item[7])) ? 1'b1 : 1'b0;
// assign judge_group = {judge1,judge2,judge3,judge4,judge5,judge6,judge7,judge8};

assign remain_money0 = input_money - top1;
assign remain_money1 = input_money - top2;
assign remain_money2 = input_money - top3;
assign remain_money3 = input_money - top4;
assign remain_money4 = input_money - top5;
assign remain_money5 = input_money - top6;
assign remain_money6 = input_money - top7;
assign remain_money7 = input_money - top8;

always @(*) begin 
    case (out_valid)
        1'b0: remain_money = input_money;
        default: begin
            // case (judge_group)
            //     8'b10000000: remain_money = budget;
            //     8'b01000000: remain_money = budget - sorted_item[0];
            //     8'b00100000: remain_money = budget - sorted_item[0] - sorted_item[1];
            //     8'b00010000: remain_money = budget - sorted_item[0] - sorted_item[1] - sorted_item[2];
            //     8'b00001000: remain_money = budget - sorted_item[0] - sorted_item[1] - sorted_item[2] - sorted_item[3];
            //     8'b00000100: remain_money = budget - sorted_item[0] - sorted_item[1] - sorted_item[2] - sorted_item[3] - sorted_item[4];
            //     8'b00000010: remain_money = budget - sorted_item[0] - sorted_item[1] - sorted_item[2] - sorted_item[3] - sorted_item[4] - sorted_item[5];
            //     8'b00000001: remain_money = budget - sorted_item[0] - sorted_item[1] - sorted_item[2] - sorted_item[3] - sorted_item[4] - sorted_item[5] - sorted_item[6];
            //     default: remain_money = budget - sorted_item[0] - sorted_item[1] - sorted_item[2] - sorted_item[3] - sorted_item[4] - sorted_item[5] - sorted_item[6] - sorted_item[7];
            //     // default: remain_money = budget - (total[0] + total[1] + total[2] + total[3] + total[4] + total[5] + total[6] + total[7]);
            // endcase

            // if(judge1) remain_money = input_money;
            // else if(judge2) remain_money = input_money - top1;
            // else if(judge3) remain_money = input_money - top2;
            // else if(judge4) remain_money = input_money - top3;
            // else if(judge5) remain_money = input_money - top4;
            // else if(judge6) remain_money = input_money - top5;
            // else if(judge7) remain_money = input_money - top6;
            // else if(judge8) remain_money = input_money - top7;
            // else remain_money = input_money - top8;

            if(remain_money0[10]) remain_money = input_money;
            else if(remain_money1[10]) remain_money = remain_money0;
            else if(remain_money2[10]) remain_money = remain_money1;
            else if(remain_money3[10]) remain_money = remain_money2;
            else if(remain_money4[10]) remain_money = remain_money3;
            else if(remain_money5[10]) remain_money = remain_money4;
            else if(remain_money6[10]) remain_money = remain_money5;
            else if(remain_money7[10]) remain_money = remain_money6;
            else remain_money = remain_money7;
        end
    endcase
end

// assign change0 = (input_money >= sorted_item[0]) ? {1'd0, input_money - sorted_item[0]} : {1'd1, input_money};
// assign change1 = (change0[9]) ? change0 : 
//                 (change0[8:0] >= sorted_item[1]) ? {1'd0, change0[8:0] - sorted_item[1]} : {1'd1, change0[8:0]};
// assign change2 = (change1[9]) ? change1 : 
//                 (change1[8:0] >= sorted_item[2]) ? {1'd0, change1[8:0] - sorted_item[2]} : {1'd1, change1[8:0]};
// assign change3 = (change2[9]) ? change2 : 
//                 (change2[8:0] >= sorted_item[3]) ? {1'd0, change2[8:0] - sorted_item[3]} : {1'd1, change2[8:0]};
// assign change4 = (change3[9]) ? change3 : 
//                 (change3[8:0] >= sorted_item[4]) ? {1'd0, change3[8:0] - sorted_item[4]} : {1'd1, change3[8:0]};
// assign change5 = (change4[9]) ? change4 : 
//                 (change4[8:0] >= sorted_item[5]) ? {1'd0, change4[8:0] - sorted_item[5]} : {1'd1, change4[8:0]};
// assign change6 = (change5[9]) ? change5 : 
//                 (change5[8:0] >= sorted_item[6]) ? {1'd0, change5[8:0] - sorted_item[6]} : {1'd1, change5[8:0]};
// assign out_change = (!out_valid) ? input_money :
//                     (change6[9]) ? change6[8:0] :
//                     (change6[8:0] >= sorted_item[7]) ? change6[8:0] - sorted_item[7] : change6[8:0];




// wire [31:0] cumulative_sum [0:7];
// wire [7:0] judge;

// // Calculate cumulative sumscd
// assign cumulative_sum[0] = sorted_item[0];
// genvar g;
// generate
//     for (g = 1; g < 8; g = g + 1) begin : gen_cumulative_sum
//         assign cumulative_sum[g] = cumulative_sum[g-1] + sorted_item[g];
//     end
// endgenerate

// // Determine which items can be bought
// generate
//     for (g = 0; g < 8; g = g + 1) begin : gen_judge
//         assign judge[g] = (budget >= cumulative_sum[g]);
//     end
// endgenerate

// // Calculate remaining money
// always @(*) begin
//     if (!out_valid)
//         remain_money = budget;
//     else begin
//         casez (judge)
//             8'b1???????: remain_money = budget - cumulative_sum[7];
//             8'b01??????: remain_money = budget - cumulative_sum[6];
//             8'b001?????: remain_money = budget - cumulative_sum[5];
//             8'b0001????: remain_money = budget - cumulative_sum[4];
//             8'b00001???: remain_money = budget - cumulative_sum[3];
//             8'b000001??: remain_money = budget - cumulative_sum[2];
//             8'b0000001?: remain_money = budget - cumulative_sum[1];
//             8'b00000001: remain_money = budget - cumulative_sum[0];
//             default: remain_money = budget;
//         endcase
//     end
// end

assign out_change = remain_money;

endmodule
