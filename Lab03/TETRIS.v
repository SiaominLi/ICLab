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
reg [3:0] tetro_index, next_tetro_index;

reg [90:0] map;
reg [83:0] shift_map;
reg [3:0] row_record [0:5], next_row_record[0:5]; //Store MAX position
reg [3:0] max1, max2, max_value;
reg [2:0] curr_pos, curr_tetrom, temp_score;
reg [11:0] row_score;

reg [4:0] total_score; 
reg [3:0] first_one_index;
reg [2:0] one_state;
reg [2:0] shift_state [0:2];
reg [2:0] shift_all [0:14];

reg [11:0] map_col0, map_col1, map_col2, map_col3, map_col4, map_col5;
reg [3:0] col_top_0, col_top_1, col_top_2, col_top_3, col_top_4, col_top_5;

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

//------------------------Control tetro_index------------------------
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		tetro_index <= 4'b0;
    end
	else begin
		if (tetris_valid) begin
			tetro_index <= 4'b0;
		end
		else tetro_index <= next_tetro_index;
	end
end

always @(*) begin
	next_tetro_index = tetro_index;
	if (score_valid) begin
		next_tetro_index = tetro_index + 1;
	end
end
//-------------------------------------------------------------------

//------------------------Calcelate max value------------------------
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
//-------------------------------------------------------------------

