module Program(input clk, INF.Program_inf inf);
import usertype::*;

// ===========================================================
//                      logic declaration
// ===========================================================
integer i, j, k, x, y, z;

Action action_ff;
// Formula_Type formula_ff;
// Mode FM_info.Mode_O;
Order_Info FM_info;
Date date_ff; 
Data_No data_no_ff;
Index T_index_ff [0:3]; //A,B,C,D

logic [2:0] T_index_cnt;

// logic R_VALID_flag;
// logic [63:0] dram_in_data;
Data_Dir dram_in_data;
logic not_valid_date;

logic [12:0] index_variation [0:3];
// logic [12:0] debug[0:3];
// logic vartation_flag [0:3];
Index update_index [0:3];

Index sort_in[0:3], sort_layer[0:3], sort_out[0:3];

logic [10:0] threshold;
logic [13:0] formula_add;
logic [11:0] formula_res;
logic [1:0] sort_cycle;

state_t curr_state, next_state;

/* FSM */
always_ff @(posedge clk or negedge inf.rst_n) begin : FSM
    if (!inf.rst_n) curr_state <= IDLE;
    else curr_state <= next_state;
end

always_comb begin : FSM_COMB
    case(curr_state)
        IDLE: begin
            if (inf.data_no_valid) next_state = ACCESS_DRAM;
            else next_state = IDLE;
        end
		ACCESS_DRAM : begin
			if(inf.AR_READY) next_state = READ_DRAM;
			else next_state = ACCESS_DRAM;
		end
		READ_DRAM : begin 
			if(dram_in_data.M != 0) begin
				if(action_ff == Check_Valid_Date) next_state = CHECK_VALID_DATE;
				else if(action_ff == Update && T_index_cnt == 'd4) next_state = VARIATION_INDEX;
				else if(action_ff == Index_Check && T_index_cnt == 'd4) next_state = CHECK_VALID_DATE;
				else next_state = READ_DRAM;
			end
			else next_state = READ_DRAM;
		end
		VARIATION_INDEX: next_state = WRITE_BACK;
		WRITE_BACK : begin 
			if(inf.B_VALID && inf.B_READY) next_state = OUTPUT_ANS;
			else next_state = WRITE_BACK;
		end
		CHECK_VALID_DATE : begin 
			if(action_ff == Index_Check && !not_valid_date) begin
				// if(FM_info.Formula_Type_O == Formula_B || FM_info.Formula_Type_O == Formula_C || FM_info.Formula_Type_O == Formula_F || FM_info.Formula_Type_O == Formula_G) next_state = CAL_FORMULA;
				// else next_state = ;
				next_state = CAL_FORMULA;
			end
			else next_state = IDLE ;
		end
		CAL_FORMULA: begin
			if(FM_info.Formula_Type_O == Formula_F || FM_info.Formula_Type_O == Formula_H) begin
				if(sort_cycle == 'd2) next_state = OUTPUT_ANS;
				else next_state = CAL_FORMULA;
			end
			else if(FM_info.Formula_Type_O == Formula_A || FM_info.Formula_Type_O == Formula_B || FM_info.Formula_Type_O == Formula_C || FM_info.Formula_Type_O == Formula_G)begin
				if(sort_cycle > 0) next_state = OUTPUT_ANS;
				else next_state = CAL_FORMULA;
			end
			else next_state = OUTPUT_ANS;
		end
		OUTPUT_ANS : next_state = IDLE;
        default: next_state = IDLE;
    endcase
end


//===============================================//
//        Read DRAM with AXI4 protocol 	         //
//===============================================//
always_comb begin : DRAM_AR_ADDR
	inf.AR_ADDR = (curr_state == IDLE) ? 'd0 : (65536 + (data_no_ff << 3));
end

always_ff @ (posedge clk or negedge inf.rst_n) begin : DRAM_AR_VALID
	if (~inf.rst_n) inf.AR_VALID <= 0;
	else begin 
		if(inf.AR_READY && inf.AR_VALID) inf.AR_VALID <= 0;
		else if (curr_state == ACCESS_DRAM) inf.AR_VALID <= 1;
	end
end

always_comb begin : DRAM_R_READY
	if (curr_state == READ_DRAM) inf.R_READY = 1;
	else inf.R_READY = 0;
end


always_ff @(posedge clk or negedge inf.rst_n) begin 
	if (~inf.rst_n) begin
		dram_in_data.Index_A <= 0;
		dram_in_data.Index_B <= 0;
		dram_in_data.Index_C <= 0;
		dram_in_data.Index_D <= 0;
		dram_in_data.M <= 0;
		dram_in_data.D <= 0;
	end
	else begin 
		if (inf.R_VALID) begin
			dram_in_data.Index_A <= inf.R_DATA[63:52];
			dram_in_data.Index_B <= inf.R_DATA[51:40];
			dram_in_data.Index_C <= inf.R_DATA[31:20];
			dram_in_data.Index_D <= inf.R_DATA[19:8];
			dram_in_data.M <= inf.R_DATA[39:32];
			dram_in_data.D <= inf.R_DATA[7:0];
		end
		else if(curr_state == IDLE) begin
			dram_in_data.Index_A <= 0;
			dram_in_data.Index_B <= 0;
			dram_in_data.Index_C <= 0;
			dram_in_data.Index_D <= 0;
			dram_in_data.M <= 0;
			dram_in_data.D <= 0;
		end
	end
end

//===============================================//
//         Write DRAM with AXI4 protocol         //
//===============================================//
always_comb begin : DRAM_AWADDR
	inf.AW_ADDR = (curr_state == IDLE) ? 'd0 : (65536 + (data_no_ff << 3));
end

always_ff @(posedge clk or negedge inf.rst_n) begin : DRAM_AW_VALID
	if (~inf.rst_n) inf.AW_VALID <= 0;
	else begin 
		if (curr_state == VARIATION_INDEX) inf.AW_VALID <= 1;
		else begin 
			if(inf.AW_READY) inf.AW_VALID <= 0;
			else inf.AW_VALID <= inf.AW_VALID;
		end
	end
end

always_comb begin : DRAM_W_DATA
	if(curr_state == IDLE) inf.W_DATA = 'd0;
	else begin
		inf.W_DATA[63:52] = update_index[0];
		inf.W_DATA[51:40] = update_index[1];
		inf.W_DATA[39:32] = date_ff.M;
		inf.W_DATA[31:20] = update_index[2];
		inf.W_DATA[19:8] = update_index[3];
		inf.W_DATA[7:0] = date_ff.D;
	end
	// $display("update_A: %d",inf.W_DATA[63:52]);
	// $display("date_ff: %d | update_Month: %d",date_ff.M,inf.W_DATA[39:32]);
	// $display("date_ff: %d | update_Day: %d",date_ff.D,inf.W_DATA[7:0]);
end

always_ff @(posedge clk or negedge inf.rst_n) begin : DRAM_W_VALID
	if (~inf.rst_n) inf.W_VALID <= 0;
	else begin 
		if (curr_state == WRITE_BACK) begin 
			if(~inf.W_READY) inf.W_VALID <= 1;
			else inf.W_VALID <= 0;
		end
		else inf.W_VALID <= 0;
	end
end

// always_comb begin : DRAM_B_READY
// 	if (inf.B_VALID) inf.B_READY = 1;
// 	else inf.B_READY = 0;
// end

always_ff @(posedge clk or negedge inf.rst_n) begin : DRAM_B_READY
	if (~inf.rst_n) inf.B_READY <= 0;
	else begin 
		if(inf.AW_VALID && inf.AW_READY) inf.B_READY <= 1;
		else if(inf.B_VALID) inf.B_READY <= 0;
		// if (curr_state == WRITE_BACK) begin 
		// 	if(inf.B_VALID) inf.B_READY <= 0;
		// 	else inf.B_READY <= 1;
		// end
		// else inf.B_READY <= 0;
	end
end

// always @(posedge clk or negedge rst_n) begin
// 	if(~rst_n) bready_s_inf <= 0;
//     else if(awvalid_s_inf && awready_s_inf) bready_s_inf <= 1;
//     else if(bvalid_s_inf) bready_s_inf <= 0;
// end

// ===========================================================
//                          design
// ===========================================================


//======================================
//       	     input D
//======================================

// action_ff
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (~inf.rst_n) action_ff <= 0;
    else begin
	    if (inf.sel_action_valid) action_ff <= inf.D.d_act[0];
		// else if(curr_state == IDLE) action_ff <= 0;
        else action_ff <= action_ff;
    end
end

// FM_info.Formula_Type_O
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (~inf.rst_n) FM_info.Formula_Type_O <= 0;
    else begin
	    if (inf.formula_valid) FM_info.Formula_Type_O <= inf.D.d_formula[0];
		// else if(curr_state == IDLE) FM_info.Formula_Type_O <= 0;
        else FM_info.Formula_Type_O <= FM_info.Formula_Type_O;
    end
end

// FM_info.Mode_O
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (~inf.rst_n) FM_info.Mode_O <= 0;
    else begin
	    if (inf.mode_valid) FM_info.Mode_O <= inf.D.d_mode[0];
		// else if(curr_state == IDLE) FM_info.Mode_O <= 0;
        else FM_info.Mode_O <= FM_info.Mode_O;
    end
end

// date_ff
always_ff @(posedge clk or negedge inf.rst_n) begin 
	if (!inf.rst_n) begin 
		date_ff.M <= 0;
		date_ff.D <= 0;
	end
	else begin
		if (inf.date_valid) date_ff <= inf.D.d_date[0];
		// else if(curr_state == IDLE) begin
		// 	date_ff.M <= 0;
		// 	date_ff.D <= 0;
		// end
		else begin 
			date_ff.M <= date_ff.M;
			date_ff.D <= date_ff.D;
		end
	end
end

// data_no_ff
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (~inf.rst_n) data_no_ff <= 0;
    else begin
	   if (inf.data_no_valid) data_no_ff <= inf.D.d_data_no[0];
	//    else if(curr_state == IDLE) data_no_ff <= 0;
       else data_no_ff <= data_no_ff;
    end
end

// T_index_cnt
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (~inf.rst_n) T_index_cnt <= 0;
    else begin
	    if (inf.index_valid) T_index_cnt <= T_index_cnt + 1;
		else if(inf.out_valid) T_index_cnt <= 0;
        else T_index_cnt <= T_index_cnt;
    end
end

// index_ff
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (~inf.rst_n) for(i = 0; i < 4; i = i + 1) T_index_ff[i] <= 0;
    else begin
	    if (inf.index_valid) T_index_ff[T_index_cnt] <= inf.D.d_index[0];
		// else if(curr_state == IDLE) for(i = 0; i < 4; i = i + 1) T_index_ff[i] <= 0;
        else for(i = 0; i < 4; i = i + 1) T_index_ff[i] <= T_index_ff[i];
    end
end




//======================================
//       	  Cal Variation
//======================================
/*
1 1111 1111 1111 // 4095
1 1000 0000 0001 // -2047
0 0111 1111 1111 // 2047 -> variation is positive -> 4095

0 0000 0110 0100 //100
1 1111 0011 1000 //-200 -> variation is negtive -> 0

0 0000 0110 0100 // 100
1 1111 1010 1000 // -88
1 1111 1111 0100 // 22

0 1010 0001 1110 // 2590
0 1011 1110 0011 // -1053

*/

/* index_variation */
always_comb begin 
	index_variation[0] = {1'b0,dram_in_data.Index_A[11:0]} + {T_index_ff[0][11],T_index_ff[0][11:0]};
	index_variation[1] = {1'b0,dram_in_data.Index_B[11:0]} + {T_index_ff[1][11],T_index_ff[1][11:0]};
	index_variation[2] = {1'b0,dram_in_data.Index_C[11:0]} + {T_index_ff[2][11],T_index_ff[2][11:0]};
	index_variation[3] = {1'b0,dram_in_data.Index_D[11:0]} + {T_index_ff[3][11],T_index_ff[3][11:0]};
end 

/* update_index */
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (~inf.rst_n) for(k = 0; k < 4; k = k + 1) update_index[k] <= 0;
	else begin
		if (curr_state == VARIATION_INDEX) begin 
			for (k = 0; k < 4; k = k + 1) begin
				if (index_variation[k][12]) update_index[k] <= (T_index_ff[k][11]) ? 12'd0 : 12'b111111111111;
				else update_index[k] <= index_variation[k][11:0];
			end
		end
		else if(curr_state == IDLE) for(k = 0; k < 4; k = k + 1) update_index[k] <= 0;
	end
end 

//======================================
//       	Check_Valid_Date
//======================================
/* not_valid_date */
always_comb begin 
	if (curr_state == CHECK_VALID_DATE) begin 
		// $display("dram_in_data- %d/%d | date_ff- %d/%d",dram_in_data.M,dram_in_data.D,date_ff.M,date_ff.D);
		if (dram_in_data.M < date_ff.M) not_valid_date = 0;
		else if ((dram_in_data.M == date_ff.M) && (dram_in_data.D <= date_ff.D)) not_valid_date = 0;
		else not_valid_date = 1;
	end
	else not_valid_date = 0;
end 

//======================================
//       	 CAL_FORMULA
//======================================

/* sort_in */
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (~inf.rst_n) for(x = 0; x < 4; x = x + 1) sort_in[x] <= 0;
    else begin
	    if (curr_state == CHECK_VALID_DATE) begin
			if(FM_info.Formula_Type_O == Formula_B || FM_info.Formula_Type_O == Formula_C) begin
				sort_in[0] <= dram_in_data.Index_A;
				sort_in[1] <= dram_in_data.Index_B;
				sort_in[2] <= dram_in_data.Index_C;
				sort_in[3] <= dram_in_data.Index_D;
				// for(x = 0; x < 4; x = x + 1) sort_in[i] <= T_index_ff[i];
			end
			else if(FM_info.Formula_Type_O == Formula_F || FM_info.Formula_Type_O == Formula_G || FM_info.Formula_Type_O == Formula_H) begin
				sort_in[0] <= (dram_in_data.Index_A > T_index_ff[0]) ? (dram_in_data.Index_A - T_index_ff[0]) : (T_index_ff[0] - dram_in_data.Index_A);
				sort_in[1] <= (dram_in_data.Index_B > T_index_ff[1]) ? (dram_in_data.Index_B - T_index_ff[1]) : (T_index_ff[1] - dram_in_data.Index_B);
				sort_in[2] <= (dram_in_data.Index_C > T_index_ff[2]) ? (dram_in_data.Index_C - T_index_ff[2]) : (T_index_ff[2] - dram_in_data.Index_C);
				sort_in[3] <= (dram_in_data.Index_D > T_index_ff[3]) ? (dram_in_data.Index_D - T_index_ff[3]) : (T_index_ff[3] - dram_in_data.Index_D);
			end
			else for(x = 0; x < 4; x = x + 1) sort_in[x] <= 0;
		end 
		// else if (curr_state == IDLE) for(i = 0; i < 4; i = i + 1) sort_in[i] <= 0;
		else for(x = 0; x < 4; x = x + 1) sort_in[x] <= 0;
    end
end

always_comb begin 
	if (curr_state == CAL_FORMULA) begin
		{sort_layer[0], sort_layer[1]} = (sort_in[0] > sort_in[1]) ? {sort_in[0], sort_in[1]} : {sort_in[1], sort_in[0]};
		{sort_layer[2], sort_layer[3]} = (sort_in[2] > sort_in[3]) ? {sort_in[2], sort_in[3]} : {sort_in[3], sort_in[2]};
	end
	else begin
		for(y = 0; y < 4; y = y + 1) sort_layer[y] = 'd0;
	end
end 

// always_ff @(posedge clk or negedge inf.rst_n) begin
// 	if (~inf.rst_n) begin
// 		for(a = 0; a < 4; a = a + 1) sort_layer[a] <= 'd0;
// 	end
//     else begin
// 		if (curr_state == CAL_FORMULA) begin
// 			{sort_layer[0], sort_layer[1]} = (sort_in[0] > sort_in[1]) ? {sort_in[0], sort_in[1]} : {sort_in[1], sort_in[0]};
// 			{sort_layer[2], sort_layer[3]} = (sort_in[2] > sort_in[3]) ? {sort_in[2], sort_in[3]} : {sort_in[3], sort_in[2]};
// 		end
// 		else begin
// 			for(a = 0; a < 4; a = a + 1) sort_layer[a] <= 'd0;
// 		end
// 	end
// end 

always_ff @(posedge clk or negedge inf.rst_n) begin
	if (~inf.rst_n) begin
		for(j = 0; j < 4; j = j + 1) sort_out[j] <= 'd0;
	end
    else begin
		if (curr_state == CAL_FORMULA) begin
			{sort_out[0], sort_out[1]} <= (sort_layer[0] > sort_layer[2]) ? {sort_layer[0], sort_layer[2]} : {sort_layer[2], sort_layer[0]};
			{sort_out[2], sort_out[3]} <= (sort_layer[1] > sort_layer[3]) ? {sort_layer[1], sort_layer[3]} : {sort_layer[3], sort_layer[1]};
		end
		else begin
			for(j = 0; j < 4; j = j + 1) sort_out[j] <= 'd0;
		end
	end
end 

/* sort_cycle */
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (~inf.rst_n) sort_cycle <= 0;
    else begin
		if (curr_state == CAL_FORMULA) sort_cycle <= sort_cycle + 1;
		else sort_cycle <= 0;
	end
end 

/* formula_add */
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (~inf.rst_n) formula_add <= 0;
    else begin
		if (curr_state == CAL_FORMULA) begin
			case(FM_info.Formula_Type_O)
				Formula_A: formula_add <= (dram_in_data.Index_A + dram_in_data.Index_B) + (dram_in_data.Index_C + dram_in_data.Index_D);
				Formula_F: formula_add <= (sort_out[1] + sort_out[2]) + sort_out[3];
				Formula_H: formula_add <= (sort_out[0] + sort_out[1]) + (sort_out[2] + sort_out[3]);
				default: formula_add <= 0;
			endcase
		end
		else formula_add <= 0;
	end
end 
// always_comb begin
// 	if (curr_state == CAL_FORMULA) begin
// 		case(FM_info.Formula_Type_O)
// 			Formula_A: formula_add = (dram_in_data.Index_A + dram_in_data.Index_B) + (dram_in_data.Index_C + dram_in_data.Index_D);
// 			Formula_F: formula_add = (sort_out[1] + sort_out[2]) + sort_out[3];
// 			Formula_H: formula_add = (sort_out[0] + sort_out[1]) + (sort_out[2] + sort_out[3]);
// 			default: formula_add = 0;
// 		endcase
// 	end
// 	else formula_add = 0;
// end

/* formula_res */
always_ff @(posedge clk or negedge inf.rst_n) begin
	if (~inf.rst_n) formula_res <= 0;
    else begin
		if (curr_state == CAL_FORMULA) begin
			// $display("dram_data = %d | %d | %d | %d",dram_in_data.Index_A,dram_in_data.Index_B,dram_in_data.Index_C,dram_in_data.Index_D);
			// $display("add = %d ",dram_in_data.Index_A+dram_in_data.Index_B+dram_in_data.Index_C+dram_in_data.Index_D);
			case(FM_info.Formula_Type_O)
				Formula_A: formula_res <= formula_add >> 2;
				Formula_B: formula_res <= sort_out[0] - sort_out[3];
				Formula_C: formula_res <= sort_out[3];
				Formula_D: begin
					formula_res <= (dram_in_data.Index_A >= 'd2047) + (dram_in_data.Index_B >= 'd2047) 
						+ (dram_in_data.Index_C >= 'd2047) + (dram_in_data.Index_D >= 'd2047);
				end
				Formula_E: begin
					formula_res <= (T_index_ff[0] <= dram_in_data.Index_A) + (T_index_ff[1] <= dram_in_data.Index_B) 
									+ (T_index_ff[2] <= dram_in_data.Index_C) + (T_index_ff[3] <= dram_in_data.Index_D);
				end
				Formula_F: formula_res <= formula_add / 3;
				Formula_G: formula_res <= (sort_out[1] >> 2) + (sort_out[2] >> 2) + (sort_out[3] >> 1);
				Formula_H: formula_res <= formula_add >> 2;
			endcase
		end
		else if(curr_state == IDLE) formula_res <= 0;
	end
end 

/* threshold */ 
always_comb begin : Look_Up_Threshold
	case(FM_info.Formula_Type_O)
		Formula_A, Formula_C: begin
			case(FM_info.Mode_O)
				Insensitive: threshold = 'd2047;
				Normal: threshold = 'd1023;
				Sensitive: threshold = 'd511;
				default: threshold = 'd0;
			endcase
		end
		Formula_B, Formula_F, Formula_G, Formula_H: begin
			case(FM_info.Mode_O)
				Insensitive: threshold = 'd800;
				Normal: threshold = 'd400;
				Sensitive: threshold = 'd200;
				default: threshold = 'd0;
			endcase
		end
		Formula_D, Formula_E: begin
			case(FM_info.Mode_O)
				Insensitive: threshold = 'd3;
				Normal: threshold = 'd2;
				Sensitive: threshold = 'd1;
				default: threshold = 'd0;
			endcase
		end
		default: threshold = 'd0;
	endcase
end


//======================================
//       	    ans_output
//======================================

/* inf.warn_msg, inf.complete, inf.out_valid */
always_ff @( posedge clk or negedge inf.rst_n) begin 
    if (~inf.rst_n) begin 
		inf.out_valid <= 0;
		inf.warn_msg  <= No_Warn;
		inf.complete <= 0;
	end
	else if(curr_state == CHECK_VALID_DATE) begin 
		if(not_valid_date) begin 
			inf.out_valid <= 1;
			inf.warn_msg <= Date_Warn;
			inf.complete <= 0;
		end
		else if(action_ff == Check_Valid_Date) begin 
			inf.out_valid <= 1;
			inf.warn_msg <= No_Warn;
			inf.complete <= 1;
		end
	end
	else if (curr_state == OUTPUT_ANS) begin
		if(action_ff == Index_Check)begin
			if(formula_res >= threshold) begin
				inf.out_valid <= 1;
				inf.warn_msg <= Risk_Warn;
				inf.complete <= 0;
			end
			else begin 
				inf.out_valid <= 1;
				inf.warn_msg <= No_Warn;
				inf.complete <= 1;
			end
		end
		else begin
			if (index_variation[0][12] || index_variation[1][12] || index_variation[2][12] || index_variation[3][12]) begin 
				inf.out_valid <= 1;
				inf.warn_msg <= Data_Warn;
				inf.complete <= 0;
			end
			else begin 
				inf.out_valid <= 1;
				inf.warn_msg <= No_Warn;
				inf.complete <= 1;
			end
		end
	end
    else begin 
		inf.out_valid <= 0;
		inf.warn_msg  <= No_Warn;
		inf.complete <= 0;
	end 
end

endmodule
