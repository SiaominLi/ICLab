
// `include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;
//================================================================
// parameters & integer
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";
parameter MAX_CYCLE = 1000;

integer   TOTAL_PATNUM = 5600;
parameter SEED = 35547;

integer act1_input_cnt;
integer i_pat;
integer i_mod9;
integer i,j,k;

//================================================================
// wire & registers 
//================================================================
logic [7:0] golden_DRAM [((65536+8*256)-1):(65536+0)];  // 32 box

reg[9*8:1]  reset_color       = "\033[1;0m";
// reg[10*8:1] txt_black_prefix  = "\033[1;30m";
// reg[10*8:1] txt_red_prefix    = "\033[1;31m";
reg[10*8:1] txt_green_prefix  = "\033[1;32m";
// reg[10*8:1] txt_yellow_prefix = "\033[1;33m";
reg[10*8:1] txt_blue_prefix   = "\033[1;34m";


logic [63:0] dram_data, dram_write;

logic [1:0] action_input;
logic [3:0] month_input;
logic [4:0] day_input;

Data_No data_no_input;
Formula_Type formula_input;
Mode mode_input;
Index index_input;
Index indexA, indexB, indexC, indexD;

Index sort_in[0:3], sort_layer[0:3], sort_out[0:3];
logic [13:0] formula_res, threshold;
logic [12:0] index_variation [0:3];

logic complete;
Warn_Msg warn_msg;
//================================================================
// class random
//================================================================

/**
 * Class representing a random action.
 */
class random_act;
    randc Action act_id;
    constraint range{
        act_id inside{Index_Check, Update, Check_Valid_Date};
    }
endclass

class random_formula; //Class representing random formula from A to H.
    randc Formula_Type [2:0] formula_id;
    constraint range{
        formula_id inside{Formula_A, Formula_B,Formula_C, Formula_D, Formula_E, Formula_F, Formula_G, Formula_H};
    }
endclass

class random_mode; 
    randc Mode [7:0] mode_id;
    constraint range{
        mode_id inside{Insensitive, Normal, Sensitive};
    }
endclass

class random_date; //Class representing a random date
    randc Date Date_id;
    constraint range{
        Date_id.M inside{[1:12]};
        if (Date_id.M == 2) Date_id.D inside {[1:28]};
        else if (Date_id.M == 4 || Date_id.M == 6 || Date_id.M == 9 || Date_id.M == 11) Date_id.D inside {[1:30]};
        else Date_id.D inside {[1:31]};
    }
endclass

class random_data_no; //Class representing a random data number from 0 to 255.
    randc Data_No data_no_id;
    constraint range{
        data_no_id inside{[0:255]};
    }
endclass

class random_index; 
    randc Index index_id;
    constraint range{
        index_id inside{[0:4095]};
    }
endclass

random_date rand_date_in = new();
random_data_no rand_data_no = new();
random_index rand_index_in = new();
random_formula rand_formula_in = new();
random_mode rand_mode_in = new();

initial begin
    $readmemh(DRAM_p_r, golden_DRAM);
    
    act1_input_cnt = 0;
    reset_signal_task;

    for (i_pat = 0; i_pat < TOTAL_PATNUM; i_pat = i_pat + 1) begin

        input_cal_task;
        wait_task;
        check_ans_task;

        $display("%0sPASS PATTERN NO.%4d %0s%0s",txt_blue_prefix, i_pat, txt_green_prefix, reset_color);
    end 
    pass_task;
end

task reset_signal_task; begin
    inf.rst_n = 1'b1;
    inf.sel_action_valid = 1'b0;
    inf.formula_valid = 1'b0;
    inf.mode_valid = 1'b0;
    inf.date_valid = 1'b0;
    inf.data_no_valid = 1'b0;
    inf.index_valid = 1'b0;
    inf.D = 72'bx;
    

    #(10) inf.rst_n = 1'b0;
    #(10) inf.rst_n = 1'b1;
    
end endtask