//------------------------Control row_record-------------------------
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		for (i = 0; i < 6; i = i + 1) begin
			row_record[i] <= 4'b0;
		end
	end
	else if (tetris_valid) begin
		for (i = 0; i < 6; i = i + 1) begin
			row_record[i] <= 4'b0;
		end
	end
	else begin
		if (current_state == UPDATE_ROW_RECORD && in_valid) begin
			curr_tetrom <= tetrominoes;
			curr_pos <= position;
			row_record[0] <= next_row_record[0];
			row_record[1] <= next_row_record[1];
			row_record[2] <= next_row_record[2];
			row_record[3] <= next_row_record[3];
			row_record[4] <= next_row_record[4];
			row_record[5] <= next_row_record[5];
		end
		else if(current_state == OUTPUT_SCORE) begin
			if( ~((|map[90:72] == 1) || tetro_index == 'd15) ) begin
				row_record[0] <= col_top_0;
				row_record[1] <= col_top_1;
				row_record[2] <= col_top_2;
				row_record[3] <= col_top_3;
				row_record[4] <= col_top_4;
				row_record[5] <= col_top_5;
			end
		end
	end
end

always @(*) begin
	for (i = 0; i < 6; i = i + 1) begin
		next_row_record[i] = row_record[i];
	end
	if (current_state == UPDATE_ROW_RECORD && in_valid) begin
		case (tetrominoes)
			3'b000: begin
				if (row_record[position] > row_record[position + 1]) begin
					next_row_record[position] = row_record[position] + 2;
					next_row_record[position + 1] = row_record[position] + 2;
				end
				else begin
					next_row_record[position] = row_record[position + 1] + 2;
					next_row_record[position + 1] = row_record[position + 1] + 2;
				end
			end
			3'b001: begin
				next_row_record[position] = (row_record[position] > 11) ? 4'd15 : row_record[position] + 4;
			end
			3'b010: begin
				next_row_record[position] = max_value;
				next_row_record[position + 1] = max_value;
				next_row_record[position + 2] = max_value;
				next_row_record[position + 3] = max_value;
			end
			3'b011: begin
				if( row_record[position] > (row_record[position+1] + 2) ) begin
					next_row_record[position] = row_record[position] + 1 ; 
					next_row_record[position+1] = row_record[position] + 1 ; 

				end
				else begin
					next_row_record[position] = row_record[position+1] + 3 ; 
					next_row_record[position+1] = row_record[position+1] + 3 ; 

				end
			end
			3'b100: begin
				next_row_record[position] = max_value; 
				next_row_record[position+1] = max_value; 
				next_row_record[position+2] = max_value; 
			end
			3'b101: begin
				if(row_record[position] > row_record[position+1]) begin
					next_row_record[position] = row_record[position] + 3 ; 
					next_row_record[position+1] = row_record[position] + 1 ; 
				end
				else begin
					next_row_record[position] = row_record[position+1] + 3 ; 
					next_row_record[position+1] = row_record[position+1] + 1 ; 
				end
			end
			3'b110: begin
				if( row_record[position] > (row_record[position+1]+1) ) begin
					next_row_record[position] = row_record[position] + 2 ; 
					next_row_record[position+1] = row_record[position] + 1 ; 
				end
				else begin
					next_row_record[position] = row_record[position+1] + 3 ; 
					next_row_record[position+1] = row_record[position+1] + 2 ; 
				end
			end
			3'b111: begin
				if(max1 >= row_record[position+2]) begin
					next_row_record[position] = max1 + 1; 
					next_row_record[position+1] = max1 + 2; 
					next_row_record[position+2] = max1 + 2; 
				end
				else begin
					next_row_record[position] = row_record[position+2]; 
					next_row_record[position+1] = row_record[position+2] + 1; 
					next_row_record[position+2] = row_record[position+2] + 1; 
				end
			end
		endcase
	end
end
//-------------------------------------------------------------------

find_top_row find0(.col(map_col0), .top(col_top_0));
find_top_row find1(.col(map_col1), .top(col_top_1));
find_top_row find2(.col(map_col2), .top(col_top_2));
find_top_row find3(.col(map_col3), .top(col_top_3));
find_top_row find4(.col(map_col4), .top(col_top_4));
find_top_row find5(.col(map_col5), .top(col_top_5));

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
		map <= 'b0;
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
			map <= shift_map;
		end
		else begin
			if(tetris_valid) begin
				map <= 'b0;	
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
			if(tetris_valid) total_score <= 'b0;
		end
	end
end

always@(*) begin
	row_score[0] = &map[5:0];  
	row_score[1] = &map[11:6];  
	row_score[2] = &map[17:12];  
	row_score[3] = &map[23:18];  
	row_score[4] = &map[29:24];  
	row_score[5] = &map[35:30];  
	row_score[6] = &map[41:36];  
	row_score[7] = &map[47:42];  
	row_score[8] = &map[53:48];  
	row_score[9] = &map[59:54];  
	row_score[10] = &map[65:60]; 
	row_score[11] = &map[71:66]; 
end

always@(*) begin
	temp_score = row_score[0] + row_score[1] + row_score[2] + row_score[3] +
		row_score[4] + row_score[5] + row_score[6] + row_score[7] +
		row_score[8] + row_score[9] + row_score[10] + row_score[11];
end

always@(*) begin
	if (row_score[0]) first_one_index = 4'd0;
	else if (row_score[1]) first_one_index = 4'd1;
	else if (row_score[2]) first_one_index = 4'd2;
	else if (row_score[3]) first_one_index = 4'd3;
	else if (row_score[4]) first_one_index = 4'd4;
	else if (row_score[5]) first_one_index = 4'd5;
	else if (row_score[6]) first_one_index = 4'd6;
	else if (row_score[7]) first_one_index = 4'd7;
	else if (row_score[8]) first_one_index = 4'd8;
	else if (row_score[9]) first_one_index = 4'd9;
	else if (row_score[10]) first_one_index = 4'd10;
	else if (row_score[11]) first_one_index = 4'd11;
	else  first_one_index = 4'd15;
end

always@(*) begin
	case(first_one_index)
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
			shift_state[0] = 2;
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
	case(first_one_index)
		4'd0: begin
			shift_all[0] = shift_state[0];
			shift_all[1] = shift_state[1];
			shift_all[2:14] = '{13{shift_state[2]}};
		end
		4'd1: begin
			shift_all[0] = 3'd0;
			shift_all[1] = shift_state[0];
			shift_all[2] = shift_state[1];
			shift_all[3:14] = '{12{shift_state[2]}};
		end
		4'd2: begin
			shift_all[0:1] = '{2{'b0}};
			shift_all[2] = shift_state[0];
			shift_all[3] = shift_state[1];
			shift_all[4:14] = '{11{shift_state[2]}};
		end
		4'd3: begin
			shift_all[0:2] = '{3{'b0}};
			shift_all[3] = shift_state[0];
			shift_all[4] = shift_state[1];
			shift_all[5:14] = '{10{shift_state[2]}};
		end
		4'd4: begin
			shift_all[0:3] = '{4{'b0}};
			shift_all[4] = shift_state[0];
			shift_all[5] = shift_state[1];
			shift_all[6:14] = '{9{shift_state[2]}};
		end
		4'd5: begin
			shift_all[0:4] = '{5{'b0}};
			shift_all[5] = shift_state[0];
			shift_all[6] = shift_state[1];
			shift_all[7:14] = '{8{shift_state[2]}};
		end
		4'd6: begin
			shift_all[0:5] = '{6{'b0}};
			shift_all[6] = shift_state[0];
			shift_all[7] = shift_state[1];
			shift_all[8:14] = '{7{shift_state[2]}};
		end
		4'd7: begin
			shift_all[0:6] = '{7{'b0}};
			shift_all[7] = shift_state[0];
			shift_all[8] = shift_state[1];
			shift_all[9:14] = '{6{shift_state[2]}};
		end
		4'd8: begin
			shift_all[0:7] = '{8{'b0}};
			shift_all[8] = shift_state[0];
			shift_all[9] = shift_state[1];
			shift_all[10:14] = '{5{shift_state[2]}};
		end
		4'd9: begin
			shift_all[0:8] = '{9{'b0}};
			shift_all[9] = shift_state[0];
			shift_all[10] = shift_state[1];
			shift_all[11:14] = '{4{shift_state[2]}};
		end
		4'd10: begin
			shift_all[0:9] = '{10{'b0}};
			shift_all[10] = shift_state[0];
			shift_all[11] = shift_state[1];
			shift_all[12:14] = '{3{shift_state[2]}};
		end
		4'd11: begin
			shift_all[0:10] = '{11{'b0}};
			shift_all[11] = shift_state[0];
			shift_all[12] = shift_state[1];
			shift_all[13:14] = '{2{shift_state[2]}};

		end
		default: begin
			shift_all[0:14] = '{15{'b0}};
		end
	endcase
