/**************************************************************************/
// Copyright (c) 2024, OASIS Lab
// MODULE: SA
// FILE NAME: SA_wocg.v
// VERSRION: 1.0
// DATE: Nov 06, 2024
// AUTHOR: Hsiao-Min Li, NYCU IOE
// CODE TYPE: RTL or Behavioral Level (Verilog)
// DESCRIPTION: 2024 Spring IC Lab / Exersise Lab08 / SA_wocg
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/

module SA(
	// Input signals
	clk,
	rst_n,
	in_valid,
	T,
	in_data,
	w_Q,
	w_K,
	w_V,
	// Output signals
	out_valid,
	out_data
);

input clk;
input rst_n;
input in_valid;
input [3:0] T;
input signed [7:0] in_data;
input signed [7:0] w_Q;
input signed [7:0] w_K;
input signed [7:0] w_V;

output reg out_valid;
output reg signed [63:0] out_data;

//==============================================//
//       parameter & integer declaration        //
//==============================================//
integer i, j, k;


//==============================================//
//           reg & wire declaration             //
//==============================================//
reg [6:0] datain_cnt, matrixin_cnt;
reg [1:0] QKV; // 0=Q, 1=K, 2=V
reg [3:0] T_ff;
reg [6:0] data_in_max; // 0~63

reg signed [62:0] matrix [0:63];
reg signed [18:0] V_ff [0:63]; // 19bits
reg signed [7:0] data_ff [0:63];

reg [2:0] cal_stateQKV; // 1->Q, 2->K, 3->V, 4->ouput cal
reg [3:0] save8x8_loc; //0~7

reg signed [7:0] mul8_a[0:63], mul8_b[0:63];
reg signed [15:0] mul8x8_res[0:63];
reg signed [18:0] mul8x8res_add[0:7];

reg signed [18:0] mul19_a[0:7];
reg signed [39:0] mul40_b[0:7];
reg signed [58:0] mul19x40_res[0:7];
wire signed [62:0] mul19x40res_add;
reg [39:0] ReLU_div_res;

reg signed [39:0] A_buffer[0:7];
reg [7:0] calA_counter; //0~63
reg [7:0] calA_MAX; //0~63

reg signed [63:0] temp_out[0:1];
reg signed [18:0] mul19_a2[0:3];
reg signed [39:0] mul40_b2[0:3];
reg signed [58:0] mul19x40_res2[0:3];

reg [7:0] output_cnt;
reg next_pattern_flag;

//==============================================//
//                  design                      //
//==============================================//