task input_cal_task; begin
    if(inf.out_valid!== 1) begin
        if(i_pat == 0) begin
            @(negedge clk);
        end

        // Action
        inf.sel_action_valid = 1'b1;    
        if(i_pat == 0) action_input = Index_Check;
        else if(i_pat > 3000) action_input = Index_Check;
        else begin    
            i_mod9 = i_pat % 9;
            case(i_mod9)
                1,3,0 : action_input = Index_Check;
                2,5,6 : action_input = Update;
                4,7,8 : action_input = Check_Valid_Date;
            endcase
        end    

        inf.D.d_act = action_input;
        @(negedge clk);
        inf.sel_action_valid = 1'b0;
        inf.D.d_act = 'bx;

        case(action_input)  // input signal
            Index_Check: In_Act1_task();
            Update: In_Act2_task();
            Check_Valid_Date:In_Act3_task();
        endcase

        Access_DRAM_task();

        case(action_input)  // calculate answer
            Index_Check: Act1_gold_task();
            Update: Act2_gold_task();
            Check_Valid_Date: Act3_gold_task();
        endcase
    end
end endtask

task In_Act1_task();
    @(negedge clk);
    // formula
    inf.formula_valid = 1'b1;   
    void'(rand_formula_in.randomize());
    // formula_input = rand_formula_in.formula_id;
    // if(act1_input_cnt > 1000) formula_input = Formula_A;
    // else if(act1_input_cnt > 1100) formula_input = Formula_B;
    // else if(act1_input_cnt > 1300) formula_input = Formula_C;
    // else if(act1_input_cnt > 1500) formula_input = Formula_D;
    // else if(act1_input_cnt > 1700) formula_input = Formula_E;
    // else if(act1_input_cnt > 1900) formula_input = Formula_F;
    // else if(act1_input_cnt > 2100) formula_input = Formula_G;
    // else if(act1_input_cnt > 2300) formula_input = Formula_H;
    // else begin
        case(act1_input_cnt % 8)
            0: formula_input = Formula_A;
            1: formula_input = Formula_B;
            2: formula_input = Formula_C;
            3: formula_input = Formula_D;
            4: formula_input = Formula_E;
            5: formula_input = Formula_F;
            6: formula_input = Formula_G;
            7: formula_input = Formula_H;
        endcase
    // end
    // formula_input = act1_input_cnt % 8;
    inf.D.d_formula = formula_input;

    @(negedge clk);

    inf.formula_valid = 1'b0;
    inf.D.d_formula = 'bx;

    @(negedge clk);

    // mode
    inf.mode_valid = 1'b1;  
    void'(rand_mode_in.randomize());    
    case(act1_input_cnt % 3)
        0: mode_input = Insensitive;
        1: mode_input = Normal;
        2: mode_input = Sensitive;
    endcase
    inf.D.d_mode = mode_input;

    @(negedge clk);

    inf.mode_valid = 1'b0;
    inf.D.d_mode = 2'bX;

    In_Act2_task();

    act1_input_cnt = act1_input_cnt + 1;
endtask

task In_Act2_task();
    @(negedge clk);
    // Date
    inf.date_valid = 1'b1;       
    void'(rand_date_in.randomize());
    month_input = rand_date_in.Date_id.M;
    day_input = rand_date_in.Date_id.D; 

    inf.D.d_date = {month_input, day_input};

    @(negedge clk);

    inf.date_valid = 1'b0;
    inf.D.d_date = 'bx;

    @(negedge clk);

    // data_no
    inf.data_no_valid = 1'b1;       
    void'(rand_data_no.randomize());
    data_no_input = rand_data_no.data_no_id;

    inf.D.d_data_no = data_no_input;

    @(negedge clk);

    inf.data_no_valid = 1'b0;
    inf.D.d_data_no = 'bx;
    
    // Index
    for(i = 0; i < 4; i = i + 1)begin
        inf.index_valid = 1'b1;       
        void'(rand_index_in.randomize());
        index_input = rand_index_in.index_id;
        inf.D.d_index = index_input;

        case(i)
            0:  indexA =  inf.D.d_index;
            1:  indexB =  inf.D.d_index;
            2:  indexC =  inf.D.d_index;
            3:  indexD =  inf.D.d_index;
        endcase 

        @(negedge clk);

        inf.index_valid = 1'b0;
        inf.D.d_index = 12'bx;

        @(negedge clk);
    end
endtask


