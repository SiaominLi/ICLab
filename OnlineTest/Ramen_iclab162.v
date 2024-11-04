module Ramen(
    // Input Registers
    input clk, 
    input rst_n, 
    input in_valid,
    input selling,
    input portion, 
    input [1:0] ramen_type,

    // Output Signals
    output reg out_valid_order,
    output reg success,

    output reg out_valid_tot,
    output reg [27:0] sold_num,
    output reg [14:0] total_gain
);


//==============================================//
//             Parameter and Integer            //
//==============================================//

// ramen_type
parameter TONKOTSU = 2'd0;
parameter TONKOTSU_SOY = 2'd1;
parameter MISO = 2'd2;
parameter MISO_SOY = 2'd3;

// initial ingredient
parameter NOODLE_INIT = 'd12000;
parameter BROTH_INIT = 'd41000;
parameter TONKOTSU_SOUP_INIT =  'd9000;
parameter MISO_INIT = 'd1000;
parameter SOY_SAUSE_INIT = 'd1500;

/* FSM */
parameter ORDERING = 2'd0;
parameter MAKING = 2'd1;
parameter OUTPUT_SUCCESS = 2'd2;
parameter ENDING = 2'd3;

//==============================================//
//                 reg declaration              //
//==============================================// 

reg [1:0] current_state, next_state;
reg portion_ff;
reg [1:0] ramen_type_ff;

reg valid_cnt;

reg [20:0] noodle_remain_ff, soup_remain_ff;
reg [20:0] broth_remain_ff;
reg [20:0] miso_remain_ff;
reg [20:0] soy_sause_remain_ff;

// reg success_ff;
reg [27:0] sold_num_ff;
reg flag;



//==============================================//
//                    Design                    //
//==============================================//


//==============================================//
//             Current State Block              //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        current_state <= ORDERING;
    else 
        current_state <= next_state;
end