/*matrixin_cnt*/
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)  matrixin_cnt <= 'd0;
    else begin
        if(in_valid) begin
            matrixin_cnt <= (matrixin_cnt == 'd63) ? 'd0 : matrixin_cnt + 1'b1;
		end
        // else if(next_pattern_flag) matrixin_cnt <= 'd0;
        else if (cal_stateQKV >= 'd3) matrixin_cnt <= (next_pattern_flag) ? 'd0 : matrixin_cnt + 1'b1;
        else if(next_pattern_flag) matrixin_cnt <= 'd0;
        else matrixin_cnt <= 'd0;
    end
end

/*QKV*/
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)  QKV <= 'd0;
    else begin
        if(in_valid && matrixin_cnt == 'd63) QKV <= QKV + 1'b1;
        else if(next_pattern_flag) QKV <= 'd0;
    end
end

/*cal_stateQKV*/
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)  cal_stateQKV <= 'd0;
    else begin
        // if(in_valid && matrixin_cnt == 'd56) cal_stateQKV <= cal_stateQKV + 1'b1;
        if(matrixin_cnt == 'd56) cal_stateQKV <= cal_stateQKV + 1'b1;
        else if(next_pattern_flag) cal_stateQKV <= 'd0;
    end
end

/*datain_cnt*/
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)  datain_cnt <= 'd0;
    else begin
        if(in_valid) datain_cnt <= (datain_cnt <= data_in_max) ? datain_cnt + 1'b1 : datain_cnt;
		else datain_cnt <= 'd0;
    end
end

/*data_in_max*/
always @(*) begin
	if(in_valid && datain_cnt == 0) data_in_max = (T == 1) ? 7 : (T == 4) ? 31 : 63;
	else data_in_max = (T_ff == 1) ? 7 : (T_ff == 4) ? 31 : 63;
end

/*T_ff*/
always @(posedge clk) begin
	if(in_valid && datain_cnt == 0) T_ff <= T;
end

/*data_ff*/
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        for (i = 0; i < 64 ; i = i + 1 ) data_ff[i] <= 'd0;
    end
    else begin
        if(in_valid && datain_cnt <= data_in_max) data_ff[datain_cnt] <= in_data;
        else if(next_pattern_flag) begin
            for (i = 0; i < 64 ; i = i + 1 ) data_ff[i] <= 'd0;
        end
    end
end

/*V_ff*/
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
		for (i = 0; i < 64 ; i = i + 1 ) begin
			V_ff[i] <= 'd0;
		end
	end
    else begin
        if(in_valid && QKV[1]) V_ff[matrixin_cnt][7:0] <= w_V;
        if(cal_stateQKV == 'd3) begin
            case(matrixin_cnt) // save V'
                'd58, 'd59, 'd60, 'd61, 'd62, 'd63, 'd0, 'd1: begin
                    V_ff[save8x8_loc] <= mul8x8res_add[0]; // save to 0
                    V_ff[save8x8_loc+8] <= mul8x8res_add[1]; // save to 8
                    V_ff[save8x8_loc+16] <= mul8x8res_add[2]; // save to 16
                    V_ff[save8x8_loc+24] <= mul8x8res_add[3]; // save to 24
                    V_ff[save8x8_loc+32] <= mul8x8res_add[4]; // save to 32
                    V_ff[save8x8_loc+40] <= mul8x8res_add[5]; // save to 40
                    V_ff[save8x8_loc+48] <= mul8x8res_add[6]; // save to 48
                    V_ff[save8x8_loc+56] <= mul8x8res_add[7]; // save to 56
                end
            endcase
        end
        else if(next_pattern_flag) begin
            for (i = 0; i < 64 ; i = i + 1 ) begin
                V_ff[i] <= 'd0;
            end
        end
    end
end

/*save8x8_loc*/
always @(posedge clk) begin
    if(cal_stateQKV == 'd1 && T_ff == 'd8) begin
        case(matrixin_cnt)
            'd1, 'd2, 'd3, 'd4, 'd5, 'd6, 'd7: save8x8_loc <= save8x8_loc + 1'b1;
            default: save8x8_loc <= 'd0;
        endcase
    end
    else begin
        case(matrixin_cnt)
            'd58, 'd59, 'd60, 'd61, 'd62, 'd63, 'd0: save8x8_loc <= save8x8_loc + 1'b1;
            default: save8x8_loc <= 'd0;
        endcase
    end
end

/*matrix*/
always @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		for (i = 0; i < 64 ; i = i + 1 ) begin
			matrix[i] <= 'd0;
		end
	end
	else begin
        /* save mul19x19 */
        case(calA_counter) //save A to buffer
            'd9: for(j = 0; j < 8; j = j + 1) matrix[j][39:0] <= A_buffer[j];
            'd17: for(j = 0; j < 8; j = j + 1) matrix[j + 8][39:0] <= A_buffer[j];
            'd25: for(j = 0; j < 8; j = j + 1) matrix[j + 16][39:0] <= A_buffer[j];
            'd33: for(j = 0; j < 8; j = j + 1) matrix[j + 24][39:0] <= A_buffer[j];
            'd41: for(j = 0; j < 8; j = j + 1) matrix[j + 32][39:0] <= A_buffer[j];
            'd49: for(j = 0; j < 8; j = j + 1) matrix[j + 40][39:0] <= A_buffer[j];
            'd57: for(j = 0; j < 8; j = j + 1) matrix[j + 48][39:0] <= A_buffer[j];
            'd65: for(j = 0; j < 8; j = j + 1) matrix[j + 56][39:0] <= A_buffer[j];
        endcase

		if(in_valid) begin
            /* save input */
            if(QKV == 'd0) matrix[matrixin_cnt][7:0] <= w_Q;
            else if(QKV == 'd1) matrix[matrixin_cnt][15:8] <= w_K;
            else if(next_pattern_flag) begin
                for (i = 0; i < 64 ; i = i + 1 ) begin
                    matrix[i] <= 'd0;
                end
            end

            /* save mul8x8 */
			if(cal_stateQKV == 'd1) begin //save Q'
                if(T_ff == 'd8) begin
                    case(matrixin_cnt)
                        'd1, 'd2, 'd3, 'd4, 'd5, 'd6, 'd7, 'd8: begin
                            matrix[save8x8_loc][34:16] <= mul8x8res_add[0]; // save to 0
                            matrix[save8x8_loc+8][34:16] <= mul8x8res_add[1]; // save to 8
                            matrix[save8x8_loc+16][34:16] <= mul8x8res_add[2]; // save to 16
                            matrix[save8x8_loc+24][34:16] <= mul8x8res_add[3]; // save to 24
                            matrix[save8x8_loc+32][34:16] <= mul8x8res_add[4]; // save to 32
                            matrix[save8x8_loc+40][34:16] <= mul8x8res_add[5]; // save to 40
                            matrix[save8x8_loc+48][34:16] <= mul8x8res_add[6]; // save to 48
                            matrix[save8x8_loc+56][34:16] <= mul8x8res_add[7]; // save to 56
                        end
                    endcase
                end
                else begin
                    case(matrixin_cnt)
                        'd58, 'd59, 'd60, 'd61, 'd62, 'd63, 'd0, 'd1: begin
                            matrix[save8x8_loc][34:16] <= mul8x8res_add[0]; // save to 0
                            matrix[save8x8_loc+8][34:16] <= mul8x8res_add[1]; // save to 8
                            matrix[save8x8_loc+16][34:16] <= mul8x8res_add[2]; // save to 16
                            matrix[save8x8_loc+24][34:16] <= mul8x8res_add[3]; // save to 24
                            matrix[save8x8_loc+32][34:16] <= mul8x8res_add[4]; // save to 32
                            matrix[save8x8_loc+40][34:16] <= mul8x8res_add[5]; // save to 40
                            matrix[save8x8_loc+48][34:16] <= mul8x8res_add[6]; // save to 48
                            matrix[save8x8_loc+56][34:16] <= mul8x8res_add[7]; // save to 56
                        end
                    endcase
                end
			end
			else if(cal_stateQKV == 'd2) begin //save K'
				case(matrixin_cnt)
					'd58, 'd59, 'd60, 'd61, 'd62, 'd63, 'd0, 'd1: begin
                        matrix[save8x8_loc][62:44] <= mul8x8res_add[0]; // save to 0
                        matrix[save8x8_loc+8][62:44] <= mul8x8res_add[1]; // save to 8
                        matrix[save8x8_loc+16][62:44] <= mul8x8res_add[2]; // save to 16
                        matrix[save8x8_loc+24][62:44] <= mul8x8res_add[3]; // save to 24
                        matrix[save8x8_loc+32][62:44] <= mul8x8res_add[4]; // save to 32
                        matrix[save8x8_loc+40][62:44] <= mul8x8res_add[5]; // save to 40
                        matrix[save8x8_loc+48][62:44] <= mul8x8res_add[6]; // save to 48
                        matrix[save8x8_loc+56][62:44] <= mul8x8res_add[7]; // save to 56
                    end
				endcase
			end
		end
        else if(next_pattern_flag) begin
            for (i = 0; i < 64 ; i = i + 1 ) begin
                matrix[i] <= 'd0;
            end
        end
	end
end

/*mul8_a*/
always @(posedge clk) begin
    if(cal_stateQKV == 'd1 && T_ff == 'd8) begin //cal Q col
        case(matrixin_cnt)
            'd0, 'd1, 'd2, 'd3, 'd4, 'd5, 'd6, 'd7: begin
                for(j = 0; j < 64; j = j + 1) begin
                    mul8_a[j] <= data_ff[j];
                end
            end
            default: for(j = 0; j < 64; j = j + 1)  mul8_a[j] <= 'd0;
        endcase
    end
    else if(cal_stateQKV > 'd0) begin
        case(matrixin_cnt)
            'd57, 'd58, 'd59, 'd60, 'd61, 'd62, 'd63, 'd0: begin
                for(j = 0; j < 64; j = j + 1) begin
                    mul8_a[j] <= data_ff[j];
                end
            end
            default: for(j = 0; j < 64; j = j + 1)  mul8_a[j] <= 'd0;
        endcase
    end
    else begin
        for(j = 0; j < 64; j = j + 1)  mul8_a[j] <= 'd0;
    end
end

/*mul8_b*/
always @(posedge clk) begin
    if(cal_stateQKV == 'd1 && T_ff == 'd8) begin
        case(matrixin_cnt)
            'd0: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[0][7:0];
                    mul8_b[j+1] <= matrix[8][7:0];
                    mul8_b[j+2] <= matrix[16][7:0];
                    mul8_b[j+3] <= matrix[24][7:0];
                    mul8_b[j+4] <= matrix[32][7:0];
                    mul8_b[j+5] <= matrix[40][7:0];
                    mul8_b[j+6] <= matrix[48][7:0];
                    mul8_b[j+7] <= matrix[56][7:0];
                end
            end
            'd1: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[1][7:0];
                    mul8_b[j+1] <= matrix[9][7:0];
                    mul8_b[j+2] <= matrix[17][7:0];
                    mul8_b[j+3] <= matrix[25][7:0];
                    mul8_b[j+4] <= matrix[33][7:0];
                    mul8_b[j+5] <= matrix[41][7:0];
                    mul8_b[j+6] <= matrix[49][7:0];
                    mul8_b[j+7] <= matrix[57][7:0];
                end
            end
            'd2: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[2][7:0];
                    mul8_b[j+1] <= matrix[10][7:0];
                    mul8_b[j+2] <= matrix[18][7:0];
                    mul8_b[j+3] <= matrix[26][7:0];
                    mul8_b[j+4] <= matrix[34][7:0];
                    mul8_b[j+5] <= matrix[42][7:0];
                    mul8_b[j+6] <= matrix[50][7:0];
                    mul8_b[j+7] <= matrix[58][7:0];
                end
            end
            'd3: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[3][7:0];
                    mul8_b[j+1] <= matrix[11][7:0];
                    mul8_b[j+2] <= matrix[19][7:0];
                    mul8_b[j+3] <= matrix[27][7:0];
                    mul8_b[j+4] <= matrix[35][7:0];
                    mul8_b[j+5] <= matrix[43][7:0];
                    mul8_b[j+6] <= matrix[51][7:0];
                    mul8_b[j+7] <= matrix[59][7:0];
                end
            end
            'd4: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[4][7:0];
                    mul8_b[j+1] <= matrix[12][7:0];
                    mul8_b[j+2] <= matrix[20][7:0];
                    mul8_b[j+3] <= matrix[28][7:0];
                    mul8_b[j+4] <= matrix[36][7:0];
                    mul8_b[j+5] <= matrix[44][7:0];
                    mul8_b[j+6] <= matrix[52][7:0];
                    mul8_b[j+7] <= matrix[60][7:0];
                end
            end
            'd5: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[5][7:0];
                    mul8_b[j+1] <= matrix[13][7:0];
                    mul8_b[j+2] <= matrix[21][7:0];
                    mul8_b[j+3] <= matrix[29][7:0];
                    mul8_b[j+4] <= matrix[37][7:0];
                    mul8_b[j+5] <= matrix[45][7:0];
                    mul8_b[j+6] <= matrix[53][7:0];
                    mul8_b[j+7] <= matrix[61][7:0];
                end
            end
            'd6: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[6][7:0];
                    mul8_b[j+1] <= matrix[14][7:0];
                    mul8_b[j+2] <= matrix[22][7:0];
                    mul8_b[j+3] <= matrix[30][7:0];
                    mul8_b[j+4] <= matrix[38][7:0];
                    mul8_b[j+5] <= matrix[46][7:0];
                    mul8_b[j+6] <= matrix[54][7:0];
                    mul8_b[j+7] <= matrix[62][7:0];
                end
            end
            'd7: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[7][7:0];
                    mul8_b[j+1] <= matrix[15][7:0];
                    mul8_b[j+2] <= matrix[23][7:0];
                    mul8_b[j+3] <= matrix[31][7:0];
                    mul8_b[j+4] <= matrix[39][7:0];
                    mul8_b[j+5] <= matrix[47][7:0];
                    mul8_b[j+6] <= matrix[55][7:0];
                    mul8_b[j+7] <= matrix[63][7:0];
                end
            end
            default: for(j = 0; j < 64; j = j + 1)  mul8_b[j] <= 'd0;
        endcase
    end
    else if(cal_stateQKV == 'd1) begin //cal Q col
        case(matrixin_cnt)
            'd57: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[0][7:0];
                    mul8_b[j+1] <= matrix[8][7:0];
                    mul8_b[j+2] <= matrix[16][7:0];
                    mul8_b[j+3] <= matrix[24][7:0];
                    mul8_b[j+4] <= matrix[32][7:0];
                    mul8_b[j+5] <= matrix[40][7:0];
                    mul8_b[j+6] <= matrix[48][7:0];
                    mul8_b[j+7] <= matrix[56][7:0];
                end
            end
            'd58: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[1][7:0];
                    mul8_b[j+1] <= matrix[9][7:0];
                    mul8_b[j+2] <= matrix[17][7:0];
                    mul8_b[j+3] <= matrix[25][7:0];
                    mul8_b[j+4] <= matrix[33][7:0];
                    mul8_b[j+5] <= matrix[41][7:0];
                    mul8_b[j+6] <= matrix[49][7:0];
                    mul8_b[j+7] <= matrix[57][7:0];
                end
            end
            'd59: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[2][7:0];
                    mul8_b[j+1] <= matrix[10][7:0];
                    mul8_b[j+2] <= matrix[18][7:0];
                    mul8_b[j+3] <= matrix[26][7:0];
                    mul8_b[j+4] <= matrix[34][7:0];
                    mul8_b[j+5] <= matrix[42][7:0];
                    mul8_b[j+6] <= matrix[50][7:0];
                    mul8_b[j+7] <= matrix[58][7:0];
                end
            end
            'd60: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[3][7:0];
                    mul8_b[j+1] <= matrix[11][7:0];
                    mul8_b[j+2] <= matrix[19][7:0];
                    mul8_b[j+3] <= matrix[27][7:0];
                    mul8_b[j+4] <= matrix[35][7:0];
                    mul8_b[j+5] <= matrix[43][7:0];
                    mul8_b[j+6] <= matrix[51][7:0];
                    mul8_b[j+7] <= matrix[59][7:0];
                end
            end
            'd61: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[4][7:0];
                    mul8_b[j+1] <= matrix[12][7:0];
                    mul8_b[j+2] <= matrix[20][7:0];
                    mul8_b[j+3] <= matrix[28][7:0];
                    mul8_b[j+4] <= matrix[36][7:0];
                    mul8_b[j+5] <= matrix[44][7:0];
                    mul8_b[j+6] <= matrix[52][7:0];
                    mul8_b[j+7] <= matrix[60][7:0];
                end
            end
            'd62: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[5][7:0];
                    mul8_b[j+1] <= matrix[13][7:0];
                    mul8_b[j+2] <= matrix[21][7:0];
                    mul8_b[j+3] <= matrix[29][7:0];
                    mul8_b[j+4] <= matrix[37][7:0];
                    mul8_b[j+5] <= matrix[45][7:0];
                    mul8_b[j+6] <= matrix[53][7:0];
                    mul8_b[j+7] <= matrix[61][7:0];
                end
            end
            'd63: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[6][7:0];
                    mul8_b[j+1] <= matrix[14][7:0];
                    mul8_b[j+2] <= matrix[22][7:0];
                    mul8_b[j+3] <= matrix[30][7:0];
                    mul8_b[j+4] <= matrix[38][7:0];
                    mul8_b[j+5] <= matrix[46][7:0];
                    mul8_b[j+6] <= matrix[54][7:0];
                    mul8_b[j+7] <= matrix[62][7:0];
                end
            end
            'd0: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[7][7:0];
                    mul8_b[j+1] <= matrix[15][7:0];
                    mul8_b[j+2] <= matrix[23][7:0];
                    mul8_b[j+3] <= matrix[31][7:0];
                    mul8_b[j+4] <= matrix[39][7:0];
                    mul8_b[j+5] <= matrix[47][7:0];
                    mul8_b[j+6] <= matrix[55][7:0];
                    mul8_b[j+7] <= matrix[63][7:0];
                end
            end
            default: for(j = 0; j < 64; j = j + 1)  mul8_b[j] <= 'd0;
        endcase
    end
    else if(cal_stateQKV == 'd2) begin //cal K col
        case(matrixin_cnt)
            'd57: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[0][15:8];
                    mul8_b[j+1] <= matrix[8][15:8];
                    mul8_b[j+2] <= matrix[16][15:8];
                    mul8_b[j+3] <= matrix[24][15:8];
                    mul8_b[j+4] <= matrix[32][15:8];
                    mul8_b[j+5] <= matrix[40][15:8];
                    mul8_b[j+6] <= matrix[48][15:8];
                    mul8_b[j+7] <= matrix[56][15:8];
                end
            end
            'd58: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[1][15:8];
                    mul8_b[j+1] <= matrix[9][15:8];
                    mul8_b[j+2] <= matrix[17][15:8];
                    mul8_b[j+3] <= matrix[25][15:8];
                    mul8_b[j+4] <= matrix[33][15:8];
                    mul8_b[j+5] <= matrix[41][15:8];
                    mul8_b[j+6] <= matrix[49][15:8];
                    mul8_b[j+7] <= matrix[57][15:8];
                end
            end
            'd59: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[2][15:8];
                    mul8_b[j+1] <= matrix[10][15:8];
                    mul8_b[j+2] <= matrix[18][15:8];
                    mul8_b[j+3] <= matrix[26][15:8];
                    mul8_b[j+4] <= matrix[34][15:8];
                    mul8_b[j+5] <= matrix[42][15:8];
                    mul8_b[j+6] <= matrix[50][15:8];
                    mul8_b[j+7] <= matrix[58][15:8];
                end
            end
            'd60: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[3][15:8];
                    mul8_b[j+1] <= matrix[11][15:8];
                    mul8_b[j+2] <= matrix[19][15:8];
                    mul8_b[j+3] <= matrix[27][15:8];
                    mul8_b[j+4] <= matrix[35][15:8];
                    mul8_b[j+5] <= matrix[43][15:8];
                    mul8_b[j+6] <= matrix[51][15:8];
                    mul8_b[j+7] <= matrix[59][15:8];
                end
            end
            'd61: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[4][15:8];
                    mul8_b[j+1] <= matrix[12][15:8];
                    mul8_b[j+2] <= matrix[20][15:8];
                    mul8_b[j+3] <= matrix[28][15:8];
                    mul8_b[j+4] <= matrix[36][15:8];
                    mul8_b[j+5] <= matrix[44][15:8];
                    mul8_b[j+6] <= matrix[52][15:8];
                    mul8_b[j+7] <= matrix[60][15:8];
                end
            end
            'd62: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[5][15:8];
                    mul8_b[j+1] <= matrix[13][15:8];
                    mul8_b[j+2] <= matrix[21][15:8];
                    mul8_b[j+3] <= matrix[29][15:8];
                    mul8_b[j+4] <= matrix[37][15:8];
                    mul8_b[j+5] <= matrix[45][15:8];
                    mul8_b[j+6] <= matrix[53][15:8];
                    mul8_b[j+7] <= matrix[61][15:8];
                end
            end
            'd63: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[6][15:8];
                    mul8_b[j+1] <= matrix[14][15:8];
                    mul8_b[j+2] <= matrix[22][15:8];
                    mul8_b[j+3] <= matrix[30][15:8];
                    mul8_b[j+4] <= matrix[38][15:8];
                    mul8_b[j+5] <= matrix[46][15:8];
                    mul8_b[j+6] <= matrix[54][15:8];
                    mul8_b[j+7] <= matrix[62][15:8];
                end
            end
            'd0: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= matrix[7][15:8];
                    mul8_b[j+1] <= matrix[15][15:8];
                    mul8_b[j+2] <= matrix[23][15:8];
                    mul8_b[j+3] <= matrix[31][15:8];
                    mul8_b[j+4] <= matrix[39][15:8];
                    mul8_b[j+5] <= matrix[47][15:8];
                    mul8_b[j+6] <= matrix[55][15:8];
                    mul8_b[j+7] <= matrix[63][15:8];
                end
            end
            default: for(j = 0; j < 64; j = j + 1)  mul8_b[j] <= 'd0;
        endcase
    end
    else if(cal_stateQKV == 'd3) begin //cal V col
        case(matrixin_cnt)
            'd57: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= V_ff[0][7:0];
                    mul8_b[j+1] <= V_ff[8][7:0];
                    mul8_b[j+2] <= V_ff[16][7:0];
                    mul8_b[j+3] <= V_ff[24][7:0];
                    mul8_b[j+4] <= V_ff[32][7:0];
                    mul8_b[j+5] <= V_ff[40][7:0];
                    mul8_b[j+6] <= V_ff[48][7:0];
                    mul8_b[j+7] <= V_ff[56][7:0];
                end
            end
            'd58: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= V_ff[1][7:0];
                    mul8_b[j+1] <= V_ff[9][7:0];
                    mul8_b[j+2] <= V_ff[17][7:0];
                    mul8_b[j+3] <= V_ff[25][7:0];
                    mul8_b[j+4] <= V_ff[33][7:0];
                    mul8_b[j+5] <= V_ff[41][7:0];
                    mul8_b[j+6] <= V_ff[49][7:0];
                    mul8_b[j+7] <= V_ff[57][7:0];
                end
            end
            'd59: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= V_ff[2][7:0];
                    mul8_b[j+1] <= V_ff[10][7:0];
                    mul8_b[j+2] <= V_ff[18][7:0];
                    mul8_b[j+3] <= V_ff[26][7:0];
                    mul8_b[j+4] <= V_ff[34][7:0];
                    mul8_b[j+5] <= V_ff[42][7:0];
                    mul8_b[j+6] <= V_ff[50][7:0];
                    mul8_b[j+7] <= V_ff[58][7:0];
                end
            end
            'd60: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= V_ff[3][7:0];
                    mul8_b[j+1] <= V_ff[11][7:0];
                    mul8_b[j+2] <= V_ff[19][7:0];
                    mul8_b[j+3] <= V_ff[27][7:0];
                    mul8_b[j+4] <= V_ff[35][7:0];
                    mul8_b[j+5] <= V_ff[43][7:0];
                    mul8_b[j+6] <= V_ff[51][7:0];
                    mul8_b[j+7] <= V_ff[59][7:0];
                end
            end
            'd61: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= V_ff[4][7:0];
                    mul8_b[j+1] <= V_ff[12][7:0];
                    mul8_b[j+2] <= V_ff[20][7:0];
                    mul8_b[j+3] <= V_ff[28][7:0];
                    mul8_b[j+4] <= V_ff[36][7:0];
                    mul8_b[j+5] <= V_ff[44][7:0];
                    mul8_b[j+6] <= V_ff[52][7:0];
                    mul8_b[j+7] <= V_ff[60][7:0];
                end
            end
            'd62: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= V_ff[5][7:0];
                    mul8_b[j+1] <= V_ff[13][7:0];
                    mul8_b[j+2] <= V_ff[21][7:0];
                    mul8_b[j+3] <= V_ff[29][7:0];
                    mul8_b[j+4] <= V_ff[37][7:0];
                    mul8_b[j+5] <= V_ff[45][7:0];
                    mul8_b[j+6] <= V_ff[53][7:0];
                    mul8_b[j+7] <= V_ff[61][7:0];
                end
            end
            'd63: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= V_ff[6][7:0];
                    mul8_b[j+1] <= V_ff[14][7:0];
                    mul8_b[j+2] <= V_ff[22][7:0];
                    mul8_b[j+3] <= V_ff[30][7:0];
                    mul8_b[j+4] <= V_ff[38][7:0];
                    mul8_b[j+5] <= V_ff[46][7:0];
                    mul8_b[j+6] <= V_ff[54][7:0];
                    mul8_b[j+7] <= V_ff[62][7:0];
                end
            end
            'd0: begin
                for(j = 0; j < 64; j = j + 8) begin
                    mul8_b[j] <= V_ff[7][7:0];
                    mul8_b[j+1] <= V_ff[15][7:0];
                    mul8_b[j+2] <= V_ff[23][7:0];
                    mul8_b[j+3] <= V_ff[31][7:0];
                    mul8_b[j+4] <= V_ff[39][7:0];
                    mul8_b[j+5] <= V_ff[47][7:0];
                    mul8_b[j+6] <= V_ff[55][7:0];
                    mul8_b[j+7] <= V_ff[63][7:0];
                end
            end
            default: for(j = 0; j < 64; j = j + 1)  mul8_b[j] <= 'd0;
        endcase
    end
    else begin
        for(j = 0; j < 64; j = j + 1)  mul8_b[j] <= 'd0;
    end
end

assign calA_MAX = (T_ff == 'd1) ? 'd9 : (T_ff == 'd4) ? 'd33 : 'd65;

/*calA_counter*/
always @(posedge clk) begin
    if(cal_stateQKV == 'd2) begin
        case(matrixin_cnt)
            'd57, 'd58, 'd59, 'd60, 'd61, 'd62, 'd63, 'd0, 'd1: calA_counter <= 'd0;
            default: calA_counter <= (calA_counter <= calA_MAX) ? calA_counter + 1'b1 : calA_counter;
        endcase
    end
    else if(cal_stateQKV == 'd3) begin
        case(matrixin_cnt)
            'd57, 'd58, 'd59, 'd60, 'd61, 'd62, 'd63, 'd0, 'd1, 'd2: calA_counter <= (calA_counter <= calA_MAX) ? calA_counter + 1'b1 : calA_counter;
            default: calA_counter <= 'd0;
        endcase
    end
    else calA_counter <= 'd0;
end

/*mul19_a*/
always @(posedge clk) begin
    // if(cal_stateQKV == 'd2) begin
        case(calA_counter) //sent Q'
            'd0, 'd1, 'd2, 'd3, 'd4, 'd5, 'd6, 'd7:
                for(j = 0; j < 8; j = j + 1) mul19_a[j] <= matrix[j][34:16];
            'd8, 'd9, 'd10, 'd11, 'd12, 'd13, 'd14, 'd15:
                for(j = 0; j < 8; j = j + 1) mul19_a[j] <= matrix[j+8][34:16];
            'd16, 'd17, 'd18, 'd19, 'd20, 'd21, 'd22, 'd23:
                for(j = 0; j < 8; j = j + 1) mul19_a[j] <= matrix[j+16][34:16];
            'd24, 'd25, 'd26, 'd27, 'd28, 'd29, 'd30, 'd31:
                for(j = 0; j < 8; j = j + 1) mul19_a[j] <= matrix[j+24][34:16];
            'd32, 'd33, 'd34, 'd35, 'd36, 'd37, 'd38, 'd39:
                for(j = 0; j < 8; j = j + 1) mul19_a[j] <= matrix[j+32][34:16];
            'd40, 'd41, 'd42, 'd43, 'd44, 'd45, 'd46, 'd47:
                for(j = 0; j < 8; j = j + 1) mul19_a[j] <= matrix[j+40][34:16];
            'd48, 'd49, 'd50, 'd51, 'd52, 'd53, 'd54, 'd55:
                for(j = 0; j < 8; j = j + 1) mul19_a[j] <= matrix[j+48][34:16];
            'd56, 'd57, 'd58, 'd59, 'd60, 'd61, 'd62, 'd63: 
                for(j = 0; j < 8; j = j + 1) mul19_a[j] <= matrix[j+56][34:16];
            default: for(j = 0; j < 8; j = j + 1)  mul19_a[j] <= 'd0;
        endcase
    // end
    if(cal_stateQKV == 'd3) begin
        case(matrixin_cnt)
            /* sent V' */
            'd7, 'd15, 'd23, 'd31, 'd39, 'd47, 'd55: begin
                mul19_a[0] <= V_ff[0];
                mul19_a[1] <= V_ff[8];
                mul19_a[2] <= V_ff[16];
                mul19_a[3] <= V_ff[24];
                mul19_a[4] <= V_ff[32];
                mul19_a[5] <= V_ff[40];
                mul19_a[6] <= V_ff[48];
                mul19_a[7] <= V_ff[56];
            end
            'd8, 'd16, 'd24, 'd32, 'd40, 'd48, 'd56: begin
                mul19_a[0] <= V_ff[1];
                mul19_a[1] <= V_ff[9];
                mul19_a[2] <= V_ff[17];
                mul19_a[3] <= V_ff[25];
                mul19_a[4] <= V_ff[33];
                mul19_a[5] <= V_ff[41];
                mul19_a[6] <= V_ff[49];
                mul19_a[7] <= V_ff[57];
            end
            'd9, 'd17, 'd25, 'd33, 'd41, 'd49: begin
                mul19_a[0] <= V_ff[2];
                mul19_a[1] <= V_ff[10];
                mul19_a[2] <= V_ff[18];
                mul19_a[3] <= V_ff[26];
                mul19_a[4] <= V_ff[34];
                mul19_a[5] <= V_ff[42];
                mul19_a[6] <= V_ff[50];
                mul19_a[7] <= V_ff[58];
            end
            'd2, 'd10, 'd18, 'd26, 'd34, 'd42, 'd50: begin
                mul19_a[0] <= V_ff[3];
                mul19_a[1] <= V_ff[11];
                mul19_a[2] <= V_ff[19];
                mul19_a[3] <= V_ff[27];
                mul19_a[4] <= V_ff[35];
                mul19_a[5] <= V_ff[43];
                mul19_a[6] <= V_ff[51];
                mul19_a[7] <= V_ff[59];
            end
            'd3, 'd11, 'd19, 'd27, 'd35, 'd43, 'd51: begin
                mul19_a[0] <= V_ff[4];
                mul19_a[1] <= V_ff[12];
                mul19_a[2] <= V_ff[20];
                mul19_a[3] <= V_ff[28];
                mul19_a[4] <= V_ff[36];
                mul19_a[5] <= V_ff[44];
                mul19_a[6] <= V_ff[52];
                mul19_a[7] <= V_ff[60];
            end
            'd4, 'd12, 'd20, 'd28, 'd36, 'd44, 'd52: begin
                mul19_a[0] <= V_ff[5];
                mul19_a[1] <= V_ff[13];
                mul19_a[2] <= V_ff[21];
                mul19_a[3] <= V_ff[29];
                mul19_a[4] <= V_ff[37];
                mul19_a[5] <= V_ff[45];
                mul19_a[6] <= V_ff[53];
                mul19_a[7] <= V_ff[61];
            end
            'd5, 'd13, 'd21, 'd29, 'd37, 'd45, 'd53: begin
                mul19_a[0] <= V_ff[6];
                mul19_a[1] <= V_ff[14];
                mul19_a[2] <= V_ff[22];
                mul19_a[3] <= V_ff[30];
                mul19_a[4] <= V_ff[38];
                mul19_a[5] <= V_ff[46];
                mul19_a[6] <= V_ff[54];
                mul19_a[7] <= V_ff[62];
            end
            'd6, 'd14, 'd22, 'd30, 'd38, 'd46, 'd54: begin
                mul19_a[0] <= V_ff[7];
                mul19_a[1] <= V_ff[15];
                mul19_a[2] <= V_ff[23];
                mul19_a[3] <= V_ff[31];
                mul19_a[4] <= V_ff[39];
                mul19_a[5] <= V_ff[47];
                mul19_a[6] <= V_ff[55];
                mul19_a[7] <= V_ff[63];
            end   
        endcase
    end
    else if(cal_stateQKV == 'd4) begin
        case(matrixin_cnt) 
            /* sent V' */
            'd57: begin
                mul19_a[0] <= V_ff[2];
                mul19_a[1] <= V_ff[10];
                mul19_a[2] <= V_ff[18];
                mul19_a[3] <= V_ff[26];
                mul19_a[4] <= V_ff[34];
                mul19_a[5] <= V_ff[42];
                mul19_a[6] <= V_ff[50];
                mul19_a[7] <= V_ff[58];
            end
            'd58: begin
                mul19_a[0] <= V_ff[3];
                mul19_a[1] <= V_ff[11];
                mul19_a[2] <= V_ff[19];
                mul19_a[3] <= V_ff[27];
                mul19_a[4] <= V_ff[35];
                mul19_a[5] <= V_ff[43];
                mul19_a[6] <= V_ff[51];
                mul19_a[7] <= V_ff[59];
            end
            'd59: begin
                mul19_a[0] <= V_ff[4];
                mul19_a[1] <= V_ff[12];
                mul19_a[2] <= V_ff[20];
                mul19_a[3] <= V_ff[28];
                mul19_a[4] <= V_ff[36];
                mul19_a[5] <= V_ff[44];
                mul19_a[6] <= V_ff[52];
                mul19_a[7] <= V_ff[60];
            end
            'd60: begin
                mul19_a[0] <= V_ff[5];
                mul19_a[1] <= V_ff[13];
                mul19_a[2] <= V_ff[21];
                mul19_a[3] <= V_ff[29];
                mul19_a[4] <= V_ff[37];
                mul19_a[5] <= V_ff[45];
                mul19_a[6] <= V_ff[53];
                mul19_a[7] <= V_ff[61];
            end
            'd61: begin
                mul19_a[0] <= V_ff[6];
                mul19_a[1] <= V_ff[14];
                mul19_a[2] <= V_ff[22];
                mul19_a[3] <= V_ff[30];
                mul19_a[4] <= V_ff[38];
                mul19_a[5] <= V_ff[46];
                mul19_a[6] <= V_ff[54];
                mul19_a[7] <= V_ff[62];
            end
            'd62: begin
                mul19_a[0] <= V_ff[7];
                mul19_a[1] <= V_ff[15];
                mul19_a[2] <= V_ff[23];
                mul19_a[3] <= V_ff[31];
                mul19_a[4] <= V_ff[39];
                mul19_a[5] <= V_ff[47];
                mul19_a[6] <= V_ff[55];
                mul19_a[7] <= V_ff[63];
            end   
        endcase
    end
end

/*mul40_b*/
always @(posedge clk) begin
    // if(cal_stateQKV == 'd2) begin 
        case(calA_counter) // sent K'
            'd0, 'd8, 'd16, 'd24, 'd32, 'd40, 'd48, 'd56: 
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= {{21{matrix[j][62]}},matrix[j][62:44]};
            'd1, 'd9, 'd17, 'd25, 'd33, 'd41, 'd49, 'd57:
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= {{21{matrix[j+8][62]}},matrix[j+8][62:44]};
            'd2, 'd10, 'd18, 'd26, 'd34, 'd42, 'd50, 'd58:
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= {{21{matrix[j+16][62]}},matrix[j+16][62:44]};
            'd3, 'd11, 'd19, 'd27, 'd35, 'd43, 'd51, 'd59:
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= {{21{matrix[j+24][62]}},matrix[j+24][62:44]};
            'd4, 'd12, 'd20, 'd28, 'd36, 'd44, 'd52, 'd60:
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= {{21{matrix[j+32][62]}},matrix[j+32][62:44]};
            'd5, 'd13, 'd21, 'd29, 'd37, 'd45, 'd53, 'd61:
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= {{21{matrix[j+40][62]}},matrix[j+40][62:44]};
            'd6, 'd14, 'd22, 'd30, 'd38, 'd46, 'd54, 'd62:
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= {{21{matrix[j+48][62]}},matrix[j+48][62:44]};
            'd7, 'd15, 'd23, 'd31, 'd39, 'd47, 'd55, 'd63:
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= {{21{matrix[j+56][62]}},matrix[j+56][62:44]};
            default: for(j = 0; j < 8; j = j + 1) mul40_b[j] <= 'd0;
        endcase
    // end
    if(cal_stateQKV == 'd3) begin
        case(matrixin_cnt) 
            /* sent P */
            'd2, 'd3, 'd4, 'd5, 'd6: begin
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= matrix[j][39:0];
            end
            'd7, 'd8, 'd9, 'd10, 'd11, 'd12, 'd13, 'd14: begin
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= matrix[j+8][39:0];
            end
            'd15, 'd16, 'd17, 'd18, 'd19, 'd20, 'd21, 'd22: begin
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= matrix[j+16][39:0];
            end
            'd23, 'd24, 'd25, 'd26, 'd27, 'd28, 'd29, 'd30: begin
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= matrix[j+24][39:0];
            end
            'd31, 'd32, 'd33, 'd34, 'd35, 'd36, 'd37, 'd38: begin
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= matrix[j+32][39:0];
            end
            'd39, 'd40, 'd41, 'd42, 'd43, 'd44, 'd45, 'd46: begin
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= matrix[j+40][39:0];
            end
            'd47, 'd48, 'd49, 'd50, 'd51, 'd52, 'd53, 'd54: begin
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= matrix[j+48][39:0];
            end
            'd55, 'd56: begin
                for(j = 0; j < 8; j = j + 1) mul40_b[j] <= matrix[j+56][39:0];
            end
        endcase
    end
    else if(cal_stateQKV == 'd4) begin
        for(j = 0; j < 8; j = j + 1) mul40_b[j] <= matrix[j+56][39:0];
    end
end 

/*mul8x8res_add*/
always @(*) begin
    mul8x8res_add[0] = ((mul8x8_res[0] + mul8x8_res[1]) + (mul8x8_res[2] + mul8x8_res[3])) + ((mul8x8_res[4] + mul8x8_res[5]) + (mul8x8_res[6] + mul8x8_res[7]));    
    mul8x8res_add[1] = ((mul8x8_res[8] + mul8x8_res[9]) + (mul8x8_res[10] + mul8x8_res[11])) + ((mul8x8_res[12] + mul8x8_res[13]) + (mul8x8_res[14] + mul8x8_res[15]));
    mul8x8res_add[2] = ((mul8x8_res[16] + mul8x8_res[17]) + (mul8x8_res[18] + mul8x8_res[19])) + ((mul8x8_res[20] + mul8x8_res[21]) + (mul8x8_res[22] + mul8x8_res[23]));
    mul8x8res_add[3] = ((mul8x8_res[24] + mul8x8_res[25]) + (mul8x8_res[26] + mul8x8_res[27])) + ((mul8x8_res[28] + mul8x8_res[29]) + (mul8x8_res[30] + mul8x8_res[31]));
    mul8x8res_add[4] = ((mul8x8_res[32] + mul8x8_res[33]) + (mul8x8_res[34] + mul8x8_res[35])) + ((mul8x8_res[36] + mul8x8_res[37]) + (mul8x8_res[38] + mul8x8_res[39]));
    mul8x8res_add[5] = ((mul8x8_res[40] + mul8x8_res[41]) + (mul8x8_res[42] + mul8x8_res[43])) + ((mul8x8_res[44] + mul8x8_res[45]) + (mul8x8_res[46] + mul8x8_res[47]));
    mul8x8res_add[6] = ((mul8x8_res[48] + mul8x8_res[49]) + (mul8x8_res[50] + mul8x8_res[51])) + ((mul8x8_res[52] + mul8x8_res[53]) + (mul8x8_res[54] + mul8x8_res[55]));
    mul8x8res_add[7] = ((mul8x8_res[56] + mul8x8_res[57]) + (mul8x8_res[58] + mul8x8_res[59])) + ((mul8x8_res[60] + mul8x8_res[61]) + (mul8x8_res[62] + mul8x8_res[63]));
end

/*mul19x40res_add*/
assign mul19x40res_add = ((mul19x40_res[0] + mul19x40_res[1]) + (mul19x40_res[2] + mul19x40_res[3])) + ((mul19x40_res[4] + mul19x40_res[5]) + (mul19x40_res[6] + mul19x40_res[7]));  

/*ReLU_div_res*/
always @(*) ReLU_div_res = (mul19x40res_add[62] == 1) ? 40'd0 : (mul19x40res_add / 2'b11);

/*A_buffer*/
always @(posedge clk) begin
    case(calA_counter) //save A to buffer
        'd1, 'd2, 'd3, 'd4, 'd5, 'd6, 'd7, 'd8: A_buffer[calA_counter - 1] <= ReLU_div_res;
        'd9, 'd10, 'd11, 'd12, 'd13, 'd14, 'd15, 'd16: A_buffer[calA_counter - 9] <= ReLU_div_res;
        'd17, 'd18, 'd19, 'd20, 'd21, 'd22, 'd23, 'd24: A_buffer[calA_counter - 17] <= ReLU_div_res;
        'd25, 'd26, 'd27, 'd28, 'd29, 'd30, 'd31, 'd32: A_buffer[calA_counter - 25] <= ReLU_div_res;
        'd33, 'd34, 'd35, 'd36, 'd37, 'd38, 'd39, 'd40: A_buffer[calA_counter - 33] <= ReLU_div_res;
        'd41, 'd42, 'd43, 'd44, 'd45, 'd46, 'd47, 'd48: A_buffer[calA_counter - 41] <= ReLU_div_res;
        'd49, 'd50, 'd51, 'd52, 'd53, 'd54, 'd55, 'd56: A_buffer[calA_counter - 49] <= ReLU_div_res;
        'd57, 'd58, 'd59, 'd60, 'd61, 'd62, 'd63, 'd64: A_buffer[calA_counter - 57] <= ReLU_div_res;
        default: for(j = 0; j < 8; j = j + 1)  A_buffer[j] <= 'd0;
    endcase
end

/*Multiplier 8x8 bits*/
always @(*) for(i=0 ; i<64 ; i=i+1) mul8x8_res[i] = mul8_a[i] * mul8_b[i];

/*Multiplier 19x40 bits*/
always @(*) for(i=0 ; i<8 ; i=i+1) mul19x40_res[i] = mul19_a[i] * mul40_b[i];

always @(*) begin
    if(T_ff == 'd1) next_pattern_flag = (output_cnt == 'd8) ? 1'b1 : 1'b0;
    else if(T_ff == 'd4) next_pattern_flag = (output_cnt == 'd32) ? 1'b1 : 1'b0;
    else next_pattern_flag = (output_cnt == 'd63) ? 1'b1 : 1'b0;
end

always @(*) begin
    if(cal_stateQKV == 'd3) begin
        case(matrixin_cnt) 
            'd59:begin
                mul19_a2[0] = V_ff[0];
                mul19_a2[1] = V_ff[8];
                mul19_a2[2] = V_ff[16];
                mul19_a2[3] = V_ff[24];
            end
            'd60:begin
                mul19_a2[0] = V_ff[32];
                mul19_a2[1] = V_ff[40];
                mul19_a2[2] = V_ff[48];
                mul19_a2[3] = V_ff[56];
            end
            'd61:begin
                mul19_a2[0] = V_ff[1];
                mul19_a2[1] = V_ff[9];
                mul19_a2[2] = V_ff[17];
                mul19_a2[3] = V_ff[25];
            end
            'd62:begin
                mul19_a2[0] = V_ff[33];
                mul19_a2[1] = V_ff[41];
                mul19_a2[2] = V_ff[49];
                mul19_a2[3] = V_ff[57];
            end
            'd0:begin
                mul19_a2[0] = V_ff[2];
                mul19_a2[1] = V_ff[10];
                mul19_a2[2] = V_ff[18];
                mul19_a2[3] = V_ff[26];
            end
            'd1:begin
                mul19_a2[0] = V_ff[34];
                mul19_a2[1] = V_ff[42];
                mul19_a2[2] = V_ff[50];
                mul19_a2[3] = V_ff[58];
            end
            default: for(i=0 ; i<4 ; i=i+1) mul19_a2[i] = 'd0;
        endcase
    end
    else for(i=0 ; i<4 ; i=i+1) mul19_a2[i] = 'd0;
end

always @(*) begin
    if(cal_stateQKV == 'd3) begin
        case(matrixin_cnt) 
            'd59, 'd61, 'd0:begin
                mul40_b2[0] = matrix[0][39:0];
                mul40_b2[1] = matrix[1][39:0];
                mul40_b2[2] = matrix[2][39:0];
                mul40_b2[3] = matrix[3][39:0];
            end
            'd60, 'd62, 'd1:begin
                mul40_b2[0] = matrix[4][39:0];
                mul40_b2[1] = matrix[5][39:0];
                mul40_b2[2] = matrix[6][39:0];
                mul40_b2[3] = matrix[7][39:0];
            end
            default: for(i=0 ; i<4 ; i=i+1) mul40_b2[i] = 'd0;
        endcase
    end
    else for(i=0 ; i<4 ; i=i+1) mul40_b2[i] = 'd0;
end 


 /*Multiplier2 19x40 bits*/
always @(*) for(i=0 ; i<4 ; i=i+1) mul19x40_res2[i] = mul19_a2[i] * mul40_b2[i];

always @(posedge clk) begin
    if(cal_stateQKV == 'd3) begin
        case(matrixin_cnt) 
            'd59:begin
                temp_out[0] <= (mul19x40_res2[0] + mul19x40_res2[1]) + (mul19x40_res2[2] + mul19x40_res2[3]);
            end
            'd60:begin
                temp_out[0] <= temp_out[0] + ((mul19x40_res2[0] + mul19x40_res2[1]) + (mul19x40_res2[2] + mul19x40_res2[3]));
            end
            'd61:begin
                temp_out[1] <= (mul19x40_res2[0] + mul19x40_res2[1]) + (mul19x40_res2[2] + mul19x40_res2[3]);
            end
            'd62:begin
                temp_out[1] <= temp_out[1] + ((mul19x40_res2[0] + mul19x40_res2[1]) + (mul19x40_res2[2] + mul19x40_res2[3]));
            end
            'd63:begin
                temp_out[0] <= temp_out[0];
                temp_out[1] <= temp_out[1];
            end
            'd0:begin
                temp_out[0] <= ((mul19x40_res2[0] + mul19x40_res2[1]) + (mul19x40_res2[2] + mul19x40_res2[3]));
            end
            'd1:begin
                temp_out[0] <= temp_out[0] + ((mul19x40_res2[0] + mul19x40_res2[1]) + (mul19x40_res2[2] + mul19x40_res2[3]));
            end
            default: begin
                temp_out[0] <= 'd0;
                temp_out[1] <= 'd0;
            end
        endcase
    end
    else begin
        temp_out[0] <= 'd0;
        temp_out[1] <= 'd0;
    end
end

always @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		out_valid <= 1'b0;
		out_data <= 'd0;
        output_cnt <= 'd0;
	end
	else begin
        if(!in_valid) begin
            if(T_ff == 'd1) begin
                if(cal_stateQKV == 'd3 && matrixin_cnt >= 'd0 && matrixin_cnt <= 'd7) begin
                    output_cnt <= output_cnt + 1'b1;
                    out_valid <= 1'b1;
                    out_data <= (output_cnt == 'd0 || output_cnt == 'd2) ? temp_out[0] : (output_cnt == 'd1) ? temp_out[1] : mul19x40res_add;
                end
                else begin
                    output_cnt <= 'd0;
                    out_valid <= 1'b0;
                    out_data <= 'd0;
                end
            end
            else if(T_ff == 'd4) begin
                if(cal_stateQKV == 'd3 && matrixin_cnt >= 'd0 && matrixin_cnt <= 'd31) begin
                    output_cnt <= output_cnt + 1'b1;
                    out_valid <= 1'b1;
                    out_data <= (output_cnt == 'd0 || output_cnt == 'd2) ? temp_out[0] : (output_cnt == 'd1) ? temp_out[1] : mul19x40res_add;
                end
                else begin
                    output_cnt <= 'd0;
                    out_valid <= 1'b0;
                    out_data <= 'd0;
                end
            end
            else begin
                if(cal_stateQKV == 'd3 && matrixin_cnt >= 'd0) begin
                    output_cnt <= output_cnt + 1'b1;
                    out_valid <= 1'b1;
                    out_data <= (output_cnt == 'd0 || output_cnt == 'd2) ? temp_out[0] : (output_cnt == 'd1) ? temp_out[1] : mul19x40res_add;
                end
                else if(cal_stateQKV == 'd4) begin
                    output_cnt <= output_cnt + 1'b1;
                    out_valid <= 1'b1;
                    out_data <= (output_cnt == 'd0 || output_cnt == 'd2) ? temp_out[0] : (output_cnt == 'd1) ? temp_out[1] : mul19x40res_add;
                end
                else begin
                    output_cnt <= 'd0;
                    out_valid <= 1'b0;
                    out_data <= 'd0;
                end
            end
        end
        else begin
            output_cnt <= 'd0;
            out_valid <= 1'b0;
            out_data <= 'd0;
        end
	end
end

endmodule