end

shift_map s0(.judge_signal(shift_all[0]) ,.top_value(7'd5) ,.map(map) ,.map_row(shift_map[5:0]));
shift_map s1(.judge_signal(shift_all[1]) ,.top_value(7'd11) ,.map(map) ,.map_row(shift_map[11:6]));
shift_map s2(.judge_signal(shift_all[2]) ,.top_value(7'd17) ,.map(map) ,.map_row(shift_map[17:12]));
shift_map s3(.judge_signal(shift_all[3]) ,.top_value(7'd23) ,.map(map) ,.map_row(shift_map[23:18]));
shift_map s4(.judge_signal(shift_all[4]) ,.top_value(7'd29) ,.map(map) ,.map_row(shift_map[29:24]));
shift_map s5(.judge_signal(shift_all[5]) ,.top_value(7'd35) ,.map(map) ,.map_row(shift_map[35:30]));
shift_map s6(.judge_signal(shift_all[6]) ,.top_value(7'd41) ,.map(map) ,.map_row(shift_map[41:36]));
shift_map s7(.judge_signal(shift_all[7]) ,.top_value(7'd47) ,.map(map) ,.map_row(shift_map[47:42]));
shift_map s8(.judge_signal(shift_all[8]) ,.top_value(7'd53) ,.map(map) ,.map_row(shift_map[53:48]));
shift_map s9(.judge_signal(shift_all[9]) ,.top_value(7'd59) ,.map(map) ,.map_row(shift_map[59:54]));
shift_map s10(.judge_signal(shift_all[10]) ,.top_value(7'd65) ,.map(map) ,.map_row(shift_map[65:60]));
// shift_map s11(.judge_signal(shift_all[11]) ,.top_value(71) ,.map(map) ,.map_row(shift_map[71:66]));
// shift_map s12(.judge_signal(shift_all[12]) ,.top_value(77) ,.map(map) ,.map_row(shift_map[11:6]));
always @(*) begin
	shift_map[71:66] = shift_all[11]==1? map[77:72]: shift_all[11] == 2? map[83:78]: shift_all[11] == 3? map[89:84]: shift_all[11] == 4? 6'b0 : map[71:66];
	shift_map[77:72] = shift_all[12]==1? map[83:78]: (shift_all[12] == 2? map[89:84]: (shift_all[12] == 3? 6'b0 : map[77:72]));
	shift_map[83:78] = shift_all[13]==1? map[89:84]: (shift_all[13] == 2? 6'b0: map[83:78]);
	// shift_map[89:84] = shift_all[14]? 6'b0 : map[89:84];
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

			if( (|map[90:72] == 1) || tetro_index == 'd15) begin
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
	input [11:0] col,
	output reg [3:0] top
);

always @(*)begin
	if(col[11]) top = 4'd12;
	else if(col[10]) top = 4'd11;
	else if(col[9]) top = 4'd10;
	else if(col[8]) top = 4'd9;
	else if(col[7]) top = 4'd8;
	else if(col[6]) top = 4'd7;
	else if(col[5]) top = 4'd6;
	else if(col[4]) top = 4'd5;
	else if(col[3]) top = 4'd4;
	else if(col[2]) top = 4'd3;
	else if(col[1]) top = 4'd2;
	else if(col[0]) top = 4'd1;
	else top = 4'd0;
end
endmodule


module  shift_map(
	input [2:0] judge_signal,
	input [6:0] top_value,
	input [90:0] map,
	output reg [5:0] map_row
);

reg [6:0] shift_position;

always @(*) begin
	case(judge_signal)
		'd1: begin
			shift_position = top_value + 6;
		end
		'd2: begin
			shift_position = top_value + 12;
		end
		'd3: begin
			shift_position = top_value + 18;
		end
		'd4: begin
			shift_position = top_value + 24;
		end
		default: shift_position = top_value;

	endcase
	map_row = { map[shift_position], map[shift_position-1], map[shift_position-2], map[shift_position-3], map[shift_position-4], map[shift_position-5]};
	// $display("map_row %d = %h, @time = %d", top_value, map_row, $time);
end
endmodule