//==============================================//
//              Next State Block                //
//==============================================//
always @(*) begin
    if(!rst_n) next_state = ORDERING;
    else if (current_state == ORDERING) begin
        if(!selling && flag) next_state = ENDING;
        else if(valid_cnt == 1'b0) next_state = ORDERING;
		else next_state = MAKING;
	end
	else if (current_state == MAKING) next_state = OUTPUT_SUCCESS;
	else if (current_state == OUTPUT_SUCCESS) begin 
        if(selling) next_state = ORDERING;
        else next_state = ENDING; 
    end
	else if (current_state == ENDING) next_state = ORDERING;
	else next_state = ORDERING;
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
		valid_cnt <= 1'b0;
    end
    else begin
        case(current_state)
            ORDERING: begin
               if(in_valid) valid_cnt <= valid_cnt + 1'b1;
            end
            default: valid_cnt <= 1'b0;
        endcase
    end
end


//output 要記得規0
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		ramen_type_ff <= 'd0;
        portion_ff <= 'd0;
    end
	else begin
        case(current_state)
            ORDERING: begin
               if(in_valid && valid_cnt == 1'b0) ramen_type_ff <= ramen_type;
               else if(in_valid && valid_cnt == 1'b1) portion_ff <= portion;
            end
            MAKING: ;
            // default: begin
            //     ramen_type_ff <= 'd0;
            //     portion_ff <= 'd0;
            // end
        endcase
	end
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		noodle_remain_ff <= NOODLE_INIT;
        broth_remain_ff <= BROTH_INIT;
        soup_remain_ff <= TONKOTSU_SOUP_INIT;
        soy_sause_remain_ff <= SOY_SAUSE_INIT;
        miso_remain_ff <= MISO_INIT;
        // sold_num_ff <= 'd0;
    end
	else begin
        case(current_state)
            MAKING: begin
                case(ramen_type_ff)
                    TONKOTSU: begin
                        // sold_num_ff[27:21] <= sold_num_ff[27:21] + 'd1;
                        if(portion_ff == 1'b0) begin //small bowl
                            noodle_remain_ff <= noodle_remain_ff - 'd100;
                            broth_remain_ff <= broth_remain_ff - 'd300;
                            soup_remain_ff <= soup_remain_ff - 'd150;
                            soy_sause_remain_ff <= soy_sause_remain_ff - 'd0;
                            // miso_remain_ff <= miso_remain_ff - 'd0;
                        end
                        else begin //big bowl
                            noodle_remain_ff <= noodle_remain_ff - 'd150;
                            broth_remain_ff <= broth_remain_ff - 'd500;
                            soup_remain_ff <= soup_remain_ff - 'd200;
                            soy_sause_remain_ff <= soy_sause_remain_ff - 'd0;
                            // miso_remain_ff <= miso_remain_ff - 'd0;
                        end
                    end
                    TONKOTSU_SOY: begin
                        if(portion_ff == 1'b0) begin //small bowl
                            noodle_remain_ff <= noodle_remain_ff - 'd100;
                            broth_remain_ff <= broth_remain_ff - 'd300;
                            soup_remain_ff <= soup_remain_ff - 'd100;
                            soy_sause_remain_ff <= soy_sause_remain_ff - 'd30;
                            // miso_remain_ff <= miso_remain_ff - 'd0;
                        end
                        else begin //big bowl
                            noodle_remain_ff <= noodle_remain_ff - 'd150;
                            broth_remain_ff <= broth_remain_ff - 'd500;
                            soup_remain_ff <= soup_remain_ff - 'd150;
                            soy_sause_remain_ff <= soy_sause_remain_ff - 'd50;
                            // miso_remain_ff <= miso_remain_ff - 'd0;
                        end
                    end
                    MISO: begin
                        if(portion_ff == 1'b0) begin //small bowl
                            noodle_remain_ff <= noodle_remain_ff - 'd100;
                            broth_remain_ff <= broth_remain_ff - 'd400;
                            soup_remain_ff <= soup_remain_ff - 'd0;
                            soy_sause_remain_ff <= soy_sause_remain_ff - 'd0;
                            miso_remain_ff <= miso_remain_ff - 'd30;
                        end
                        else begin //big bowl
                            noodle_remain_ff <= noodle_remain_ff - 'd150;
                            broth_remain_ff <= broth_remain_ff - 'd650;
                            soup_remain_ff <= soup_remain_ff - 'd0;
                            soy_sause_remain_ff <= soy_sause_remain_ff - 'd0;
                            miso_remain_ff <= miso_remain_ff - 'd50;
                        end
                    end
                    MISO_SOY: begin
                        if(portion_ff == 1'b0) begin //small bowl
                            noodle_remain_ff <= noodle_remain_ff - 'd100;
                            broth_remain_ff <= broth_remain_ff - 'd300;
                            soup_remain_ff <= soup_remain_ff - 'd70;
                            soy_sause_remain_ff <= soy_sause_remain_ff - 'd15;
                            miso_remain_ff <= miso_remain_ff - 'd15;
                        end
                        else begin //big bowl
                            noodle_remain_ff <= noodle_remain_ff - 'd150;
                            broth_remain_ff <= broth_remain_ff - 'd500;
                            soup_remain_ff <= soup_remain_ff - 'd100;
                            soy_sause_remain_ff <= soy_sause_remain_ff - 'd25;
                            miso_remain_ff <= miso_remain_ff - 'd25;
                        end
                    end
               endcase
            end
            OUTPUT_SUCCESS: begin
                if(ramen_type_ff == TONKOTSU && (noodle_remain_ff[20] == 1 || soup_remain_ff[20] == 1 || broth_remain_ff[20] == 1 )) begin
                    if(portion_ff == 1'b0) begin //small bowl
                        noodle_remain_ff <= noodle_remain_ff + 'd100;
                        broth_remain_ff <= broth_remain_ff + 'd300;
                        soup_remain_ff <= soup_remain_ff + 'd150;
                        soy_sause_remain_ff <= soy_sause_remain_ff + 'd0;
                        // miso_remain_ff <= miso_remain_ff - 'd0;
                    end
                    else begin //big bowl
                        noodle_remain_ff <= noodle_remain_ff + 'd150;
                        broth_remain_ff <= broth_remain_ff + 'd500;
                        soup_remain_ff <= soup_remain_ff + 'd200;
                        soy_sause_remain_ff <= soy_sause_remain_ff + 'd0;
                        // miso_remain_ff <= miso_remain_ff - 'd0;
                    end
                end
                else if(ramen_type_ff == TONKOTSU_SOY && (noodle_remain_ff[20] == 1 || soup_remain_ff[20] == 1 || broth_remain_ff[20] == 1 || soy_sause_remain_ff[20] == 1)) begin
                    if(portion_ff == 1'b0) begin //small bowl
                        noodle_remain_ff <= noodle_remain_ff + 'd100;
                        broth_remain_ff <= broth_remain_ff + 'd300;
                        soup_remain_ff <= soup_remain_ff + 'd100;
                        soy_sause_remain_ff <= soy_sause_remain_ff + 'd30;
                        // miso_remain_ff <= miso_remain_ff - 'd0;
                    end
                    else begin //big bowl
                        noodle_remain_ff <= noodle_remain_ff + 'd150;
                        broth_remain_ff <= broth_remain_ff + 'd500;
                        soup_remain_ff <= soup_remain_ff + 'd150;
                        soy_sause_remain_ff <= soy_sause_remain_ff + 'd50;
                        // miso_remain_ff <= miso_remain_ff - 'd0;
                    end
                end
                else if(ramen_type_ff == MISO && (noodle_remain_ff[20] == 1 || broth_remain_ff[20] == 1 ||  miso_remain_ff[20] == 1)) begin
                    if(portion_ff == 1'b0) begin //small bowl
                        noodle_remain_ff <= noodle_remain_ff + 'd100;
                        broth_remain_ff <= broth_remain_ff + 'd400;
                        soup_remain_ff <= soup_remain_ff + 'd0;
                        soy_sause_remain_ff <= soy_sause_remain_ff + 'd0;
                        miso_remain_ff <= miso_remain_ff + 'd30;
                    end
                    else begin //big bowl
                        noodle_remain_ff <= noodle_remain_ff + 'd150;
                        broth_remain_ff <= broth_remain_ff + 'd650;
                        soup_remain_ff <= soup_remain_ff + 'd0;
                        soy_sause_remain_ff <= soy_sause_remain_ff + 'd0;
                        miso_remain_ff <= miso_remain_ff + 'd50;
                    end
                end
                else if(ramen_type_ff == MISO_SOY && (noodle_remain_ff[20] == 1 || soup_remain_ff[20] == 1 || broth_remain_ff[20] == 1 || miso_remain_ff[20] == 1 || soy_sause_remain_ff[20] == 1)) begin
                    if(portion_ff == 1'b0) begin //small bowl
                        noodle_remain_ff <= noodle_remain_ff + 'd100;
                        broth_remain_ff <= broth_remain_ff + 'd300;
                        soup_remain_ff <= soup_remain_ff + 'd70;
                        soy_sause_remain_ff <= soy_sause_remain_ff + 'd15;
                        miso_remain_ff <= miso_remain_ff + 'd15;
                    end
                    else begin //big bowl
                        noodle_remain_ff <= noodle_remain_ff + 'd150;
                        broth_remain_ff <= broth_remain_ff + 'd500;
                        soup_remain_ff <= soup_remain_ff + 'd100;
                        soy_sause_remain_ff <= soy_sause_remain_ff + 'd25;
                        miso_remain_ff <= miso_remain_ff + 'd25;
                    end
                end
            end
            ENDING: begin
                noodle_remain_ff <= NOODLE_INIT;
                broth_remain_ff <= BROTH_INIT;
                soup_remain_ff <= TONKOTSU_SOUP_INIT;
                soy_sause_remain_ff <= SOY_SAUSE_INIT;
                miso_remain_ff <= MISO_INIT;
            end
        endcase
	end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        success <= 1'b0;
        out_valid_order <= 1'b0;
        sold_num_ff <= 'd0;
        flag <= 1'b0;
    end
    else begin
        if(current_state == OUTPUT_SUCCESS) begin
            out_valid_order <= 1'b1;
            flag <= 1'b1;
            if(ramen_type_ff == TONKOTSU && (noodle_remain_ff[20] == 1 || soup_remain_ff[20] == 1 || broth_remain_ff[20] == 1 )) success <= 1'b0;
            else if(ramen_type_ff == TONKOTSU_SOY && (noodle_remain_ff[20] == 1 || soup_remain_ff[20] == 1 || broth_remain_ff[20] == 1 || soy_sause_remain_ff[20] == 1)) success <= 1'b0;
            else if(ramen_type_ff == MISO && (noodle_remain_ff[20] == 1 || broth_remain_ff[20] == 1 ||  miso_remain_ff[20] == 1)) success <= 1'b0;
            else if(ramen_type_ff == MISO_SOY && (noodle_remain_ff[20] == 1 || soup_remain_ff[20] == 1 || broth_remain_ff[20] == 1 || miso_remain_ff[20] == 1 || soy_sause_remain_ff[20] == 1)) success <= 1'b0;

            // if(noodle_remain_ff[20] == 1 || soup_remain_ff[20] == 1 || broth_remain_ff[20] == 1 || miso_remain_ff[20] == 1 || soy_sause_remain_ff[20] == 1) success <= 1'b0;
            else begin
                success <= 1'b1;

                if(ramen_type_ff == TONKOTSU) sold_num_ff[27:21] <= sold_num_ff[27:21] + 'd1;
                else if(ramen_type_ff == TONKOTSU_SOY) sold_num_ff[20:14] <= sold_num_ff[20:14] + 'd1;
                else if(ramen_type_ff == MISO) sold_num_ff[13:7] <= sold_num_ff[13:7] + 'd1;
                else sold_num_ff[6:0] <= sold_num_ff[6:0] + 'd1;
            end
        end
        else if(current_state == ENDING) begin
            success <= 1'b0;
            out_valid_order <= 1'b0;
            sold_num_ff <= 'd0;
            flag <= 1'b0;
        end
        else begin
            success <= 1'b0;
            out_valid_order <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sold_num <= 'd0;
        total_gain <= 'd0;
        out_valid_tot <= 1'b0;
    end
    else begin
        if(current_state == ENDING) begin
            out_valid_tot <= 1'b1;
            sold_num <= sold_num_ff;
            total_gain <= sold_num_ff[27:21] * 200 + sold_num_ff[20:14] * 250 + sold_num_ff[13:7] * 200 + sold_num_ff[6:0] * 250;
        end
        else begin
            sold_num <= 'd0;
            total_gain <= 'd0;
            out_valid_tot <= 1'b0;
        end
    end
end






endmodule
