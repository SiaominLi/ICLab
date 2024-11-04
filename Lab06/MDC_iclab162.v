//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2024/9
//		Version		: v1.0
//   	File Name   : MDC.v
//   	Module Name : MDC
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "HAMMING_IP.v"
//synopsys translate_on

module MDC(
    // Input signals
    clk,
	rst_n, 
	in_valid,
    in_data, 
	in_mode,
    // Output signals
    out_valid, 
	out_data
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk, rst_n, in_valid;
input [8:0] in_mode;
input [14:0] in_data;

output reg out_valid;
output reg [206:0] out_data;

/* reg & wire */
integer i, j;

reg [1:0] mode_ff;
wire [4:0] decode_mode;

reg [5:0] clock_cnt;
wire signed [10:0] decode_data;

reg signed [21:0] data [0:8];        
reg signed [11:0] temp_data [0:2];   
reg signed [33:0] data_33bits [0:1]; 
reg signed [44:0] cal_res;


/* Soft_IP */
HAMMING_IP #(.IP_BIT(11)) hamming_data (.IN_code(in_data), .OUT_code(decode_data));
HAMMING_IP #(.IP_BIT(5)) hamming_mode (.IN_code(in_mode), .OUT_code(decode_mode));


/* design */

always @(posedge clk) begin
    if(in_valid) clock_cnt <= clock_cnt + 1'b1;
    else clock_cnt <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        mode_ff <= 'd0;
    end
    else begin
        if(clock_cnt == 0) begin
            if(decode_mode == 5'b00100) mode_ff <= 2'b00;
            else if(decode_mode == 5'b00110) mode_ff <= 2'b01;
            else if(decode_mode == 5'b10110) mode_ff <= 2'b10;
            else mode_ff <= 2'b00;
        end
    end
end

always @(posedge clk) begin
    if(clock_cnt == 'd16) begin
        for (i = 0; i < 9 ; i = i+1) begin
            data[i] <= 'd0;
        end
        for (j = 0; j < 3 ; j = j+1) begin
            temp_data[j] <= 'd0;
        end
        data_33bits[0] <= 'd0;
        data_33bits[1] <= 'd0;
    end
    else begin
        if(clock_cnt == 'd0) begin
            if(decode_mode == 5'b00100 && in_valid) data[1] <= decode_data; //0
            else if(decode_mode == 5'b00110 && in_valid) data[2] <= decode_data; //0
            else if(decode_mode == 5'b10110 && in_valid) data[6] <= decode_data; //0
        end
        else begin
            case(mode_ff)
                2'b00: begin
                    case(clock_cnt)
                        // 'd0: if(in_valid) data[1] <= decode_data; //0
                        'd1: data[4] <= decode_data; //1
                        'd2: data[5] <= decode_data; //2
                        'd3: data[3] <= decode_data; //3
                        'd4: begin
                            data[6] <= decode_data; //4
                            data[0] <= data[4] * decode_data; // 1*4
                        end
                        'd5: begin
                            data[7] <= decode_data; //5
                            data[0] <= (data[1] * decode_data) - data[0]; // 0*5
                            data[1] <= data[5] * decode_data; // 5*2
                        end
                        'd6: begin
                            data[8] <= decode_data; //6
                            data[1] <= (data[4] * decode_data) - data[1]; // 6*1
                            data[2] <= data[3] * decode_data; //6*3
                        end
                        'd7: begin
                            temp_data[0] <= decode_data; //7
                            data[2] <= (data[5] * decode_data) - data[2]; // 6*1
                        end
                        'd8: begin
                            temp_data[1] <= decode_data; //8
                            data[3] <= data[7] * decode_data; // 8*5
                        end
                        'd9: begin
                            temp_data[2] <= decode_data; //9
                            data[3] <= (data[6] * decode_data) - data[3]; // 9*4
                            data[4] <= data[8] * decode_data; // 9*6
                        end
                        'd10: begin
                            temp_data[0] <= decode_data; //A
                            data[4] <= (data[7] * decode_data) - data[4]; // A*5
                            data[5] <= temp_data[0] * decode_data; // A*7
                        end
                        'd11: begin
                            data[8] <= decode_data; //B
                            data[5] <= (data[8] * decode_data) - data[5]; // B*6
                        end
                        'd12: data[6] <= temp_data[2] * decode_data; // 9*C
                        'd13: begin
                            data[6] <= (temp_data[1] * decode_data) - data[6]; // D*8
                            data[7] <= temp_data[0] * decode_data; // A*D
                        end
                        'd14: begin
                            data[7] <= (temp_data[2] * decode_data) - data[7]; // E*9
                            data[8] <= data[8] * decode_data; // E*B
                        end
                        'd15: data[8] <= (temp_data[0] * decode_data) - data[8]; // A*F
                    endcase
                end
                2'b01: begin
                    case(clock_cnt)
                        // 'd0: if(in_valid) data[2] <= decode_data; //0
                        'd1: data[3] <= decode_data; //1
                        'd2: data[7] <= decode_data; //2
                        'd3: temp_data[2] <= decode_data; //3
                        'd4: begin
                            data[8] <= decode_data; //4
                            data[0] <= data[3] * decode_data; // 1*4
                            data[4] <= data[7] * decode_data; // 2*4
                        end
                        'd5: begin
                            temp_data[1] <= decode_data; //5
                            data[0] <= (data[2] * decode_data) - data[0]; // 0*5
                            data[1] <= data[7] * decode_data; // 2*5
                            data[5] <= temp_data[2] * decode_data; // 3*5
                        end
                        'd6: begin
                            temp_data[2] <= decode_data; //6
                            data[1] <= (data[3] * decode_data) - data[1]; // 6*1
                            data[2] <= temp_data[2] * decode_data; //6*3
                            data[4] <= (data[2] * decode_data) - data[4]; // 6*0
                            // $display(" ------------  data[4]: %d, cal: %d",data[4],(data[2] * decode_data)- data[4]);
                        end
                        'd7: begin
                            data[7] <= decode_data; //7
                            data[2] <= (data[7] * decode_data) - data[2]; // 7*2
                            data[5] <= (data[3] * decode_data) - data[5]; // 7*1
                        end
                        'd8: begin
                            data[3] <= temp_data[1] * decode_data; // 8*5
                            data[6] <= temp_data[2] * decode_data; // 8*6
                            data_33bits[1] <= data[1] * decode_data; //8*(1256)
                        end
                        'd9: begin
                            data[2] <= (data[8] * decode_data) - data[3]; // 9*4
                            data[3] <= temp_data[2] * decode_data; // 9*6
                            data[4] <= data[7] * decode_data; // 9*7
                            data_33bits[0] <= data[2] * decode_data; //9*(2367)
                            data_33bits[1] <= data_33bits[1] - (data[4] * decode_data); //9*(0246)
                        end
                        'd10: begin
                            data[0] <= (data[8] * decode_data) - data[6]; // 4*A
                            data[3] <= (temp_data[1] * decode_data) - data[3]; // 5*A
                            data[5] <= data[7] * decode_data; // A*7
                            data_33bits[0] <= data_33bits[0] - (data[5] * decode_data); // A*(1357)
                            {data[6],data[7],data[8]} <= data_33bits[1] + (data[0] * decode_data); // A*(0145)
                        end
                        'd11: begin
                            data[1] <= (temp_data[2] * decode_data) - data[5]; // B*6
                            data[4] <= (temp_data[1] * decode_data) - data[4]; // B*5
                            {temp_data[0],temp_data[1],temp_data[2]} <= cal_res;
                        end
                        'd12: data_33bits[0] <= data[3] * decode_data; // C*(569A)
                        'd13: begin
                            data_33bits[0] <= data_33bits[0] - (data[0] * decode_data); // D*(468A)
                            data_33bits[1] <= data[1] * decode_data; //D*(67AB)
                        end
                        'd14: begin
                            {data[0],data[1],data[2]} <= {data[6],data[7],data[8]};
                            {data[6],data[7],data[8]} <= data_33bits[0] + (data[2] * decode_data); // E*(4589)
                            data_33bits[1] <= data_33bits[1] - (data[4] * decode_data); //E*(579B)
                        end
                        'd15: begin
                            {data[3],data[4],data[5]} <= {{34{temp_data[0][11]}},temp_data[0],temp_data[1],temp_data[2]};
                            {temp_data[0],temp_data[1],temp_data[2]} <= (data[3] * decode_data) + data_33bits[1]; // F*(569A)
                        end
                    endcase
                end
                2'b10: begin
                    case(clock_cnt)
                        // 'd0: if(in_valid) data[6] <= decode_data; //0
                        'd1: data[7] <= decode_data; //1
                        'd2: data[8] <= decode_data; //2
                        'd3: data[2] <= decode_data; //3
                        'd4: begin 
                            data[0] <= data[7] * decode_data; // 1*4
                            data[3] <= data[2] * decode_data; // 3*4
                            data[4] <= data[8] * decode_data; // 2*4
                        end
                        'd5: begin
                            data[0] <= (data[6] * decode_data) - data[0]; // 0*5
                            data[1] <= data[8] * decode_data; // 2*5
                            data[5] <= data[2] * decode_data; // 3*5
                        end
                        'd6: begin
                            data[1] <= (data[7] * decode_data) - data[1]; // 6*1
                            data[2] <= data[2] * decode_data; //6*3
                            data[4] <= (data[6] * decode_data) - data[4]; // 6*0
                        end
                        'd7: begin
                            data[7] <= decode_data; //7
                            data[2] <= (data[8] * decode_data) - data[2]; // 7*2
                            data[3] <= (data[6] * decode_data) - data[3]; // 7*0
                            data[5] <= (data[7] * decode_data) - data[5]; // 7*1
                        end
                        'd8: begin
                            // $display("------ data2= %d * %d = %d",data[2],decode_data,(data[2] * decode_data));
                            {data[6],data[7]} <= {{12{cal_res[44]}},cal_res}; // 8*(2367)
                            // $display("------ 8*(2367)act= %d",cal_res);
                            {temp_data[0],temp_data[1],temp_data[2]} <= data[5] * decode_data; // 8*(1357)
                            data_33bits[1] <= data[1] * decode_data; //8*(1256)
                        end
                        'd9: begin
                            // $display("------ 8*(2367)= %d | %d | %d",data[6],data[7],$signed({data[6],data[7]}));
                            {temp_data[0],temp_data[1],temp_data[2]} <= $signed({temp_data[0],temp_data[1],temp_data[2]}) - (data[3] * decode_data); // 9*(0347)
                            data_33bits[0] <= data[2] * decode_data; //9*(2367)
                            data_33bits[1] <= data_33bits[1] - (data[4] * decode_data); //9*(0246)
                        end
                        'd10: begin 
                            {data[6],data[7]} <= $signed({data[6],data[7]}) - (data[3] * decode_data); // A*(0347)
                            data_33bits[0] <= data_33bits[0] - (data[5] * decode_data); // A*(1357)
                            {data[2],data[3]} <= data_33bits[1] + (data[0] * decode_data); // A*(0145)
                        end
                        'd11: begin
                            {data[0],data[1]} <= $signed({data[6],data[7]}) + (data[4] * decode_data); // B*(0246)
                            {data[5],data[6]} <= $signed({temp_data[0],temp_data[1],temp_data[2]}) + (data[0] * decode_data); // B*(0145)
                            // $display("------ {data[5],data[6]}_cal= %d",$signed({temp_data[0],temp_data[1],temp_data[2]}) + (data[0] * decode_data));
                            {data[7],data[8]} <= {{10{cal_res[44]}},cal_res}; // B*(1256)
                        end 
                        'd12: begin
                            {data[7],data[8]} <= {{10{cal_res[44]}},cal_res}; // C*(right-up)
                        end
                        'd13: begin
                            // $display("------ D= %d",$signed({data[0],data[1]}) * decode_data);
                            {data_33bits[0],data_33bits[1]} <= {{23{cal_res[44]}},cal_res};
                        end
                        'd14: begin
                            // $display("------ D= %d",{data_33bits[0],data_33bits[1]});
                            {data_33bits[0],data_33bits[1]} <= {{23{cal_res[44]}},cal_res}; // D-E
                        end
                        'd15: begin
                            {data_33bits[0],data_33bits[1]} <= {{24{cal_res[44]}},cal_res}; // D+F
                        end
                    endcase
                end
            endcase
        end
        
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <= 'd0;
        out_data <= 'd0;
    end
    else begin
        if(clock_cnt == 'd16) begin
            out_valid <= 'd1;
            if(mode_ff == 2'b00) begin
                out_data[22:0]   <= data[8];   
                // out_data[22:0] <= data[8] - (temp_data[0] * decode_data);
                out_data[45:23]  <= data[7];   
                out_data[68:46]  <= data[6]; 
                out_data[91:69]  <= data[5]; 
                out_data[114:92] <= data[4];  
                out_data[137:115] <= data[3];  
                out_data[160:138] <= data[2];  
                out_data[183:161] <= data[1];  
                out_data[206:184] <= data[0];  
            end
            else if(mode_ff == 2'b01) begin
                out_data[50:0] <= {{19{temp_data[0][11]}},temp_data[0],temp_data[1],temp_data[2]};
                out_data[101:51] <= {data[6],data[7],data[8]};
                out_data[152:102] <= {data[3],data[4],data[5]};
                out_data[203:153] <= {data[0],data[1],data[2]};
                out_data[206:204] <= 3'b000;
            end
            else if(mode_ff == 2'b10) begin
                out_data <= {{140{data_33bits[0][33]}},data_33bits[0],data_33bits[1]};
            end
        end
        else begin
            out_valid <= 'd0;
            out_data <= 'd0;
        end
    end
end

always @(*) begin
    if(clock_cnt == 'd8 && mode_ff == 2'b10)
        cal_res = data[2] * decode_data; // 8*(2367)
    else if(clock_cnt == 'd11 && mode_ff == 2'b10)
        cal_res = data_33bits[0] + (data[1] * decode_data); 
    else if(clock_cnt == 'd12 && mode_ff == 2'b10)
        cal_res = $signed({data[7],data[8]}) * decode_data; // C*(right-up)
    else if(clock_cnt == 'd13 && mode_ff == 2'b10)
        cal_res = ($signed({data[0],data[1]}) * decode_data) - $signed({data[7],data[8]}); // D-C
    else if(clock_cnt == 'd14 && mode_ff == 2'b10)
        cal_res = $signed({data_33bits[0],data_33bits[1]}) - ($signed({data[5],data[6]}) * decode_data); // D-E
    else if(clock_cnt == 'd15 && mode_ff == 2'b10)
        cal_res = $signed({data_33bits[0],data_33bits[1]}) + ($signed({data[2],data[3]}) * decode_data); // D+F
    

    else if(clock_cnt == 'd11 && mode_ff == 2'b01)
        cal_res = data_33bits[0] + (data[1] * decode_data); // B*(1256)
    else
        cal_res = 'd0;
end

endmodule


// module MUL_11BITS(
//     in_0, in_1,
//     mul_value
// );

// input [11-1:0] in_0, in_1;
// output reg [22-1:0] mul_value;

// assign mul_value = in_0 * in_1;

// endmodule