task In_Act3_task();
    @(negedge clk);

    // Date
    inf.date_valid = 1'b1;       
    void'(rand_date_in.randomize());
    month_input = rand_date_in.Date_id.M;
    day_input = rand_date_in.Date_id.D; 

    inf.D.d_date = {month_input, day_input};

    @(negedge clk);

    inf.date_valid = 1'b0;
    inf.D.d_date = 'bx;

    @(negedge clk);

    // data_no
    inf.data_no_valid = 1'b1;       
    void'(rand_data_no.randomize());
    data_no_input = rand_data_no.data_no_id;

    inf.D.d_data_no = data_no_input;

    @(negedge clk);

    inf.data_no_valid = 1'b0;
    inf.D.d_data_no = 'bx;
endtask


task Access_DRAM_task();
    dram_data[7:0]   = golden_DRAM[65536+(data_no_input*8)] ;
	dram_data[15:8]  = golden_DRAM[65536+(data_no_input*8)+1] ;
	dram_data[23:16] = golden_DRAM[65536+(data_no_input*8)+2] ;
	dram_data[31:24] = golden_DRAM[65536+(data_no_input*8)+3] ;
	dram_data[39:32] = golden_DRAM[65536+(data_no_input*8)+4] ;
	dram_data[47:40] = golden_DRAM[65536+(data_no_input*8)+5] ;
	dram_data[55:48] = golden_DRAM[65536+(data_no_input*8)+6] ;
	dram_data[63:56] = golden_DRAM[65536+(data_no_input*8)+7] ;
endtask

task Act1_gold_task();

    if((month_input < dram_data[39:32]) || (month_input == dram_data[39:32] && day_input < dram_data[7:0]))begin
        complete = 0;
        warn_msg = Date_Warn; 
    end
    else begin
        if(formula_input == Formula_B || formula_input == Formula_C) begin
            sort_in[0] = dram_data[63:52];
            sort_in[1] = dram_data[51:40];
            sort_in[2] = dram_data[31:20];
            sort_in[3] = dram_data[19:8];
        end
        else if(formula_input == Formula_F || formula_input == Formula_G || formula_input == Formula_H) begin
            sort_in[0] = (dram_data[63:52] > indexA) ? (dram_data[63:52] - indexA) : (indexA - dram_data[63:52]);
            sort_in[1] = (dram_data[51:40] > indexB) ? (dram_data[51:40] - indexB) : (indexB - dram_data[51:40]);
            sort_in[2] = (dram_data[31:20] > indexC) ? (dram_data[31:20] - indexC) : (indexC - dram_data[31:20]);
            sort_in[3] = (dram_data[19:8] > indexD) ? (dram_data[19:8] - indexD) : (indexD - dram_data[19:8]);
        end

        // SORTING
        {sort_layer[0], sort_layer[1]} = (sort_in[0] > sort_in[1]) ? {sort_in[0], sort_in[1]} : {sort_in[1], sort_in[0]};
		{sort_layer[2], sort_layer[3]} = (sort_in[2] > sort_in[3]) ? {sort_in[2], sort_in[3]} : {sort_in[3], sort_in[2]};
		{sort_out[0], sort_out[1]} = (sort_layer[0] > sort_layer[2]) ? {sort_layer[0], sort_layer[2]} : {sort_layer[2], sort_layer[0]};
		{sort_out[2], sort_out[3]} = (sort_layer[1] > sort_layer[3]) ? {sort_layer[1], sort_layer[3]} : {sort_layer[3], sort_layer[1]};

        // cal formula
        case(formula_input)
            Formula_A: begin
                formula_res = (dram_data[63:52] + dram_data[51:40] + dram_data[31:20] + dram_data[19:8]) >> 2;
            end
            Formula_B: begin
                formula_res = sort_out[0] - sort_out[3];
            end
            Formula_C: begin
                formula_res = sort_out[3];
            end
            Formula_D: begin
				formula_res = (dram_data[63:52] >= 'd2047) + (dram_data[51:40] >= 'd2047) 
						+ (dram_data[31:20] >= 'd2047) + (dram_data[19:8] >= 'd2047);
				end
            Formula_E: begin
                formula_res = (indexA <= dram_data[63:52]) + (indexB <= dram_data[51:40]) 
                                + (indexC <= dram_data[31:20]) + (indexD <= dram_data[19:8]);
            end
            Formula_F: begin
                formula_res = (sort_out[1] + sort_out[2] + sort_out[3]) / 3;
            end
            Formula_G: begin
                formula_res =  (sort_out[1] >> 2) + (sort_out[2] >> 2) + (sort_out[3] >> 1);
            end
            Formula_H: begin
                formula_res = (sort_out[0] + sort_out[1] + sort_out[2] + sort_out[3]) >> 2;
            end
        endcase

        // threshold
        case(formula_input)
            Formula_A, Formula_C: begin
                case(mode_input)
                    Insensitive: threshold = 'd2047;
                    Normal: threshold = 'd1023;
                    Sensitive: threshold = 'd511;
                    default: threshold = 'd0;
                endcase
            end
            Formula_B, Formula_F, Formula_G, Formula_H: begin
                case(mode_input)
                    Insensitive: threshold = 'd800;
                    Normal: threshold = 'd400;
                    Sensitive: threshold = 'd200;
                    default: threshold = 'd0;
                endcase
            end
            Formula_D, Formula_E: begin
                case(mode_input)
                    Insensitive: threshold = 'd3;
                    Normal: threshold = 'd2;
                    Sensitive: threshold = 'd1;
                    default: threshold = 'd0;
                endcase
            end
            default: threshold = 'd0;
        endcase

        if(formula_res >= threshold) begin 
            warn_msg = Risk_Warn;
            complete = 0;
        end
        else begin 
            warn_msg = No_Warn;
            complete = 1;
        end
    end
