/**************************************************************************/
// Copyright (c) 2024, OASIS Lab
// MODULE: TETRIS
// FILE NAME: TETRIS.v
// VERSRION: 1.0
// DATE: August 15, 2024
// AUTHOR: Yu-Hsuan Hsu, NYCU IEE
// DESCRIPTION: ICLAB2024FALL / LAB3 / TETRIS
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/
module TETRIS (
	//INPUT
	rst_n,
	clk,
	in_valid,
	tetrominoes,
	position,
	//OUTPUTL
	tetris_valid,
	score_valid,
	fail,
	score,
	tetris
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input				rst_n, clk, in_valid;
input		[2:0]	tetrominoes;
input		[2:0]	position;
output reg			tetris_valid, score_valid, fail;
output reg	[3:0]	score;
output reg 	[71:0]	tetris;

//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer i, j;

// FSM states
parameter UPDATE_ROW_RECORD = 2'd00;
parameter UPDATE_MAP = 2'd01;
parameter SHIFT_MAP = 2'd10;
parameter OUTPUT_SCORE = 2'd11;

//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------
reg [90:0] map;
reg [3:0] row_record [0:5]; //Store MAX position
reg [3:0] max1, max2, max_value;
reg [2:0] curr_pos, curr_tetrom, temp_score;
reg [11:0] row_score;
reg [4:0] tetris_cnt;
reg [4:0] total_score; 
reg [3:0] one_flag;
reg [2:0] one_state;
reg [2:0] shift_state [0:2];
reg [2:0] shift_all [0:14];

// reg [11:0]row_record_0, row_record_1, row_record_2, row_record_3, row_record_4, row_record_5;
reg [11:0] map_col0, map_col1, map_col2, map_col3, map_col4, map_col5;
reg [3:0] row_max_0,row_max_1,row_max_2,row_max_3,row_max_4,row_max_5;

reg [1:0] current_state, next_state;

//==============================================//
//             Current State Block              //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        current_state <= UPDATE_ROW_RECORD;
    else 
        current_state <= next_state;
end

//==============================================//
//              Next State Block                //
//==============================================//
always @(*) begin
    if(!rst_n) next_state = UPDATE_ROW_RECORD;
    else if (current_state == UPDATE_ROW_RECORD) begin
		if(in_valid) next_state = UPDATE_MAP;
		else next_state = UPDATE_ROW_RECORD;
	end
	else if (current_state == UPDATE_MAP) next_state = SHIFT_MAP;
	else if (current_state == SHIFT_MAP) next_state = OUTPUT_SCORE;
	else next_state = UPDATE_ROW_RECORD;
end

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		tetris_cnt <= 4'b0;
    end
	else begin
		if (in_valid) begin
			tetris_cnt <= tetris_cnt + 1;
		end
		else begin
			if(tetris_valid) begin
				tetris_cnt <= 4'b0;
			end
		end
	end
end

always @(*) begin
	case(tetrominoes)
		3'b010: begin
			max1 = (row_record[position] > row_record[position+1]) ? 
				row_record[position] : row_record[position+1];

			max2 = (row_record[position+2] > row_record[position+3]) ? 
				row_record[position+2] : row_record[position+3];

			max_value = (max1 > max2) ? (max1 + 1) : (max2 + 1);
		end
		3'b100: begin
			// $display("row_record: %d %d %d %d %d %d @ %d",row_record[0], row_record[1], row_record[2], row_record[3], row_record[4], row_record[5], $time);

			max1 = ((row_record[position+2]) > row_record[position+1]) ? 
			row_record[position+2] : row_record[position+1];
			max2 = 0;

			max_value = (max1 > (row_record[position]+1)) ? (max1+1) : (row_record[position]+2);
		end
		3'b111: begin
			max1 = ((row_record[position]) > row_record[position+1]) ? 
			row_record[position] : row_record[position+1];
			max2 = 0;
			max_value = 0;
		end
		default: begin
			max1 = 'b0;
			max2 = 'b0;
			max_value = 'b0;
		end
	endcase
end
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		for (i = 0; i < 6; i = i + 1) begin
            row_record[i] <= 4'b0;
        end
    end
	else if( tetris_valid ) begin
		for (i = 0; i < 6; i = i + 1) begin
			row_record[i] <= 4'b0;
		end
	end
	else begin
		if (current_state == UPDATE_ROW_RECORD) begin
			if (in_valid) begin
				// max1 <= 4'b0;
				// max2 <= 4'b0;
				// max_value <= 4'b0;
				curr_tetrom <= tetrominoes;
				curr_pos <= position;
				case(tetrominoes)
					3'b000: begin
						if(row_record[position] > row_record[position+1]) begin
							row_record[position] <= row_record[position] + 2 ; 
							row_record[position+1] <= row_record[position] + 2 ; 
						end
						else begin
							row_record[position] <= row_record[position+1] + 2 ; 
							row_record[position+1] <= row_record[position+1] + 2 ; 
						end
					end
					3'b001: begin
						// row_record[position] <= row_record[position]>11? 4'd15:row_record[position] + 4;
						if( row_record[position] > 11 ) row_record[position] <= 4'd15;
						else row_record[position] <= row_record[position] + 4;
					end
					3'b010: begin
						// max1 <= (row_record[position] > row_record[position+1]) ? 
						// 	row_record[position] : row_record[position+1];

						// max2 <= (row_record[position+2] > row_record[position+3]) ? 
						// 	row_record[position+2] : row_record[position+3];

						// max_value <= (max1 > max2) ? (max1 + 1) : (max2 + 1);
						// $display("max value: %d time %d ",max_value, $time);
						// $display("max1: %d max2 %d position %d",max1, max2, position);
						// $display("row_record: %d %d %d %d %d %d ",row_record[0], row_record[1], row_record[2], row_record[3], row_record[4], row_record[5]);

						row_record[position] <= max_value; 
						row_record[position+1] <= max_value; 
						row_record[position+2] <= max_value; 
						row_record[position+3] <= max_value; 
					end
					3'b011: begin
						if( row_record[position] > (row_record[position+1] + 2) ) begin
							row_record[position] <= row_record[position] + 1 ; 
							row_record[position+1] <= row_record[position] + 1 ; 

						end
						else begin
							row_record[position] <= row_record[position+1] + 3 ; 
							row_record[position+1] <= row_record[position+1] + 3 ; 

						end
					end
					3'b100: begin
						// max1 = ((row_record[position+2]) > row_record[position+1]) ? 
						// 	row_record[position+2] : row_record[position+1];

						// max_value = (max1 > (row_record[position]+1)) ? (max1+1) : (row_record[position]+2);
						// $display("maxV: %d max2 %d position %d",max_value, max2, position);
						row_record[position] <= max_value; 
						row_record[position+1] <= max_value; 
						row_record[position+2] <= max_value; 
					end
					3'b101: begin
						if(row_record[position] > row_record[position+1]) begin
							row_record[position] <= row_record[position] + 3 ; 
							row_record[position+1] <= row_record[position] + 1 ; 
						end
						else begin
							row_record[position] <= row_record[position+1] + 3 ; 
							row_record[position+1] <= row_record[position+1] + 1 ; 
						end
					end
					3'b110: begin
						if( row_record[position] > (row_record[position+1]+1) ) begin
							row_record[position] <= row_record[position] + 2 ; 
							row_record[position+1] <= row_record[position] + 1 ; 
						end
						else begin
							row_record[position] <= row_record[position+1] + 3 ; 
							row_record[position+1] <= row_record[position+1] + 2 ; 
						end
					end
					3'b111: begin
						// max1 = ((row_record[position]) > row_record[position+1]) ? 
						// 	row_record[position] : row_record[position+1];

						if(max1 >= row_record[position+2]) begin
							row_record[position] <= max1 + 1; 
							row_record[position+1] <= max1 + 2; 
							row_record[position+2] <= max1 + 2; 
						end
						else begin
							row_record[position] <= row_record[position+2]; 
							row_record[position+1] <= row_record[position+2] + 1; 
							row_record[position+2] <= row_record[position+2] + 1; 
						end
					end

				endcase
			end
		end
		else if(current_state == OUTPUT_SCORE && ~((|map[90:72] == 1) || tetris_cnt == 'd16) ) begin
			row_record[0] <= row_max_0;
			row_record[1] <= row_max_1;
			row_record[2] <= row_max_2;
			row_record[3] <= row_max_3;
			row_record[4] <= row_max_4;
			row_record[5] <= row_max_5;
		end
		else begin
			if( tetris_valid ) begin
				for (i = 0; i < 6; i = i + 1) begin
					row_record[i] <= 4'b0;
				end
			end
		end
	end
end

find_top_row find0(.map_x(map_col0), .row_max(row_max_0));
find_top_row find1(.map_x(map_col1), .row_max(row_max_1));
find_top_row find2(.map_x(map_col2), .row_max(row_max_2));
find_top_row find3(.map_x(map_col3), .row_max(row_max_3));
find_top_row find4(.map_x(map_col4), .row_max(row_max_4));
find_top_row find5(.map_x(map_col5), .row_max(row_max_5));


// always @(*)begin
// 	row_record_1 = row_record[1];
// 	row_record_2 = row_record[2];
// 	row_record_3 = row_record[3];
// 	row_record_4 = row_record[4];
// 	row_record_5 = row_record[5];
// end

always @(*) begin
    map_col0 = {map[66], map[60], map[54], map[48], map[42], map[36], map[30], map[24], map[18], map[12], map[6], map[0]};
    map_col1 = {map[67], map[61], map[55], map[49], map[43], map[37], map[31], map[25], map[19], map[13], map[7], map[1]};
    map_col2 = {map[68], map[62], map[56], map[50], map[44], map[38], map[32], map[26], map[20], map[14], map[8], map[2]};
    map_col3 = {map[69], map[63], map[57], map[51], map[45], map[39], map[33], map[27], map[21], map[15], map[9], map[3]};
    map_col4 = {map[70], map[64], map[58], map[52], map[46], map[40], map[34], map[28], map[22], map[16], map[10], map[4]};
    map_col5 = {map[71], map[65], map[59], map[53], map[47], map[41], map[35], map[29], map[23], map[17], map[11], map[5]};
end


always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		map <= 9'b0;
		// total_score <= 'b0;
    end
	else begin
		if (current_state == UPDATE_MAP) begin
			case(curr_tetrom)
				3'b000: begin
					map[(row_record[curr_pos] - 2) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos] - 2) * 6 + curr_pos + 1] <= 1'b1;
					map[(row_record[curr_pos] - 1) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos] - 1) * 6 + curr_pos + 1] <= 1'b1;
				end
				3'b001: begin
					map[(row_record[curr_pos] - 1) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos] - 2) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos] - 3) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos] - 4) * 6 + curr_pos] <= 1'b1;
				end
				3'b010: begin
					map[(row_record[curr_pos] - 1) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos] - 1) * 6 + curr_pos + 1] <= 1'b1;
					map[(row_record[curr_pos] - 1) * 6 + curr_pos + 2] <= 1'b1;
					map[(row_record[curr_pos] - 1) * 6 + curr_pos + 3] <= 1'b1;
				end
				3'b011: begin
					map[(row_record[curr_pos] - 1) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos] - 1) * 6 + curr_pos + 1] <= 1'b1;
					map[(row_record[curr_pos] - 2) * 6 + curr_pos + 1] <= 1'b1;
					map[(row_record[curr_pos] - 3) * 6 + curr_pos + 1] <= 1'b1;
				end
				3'b100: begin
					map[(row_record[curr_pos] - 1) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos] - 1) * 6 + curr_pos + 1] <= 1'b1;
					map[(row_record[curr_pos] - 1) * 6 + curr_pos + 2] <= 1'b1;
					map[(row_record[curr_pos] - 2) * 6 + curr_pos] <= 1'b1;
				end
				3'b101: begin
					map[(row_record[curr_pos] - 1) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos] - 2) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos] - 3) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos + 1] - 1) * 6 + curr_pos + 1] <= 1'b1;
				end
				3'b110: begin
					map[(row_record[curr_pos] - 1) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos] - 2) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos + 1] - 1) * 6 + curr_pos + 1] <= 1'b1;
					map[(row_record[curr_pos + 1] - 2) * 6 + curr_pos + 1] <= 1'b1;
				end
				3'b111: begin
					map[(row_record[curr_pos] - 1) * 6 + curr_pos] <= 1'b1;
					map[(row_record[curr_pos + 1] - 1) * 6 + curr_pos + 1] <= 1'b1;
					map[(row_record[curr_pos + 1] - 2) * 6 + curr_pos + 1] <= 1'b1;
					map[(row_record[curr_pos + 2] - 1) * 6 + curr_pos + 2] <= 1'b1;
				end
			endcase
		end
		else if (current_state == SHIFT_MAP) begin
			// $display("map = %h, @time = %d", map, $time);
			map[5:0]   <= shift_all[0]==1? map[11:6]:  shift_all[0] == 2? map[17:12]: shift_all[0] == 3? map[23:18]: shift_all[0] == 4? map[29:24]: map[5:0];
			map[11:6]  <= shift_all[1]==1? map[17:12]: shift_all[1] == 2? map[23:18]: shift_all[1] == 3? map[29:24]: shift_all[1] == 4? map[35:30]: map[11:6];
			map[17:12] <= shift_all[2]==1? map[23:18]: shift_all[2] == 2? map[29:24]: shift_all[2] == 3? map[35:30]: shift_all[2] == 4? map[41:36]: map[17:12];
			map[23:18] <= shift_all[3]==1? map[29:24]: shift_all[3] == 2? map[35:30]: shift_all[3] == 3? map[41:36]: shift_all[3] == 4? map[47:42]: map[23:18];
			map[29:24] <= shift_all[4]==1? map[35:30]: shift_all[4] == 2? map[41:36]: shift_all[4] == 3? map[47:42]: shift_all[4] == 4? map[53:48]: map[29:24];
			map[35:30] <= shift_all[5]==1? map[41:36]: shift_all[5] == 2? map[47:42]: shift_all[5] == 3? map[53:48]: shift_all[5] == 4? map[59:54]: map[35:30];
			map[41:36] <= shift_all[6]==1? map[47:42]: shift_all[6] == 2? map[53:48]: shift_all[6] == 3? map[59:54]: shift_all[6] == 4? map[65:60]: map[41:36];
			map[47:42] <= shift_all[7]==1? map[53:48]: shift_all[7] == 2? map[59:54]: shift_all[7] == 3? map[65:60]: shift_all[7] == 4? map[71:66]: map[47:42];
			map[53:48] <= shift_all[8]==1? map[59:54]: shift_all[8] == 2? map[65:60]: shift_all[8] == 3? map[71:66]: shift_all[8] == 4? map[77:72]: map[53:48];
			map[59:54] <= shift_all[9]==1? map[65:60]: shift_all[9] == 2? map[71:66]: shift_all[9] == 3? map[77:72]: shift_all[9] == 4? map[83:78]: map[59:54];
			map[65:60] <= shift_all[10]==1? map[71:66]: shift_all[10] == 2? map[77:72]: shift_all[10] == 3? map[83:78]: shift_all[10] == 4? map[89:84]: map[65:60];
			map[71:66] <= shift_all[11]==1? map[77:72]: shift_all[11] == 2? map[83:78]: shift_all[11] == 3? map[89:84]: shift_all[11] == 4? 6'b0 : map[71:66];
			map[77:72] <= shift_all[12]==1? map[83:78]: (shift_all[12] == 2? map[89:84]: (shift_all[12] == 3? 6'b0 : map[77:72]));
			map[83:78] <= shift_all[13]==1? map[89:84]: (shift_all[13] == 2? 6'b0: map[83:78]);
			map[89:84] <= shift_all[14]? 6'b0 : map[89:84];
		end
		else begin
			if(tetris_valid) begin
				map <= 91'b0;	
			end
		end
	end
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		total_score <= 'b0;
    end
	else begin
		if (current_state == SHIFT_MAP) total_score <= total_score + temp_score;
		else begin
			if(tetris_valid) begin
				total_score <= 'b0;
			end
		end
	end
end

always@(*) begin
	row_score[0] = &map[5:0];    // 0-5 位
	row_score[1] = &map[11:6];   // 6-11 位
	row_score[2] = &map[17:12];  // 12-17 位
	row_score[3] = &map[23:18];  // 18-23 位
	row_score[4] = &map[29:24];  // 24-29 位
	row_score[5] = &map[35:30];  // 30-35 位
	row_score[6] = &map[41:36];  // 36-41 位
	row_score[7] = &map[47:42];  // 42-47 位
	row_score[8] = &map[53:48];  // 48-53 位
	row_score[9] = &map[59:54];  // 54-59 位
	row_score[10] = &map[65:60]; // 60-65 位
	row_score[11] = &map[71:66]; // 66-71 位
end

always@(*) begin
	temp_score = row_score[0] + row_score[1] + row_score[2] + row_score[3] +
		row_score[4] + row_score[5] + row_score[6] + row_score[7] +
		row_score[8] + row_score[9] + row_score[10] + row_score[11];
end

always@(*) begin
	if (row_score[0]) one_flag = 4'd0;
	else if (row_score[1]) one_flag = 4'd1;
	else if (row_score[2]) one_flag = 4'd2;
	else if (row_score[3]) one_flag = 4'd3;
	else if (row_score[4]) one_flag = 4'd4;
	else if (row_score[5]) one_flag = 4'd5;
	else if (row_score[6]) one_flag = 4'd6;
	else if (row_score[7]) one_flag = 4'd7;
	else if (row_score[8]) one_flag = 4'd8;
	else if (row_score[9]) one_flag = 4'd9;
	else if (row_score[10]) one_flag = 4'd10;
	else if (row_score[11]) one_flag = 4'd11;
	else  one_flag = 4'd15;
end

always@(*) begin
	case(one_flag)
		// 4'd0: one_state = {row_score[1], row_score[2], row_score[3]};
		// 4'd1: one_state = {row_score[2], row_score[3], row_score[4]};
		// 4'd2: one_state = {row_score[3], row_score[4], row_score[5]};
		// 4'd3: one_state = {row_score[4], row_score[5], row_score[6]};
		// 4'd4: one_state = {row_score[5], row_score[6], row_score[7]};
		// 4'd5: one_state = {row_score[6], row_score[7], row_score[8]};
		// 4'd6: one_state = {row_score[7], row_score[8], row_score[9]};
		// 4'd7: one_state = {row_score[8], row_score[9], row_score[10]};
		// 4'd8: one_state = {row_score[9], row_score[10], row_score[11]};
		// 4'd9: one_state = {row_score[10], row_score[11], 1'b0};
		// 4'd10: one_state = {row_score[11], 1'b0, 1'b0}; 
		// 4'd11: one_state = {1'b0, 1'b0, 1'b0};
		// default: one_state = {1'b0, 1'b0, 1'b0};
		4'd0: one_state = {row_score[3], row_score[2], row_score[1]};
		4'd1: one_state = {row_score[4], row_score[3], row_score[2]};
		4'd2: one_state = {row_score[5], row_score[4], row_score[3]};
		4'd3: one_state = {row_score[6], row_score[5], row_score[4]};
		4'd4: one_state = {row_score[7], row_score[6], row_score[5]};
		4'd5: one_state = {row_score[8], row_score[7], row_score[6]};
		4'd6: one_state = {row_score[9], row_score[8], row_score[7]};
		4'd7: one_state = {row_score[10], row_score[9], row_score[8]};
		4'd8: one_state = {row_score[11], row_score[10], row_score[9]};
		4'd9: one_state = {1'b0, row_score[11], row_score[10]};
		4'd10: one_state = {1'b0, 1'b0, row_score[11]};
		4'd11: one_state = {1'b0, 1'b0, 1'b0};
		default: one_state = {1'b0, 1'b0, 1'b0};

	endcase
end

always@(*) begin
	case(one_state)
		3'b000: begin
			shift_state[0] = 1;
			shift_state[1] = 1;
			shift_state[2] = 1;
		end
		3'b001: begin
			shift_state[0] = 2;
			shift_state[1] = 2;
			shift_state[2] = 2;
		end
		3'b010: begin
			shift_state[0] = 1;
			shift_state[1] = 2;
			shift_state[2] = 2;
		end
		3'b011: begin
			shift_state[0] = 3;
			shift_state[1] = 3;
			shift_state[2] = 3;
		end
		3'b100: begin
			shift_state[0] = 1;
			shift_state[1] = 1;
			shift_state[2] = 2;
		end
		3'b101: begin
			shift_state [0] = 2;
			shift_state[1] = 3;
			shift_state[2] = 3;
		end
		3'b110: begin
			shift_state[0] = 1;
			shift_state[1] = 3;
			shift_state[2] = 3;
		end
		3'b111: begin
			shift_state[0] = 4;
			shift_state[1] = 4;
			shift_state[2] = 4;
		end
	endcase
end

always@(*) begin
	case(one_flag)
		4'd0: begin
			shift_all[0] = shift_state[0];
			shift_all[1] = shift_state[1];
			shift_all[2] = shift_state[2];
			shift_all[3] = shift_state[2];
			shift_all[4] = shift_state[2];
			shift_all[5] = shift_state[2];
			shift_all[6] = shift_state[2];
			shift_all[7] = shift_state[2];
			shift_all[8] = shift_state[2];
			shift_all[9] = shift_state[2];
			shift_all[10] = shift_state[2];
			shift_all[11] = shift_state[2];
			shift_all[12] = shift_state[2];
			shift_all[13] = shift_state[2];
			shift_all[14] = shift_state[2];
		end
		4'd1: begin
			shift_all[0] = 3'd0;
			shift_all[1] = shift_state[0];
			shift_all[2] = shift_state[1];
			shift_all[3] = shift_state[2];
			shift_all[4] = shift_state[2];
			shift_all[5] = shift_state[2];
			shift_all[6] = shift_state[2];
			shift_all[7] = shift_state[2];
			shift_all[8] = shift_state[2];
			shift_all[9] = shift_state[2];
			shift_all[10] = shift_state[2];
			shift_all[11] = shift_state[2];
			shift_all[12] = shift_state[2];
			shift_all[13] = shift_state[2];
			shift_all[14] = shift_state[2];
		end
		4'd2: begin
			shift_all[0] = 3'd0;
			shift_all[1] = 3'd0;
			shift_all[2] = shift_state[0];
			shift_all[3] = shift_state[1];
			shift_all[4] = shift_state[2];
			shift_all[5] = shift_state[2];
			shift_all[6] = shift_state[2];
			shift_all[7] = shift_state[2];
			shift_all[8] = shift_state[2];
			shift_all[9] = shift_state[2];
			shift_all[10] = shift_state[2];
			shift_all[11] = shift_state[2];
			shift_all[12] = shift_state[2];
			shift_all[13] = shift_state[2];
			shift_all[14] = shift_state[2];
		end
		4'd3: begin
			shift_all[0] = 3'd0;
			shift_all[1] = 3'd0;
			shift_all[2] = 3'd0;
			shift_all[3] = shift_state[0];
			shift_all[4] = shift_state[1];
			shift_all[5] = shift_state[2];
			shift_all[6] = shift_state[2];
			shift_all[7] = shift_state[2];
			shift_all[8] = shift_state[2];
			shift_all[9] = shift_state[2];
			shift_all[10] = shift_state[2];
			shift_all[11] = shift_state[2];
			shift_all[12] = shift_state[2];
			shift_all[13] = shift_state[2];
			shift_all[14] = shift_state[2];
		end
		4'd4: begin
			shift_all[0] = 3'd0;
			shift_all[1] = 3'd0;
			shift_all[2] = 3'd0;
			shift_all[3] = 3'd0;
			shift_all[4] = shift_state[0];
			shift_all[5] = shift_state[1];
			shift_all[6] = shift_state[2];
			shift_all[7] = shift_state[2];
			shift_all[8] = shift_state[2];
			shift_all[9] = shift_state[2];
			shift_all[10] = shift_state[2];
			shift_all[11] = shift_state[2];
			shift_all[12] = shift_state[2];
			shift_all[13] = shift_state[2];
			shift_all[14] = shift_state[2];
		end
		4'd5: begin
			shift_all[0] = 3'd0;
			shift_all[1] = 3'd0;
			shift_all[2] = 3'd0;
			shift_all[3] = 3'd0;
			shift_all[4] = 3'd0;
			shift_all[5] = shift_state[0];
			shift_all[6] = shift_state[1];
			shift_all[7] = shift_state[2];
			shift_all[8] = shift_state[2];
			shift_all[9] = shift_state[2];
			shift_all[10] = shift_state[2];
			shift_all[11] = shift_state[2];
			shift_all[12] = shift_state[2];
			shift_all[13] = shift_state[2];
			shift_all[14] = shift_state[2];
		end
		4'd6: begin
			shift_all[0] = 3'd0;
			shift_all[1] = 3'd0;
			shift_all[2] = 3'd0;
			shift_all[3] = 3'd0;
			shift_all[4] = 3'd0;
			shift_all[5] = 3'd0;
			shift_all[6] = shift_state[0];
			shift_all[7] = shift_state[1];
			shift_all[8] = shift_state[2];
			shift_all[9] = shift_state[2];
			shift_all[10] = shift_state[2];
			shift_all[11] = shift_state[2];
			shift_all[12] = shift_state[2];
			shift_all[13] = shift_state[2];
			shift_all[14] = shift_state[2];
		end
		4'd7: begin
			shift_all[0] = 3'd0;
			shift_all[1] = 3'd0;
			shift_all[2] = 3'd0;
			shift_all[3] = 3'd0;
			shift_all[4] = 3'd0;
			shift_all[5] = 3'd0;
			shift_all[6] = 3'd0;
			shift_all[7] = shift_state[0];
			shift_all[8] = shift_state[1];
			shift_all[9] = shift_state[2];
			shift_all[10] = shift_state[2];
			shift_all[11] = shift_state[2];
			shift_all[12] = shift_state[2];
			shift_all[13] = shift_state[2];
			shift_all[14] = shift_state[2];
		end
		4'd8: begin
			shift_all[0] = 3'd0;
			shift_all[1] = 3'd0;
			shift_all[2] = 3'd0;
			shift_all[3] = 3'd0;
			shift_all[4] = 3'd0;
			shift_all[5] = 3'd0;
			shift_all[6] = 3'd0;
			shift_all[7] = 3'd0;
			shift_all[8] = shift_state[0];
			shift_all[9] = shift_state[1];
			shift_all[10] = shift_state[2];
			shift_all[11] = shift_state[2];
			shift_all[12] = shift_state[2];
			shift_all[13] = shift_state[2];
			shift_all[14] = shift_state[2];
		end
		4'd9: begin
			shift_all[0] = 3'd0;
			shift_all[1] = 3'd0;
			shift_all[2] = 3'd0;
			shift_all[3] = 3'd0;
			shift_all[4] = 3'd0;
			shift_all[5] = 3'd0;
			shift_all[6] = 3'd0;
			shift_all[7] = 3'd0;
			shift_all[8] = 3'd0;
			shift_all[9] = shift_state[0];
			shift_all[10] = shift_state[1];
			shift_all[11] = shift_state[2];
			shift_all[12] = shift_state[2];
			shift_all[13] = shift_state[2];
			shift_all[14] = shift_state[2];
		end
		4'd10: begin
			shift_all[0] = 3'd0;
			shift_all[1] = 3'd0;
			shift_all[2] = 3'd0;
			shift_all[3] = 3'd0;
			shift_all[4] = 3'd0;
			shift_all[5] = 3'd0;
			shift_all[6] = 3'd0;
			shift_all[7] = 3'd0;
			shift_all[8] = 3'd0;
			shift_all[9] = 3'd0;
			shift_all[10] = shift_state[0];
			shift_all[11] = shift_state[1];
			shift_all[12] = shift_state[2];
			shift_all[13] = shift_state[2];
			shift_all[14] = shift_state[2];
		end
		4'd11: begin
			shift_all[0] = 3'd0;
			shift_all[1] = 3'd0;
			shift_all[2] = 3'd0;
			shift_all[3] = 3'd0;
			shift_all[4] = 3'd0;
			shift_all[5] = 3'd0;
			shift_all[6] = 3'd0;
			shift_all[7] = 3'd0;
			shift_all[8] = 3'd0;
			shift_all[9] = 3'd0;
			shift_all[10] = 3'd0;
			shift_all[11] = shift_state[0];
			shift_all[12] = shift_state[1];
			shift_all[13] = shift_state[2];
			shift_all[14] = shift_state[2];
		end
		default: begin
			shift_all[1] = 'b0;
			shift_all[0] = 'b0;
			shift_all[2] = 'b0;
			shift_all[3] = 'b0;
			shift_all[4] = 'b0;
			shift_all[5] = 'b0;
			shift_all[6] = 'b0;
			shift_all[7] = 'b0;
			shift_all[8] = 'b0;
			shift_all[9] = 'b0;
			shift_all[10] = 'b0;
			shift_all[11] = 'b0;
			shift_all[12] = 'b0;
			shift_all[13] = 'b0;
			shift_all[14] = 'b0;
		end
	endcase
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		tetris_valid <= 1'b0;
		score_valid <= 1'b0;
		fail <= 1'b0;
		score <= 4'b0;
		tetris <= 72'b0;
    end
	else begin
		if (current_state == OUTPUT_SCORE) begin
			score_valid <= 1'b1;
			fail <= |(map[90:72]);

			if( (|map[90:72] == 1) || tetris_cnt == 'd16) begin
				tetris_valid <= 1'b1;
				tetris <= map[71:0];
			end
			score <= total_score;
		end
		else begin
			score_valid <= 1'b0;
			fail <= 1'b0;
			tetris_valid <= 1'b0;
			score <= 4'b0;
			tetris <= 72'b0;
		end
	end
end

endmodule

module  find_top_row(
	input [11:0] map_x,
	output reg [3:0] row_max
);

always @(*)begin
	if(map_x[11]) row_max = 4'd12;
	else if(map_x[10]) row_max = 4'd11;
	else if(map_x[9]) row_max = 4'd10;
	else if(map_x[8]) row_max = 4'd9;
	else if(map_x[7]) row_max = 4'd8;
	else if(map_x[6]) row_max = 4'd7;
	else if(map_x[5]) row_max = 4'd6;
	else if(map_x[4]) row_max = 4'd5;
	else if(map_x[3]) row_max = 4'd4;
	else if(map_x[2]) row_max = 4'd3;
	else if(map_x[1]) row_max = 4'd2;
	else if(map_x[0]) row_max = 4'd1;
	else row_max = 4'd0;
end
endmodule