endtask

task Act2_gold_task();
    complete = 1;
    warn_msg = No_Warn; 
    dram_write[39:32] = month_input;
    dram_write[7:0]   = day_input;
    
    index_variation[0] = {1'b0,dram_data[63:52]} + {indexA[11],indexA};
    index_variation[1] = {1'b0,dram_data[51:40]} + {indexB[11],indexB};
    index_variation[2] = {1'b0,dram_data[31:20]} + {indexC[11],indexC};
    index_variation[3] = {1'b0,dram_data[19:8]} + {indexD[11],indexD};

    if(index_variation[0][12]) begin
        complete = 0; 
        warn_msg = Data_Warn;
        dram_write[63:52] = (indexA[11]) ? 12'd0 : 12'b111111111111;
    end
    else dram_write[63:52] = index_variation[0][11:0];
    
    if(index_variation[1][12]) begin
        complete = 0; 
        warn_msg = Data_Warn;
        dram_write[51:40] = (indexB[11]) ? 12'd0 : 12'b111111111111;
    end
    else dram_write[51:40] = index_variation[1][11:0];
    
    if(index_variation[2][12]) begin
        complete = 0; 
        warn_msg = Data_Warn;
        dram_write[31:20] = (indexC[11]) ? 12'd0 : 12'b111111111111;
    end
    else dram_write[31:20] = index_variation[2][11:0];
    
    if(index_variation[3][12]) begin
        complete = 0; 
        warn_msg = Data_Warn;
        dram_write[19:8] = (indexD[11]) ? 12'd0 : 12'b111111111111;
    end
    else dram_write[19:8] = index_variation[3][11:0];

    for(i = 0 ; i < 8 ; i = i + 1)
        golden_DRAM [ (65536 + 8 * data_no_input + i)] = dram_write[ 8 *i +: 8 ] ; // 256 box

    dram_write = 0;
endtask

task Act3_gold_task();
    if ((month_input > dram_data[39:32]) || (month_input == dram_data[39:32] && day_input >= dram_data[7:0]))begin
        complete = 1;
        warn_msg = No_Warn; 
    end
    else begin
        complete = 0;
        warn_msg = Date_Warn; 
    end
endtask


task wait_task; begin
    while (inf.out_valid!== 1'b1) begin
        @(negedge clk);
    end
end endtask

task check_ans_task; begin
    if(inf.out_valid === 1) begin       
        if(inf.warn_msg !== warn_msg || inf.complete != complete) begin 
            $display("Gold warn_msg is : %d", warn_msg);
            $display("Your answer is : %d", inf.warn_msg);
            fail_task;
        end
        @(negedge clk);
    end
end endtask

task fail_task; begin
        $display("*************************************************************************");
        $display("*                             Wrong Answer                              *");
        $display("*************************************************************************");
        $finish;
end endtask 

task pass_task ; begin 
    $display("==========================================================================") ;
	$display("                            Congratulations                               ") ;
    $display("==========================================================================") ;
end endtask 


endprogram
