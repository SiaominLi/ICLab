//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2023 Fall
//   Lab04 Exercise		: Template Matching with Image Processing
//   Author     		: Hsiao-min Li (siaomin.cs13@nycu.edu.tw)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : TMIP.v
//   Module Name : TMIP
//   Release version : V1.0 (Release Date: 2024-10)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module TMIP(
    // input signals
    clk,
    rst_n,
    in_valid, 
    in_valid2,
    
    image,
    template,
    image_size,
	action,
	
    // output signals
    out_valid,
    out_value
    );

input            clk, rst_n;
input            in_valid, in_valid2;

input      [7:0] image;
input      [7:0] template;
input      [1:0] image_size;
input      [2:0] action;

output reg       out_valid;
output reg       out_value;

//==================================================================
// parameter & integer
//==================================================================
parameter WRITE_IDLE            =  'd0,
          WRITE_MAX_GRAYIMG     =  'd1,
          WRITE_AVG_GRAYIMG     =  'd2,
          WRITE_WEIGHT_GRAYIMG  =  'd3,
          READ_ACTION           =  'd4,
          SHIFT_REG             =  'd5,
          CATCH_SRAM_DATA       =  'd6,
          MAXPOOLING            =  'd7,
          MEDIAN                =  'd8,
          CROSS_CORELATION      =  'd9,
          NEG_FLIP              =  'd10,
          FLIP                  =  'd11;

integer i, j, k, x, y ,z, a, b;    

//==================================================================
// SRAM
//==================================================================
reg image_WEB;
reg [8:0] image_addr;
reg [15:0] DO, image_data_in;
SRAM_512x16 IMG_SRAM (  .A0(image_addr[0]), .A1(image_addr[1]), .A2(image_addr[2]), .A3(image_addr[3]), .A4(image_addr[4]), .A5(image_addr[5]), .A6(image_addr[6]), .A7(image_addr[7]), .A8(image_addr[8]),
                        .DO0(DO[0]), .DO1(DO[1]), .DO2(DO[2]), .DO3(DO[3]), .DO4(DO[4]), .DO5(DO[5]), .DO6(DO[6]), .DO7(DO[7]),
                        .DO8(DO[8]), .DO9(DO[9]), .DO10(DO[10]), .DO11(DO[11]), .DO12(DO[12]), .DO13(DO[13]), .DO14(DO[14]), .DO15(DO[15]),
                        .DI0(image_data_in[0]), .DI1(image_data_in[1]), .DI2(image_data_in[2]), .DI3(image_data_in[3]), .DI4(image_data_in[4]), .DI5(image_data_in[5]), .DI6(image_data_in[6]), .DI7(image_data_in[7]),
                        .DI8(image_data_in[8]), .DI9(image_data_in[9]), .DI10(image_data_in[10]), .DI11(image_data_in[11]), .DI12(image_data_in[12]), .DI13(image_data_in[13]), .DI14(image_data_in[14]), .DI15(image_data_in[15]),
                        .CK(clk), .WEB(image_WEB), .OE(1'b1), .CS(1'b1) );

//==================================================================
// reg & wire
//==================================================================

reg [1:0] RGB_cnt;
reg [9:0] input_cnt; 
reg [7:0] MAX_grayimg_ff;
// reg [8:0] AVG_grayimg_ff;
reg [7:0] AVG_grayimg_qua_ff;
reg [2:0] AVG_grayimg_remain_ff;
reg [7:0] WEIGHT_grayimg_ff;
reg [7:0] AVG_grayimg;
wire [7:0] quotient; //most to 85
wire [1:0] remainder;
reg [2:0] total_remainder; //most to 6

reg [7:0] ready_write_ff [0:4];
reg ready_write_flag;
// reg [1:0] write_cs, write_ns;
reg [7:0] SRAM_write_loc;

reg [7:0] template_ff [0:8];
reg [1:0] image_size_ff; //0 => 4x4, 1 => 8x8 , 2 => 16x16

reg in_valid_flag;

reg [3:0] current_state, next_state; //待定大小
reg [3:0] action_ff [0:7];
reg [3:0] action_cnt;
reg flip_flag;
reg [8:0] offset;
reg CATCH_SRAM_DATA_flag;

reg [7:0] CAL_image_ff [0:255];
// reg read_SRAM_flag;
wire [8:0] offset_limit;
assign offset_limit = (image_size_ff == 0) ? 'd8 : (image_size_ff == 1) ? 'd32 : 'd128;

wire offset_flag;
assign offset_flag = (offset == (offset_limit + 1)) ? 1'b0 : 1'b1;

reg [3:0] cur_act_index;
wire [7:0] max_outup0, max_outup1, max_outup2, max_outup3;
reg [7:0] maxcmp_index;
reg [6:0] maxcmp_add;
reg [5:0] save_max_loc; // max 8x8
reg [1:0] curr_image_size;

reg [7:0] mid_0[0:8], mid_1[0:8], mid_2[0:8], mid_3[0:8], mid_4[0:8], mid_5[0:8], mid_6[0:8], mid_7[0:8], mid_8[0:8], mid_9[0:8], mid_10[0:8], mid_11[0:8], mid_12[0:8], mid_13[0:8], mid_14[0:8], mid_15[0:8];
wire [7:0] mid_res[0:15];
reg [4:0] clock_cnt;

reg neg_cnt;
// reg max_16_cnt;

reg [7:0] temp_median_ans[0:15];

reg [19:0] final_ans;
reg [7:0] img_pixel, template_pixel;

reg [3:0] template_cnt;
reg [5:0] mul_cnt;

reg [8:0] ouput_index;
reg [7:0] mul [0:8];
reg [4:0] outbit_index;
reg [19:0] temp_out;
reg [3:0] set_cnt;

wire [8:0] output_limit;
assign output_limit = (curr_image_size == 0) ? 'd16 : (curr_image_size == 1) ? 'd64 : 'd256;
//==================================================================
// design
//==================================================================

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        RGB_cnt <= 'd0;
        input_cnt <= 'd0;

        MAX_grayimg_ff <= 'd0;
        AVG_grayimg_qua_ff <= 'd0;
        AVG_grayimg_remain_ff <= 'd0;
        WEIGHT_grayimg_ff <= 'd0;
        template_ff[0] <= 'd0;
        template_ff[1] <= 'd0;
        template_ff[2] <= 'd0;
        template_ff[3] <= 'd0;
        template_ff[4] <= 'd0;
        template_ff[5] <= 'd0;
        template_ff[6] <= 'd0;
        template_ff[7] <= 'd0;
        template_ff[8] <= 'd0;
        image_size_ff <= 'd0;

        ready_write_flag <= 1'b0;

        // out_valid = 0;
        // out_value = 0;
    end
    else begin
        if(in_valid) begin
            case(RGB_cnt)
                0:  begin
                    MAX_grayimg_ff <= image;
                    AVG_grayimg_qua_ff <= quotient;
                    AVG_grayimg_remain_ff <= remainder;
                    WEIGHT_grayimg_ff <= image >> 2;
                    RGB_cnt <= RGB_cnt + 'd1;
                end
                1:  begin
                    MAX_grayimg_ff <= (image > MAX_grayimg_ff) ? image : MAX_grayimg_ff;
                    AVG_grayimg_remain_ff <= AVG_grayimg_remain_ff + remainder;
                    AVG_grayimg_qua_ff <= AVG_grayimg_qua_ff + quotient;
                    WEIGHT_grayimg_ff <= WEIGHT_grayimg_ff + (image >> 1);
                    RGB_cnt <= RGB_cnt + 'd1;
                end
                2:  begin
                    if(ready_write_flag) begin
                        ready_write_ff[2] <= AVG_grayimg;
                        ready_write_ff[4] <= WEIGHT_grayimg_ff + (image >> 2);
                    end
                    else begin
                        ready_write_ff[0] <= (image > MAX_grayimg_ff) ? image : MAX_grayimg_ff;
                        ready_write_ff[1] <= AVG_grayimg;
                        ready_write_ff[3] <= WEIGHT_grayimg_ff + (image >> 2);
                    end
                    ready_write_flag <= ready_write_flag + 1'b1;
                    RGB_cnt <= 'd0;
                    
                end
            endcase

            if(input_cnt == 0) image_size_ff <= image_size;
            if(input_cnt < 9) template_ff[input_cnt] <= template;
            
            input_cnt <= input_cnt + 'd1;
        end
        else if(in_valid_flag) begin
            case(image_size_ff)
                0: begin
                    input_cnt <= (input_cnt < 49) ? (input_cnt + 'd1) : 'd0;
                end
                1: begin
                    input_cnt <= (input_cnt < 193) ? (input_cnt + 'd1) : 'd0;
                end
                2: begin
                    input_cnt <= (input_cnt < 769) ? (input_cnt + 'd1) : 'd0;
                end
            endcase
        end
        else input_cnt <= 'd0;
    end
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) in_valid_flag <= 1'b0;
    else begin
        if(in_valid) in_valid_flag <= 1'b1;
        else if(in_valid2) in_valid_flag <= 1'b0;
    end
end
/* -------------------- calulate average grayscale -------------------- */
DIV3_TABLE div0(.dividend(image), .quotient(quotient), .remainder(remainder));

always @(*) begin
    if( RGB_cnt == 2 ) begin
        total_remainder = AVG_grayimg_remain_ff + remainder;

        if( total_remainder == 'd0 || total_remainder == 'd1 || total_remainder == 'd2) 
            AVG_grayimg = AVG_grayimg_qua_ff + quotient;
        else if( total_remainder == 'd3 || total_remainder == 'd4 || total_remainder == 'd5) 
            AVG_grayimg = AVG_grayimg_qua_ff + quotient + 1;
        else if( total_remainder == 'd6 )
            AVG_grayimg = AVG_grayimg_qua_ff + quotient + 2;
        else AVG_grayimg = 'd0;
    end
    else AVG_grayimg = 'd0;
end
/* -------------------------------------------------------------------- */

/* ----------- [FSM] Control WRITE Current State & Next State ---------- */
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        current_state <= WRITE_IDLE;
    else 
        current_state <= next_state;
end

always @(*) begin
    if(!rst_n) next_state = WRITE_IDLE;
    else begin
        case(current_state)
            /* PART1 */
            WRITE_IDLE: begin
                case(input_cnt)
                    4, 10, 16, 22, 28, 34, 40, 46, 52, 58, 64, 70, 76, 82, 88, 94, 100, 106, 112, 118, 124, 130,
                    136, 142, 148, 154, 160, 166, 172, 178, 184, 190, 196, 202, 208, 214, 220, 226, 232, 238, 244,
                    250, 256, 262, 268, 274, 280, 286, 292, 298, 304, 310, 316, 322, 328, 334, 340, 346, 352, 358,
                    364, 370, 376, 382, 388, 394, 400, 406, 412, 418, 424, 430, 436, 442, 448, 454, 460, 466, 472,
                    478, 484, 490, 496, 502, 508, 514, 520, 526, 532, 538, 544, 550, 556, 562, 568, 574, 580, 586,
                    592, 598, 604, 610, 616, 622, 628, 634, 640, 646, 652, 658, 664, 670, 676, 682, 688, 694, 700,
                    706, 712, 718, 724, 730, 736, 742, 748, 754, 760, 766: next_state = WRITE_MAX_GRAYIMG;
                    default: next_state = WRITE_IDLE;
                endcase
            end
            WRITE_MAX_GRAYIMG:  next_state = WRITE_AVG_GRAYIMG;
            WRITE_AVG_GRAYIMG:  next_state = WRITE_WEIGHT_GRAYIMG;
            WRITE_WEIGHT_GRAYIMG:  begin
                if(!in_valid && current_state == WRITE_WEIGHT_GRAYIMG) next_state = READ_ACTION;
                else next_state = WRITE_IDLE;
            end
            /* PART2 */
            READ_ACTION: begin
                if(!in_valid2 && action_cnt >= 1) next_state = SHIFT_REG;
                else if(set_cnt == 'd8) next_state = WRITE_IDLE;
                else next_state = READ_ACTION;
            end
            MAXPOOLING: begin
                case(action_ff[cur_act_index]) 
                    'd3: next_state = MAXPOOLING;
                    'd4: next_state = NEG_FLIP;
                    'd6: next_state = MEDIAN;
                    'd7: next_state = CROSS_CORELATION;
                    default:  next_state = NEG_FLIP;
                endcase
            end
            MEDIAN: begin
                case(action_ff[cur_act_index]) 
                    'd3: next_state = MAXPOOLING;
                    'd4: next_state = NEG_FLIP;
                    'd6: next_state = MEDIAN;
                    'd7: next_state = CROSS_CORELATION;
                    default:  next_state = NEG_FLIP;
                endcase
            end
            CROSS_CORELATION: begin
                if(out_valid == 0 && ouput_index != 0) next_state = READ_ACTION;
                else begin
                    case(image_size_ff) 
                        'd0: begin
                            if(ouput_index == 17) next_state = READ_ACTION;
                            else next_state = CROSS_CORELATION;
                        end
                        'd1: begin
                            if(ouput_index == 65) next_state = READ_ACTION;
                            else next_state = CROSS_CORELATION;
                        end
                        'd2: begin
                            if(ouput_index == 257) next_state = READ_ACTION;
                            else next_state = CROSS_CORELATION;
                        end
                        default:  next_state = CROSS_CORELATION;
                    endcase
                end
            end
            SHIFT_REG: begin
                next_state = CATCH_SRAM_DATA;
            end
            CATCH_SRAM_DATA: begin
                if(!offset_flag) next_state = FLIP;
                else next_state = CATCH_SRAM_DATA;
            end
            NEG_FLIP: begin
                case(action_ff[cur_act_index]) 
                    'd3: next_state = MAXPOOLING;
                    'd4: next_state = NEG_FLIP;
                    'd6: next_state = MEDIAN;
                    'd7: next_state = CROSS_CORELATION;
                    default:  next_state = NEG_FLIP;
                endcase
            end
            FLIP: begin
                case(action_ff[1]) 
                    'd3: next_state = MAXPOOLING;
                    'd4: next_state = NEG_FLIP;
                    'd6: next_state = MEDIAN;
                    'd7: next_state = CROSS_CORELATION;
                    default:  next_state = NEG_FLIP;
                endcase
            end
            default: next_state = WRITE_IDLE;
        endcase
    end
end
/* -------------------------------------------------------------------- */

/* ---------------------- Control SRAM_write_loc ---------------------- */
always @(posedge clk) begin
    if (in_valid && (input_cnt == 0)) SRAM_write_loc <= 'd0; 
    else begin
        if(current_state == WRITE_WEIGHT_GRAYIMG) begin
            case(image_size_ff)
                0: begin   
                    if(SRAM_write_loc < 7) SRAM_write_loc <= SRAM_write_loc + 'd1;
                    else  SRAM_write_loc <= 'd0; 
                end
                1: begin
                    if(SRAM_write_loc < 31) SRAM_write_loc <= SRAM_write_loc + 'd1;
                    else  SRAM_write_loc <= 'd0; 
                end
                2: begin
                    if(SRAM_write_loc < 127) SRAM_write_loc <= SRAM_write_loc + 'd1;
                    else  SRAM_write_loc <= 'd0; 
                end
            endcase
        end
    end
end
/* -------------------------------------------------------------------- */
/* -------------------------- Read/Write SRAM ------------------------- */
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        image_WEB <= 0;
        image_data_in <= 0;
        image_addr <= 0;
    end
    else begin
        case(current_state)
            WRITE_MAX_GRAYIMG: begin
                image_WEB <= 0;
                image_data_in <= (image > MAX_grayimg_ff) ?  {image, ready_write_ff[0]} : {MAX_grayimg_ff, ready_write_ff[0]};
                image_addr <= {1'b0, SRAM_write_loc} + 9'd0;
            end
            WRITE_AVG_GRAYIMG:  begin
                image_WEB <= 0;
                image_data_in <= {ready_write_ff[2], ready_write_ff[1]};
                image_addr <= {1'b0, SRAM_write_loc} + 9'd128;
            end
            WRITE_WEIGHT_GRAYIMG:  begin
                image_WEB <= 0;
                image_data_in <= {ready_write_ff[4], ready_write_ff[3]};
                image_addr <= {1'b0, SRAM_write_loc} + 9'd256;
            end
            READ_ACTION, SHIFT_REG, CATCH_SRAM_DATA: begin
                if(CATCH_SRAM_DATA_flag) begin
                    if(action_ff[0] == 3'd0) begin
                        offset <= offset + 'd1;
                        image_addr <= ('d0 + offset);
                        image_WEB <= 1;
                    end
                    else if(action_ff[0] == 3'd1) begin
                        offset <= offset + 'd1;
                        image_addr <= ('d128 + offset);
                        image_WEB <= 1;
                    end
                    else if(action_ff[0] == 3'd2) begin
                        offset <= offset + 'd1;
                        image_addr <= ('d256 + offset);
                        image_WEB <= 1;
                    end
                end
                else begin
                    image_WEB <= 1;
                    image_addr <= 'd0;
                    offset <= 'd0;
                end   
            end
            default: begin
                image_WEB <= 1;
                image_addr <= 'd0;
                offset <= 'd0;
            end
        endcase
    end
end
/* -------------------------------------------------------------------- */

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (i = 0; i < 8 ; i = i + 1) begin
            action_ff[i] <= 'd7;
        end
        action_cnt <= 'd0;
        flip_flag <= 'd0;
        CATCH_SRAM_DATA_flag <= 1'b0;
    end
    else if(out_valid) begin
        for (i = 0; i < 8 ; i = i + 1) begin
            action_ff[i] <= 'd7;
        end
        action_cnt <= 'd0;
        flip_flag <= 'd0;
        CATCH_SRAM_DATA_flag <= 1'b0;
    end
    else begin
        case(current_state)
            READ_ACTION: begin
                if(in_valid2) begin
                    CATCH_SRAM_DATA_flag <= 1'b1;
                    if( action == 3'd5 )begin
                        flip_flag <= flip_flag + 'd1;
                    end
                    else begin
                        action_ff[action_cnt] <= action;
                        action_cnt <= action_cnt + 'd1;
                    end
                end
            end
            SHIFT_REG: begin
                // CATCH_SRAM_DATA_flag <= (action_cnt == 7 && image_size_ff == 0) ? 1'b0 : 1'b1;
                CATCH_SRAM_DATA_flag <= 1'b1;
                if((action_ff[1] == 3'd4) && (action_ff[2] == 3'd4)) begin
                    action_ff[1] <= action_ff[3];
                    action_ff[2] <= action_ff[4];
                    action_ff[3] <= action_ff[5];
                    action_ff[4] <= action_ff[6];
                    action_ff[5] <= action_ff[7];
                    action_ff[6] <= 'd0;
                    action_ff[7] <= 'd0;

                    action_cnt <= action_cnt - 'd2;
                end
            end
            CATCH_SRAM_DATA: begin
                CATCH_SRAM_DATA_flag <= 1'b1; //其他case都要是 0
            end
            CROSS_CORELATION: begin
                for (i = 0; i < 8 ; i = i + 1) begin
                    action_ff[i] <= 0;
                end
            end
            default: begin
                action_cnt <= 'd0;
                flip_flag <= 'd0;
                CATCH_SRAM_DATA_flag <= 1'b0;
            end
        endcase
    end
end

wire [8:0] CAL_image_ff_loc;
assign CAL_image_ff_loc = (offset - 2) << 1;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (j = 0; j < 256 ; j = j + 1) begin
            CAL_image_ff[j] <= 0;
        end
    end
    else begin
    case(current_state)
        WRITE_IDLE, WRITE_MAX_GRAYIMG, WRITE_AVG_GRAYIMG, WRITE_WEIGHT_GRAYIMG: begin
            for (j = 0; j < 256 ; j = j + 1) begin
                CAL_image_ff[j] <= 0;
            end
        end
        READ_ACTION, SHIFT_REG, CATCH_SRAM_DATA: begin
            if ((offset - 2) < offset_limit) begin
                CAL_image_ff[CAL_image_ff_loc] <= DO[7:0];
                CAL_image_ff[CAL_image_ff_loc + 1] <= DO[15:8];
            end 
        end
        MAXPOOLING: begin
            if(maxcmp_index == 8'b11111111 || maxcmp_index == 8'b11110000) begin
                if(curr_image_size == 2'd0) begin
                    for (j = 16; j < 64 ; j = j + 1) begin
                        CAL_image_ff[j] <= 0;
                    end
                end
                else if(curr_image_size == 2'd1) begin
                    for (j = 64; j < 256 ; j = j + 1) begin
                        CAL_image_ff[j] <= 0;
                    end
                end
            end
            else if(maxcmp_add != 'd0) begin
                CAL_image_ff[save_max_loc] <= max_outup0;
                CAL_image_ff[save_max_loc+1] <= max_outup1;
                CAL_image_ff[save_max_loc+2] <= max_outup2;
                CAL_image_ff[save_max_loc+3] <= max_outup3;
            end
        end
        NEG_FLIP: begin
            if(next_state == current_state) begin
                // if(action_ff[cur_act_index-1] != 'd4) begin
                    case(curr_image_size)
                        2'd0: begin
                            for (k = 0; k < 16 ; k = k + 1) begin
                                CAL_image_ff[k] <= ~CAL_image_ff[k];
                            end
                        end
                        2'd1: begin
                            for (k = 0; k < 64 ; k = k + 1) begin
                                CAL_image_ff[k] <= ~CAL_image_ff[k];
                            end
                        end
                        2'd2: begin
                            for (k = 0; k < 256 ; k = k + 1) begin
                                CAL_image_ff[k] <= ~CAL_image_ff[k];
                            end
                        end
                    endcase
                // end
            end
        end
        MEDIAN: begin
            case(curr_image_size)
                2'd0: begin
                    if(clock_cnt == 5'b11111) begin
                        for (k = 0; k < 16 ; k = k + 1) begin
                            CAL_image_ff[k] <= mid_res[k];
                        end
                    end
                end
                2'd1: begin
                    if(clock_cnt == 5'b11111) begin
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd0) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x]<= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd1) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+16]<= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd2) begin
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= 0;
                        end
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+32]<= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            CAL_image_ff[k+48] <= mid_res[k];
                        end
                    end
                end
                2'd2: begin
                    if(clock_cnt == 5'b11111) begin
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd0) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd1) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+16] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd2) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+32] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd3) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+48] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd4) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+64] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd5) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+80] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd6) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+96] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd7) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+112] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd8) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+128] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd9) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+144] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd10) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+160] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd11) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+176] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd12) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+192] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd13) begin
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+208] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= mid_res[k];
                        end
                    end
                    else if(clock_cnt == 'd14) begin
                        for (k = 0; k < 16 ; k = k + 1) begin
                            temp_median_ans[k] <= 0;
                        end
                        for (x = 0; x < 16 ; x = x + 1) begin
                            CAL_image_ff[x+224] <= temp_median_ans[x];
                        end
                        for (k = 0; k < 16 ; k = k + 1) begin
                            CAL_image_ff[k+240] <= mid_res[k];
                        end
                    end
                end              
            endcase
        end
        FLIP: begin
            if(flip_flag) begin
                case(curr_image_size)
                    2'd0: begin
                        for (z = 0; z < 16 ; z = z + 4) begin
                            CAL_image_ff[z] <= CAL_image_ff[z+3];
                            CAL_image_ff[z+3] <= CAL_image_ff[z];
                            CAL_image_ff[z+1] <= CAL_image_ff[z+2];
                            CAL_image_ff[z+2] <= CAL_image_ff[z+1];
                        end
                    end
                    2'd1: begin
                        for (a = 0; a < 64 ; a = a + 8) begin
                            CAL_image_ff[a] <= CAL_image_ff[a+7];
                            CAL_image_ff[a+7] <= CAL_image_ff[a];
                            CAL_image_ff[a+1] <= CAL_image_ff[a+6];
                            CAL_image_ff[a+6] <= CAL_image_ff[a+1];
                            CAL_image_ff[a+2] <= CAL_image_ff[a+5];
                            CAL_image_ff[a+5] <= CAL_image_ff[a+2];
                            CAL_image_ff[a+3] <= CAL_image_ff[a+4];
                            CAL_image_ff[a+4] <= CAL_image_ff[a+3];
                        end
                    end
                    2'd2: begin
                        for (b = 0; b < 256 ; b = b + 16) begin
                            CAL_image_ff[b] <= CAL_image_ff[b+15];
                            CAL_image_ff[b+15] <= CAL_image_ff[b];
                            CAL_image_ff[b+1] <= CAL_image_ff[b+14];
                            CAL_image_ff[b+14] <= CAL_image_ff[b+1];
                            CAL_image_ff[b+2] <= CAL_image_ff[b+13];
                            CAL_image_ff[b+13] <= CAL_image_ff[b+2];
                            CAL_image_ff[b+3] <= CAL_image_ff[b+12];
                            CAL_image_ff[b+12] <= CAL_image_ff[b+3];
                            CAL_image_ff[b+4] <= CAL_image_ff[b+11];
                            CAL_image_ff[b+11] <= CAL_image_ff[b+4];
                            CAL_image_ff[b+5] <= CAL_image_ff[b+10];
                            CAL_image_ff[b+10] <= CAL_image_ff[b+5];
                            CAL_image_ff[b+6] <= CAL_image_ff[b+9];
                            CAL_image_ff[b+9] <= CAL_image_ff[b+6];
                            CAL_image_ff[b+7] <= CAL_image_ff[b+8];
                            CAL_image_ff[b+8] <= CAL_image_ff[b+7];
                        end
                    end
                endcase
            end
        end
    endcase 
    end
end

// always @(posedge clk) begin
//     case(current_state)
//         READ_ACTION, SHIFT_REG, CATCH_SRAM_DATA: curr_image_size <= image_size_ff;
//         MAXPOOLING: begin
//             if(curr_image_size == 2'd1 && maxcmp_index == 'd48) curr_image_size <= 1'b0;
//             else if(curr_image_size == 2'd2 && maxcmp_index == 'd224) curr_image_size <= 1'b1;
//         end
//     endcase
// end

always @(posedge clk) begin
    case(current_state)
        READ_ACTION, SHIFT_REG, CATCH_SRAM_DATA: begin
            curr_image_size <= image_size_ff;
            // neg_cnt <= 0;
            maxcmp_index <= (curr_image_size == 2'd1) ? 8'b11110000 : 8'b11111000;
            save_max_loc <= 6'b111100;
            maxcmp_add <= 0;
            // max_16_cnt <= 0;
        end
        MAXPOOLING: begin
            case(curr_image_size)
                'd0: if(current_state == next_state) cur_act_index <= cur_act_index + 1'b1;
                'd1: begin
                    if(maxcmp_index == 'd48) begin
                        // $display("MAXPOOLING to change cur_act_index %d @time: %t",cur_act_index,$time);
                        curr_image_size <= 1'b0;
                        cur_act_index <= cur_act_index + 1'b1;
                        maxcmp_index <= 8'b11111111;
                    end
                    else begin
                        maxcmp_index <= maxcmp_index + 'd16;
                        maxcmp_add <= 'd8;
                        save_max_loc <= save_max_loc + 'd4;
                    end
                end
                'd2: begin
                    // max_16_cnt <= max_16_cnt + 1;
                    if(maxcmp_index == 'd232) begin
                        // $display("MAXPOOLING to change cur_act_index %d @time: %t",cur_act_index,$time);
                        curr_image_size <= 1'b1;
                        cur_act_index <= cur_act_index + 1'b1;
                        // maxcmp_index <= 8'b11111111;
                        maxcmp_index <= 8'b11110000;
                    end
                    else begin
                        if(maxcmp_index == 8 || maxcmp_index == 40 || maxcmp_index == 72 || maxcmp_index == 104 || maxcmp_index == 136 || maxcmp_index == 168 || maxcmp_index == 200) maxcmp_index <= maxcmp_index + 'd24;
                        else maxcmp_index <= maxcmp_index + 'd8;
                        maxcmp_add <= 'd16;
                        save_max_loc <= save_max_loc + 'd4;
                    end
                end
            endcase
            clock_cnt <= 5'b11111;
        end
        MEDIAN: begin
            if(curr_image_size == 2'd0) begin
                if(clock_cnt == 5'b11111) begin
                    cur_act_index <= cur_act_index + 1'b1;
                    clock_cnt <= clock_cnt + 1'b1;
                    // clock_cnt <= 4'b1111;
                end
                else if(clock_cnt == 'd0)  clock_cnt <= 5'b11111;
                else clock_cnt <= clock_cnt + 1'b1;
            end
            else if(curr_image_size == 2'd1) begin
                if(clock_cnt == 'd1) begin
                    cur_act_index <= cur_act_index + 1'b1;
                    clock_cnt <= clock_cnt + 1'b1;
                end
                else if(clock_cnt == 'd2)  clock_cnt <= 5'b11111;
                else clock_cnt <= clock_cnt + 1'b1;
            end
            else if(curr_image_size == 2'd2) begin
                if(clock_cnt == 'd14) begin
                    cur_act_index <= cur_act_index + 1'b1;
                    clock_cnt <= clock_cnt + 1'b1;
                end
                else if(clock_cnt == 'd15)  clock_cnt <= 5'b11111;
                else clock_cnt <= clock_cnt + 1'b1;
            end
            else clock_cnt <= clock_cnt + 1'b1;
            maxcmp_index <= (curr_image_size == 2'd1) ? 8'b11110000 : 8'b11111000;
            save_max_loc <= 6'b111100;
            maxcmp_add <= 0;
        end
        NEG_FLIP: begin
            if(next_state == current_state) begin
                // $display("NEG_FLIP to change cur_act_index %d @time: %t",cur_act_index,$time);
                // $display("next_state %d | current_state %d |  @time : %t",next_state,current_state,$time);
                cur_act_index <= cur_act_index + 1'b1;
            end
            clock_cnt <= 5'b11111;
            maxcmp_index <= (curr_image_size == 2'd1) ? 8'b11110000 : 8'b11111000;
            save_max_loc <= 6'b111100;
            maxcmp_add <= 0;
        end
        default: begin
            clock_cnt <= 5'b11111;
            cur_act_index <= 1'b1;
            maxcmp_add <= 0;
            maxcmp_index <= (curr_image_size == 2'd1) ? 8'b11110000 : 8'b11111000;
            save_max_loc <= 6'b111100;
        end
    endcase
end
// med, max, neg, flip, med
always @(*) begin
    if((current_state == MEDIAN)) begin
        case(curr_image_size)
            2'd0: begin //4x4
                if(clock_cnt == 5'b11111) begin
                    // mid_0 mapping
                    mid_0[0] = CAL_image_ff[0]; 
                    mid_0[1] = CAL_image_ff[0]; 
                    mid_0[2] = CAL_image_ff[1]; 
                    mid_0[3] = CAL_image_ff[0]; 
                    mid_0[4] = CAL_image_ff[0]; 
                    mid_0[5] = CAL_image_ff[1]; 
                    mid_0[6] = CAL_image_ff[4]; 
                    mid_0[7] = CAL_image_ff[4]; 
                    mid_0[8] = CAL_image_ff[5]; 

                    // mid_1 mapping
                    mid_1[0] = CAL_image_ff[0]; 
                    mid_1[1] = CAL_image_ff[1]; 
                    mid_1[2] = CAL_image_ff[2]; 
                    mid_1[3] = CAL_image_ff[0]; 
                    mid_1[4] = CAL_image_ff[1]; 
                    mid_1[5] = CAL_image_ff[2]; 
                    mid_1[6] = CAL_image_ff[4]; 
                    mid_1[7] = CAL_image_ff[5]; 
                    mid_1[8] = CAL_image_ff[6]; 

                    // mid_2 mapping
                    mid_2[0] = CAL_image_ff[1]; 
                    mid_2[1] = CAL_image_ff[2]; 
                    mid_2[2] = CAL_image_ff[3]; 
                    mid_2[3] = CAL_image_ff[1]; 
                    mid_2[4] = CAL_image_ff[2]; 
                    mid_2[5] = CAL_image_ff[3]; 
                    mid_2[6] = CAL_image_ff[5]; 
                    mid_2[7] = CAL_image_ff[6]; 
                    mid_2[8] = CAL_image_ff[7]; 

                    // mid_3 mapping
                    mid_3[0] = CAL_image_ff[2]; 
                    mid_3[1] = CAL_image_ff[3]; 
                    mid_3[2] = CAL_image_ff[3]; 
                    mid_3[3] = CAL_image_ff[2]; 
                    mid_3[4] = CAL_image_ff[3]; 
                    mid_3[5] = CAL_image_ff[3]; 
                    mid_3[6] = CAL_image_ff[6]; 
                    mid_3[7] = CAL_image_ff[7]; 
                    mid_3[8] = CAL_image_ff[7]; 

                    // mid_4 mapping
                    mid_4[0] = CAL_image_ff[0]; 
                    mid_4[1] = CAL_image_ff[0]; 
                    mid_4[2] = CAL_image_ff[1]; 
                    mid_4[3] = CAL_image_ff[4]; 
                    mid_4[4] = CAL_image_ff[4]; 
                    mid_4[5] = CAL_image_ff[5]; 
                    mid_4[6] = CAL_image_ff[8]; 
                    mid_4[7] = CAL_image_ff[8]; 
                    mid_4[8] = CAL_image_ff[9]; 

                    // mid_5 mapping
                    mid_5[0] = CAL_image_ff[0];
                    mid_5[1] = CAL_image_ff[1];
                    mid_5[2] = CAL_image_ff[2];
                    mid_5[3] = CAL_image_ff[4];
                    mid_5[4] = CAL_image_ff[5];
                    mid_5[5] = CAL_image_ff[6];
                    mid_5[6] = CAL_image_ff[8];
                    mid_5[7] = CAL_image_ff[9];
                    mid_5[8] = CAL_image_ff[10];

                    // mid_6 mapping
                    mid_6[0] = CAL_image_ff[1]; 
                    mid_6[1] = CAL_image_ff[2]; 
                    mid_6[2] = CAL_image_ff[3]; 
                    mid_6[3] = CAL_image_ff[5]; 
                    mid_6[4] = CAL_image_ff[6]; 
                    mid_6[5] = CAL_image_ff[7]; 
                    mid_6[6] = CAL_image_ff[9]; 
                    mid_6[7] = CAL_image_ff[10];
                    mid_6[8] = CAL_image_ff[11];

                    // mid_7 mapping
                    mid_7[0] = CAL_image_ff[2];
                    mid_7[1] = CAL_image_ff[3];
                    mid_7[2] = CAL_image_ff[3];
                    mid_7[3] = CAL_image_ff[6];
                    mid_7[4] = CAL_image_ff[7];
                    mid_7[5] = CAL_image_ff[7];
                    mid_7[6] = CAL_image_ff[10]; 
                    mid_7[7] = CAL_image_ff[11]; 
                    mid_7[8] = CAL_image_ff[11]; 

                    // mid_8 mapping
                    mid_8[0] = CAL_image_ff[4]; 
                    mid_8[1] = CAL_image_ff[4]; 
                    mid_8[2] = CAL_image_ff[5]; 
                    mid_8[3] = CAL_image_ff[8]; 
                    mid_8[4] = CAL_image_ff[8]; 
                    mid_8[5] = CAL_image_ff[9]; 
                    mid_8[6] = CAL_image_ff[12];
                    mid_8[7] = CAL_image_ff[12]; 
                    mid_8[8] = CAL_image_ff[13]; 

                    mid_9[0] = CAL_image_ff[4];
                    mid_9[1] = CAL_image_ff[5];
                    mid_9[2] = CAL_image_ff[6];
                    mid_9[3] = CAL_image_ff[8];
                    mid_9[4] = CAL_image_ff[9];
                    mid_9[5] = CAL_image_ff[10];
                    mid_9[6] = CAL_image_ff[12];
                    mid_9[7] = CAL_image_ff[13];
                    mid_9[8] = CAL_image_ff[14];

                    mid_10[0] = CAL_image_ff[5];
                    mid_10[1] = CAL_image_ff[6];
                    mid_10[2] = CAL_image_ff[7];
                    mid_10[3] = CAL_image_ff[9];
                    mid_10[4] = CAL_image_ff[10];
                    mid_10[5] = CAL_image_ff[11];
                    mid_10[6] = CAL_image_ff[13];
                    mid_10[7] = CAL_image_ff[14];
                    mid_10[8] = CAL_image_ff[15];

                    mid_11[0] = CAL_image_ff[6];
                    mid_11[1] = CAL_image_ff[7];
                    mid_11[2] = CAL_image_ff[7];
                    mid_11[3] = CAL_image_ff[10];
                    mid_11[4] = CAL_image_ff[11];
                    mid_11[5] = CAL_image_ff[11];
                    mid_11[6] = CAL_image_ff[14];
                    mid_11[7] = CAL_image_ff[15];
                    mid_11[8] = CAL_image_ff[15];

                    mid_12[0] = CAL_image_ff[8];
                    mid_12[1] = CAL_image_ff[8];
                    mid_12[2] = CAL_image_ff[9];
                    mid_12[3] = CAL_image_ff[12];
                    mid_12[4] = CAL_image_ff[12];
                    mid_12[5] = CAL_image_ff[13];
                    mid_12[6] = CAL_image_ff[12];
                    mid_12[7] = CAL_image_ff[12];
                    mid_12[8] = CAL_image_ff[13];

                    mid_13[0] = CAL_image_ff[8];
                    mid_13[1] = CAL_image_ff[9];
                    mid_13[2] = CAL_image_ff[10];
                    mid_13[3] = CAL_image_ff[12];
                    mid_13[4] = CAL_image_ff[13];
                    mid_13[5] = CAL_image_ff[14];
                    mid_13[6] = CAL_image_ff[12];
                    mid_13[7] = CAL_image_ff[13];
                    mid_13[8] = CAL_image_ff[14];

                    mid_14[0] = CAL_image_ff[9];
                    mid_14[1] = CAL_image_ff[10];
                    mid_14[2] = CAL_image_ff[11];
                    mid_14[3] = CAL_image_ff[13];
                    mid_14[4] = CAL_image_ff[14];
                    mid_14[5] = CAL_image_ff[15];
                    mid_14[6] = CAL_image_ff[13];
                    mid_14[7] = CAL_image_ff[14];
                    mid_14[8] = CAL_image_ff[15];

                    mid_15[0] = CAL_image_ff[10];
                    mid_15[1] = CAL_image_ff[11];
                    mid_15[2] = CAL_image_ff[11];
                    mid_15[3] = CAL_image_ff[14];
                    mid_15[4] = CAL_image_ff[15];
                    mid_15[5] = CAL_image_ff[15];
                    mid_15[6] = CAL_image_ff[14];
                    mid_15[7] = CAL_image_ff[15];
                    mid_15[8] = CAL_image_ff[15];
                end
                else begin
                    for( i = 0 ; i < 9 ; i = i + 1) begin
                        mid_0[i] = 0;
                        mid_1[i] = 0;
                        mid_2[i] = 0;
                        mid_3[i] = 0;
                        mid_4[i] = 0;
                        mid_5[i] = 0;
                        mid_6[i] = 0;
                        mid_7[i] = 0;
                        mid_8[i] = 0;
                        mid_9[i] = 0;
                        mid_10[i] = 0;
                        mid_11[i] = 0;
                        mid_12[i] = 0;
                        mid_13[i] = 0;
                        mid_14[i] = 0;
                        mid_15[i] = 0;
                    end
                end
            end
            2'd1: begin
                if(clock_cnt == 5'b11111) begin
                    mid_0[0] = CAL_image_ff[0];
                    mid_0[1] = CAL_image_ff[0];
                    mid_0[2] = CAL_image_ff[1];
                    mid_0[3] = CAL_image_ff[0];
                    mid_0[4] = CAL_image_ff[0];
                    mid_0[5] = CAL_image_ff[1];
                    mid_0[6] = CAL_image_ff[8];
                    mid_0[7] = CAL_image_ff[8];
                    mid_0[8] = CAL_image_ff[9];
                    mid_1[0] = CAL_image_ff[0];
                    mid_1[1] = CAL_image_ff[1];
                    mid_1[2] = CAL_image_ff[2];
                    mid_1[3] = CAL_image_ff[0];
                    mid_1[4] = CAL_image_ff[1];
                    mid_1[5] = CAL_image_ff[2];
                    mid_1[6] = CAL_image_ff[8];
                    mid_1[7] = CAL_image_ff[9];
                    mid_1[8] = CAL_image_ff[10];
                    mid_2[0] = CAL_image_ff[1];
                    mid_2[1] = CAL_image_ff[2];
                    mid_2[2] = CAL_image_ff[3];
                    mid_2[3] = CAL_image_ff[1];
                    mid_2[4] = CAL_image_ff[2];
                    mid_2[5] = CAL_image_ff[3];
                    mid_2[6] = CAL_image_ff[9];
                    mid_2[7] = CAL_image_ff[10];
                    mid_2[8] = CAL_image_ff[11];
                    mid_3[0] = CAL_image_ff[2];
                    mid_3[1] = CAL_image_ff[3];
                    mid_3[2] = CAL_image_ff[4];
                    mid_3[3] = CAL_image_ff[2];
                    mid_3[4] = CAL_image_ff[3];
                    mid_3[5] = CAL_image_ff[4];
                    mid_3[6] = CAL_image_ff[10];
                    mid_3[7] = CAL_image_ff[11];
                    mid_3[8] = CAL_image_ff[12];
                    mid_4[0] = CAL_image_ff[3];
                    mid_4[1] = CAL_image_ff[4];
                    mid_4[2] = CAL_image_ff[5];
                    mid_4[3] = CAL_image_ff[3];
                    mid_4[4] = CAL_image_ff[4];
                    mid_4[5] = CAL_image_ff[5];
                    mid_4[6] = CAL_image_ff[11];
                    mid_4[7] = CAL_image_ff[12];
                    mid_4[8] = CAL_image_ff[13];
                    mid_5[0] = CAL_image_ff[4];
                    mid_5[1] = CAL_image_ff[5];
                    mid_5[2] = CAL_image_ff[6];
                    mid_5[3] = CAL_image_ff[4];
                    mid_5[4] = CAL_image_ff[5];
                    mid_5[5] = CAL_image_ff[6];
                    mid_5[6] = CAL_image_ff[12];
                    mid_5[7] = CAL_image_ff[13];
                    mid_5[8] = CAL_image_ff[14];
                    mid_6[0] = CAL_image_ff[5];
                    mid_6[1] = CAL_image_ff[6];
                    mid_6[2] = CAL_image_ff[7];
                    mid_6[3] = CAL_image_ff[5];
                    mid_6[4] = CAL_image_ff[6];
                    mid_6[5] = CAL_image_ff[7];
                    mid_6[6] = CAL_image_ff[13];
                    mid_6[7] = CAL_image_ff[14];
                    mid_6[8] = CAL_image_ff[15];
                    mid_7[0] = CAL_image_ff[6];
                    mid_7[1] = CAL_image_ff[7];
                    mid_7[2] = CAL_image_ff[7];
                    mid_7[3] = CAL_image_ff[6];
                    mid_7[4] = CAL_image_ff[7];
                    mid_7[5] = CAL_image_ff[7];
                    mid_7[6] = CAL_image_ff[14];
                    mid_7[7] = CAL_image_ff[15];
                    mid_7[8] = CAL_image_ff[15];
                    mid_8[0] = CAL_image_ff[0];
                    mid_8[1] = CAL_image_ff[0];
                    mid_8[2] = CAL_image_ff[1];
                    mid_8[3] = CAL_image_ff[8];
                    mid_8[4] = CAL_image_ff[8];
                    mid_8[5] = CAL_image_ff[9];
                    mid_8[6] = CAL_image_ff[16];
                    mid_8[7] = CAL_image_ff[16];
                    mid_8[8] = CAL_image_ff[17];
                    mid_9[0] = CAL_image_ff[0];
                    mid_9[1] = CAL_image_ff[1];
                    mid_9[2] = CAL_image_ff[2];
                    mid_9[3] = CAL_image_ff[8];
                    mid_9[4] = CAL_image_ff[9];
                    mid_9[5] = CAL_image_ff[10];
                    mid_9[6] = CAL_image_ff[16];
                    mid_9[7] = CAL_image_ff[17];
                    mid_9[8] = CAL_image_ff[18];
                    mid_10[0] = CAL_image_ff[1];
                    mid_10[1] = CAL_image_ff[2];
                    mid_10[2] = CAL_image_ff[3];
                    mid_10[3] = CAL_image_ff[9];
                    mid_10[4] = CAL_image_ff[10];
                    mid_10[5] = CAL_image_ff[11];
                    mid_10[6] = CAL_image_ff[17];
                    mid_10[7] = CAL_image_ff[18];
                    mid_10[8] = CAL_image_ff[19];
                    mid_11[0] = CAL_image_ff[2];
                    mid_11[1] = CAL_image_ff[3];
                    mid_11[2] = CAL_image_ff[4];
                    mid_11[3] = CAL_image_ff[10];
                    mid_11[4] = CAL_image_ff[11];
                    mid_11[5] = CAL_image_ff[12];
                    mid_11[6] = CAL_image_ff[18];
                    mid_11[7] = CAL_image_ff[19];
                    mid_11[8] = CAL_image_ff[20];
                    mid_12[0] = CAL_image_ff[3];
                    mid_12[1] = CAL_image_ff[4];
                    mid_12[2] = CAL_image_ff[5];
                    mid_12[3] = CAL_image_ff[11];
                    mid_12[4] = CAL_image_ff[12];
                    mid_12[5] = CAL_image_ff[13];
                    mid_12[6] = CAL_image_ff[19];
                    mid_12[7] = CAL_image_ff[20];
                    mid_12[8] = CAL_image_ff[21];
                    mid_13[0] = CAL_image_ff[4];
                    mid_13[1] = CAL_image_ff[5];
                    mid_13[2] = CAL_image_ff[6];
                    mid_13[3] = CAL_image_ff[12];
                    mid_13[4] = CAL_image_ff[13];
                    mid_13[5] = CAL_image_ff[14];
                    mid_13[6] = CAL_image_ff[20];
                    mid_13[7] = CAL_image_ff[21];
                    mid_13[8] = CAL_image_ff[22];
                    mid_14[0] = CAL_image_ff[5];
                    mid_14[1] = CAL_image_ff[6];
                    mid_14[2] = CAL_image_ff[7];
                    mid_14[3] = CAL_image_ff[13];
                    mid_14[4] = CAL_image_ff[14];
                    mid_14[5] = CAL_image_ff[15];
                    mid_14[6] = CAL_image_ff[21];
                    mid_14[7] = CAL_image_ff[22];
                    mid_14[8] = CAL_image_ff[23];
                    mid_15[0] = CAL_image_ff[6];
                    mid_15[1] = CAL_image_ff[7];
                    mid_15[2] = CAL_image_ff[7];
                    mid_15[3] = CAL_image_ff[14];
                    mid_15[4] = CAL_image_ff[15];
                    mid_15[5] = CAL_image_ff[15];
                    mid_15[6] = CAL_image_ff[22];
                    mid_15[7] = CAL_image_ff[23];
                    mid_15[8] = CAL_image_ff[23];
                end
                else if(clock_cnt == 'd0) begin
                    mid_0[0] = CAL_image_ff[8];
                    mid_0[1] = CAL_image_ff[8];
                    mid_0[2] = CAL_image_ff[9];
                    mid_0[3] = CAL_image_ff[16];
                    mid_0[4] = CAL_image_ff[16];
                    mid_0[5] = CAL_image_ff[17];
                    mid_0[6] = CAL_image_ff[24];
                    mid_0[7] = CAL_image_ff[24];
                    mid_0[8] = CAL_image_ff[25];
                    mid_1[0] = CAL_image_ff[8];
                    mid_1[1] = CAL_image_ff[9];
                    mid_1[2] = CAL_image_ff[10];
                    mid_1[3] = CAL_image_ff[16];
                    mid_1[4] = CAL_image_ff[17];
                    mid_1[5] = CAL_image_ff[18];
                    mid_1[6] = CAL_image_ff[24];
                    mid_1[7] = CAL_image_ff[25];
                    mid_1[8] = CAL_image_ff[26];
                    mid_2[0] = CAL_image_ff[9];
                    mid_2[1] = CAL_image_ff[10];
                    mid_2[2] = CAL_image_ff[11];
                    mid_2[3] = CAL_image_ff[17];
                    mid_2[4] = CAL_image_ff[18];
                    mid_2[5] = CAL_image_ff[19];
                    mid_2[6] = CAL_image_ff[25];
                    mid_2[7] = CAL_image_ff[26];
                    mid_2[8] = CAL_image_ff[27];
                    mid_3[0] = CAL_image_ff[10];
                    mid_3[1] = CAL_image_ff[11];
                    mid_3[2] = CAL_image_ff[12];
                    mid_3[3] = CAL_image_ff[18];
                    mid_3[4] = CAL_image_ff[19];
                    mid_3[5] = CAL_image_ff[20];
                    mid_3[6] = CAL_image_ff[26];
                    mid_3[7] = CAL_image_ff[27];
                    mid_3[8] = CAL_image_ff[28];
                    mid_4[0] = CAL_image_ff[11];
                    mid_4[1] = CAL_image_ff[12];
                    mid_4[2] = CAL_image_ff[13];
                    mid_4[3] = CAL_image_ff[19];
                    mid_4[4] = CAL_image_ff[20];
                    mid_4[5] = CAL_image_ff[21];
                    mid_4[6] = CAL_image_ff[27];
                    mid_4[7] = CAL_image_ff[28];
                    mid_4[8] = CAL_image_ff[29];
                    mid_5[0] = CAL_image_ff[12];
                    mid_5[1] = CAL_image_ff[13];
                    mid_5[2] = CAL_image_ff[14];
                    mid_5[3] = CAL_image_ff[20];
                    mid_5[4] = CAL_image_ff[21];
                    mid_5[5] = CAL_image_ff[22];
                    mid_5[6] = CAL_image_ff[28];
                    mid_5[7] = CAL_image_ff[29];
                    mid_5[8] = CAL_image_ff[30];
                    mid_6[0] = CAL_image_ff[13];
                    mid_6[1] = CAL_image_ff[14];
                    mid_6[2] = CAL_image_ff[15];
                    mid_6[3] = CAL_image_ff[21];
                    mid_6[4] = CAL_image_ff[22];
                    mid_6[5] = CAL_image_ff[23];
                    mid_6[6] = CAL_image_ff[29];
                    mid_6[7] = CAL_image_ff[30];
                    mid_6[8] = CAL_image_ff[31];
                    mid_7[0] = CAL_image_ff[14];
                    mid_7[1] = CAL_image_ff[15];
                    mid_7[2] = CAL_image_ff[15];
                    mid_7[3] = CAL_image_ff[22];
                    mid_7[4] = CAL_image_ff[23];
                    mid_7[5] = CAL_image_ff[23];
                    mid_7[6] = CAL_image_ff[30];
                    mid_7[7] = CAL_image_ff[31];
                    mid_7[8] = CAL_image_ff[31];
                    mid_8[0] = CAL_image_ff[16];
                    mid_8[1] = CAL_image_ff[16];
                    mid_8[2] = CAL_image_ff[17];
                    mid_8[3] = CAL_image_ff[24];
                    mid_8[4] = CAL_image_ff[24];
                    mid_8[5] = CAL_image_ff[25];
                    mid_8[6] = CAL_image_ff[32];
                    mid_8[7] = CAL_image_ff[32];
                    mid_8[8] = CAL_image_ff[33];
                    mid_9[0] = CAL_image_ff[16];
                    mid_9[1] = CAL_image_ff[17];
                    mid_9[2] = CAL_image_ff[18];
                    mid_9[3] = CAL_image_ff[24];
                    mid_9[4] = CAL_image_ff[25];
                    mid_9[5] = CAL_image_ff[26];
                    mid_9[6] = CAL_image_ff[32];
                    mid_9[7] = CAL_image_ff[33];
                    mid_9[8] = CAL_image_ff[34];
                    mid_10[0] = CAL_image_ff[17];
                    mid_10[1] = CAL_image_ff[18];
                    mid_10[2] = CAL_image_ff[19];
                    mid_10[3] = CAL_image_ff[25];
                    mid_10[4] = CAL_image_ff[26];
                    mid_10[5] = CAL_image_ff[27];
                    mid_10[6] = CAL_image_ff[33];
                    mid_10[7] = CAL_image_ff[34];
                    mid_10[8] = CAL_image_ff[35];
                    mid_11[0] = CAL_image_ff[18];
                    mid_11[1] = CAL_image_ff[19];
                    mid_11[2] = CAL_image_ff[20];
                    mid_11[3] = CAL_image_ff[26];
                    mid_11[4] = CAL_image_ff[27];
                    mid_11[5] = CAL_image_ff[28];
                    mid_11[6] = CAL_image_ff[34];
                    mid_11[7] = CAL_image_ff[35];
                    mid_11[8] = CAL_image_ff[36];
                    mid_12[0] = CAL_image_ff[19];
                    mid_12[1] = CAL_image_ff[20];
                    mid_12[2] = CAL_image_ff[21];
                    mid_12[3] = CAL_image_ff[27];
                    mid_12[4] = CAL_image_ff[28];
                    mid_12[5] = CAL_image_ff[29];
                    mid_12[6] = CAL_image_ff[35];
                    mid_12[7] = CAL_image_ff[36];
                    mid_12[8] = CAL_image_ff[37];
                    mid_13[0] = CAL_image_ff[20];
                    mid_13[1] = CAL_image_ff[21];
                    mid_13[2] = CAL_image_ff[22];
                    mid_13[3] = CAL_image_ff[28];
                    mid_13[4] = CAL_image_ff[29];
                    mid_13[5] = CAL_image_ff[30];
                    mid_13[6] = CAL_image_ff[36];
                    mid_13[7] = CAL_image_ff[37];
                    mid_13[8] = CAL_image_ff[38];
                    mid_14[0] = CAL_image_ff[21];
                    mid_14[1] = CAL_image_ff[22];
                    mid_14[2] = CAL_image_ff[23];
                    mid_14[3] = CAL_image_ff[29];
                    mid_14[4] = CAL_image_ff[30];
                    mid_14[5] = CAL_image_ff[31];
                    mid_14[6] = CAL_image_ff[37];
                    mid_14[7] = CAL_image_ff[38];
                    mid_14[8] = CAL_image_ff[39];
                    mid_15[0] = CAL_image_ff[22];
                    mid_15[1] = CAL_image_ff[23];
                    mid_15[2] = CAL_image_ff[23];
                    mid_15[3] = CAL_image_ff[30];
                    mid_15[4] = CAL_image_ff[31];
                    mid_15[5] = CAL_image_ff[31];
                    mid_15[6] = CAL_image_ff[38];
                    mid_15[7] = CAL_image_ff[39];
                    mid_15[8] = CAL_image_ff[39];
                end
                else if(clock_cnt == 'd1) begin
                    mid_0[0] = CAL_image_ff[24];
                    mid_0[1] = CAL_image_ff[24];
                    mid_0[2] = CAL_image_ff[25];
                    mid_0[3] = CAL_image_ff[32];
                    mid_0[4] = CAL_image_ff[32];
                    mid_0[5] = CAL_image_ff[33];
                    mid_0[6] = CAL_image_ff[40];
                    mid_0[7] = CAL_image_ff[40];
                    mid_0[8] = CAL_image_ff[41];
                    mid_1[0] = CAL_image_ff[24];
                    mid_1[1] = CAL_image_ff[25];
                    mid_1[2] = CAL_image_ff[26];
                    mid_1[3] = CAL_image_ff[32];
                    mid_1[4] = CAL_image_ff[33];
                    mid_1[5] = CAL_image_ff[34];
                    mid_1[6] = CAL_image_ff[40];
                    mid_1[7] = CAL_image_ff[41];
                    mid_1[8] = CAL_image_ff[42];
                    mid_2[0] = CAL_image_ff[25];
                    mid_2[1] = CAL_image_ff[26];
                    mid_2[2] = CAL_image_ff[27];
                    mid_2[3] = CAL_image_ff[33];
                    mid_2[4] = CAL_image_ff[34];
                    mid_2[5] = CAL_image_ff[35];
                    mid_2[6] = CAL_image_ff[41];
                    mid_2[7] = CAL_image_ff[42];
                    mid_2[8] = CAL_image_ff[43];
                    mid_3[0] = CAL_image_ff[26];
                    mid_3[1] = CAL_image_ff[27];
                    mid_3[2] = CAL_image_ff[28];
                    mid_3[3] = CAL_image_ff[34];
                    mid_3[4] = CAL_image_ff[35];
                    mid_3[5] = CAL_image_ff[36];
                    mid_3[6] = CAL_image_ff[42];
                    mid_3[7] = CAL_image_ff[43];
                    mid_3[8] = CAL_image_ff[44];
                    mid_4[0] = CAL_image_ff[27];
                    mid_4[1] = CAL_image_ff[28];
                    mid_4[2] = CAL_image_ff[29];
                    mid_4[3] = CAL_image_ff[35];
                    mid_4[4] = CAL_image_ff[36];
                    mid_4[5] = CAL_image_ff[37];
                    mid_4[6] = CAL_image_ff[43];
                    mid_4[7] = CAL_image_ff[44];
                    mid_4[8] = CAL_image_ff[45];
                    mid_5[0] = CAL_image_ff[28];
                    mid_5[1] = CAL_image_ff[29];
                    mid_5[2] = CAL_image_ff[30];
                    mid_5[3] = CAL_image_ff[36];
                    mid_5[4] = CAL_image_ff[37];
                    mid_5[5] = CAL_image_ff[38];
                    mid_5[6] = CAL_image_ff[44];
                    mid_5[7] = CAL_image_ff[45];
                    mid_5[8] = CAL_image_ff[46];
                    mid_6[0] = CAL_image_ff[29];
                    mid_6[1] = CAL_image_ff[30];
                    mid_6[2] = CAL_image_ff[31];
                    mid_6[3] = CAL_image_ff[37];
                    mid_6[4] = CAL_image_ff[38];
                    mid_6[5] = CAL_image_ff[39];
                    mid_6[6] = CAL_image_ff[45];
                    mid_6[7] = CAL_image_ff[46];
                    mid_6[8] = CAL_image_ff[47];
                    mid_7[0] = CAL_image_ff[30];
                    mid_7[1] = CAL_image_ff[31];
                    mid_7[2] = CAL_image_ff[31];
                    mid_7[3] = CAL_image_ff[38];
                    mid_7[4] = CAL_image_ff[39];
                    mid_7[5] = CAL_image_ff[39];
                    mid_7[6] = CAL_image_ff[46];
                    mid_7[7] = CAL_image_ff[47];
                    mid_7[8] = CAL_image_ff[47];
                    mid_8[0] = CAL_image_ff[32];
                    mid_8[1] = CAL_image_ff[32];
                    mid_8[2] = CAL_image_ff[33];
                    mid_8[3] = CAL_image_ff[40];
                    mid_8[4] = CAL_image_ff[40];
                    mid_8[5] = CAL_image_ff[41];
                    mid_8[6] = CAL_image_ff[48];
                    mid_8[7] = CAL_image_ff[48];
                    mid_8[8] = CAL_image_ff[49];
                    mid_9[0] = CAL_image_ff[32];
                    mid_9[1] = CAL_image_ff[33];
                    mid_9[2] = CAL_image_ff[34];
                    mid_9[3] = CAL_image_ff[40];
                    mid_9[4] = CAL_image_ff[41];
                    mid_9[5] = CAL_image_ff[42];
                    mid_9[6] = CAL_image_ff[48];
                    mid_9[7] = CAL_image_ff[49];
                    mid_9[8] = CAL_image_ff[50];
                    mid_10[0] = CAL_image_ff[33];
                    mid_10[1] = CAL_image_ff[34];
                    mid_10[2] = CAL_image_ff[35];
                    mid_10[3] = CAL_image_ff[41];
                    mid_10[4] = CAL_image_ff[42];
                    mid_10[5] = CAL_image_ff[43];
                    mid_10[6] = CAL_image_ff[49];
                    mid_10[7] = CAL_image_ff[50];
                    mid_10[8] = CAL_image_ff[51];
                    mid_11[0] = CAL_image_ff[34];
                    mid_11[1] = CAL_image_ff[35];
                    mid_11[2] = CAL_image_ff[36];
                    mid_11[3] = CAL_image_ff[42];
                    mid_11[4] = CAL_image_ff[43];
                    mid_11[5] = CAL_image_ff[44];
                    mid_11[6] = CAL_image_ff[50];
                    mid_11[7] = CAL_image_ff[51];
                    mid_11[8] = CAL_image_ff[52];
                    mid_12[0] = CAL_image_ff[35];
                    mid_12[1] = CAL_image_ff[36];
                    mid_12[2] = CAL_image_ff[37];
                    mid_12[3] = CAL_image_ff[43];
                    mid_12[4] = CAL_image_ff[44];
                    mid_12[5] = CAL_image_ff[45];
                    mid_12[6] = CAL_image_ff[51];
                    mid_12[7] = CAL_image_ff[52];
                    mid_12[8] = CAL_image_ff[53];
                    mid_13[0] = CAL_image_ff[36];
                    mid_13[1] = CAL_image_ff[37];
                    mid_13[2] = CAL_image_ff[38];
                    mid_13[3] = CAL_image_ff[44];
                    mid_13[4] = CAL_image_ff[45];
                    mid_13[5] = CAL_image_ff[46];
                    mid_13[6] = CAL_image_ff[52];
                    mid_13[7] = CAL_image_ff[53];
                    mid_13[8] = CAL_image_ff[54];
                    mid_14[0] = CAL_image_ff[37];
                    mid_14[1] = CAL_image_ff[38];
                    mid_14[2] = CAL_image_ff[39];
                    mid_14[3] = CAL_image_ff[45];
                    mid_14[4] = CAL_image_ff[46];
                    mid_14[5] = CAL_image_ff[47];
                    mid_14[6] = CAL_image_ff[53];
                    mid_14[7] = CAL_image_ff[54];
                    mid_14[8] = CAL_image_ff[55];
                    mid_15[0] = CAL_image_ff[38];
                    mid_15[1] = CAL_image_ff[39];
                    mid_15[2] = CAL_image_ff[39];
                    mid_15[3] = CAL_image_ff[46];
                    mid_15[4] = CAL_image_ff[47];
                    mid_15[5] = CAL_image_ff[47];
                    mid_15[6] = CAL_image_ff[54];
                    mid_15[7] = CAL_image_ff[55];
                    mid_15[8] = CAL_image_ff[55];
                end
                else if(clock_cnt == 'd2) begin
                    mid_0[0] = CAL_image_ff[40];
                    mid_0[1] = CAL_image_ff[40];
                    mid_0[2] = CAL_image_ff[41];
                    mid_0[3] = CAL_image_ff[48];
                    mid_0[4] = CAL_image_ff[48];
                    mid_0[5] = CAL_image_ff[49];
                    mid_0[6] = CAL_image_ff[56];
                    mid_0[7] = CAL_image_ff[56];
                    mid_0[8] = CAL_image_ff[57];
                    mid_1[0] = CAL_image_ff[40];
                    mid_1[1] = CAL_image_ff[41];
                    mid_1[2] = CAL_image_ff[42];
                    mid_1[3] = CAL_image_ff[48];
                    mid_1[4] = CAL_image_ff[49];
                    mid_1[5] = CAL_image_ff[50];
                    mid_1[6] = CAL_image_ff[56];
                    mid_1[7] = CAL_image_ff[57];
                    mid_1[8] = CAL_image_ff[58];
                    mid_2[0] = CAL_image_ff[41];
                    mid_2[1] = CAL_image_ff[42];
                    mid_2[2] = CAL_image_ff[43];
                    mid_2[3] = CAL_image_ff[49];
                    mid_2[4] = CAL_image_ff[50];
                    mid_2[5] = CAL_image_ff[51];
                    mid_2[6] = CAL_image_ff[57];
                    mid_2[7] = CAL_image_ff[58];
                    mid_2[8] = CAL_image_ff[59];
                    mid_3[0] = CAL_image_ff[42];
                    mid_3[1] = CAL_image_ff[43];
                    mid_3[2] = CAL_image_ff[44];
                    mid_3[3] = CAL_image_ff[50];
                    mid_3[4] = CAL_image_ff[51];
                    mid_3[5] = CAL_image_ff[52];
                    mid_3[6] = CAL_image_ff[58];
                    mid_3[7] = CAL_image_ff[59];
                    mid_3[8] = CAL_image_ff[60];
                    mid_4[0] = CAL_image_ff[43];
                    mid_4[1] = CAL_image_ff[44];
                    mid_4[2] = CAL_image_ff[45];
                    mid_4[3] = CAL_image_ff[51];
                    mid_4[4] = CAL_image_ff[52];
                    mid_4[5] = CAL_image_ff[53];
                    mid_4[6] = CAL_image_ff[59];
                    mid_4[7] = CAL_image_ff[60];
                    mid_4[8] = CAL_image_ff[61];
                    mid_5[0] = CAL_image_ff[44];
                    mid_5[1] = CAL_image_ff[45];
                    mid_5[2] = CAL_image_ff[46];
                    mid_5[3] = CAL_image_ff[52];
                    mid_5[4] = CAL_image_ff[53];
                    mid_5[5] = CAL_image_ff[54];
                    mid_5[6] = CAL_image_ff[60];
                    mid_5[7] = CAL_image_ff[61];
                    mid_5[8] = CAL_image_ff[62];
                    mid_6[0] = CAL_image_ff[45];
                    mid_6[1] = CAL_image_ff[46];
                    mid_6[2] = CAL_image_ff[47];
                    mid_6[3] = CAL_image_ff[53];
                    mid_6[4] = CAL_image_ff[54];
                    mid_6[5] = CAL_image_ff[55];
                    mid_6[6] = CAL_image_ff[61];
                    mid_6[7] = CAL_image_ff[62];
                    mid_6[8] = CAL_image_ff[63];
                    mid_7[0] = CAL_image_ff[46];
                    mid_7[1] = CAL_image_ff[47];
                    mid_7[2] = CAL_image_ff[47];
                    mid_7[3] = CAL_image_ff[54];
                    mid_7[4] = CAL_image_ff[55];
                    mid_7[5] = CAL_image_ff[55];
                    mid_7[6] = CAL_image_ff[62];
                    mid_7[7] = CAL_image_ff[63];
                    mid_7[8] = CAL_image_ff[63];
                    mid_8[0] = CAL_image_ff[48];
                    mid_8[1] = CAL_image_ff[48];
                    mid_8[2] = CAL_image_ff[49];
                    mid_8[3] = CAL_image_ff[56];
                    mid_8[4] = CAL_image_ff[56];
                    mid_8[5] = CAL_image_ff[57];
                    mid_8[6] = CAL_image_ff[56];
                    mid_8[7] = CAL_image_ff[56];
                    mid_8[8] = CAL_image_ff[57];
                    mid_9[0] = CAL_image_ff[48];
                    mid_9[1] = CAL_image_ff[49];
                    mid_9[2] = CAL_image_ff[50];
                    mid_9[3] = CAL_image_ff[56];
                    mid_9[4] = CAL_image_ff[57];
                    mid_9[5] = CAL_image_ff[58];
                    mid_9[6] = CAL_image_ff[56];
                    mid_9[7] = CAL_image_ff[57];
                    mid_9[8] = CAL_image_ff[58];
                    mid_10[0] = CAL_image_ff[49];
                    mid_10[1] = CAL_image_ff[50];
                    mid_10[2] = CAL_image_ff[51];
                    mid_10[3] = CAL_image_ff[57];
                    mid_10[4] = CAL_image_ff[58];
                    mid_10[5] = CAL_image_ff[59];
                    mid_10[6] = CAL_image_ff[57];
                    mid_10[7] = CAL_image_ff[58];
                    mid_10[8] = CAL_image_ff[59];
                    mid_11[0] = CAL_image_ff[50];
                    mid_11[1] = CAL_image_ff[51];
                    mid_11[2] = CAL_image_ff[52];
                    mid_11[3] = CAL_image_ff[58];
                    mid_11[4] = CAL_image_ff[59];
                    mid_11[5] = CAL_image_ff[60];
                    mid_11[6] = CAL_image_ff[58];
                    mid_11[7] = CAL_image_ff[59];
                    mid_11[8] = CAL_image_ff[60];
                    mid_12[0] = CAL_image_ff[51];
                    mid_12[1] = CAL_image_ff[52];
                    mid_12[2] = CAL_image_ff[53];
                    mid_12[3] = CAL_image_ff[59];
                    mid_12[4] = CAL_image_ff[60];
                    mid_12[5] = CAL_image_ff[61];
                    mid_12[6] = CAL_image_ff[59];
                    mid_12[7] = CAL_image_ff[60];
                    mid_12[8] = CAL_image_ff[61];
                    mid_13[0] = CAL_image_ff[52];
                    mid_13[1] = CAL_image_ff[53];
                    mid_13[2] = CAL_image_ff[54];
                    mid_13[3] = CAL_image_ff[60];
                    mid_13[4] = CAL_image_ff[61];
                    mid_13[5] = CAL_image_ff[62];
                    mid_13[6] = CAL_image_ff[60];
                    mid_13[7] = CAL_image_ff[61];
                    mid_13[8] = CAL_image_ff[62];
                    mid_14[0] = CAL_image_ff[53];
                    mid_14[1] = CAL_image_ff[54];
                    mid_14[2] = CAL_image_ff[55];
                    mid_14[3] = CAL_image_ff[61];
                    mid_14[4] = CAL_image_ff[62];
                    mid_14[5] = CAL_image_ff[63];
                    mid_14[6] = CAL_image_ff[61];
                    mid_14[7] = CAL_image_ff[62];
                    mid_14[8] = CAL_image_ff[63];
                    mid_15[0] = CAL_image_ff[54];
                    mid_15[1] = CAL_image_ff[55];
                    mid_15[2] = CAL_image_ff[55];
                    mid_15[3] = CAL_image_ff[62];
                    mid_15[4] = CAL_image_ff[63];
                    mid_15[5] = CAL_image_ff[63];
                    mid_15[6] = CAL_image_ff[62];
                    mid_15[7] = CAL_image_ff[63];
                    mid_15[8] = CAL_image_ff[63];
                end
                else begin
                    for( i = 0 ; i < 9 ; i = i + 1) begin
                        mid_0[i] = 0;
                        mid_1[i] = 0;
                        mid_2[i] = 0;
                        mid_3[i] = 0;
                        mid_4[i] = 0;
                        mid_5[i] = 0;
                        mid_6[i] = 0;
                        mid_7[i] = 0;
                        mid_8[i] = 0;
                        mid_9[i] = 0;
                        mid_10[i] = 0;
                        mid_11[i] = 0;
                        mid_12[i] = 0;
                        mid_13[i] = 0;
                        mid_14[i] = 0;
                        mid_15[i] = 0;
                    end
                end
            end
            2'd2: begin
                if(clock_cnt == 5'b11111) begin
                    mid_0[0] = CAL_image_ff[0];
                    mid_0[1] = CAL_image_ff[0];
                    mid_0[2] = CAL_image_ff[1];
                    mid_0[3] = CAL_image_ff[0];
                    mid_0[4] = CAL_image_ff[0];
                    mid_0[5] = CAL_image_ff[1];
                    mid_0[6] = CAL_image_ff[16];
                    mid_0[7] = CAL_image_ff[16];
                    mid_0[8] = CAL_image_ff[17];
                    mid_1[0] = CAL_image_ff[0];
                    mid_1[1] = CAL_image_ff[1];
                    mid_1[2] = CAL_image_ff[2];
                    mid_1[3] = CAL_image_ff[0];
                    mid_1[4] = CAL_image_ff[1];
                    mid_1[5] = CAL_image_ff[2];
                    mid_1[6] = CAL_image_ff[16];
                    mid_1[7] = CAL_image_ff[17];
                    mid_1[8] = CAL_image_ff[18];
                    mid_2[0] = CAL_image_ff[1];
                    mid_2[1] = CAL_image_ff[2];
                    mid_2[2] = CAL_image_ff[3];
                    mid_2[3] = CAL_image_ff[1];
                    mid_2[4] = CAL_image_ff[2];
                    mid_2[5] = CAL_image_ff[3];
                    mid_2[6] = CAL_image_ff[17];
                    mid_2[7] = CAL_image_ff[18];
                    mid_2[8] = CAL_image_ff[19];
                    mid_3[0] = CAL_image_ff[2];
                    mid_3[1] = CAL_image_ff[3];
                    mid_3[2] = CAL_image_ff[4];
                    mid_3[3] = CAL_image_ff[2];
                    mid_3[4] = CAL_image_ff[3];
                    mid_3[5] = CAL_image_ff[4];
                    mid_3[6] = CAL_image_ff[18];
                    mid_3[7] = CAL_image_ff[19];
                    mid_3[8] = CAL_image_ff[20];
                    mid_4[0] = CAL_image_ff[3];
                    mid_4[1] = CAL_image_ff[4];
                    mid_4[2] = CAL_image_ff[5];
                    mid_4[3] = CAL_image_ff[3];
                    mid_4[4] = CAL_image_ff[4];
                    mid_4[5] = CAL_image_ff[5];
                    mid_4[6] = CAL_image_ff[19];
                    mid_4[7] = CAL_image_ff[20];
                    mid_4[8] = CAL_image_ff[21];
                    mid_5[0] = CAL_image_ff[4];
                    mid_5[1] = CAL_image_ff[5];
                    mid_5[2] = CAL_image_ff[6];
                    mid_5[3] = CAL_image_ff[4];
                    mid_5[4] = CAL_image_ff[5];
                    mid_5[5] = CAL_image_ff[6];
                    mid_5[6] = CAL_image_ff[20];
                    mid_5[7] = CAL_image_ff[21];
                    mid_5[8] = CAL_image_ff[22];
                    mid_6[0] = CAL_image_ff[5];
                    mid_6[1] = CAL_image_ff[6];
                    mid_6[2] = CAL_image_ff[7];
                    mid_6[3] = CAL_image_ff[5];
                    mid_6[4] = CAL_image_ff[6];
                    mid_6[5] = CAL_image_ff[7];
                    mid_6[6] = CAL_image_ff[21];
                    mid_6[7] = CAL_image_ff[22];
                    mid_6[8] = CAL_image_ff[23];
                    mid_7[0] = CAL_image_ff[6];
                    mid_7[1] = CAL_image_ff[7];
                    mid_7[2] = CAL_image_ff[8];
                    mid_7[3] = CAL_image_ff[6];
                    mid_7[4] = CAL_image_ff[7];
                    mid_7[5] = CAL_image_ff[8];
                    mid_7[6] = CAL_image_ff[22];
                    mid_7[7] = CAL_image_ff[23];
                    mid_7[8] = CAL_image_ff[24];
                    mid_8[0] = CAL_image_ff[7];
                    mid_8[1] = CAL_image_ff[8];
                    mid_8[2] = CAL_image_ff[9];
                    mid_8[3] = CAL_image_ff[7];
                    mid_8[4] = CAL_image_ff[8];
                    mid_8[5] = CAL_image_ff[9];
                    mid_8[6] = CAL_image_ff[23];
                    mid_8[7] = CAL_image_ff[24];
                    mid_8[8] = CAL_image_ff[25];
                    mid_9[0] = CAL_image_ff[8];
                    mid_9[1] = CAL_image_ff[9];
                    mid_9[2] = CAL_image_ff[10];
                    mid_9[3] = CAL_image_ff[8];
                    mid_9[4] = CAL_image_ff[9];
                    mid_9[5] = CAL_image_ff[10];
                    mid_9[6] = CAL_image_ff[24];
                    mid_9[7] = CAL_image_ff[25];
                    mid_9[8] = CAL_image_ff[26];
                    mid_10[0] = CAL_image_ff[9];
                    mid_10[1] = CAL_image_ff[10];
                    mid_10[2] = CAL_image_ff[11];
                    mid_10[3] = CAL_image_ff[9];
                    mid_10[4] = CAL_image_ff[10];
                    mid_10[5] = CAL_image_ff[11];
                    mid_10[6] = CAL_image_ff[25];
                    mid_10[7] = CAL_image_ff[26];
                    mid_10[8] = CAL_image_ff[27];
                    mid_11[0] = CAL_image_ff[10];
                    mid_11[1] = CAL_image_ff[11];
                    mid_11[2] = CAL_image_ff[12];
                    mid_11[3] = CAL_image_ff[10];
                    mid_11[4] = CAL_image_ff[11];
                    mid_11[5] = CAL_image_ff[12];
                    mid_11[6] = CAL_image_ff[26];
                    mid_11[7] = CAL_image_ff[27];
                    mid_11[8] = CAL_image_ff[28];
                    mid_12[0] = CAL_image_ff[11];
                    mid_12[1] = CAL_image_ff[12];
                    mid_12[2] = CAL_image_ff[13];
                    mid_12[3] = CAL_image_ff[11];
                    mid_12[4] = CAL_image_ff[12];
                    mid_12[5] = CAL_image_ff[13];
                    mid_12[6] = CAL_image_ff[27];
                    mid_12[7] = CAL_image_ff[28];
                    mid_12[8] = CAL_image_ff[29];
                    mid_13[0] = CAL_image_ff[12];
                    mid_13[1] = CAL_image_ff[13];
                    mid_13[2] = CAL_image_ff[14];
                    mid_13[3] = CAL_image_ff[12];
                    mid_13[4] = CAL_image_ff[13];
                    mid_13[5] = CAL_image_ff[14];
                    mid_13[6] = CAL_image_ff[28];
                    mid_13[7] = CAL_image_ff[29];
                    mid_13[8] = CAL_image_ff[30];
                    mid_14[0] = CAL_image_ff[13];
                    mid_14[1] = CAL_image_ff[14];
                    mid_14[2] = CAL_image_ff[15];
                    mid_14[3] = CAL_image_ff[13];
                    mid_14[4] = CAL_image_ff[14];
                    mid_14[5] = CAL_image_ff[15];
                    mid_14[6] = CAL_image_ff[29];
                    mid_14[7] = CAL_image_ff[30];
                    mid_14[8] = CAL_image_ff[31];
                    mid_15[0] = CAL_image_ff[14];
                    mid_15[1] = CAL_image_ff[15];
                    mid_15[2] = CAL_image_ff[15];
                    mid_15[3] = CAL_image_ff[14];
                    mid_15[4] = CAL_image_ff[15];
                    mid_15[5] = CAL_image_ff[15];
                    mid_15[6] = CAL_image_ff[30];
                    mid_15[7] = CAL_image_ff[31];
                    mid_15[8] = CAL_image_ff[31];
                end
                else if(clock_cnt == 'd0) begin
                    mid_0[0] = CAL_image_ff[0];
                    mid_0[1] = CAL_image_ff[0];
                    mid_0[2] = CAL_image_ff[1];
                    mid_0[3] = CAL_image_ff[16];
                    mid_0[4] = CAL_image_ff[16];
                    mid_0[5] = CAL_image_ff[17];
                    mid_0[6] = CAL_image_ff[32];
                    mid_0[7] = CAL_image_ff[32];
                    mid_0[8] = CAL_image_ff[33];
                    mid_1[0] = CAL_image_ff[0];
                    mid_1[1] = CAL_image_ff[1];
                    mid_1[2] = CAL_image_ff[2];
                    mid_1[3] = CAL_image_ff[16];
                    mid_1[4] = CAL_image_ff[17];
                    mid_1[5] = CAL_image_ff[18];
                    mid_1[6] = CAL_image_ff[32];
                    mid_1[7] = CAL_image_ff[33];
                    mid_1[8] = CAL_image_ff[34];
                    mid_2[0] = CAL_image_ff[1];
                    mid_2[1] = CAL_image_ff[2];
                    mid_2[2] = CAL_image_ff[3];
                    mid_2[3] = CAL_image_ff[17];
                    mid_2[4] = CAL_image_ff[18];
                    mid_2[5] = CAL_image_ff[19];
                    mid_2[6] = CAL_image_ff[33];
                    mid_2[7] = CAL_image_ff[34];
                    mid_2[8] = CAL_image_ff[35];
                    mid_3[0] = CAL_image_ff[2];
                    mid_3[1] = CAL_image_ff[3];
                    mid_3[2] = CAL_image_ff[4];
                    mid_3[3] = CAL_image_ff[18];
                    mid_3[4] = CAL_image_ff[19];
                    mid_3[5] = CAL_image_ff[20];
                    mid_3[6] = CAL_image_ff[34];
                    mid_3[7] = CAL_image_ff[35];
                    mid_3[8] = CAL_image_ff[36];
                    mid_4[0] = CAL_image_ff[3];
                    mid_4[1] = CAL_image_ff[4];
                    mid_4[2] = CAL_image_ff[5];
                    mid_4[3] = CAL_image_ff[19];
                    mid_4[4] = CAL_image_ff[20];
                    mid_4[5] = CAL_image_ff[21];
                    mid_4[6] = CAL_image_ff[35];
                    mid_4[7] = CAL_image_ff[36];
                    mid_4[8] = CAL_image_ff[37];
                    mid_5[0] = CAL_image_ff[4];
                    mid_5[1] = CAL_image_ff[5];
                    mid_5[2] = CAL_image_ff[6];
                    mid_5[3] = CAL_image_ff[20];
                    mid_5[4] = CAL_image_ff[21];
                    mid_5[5] = CAL_image_ff[22];
                    mid_5[6] = CAL_image_ff[36];
                    mid_5[7] = CAL_image_ff[37];
                    mid_5[8] = CAL_image_ff[38];
                    mid_6[0] = CAL_image_ff[5];
                    mid_6[1] = CAL_image_ff[6];
                    mid_6[2] = CAL_image_ff[7];
                    mid_6[3] = CAL_image_ff[21];
                    mid_6[4] = CAL_image_ff[22];
                    mid_6[5] = CAL_image_ff[23];
                    mid_6[6] = CAL_image_ff[37];
                    mid_6[7] = CAL_image_ff[38];
                    mid_6[8] = CAL_image_ff[39];
                    mid_7[0] = CAL_image_ff[6];
                    mid_7[1] = CAL_image_ff[7];
                    mid_7[2] = CAL_image_ff[8];
                    mid_7[3] = CAL_image_ff[22];
                    mid_7[4] = CAL_image_ff[23];
                    mid_7[5] = CAL_image_ff[24];
                    mid_7[6] = CAL_image_ff[38];
                    mid_7[7] = CAL_image_ff[39];
                    mid_7[8] = CAL_image_ff[40];
                    mid_8[0] = CAL_image_ff[7];
                    mid_8[1] = CAL_image_ff[8];
                    mid_8[2] = CAL_image_ff[9];
                    mid_8[3] = CAL_image_ff[23];
                    mid_8[4] = CAL_image_ff[24];
                    mid_8[5] = CAL_image_ff[25];
                    mid_8[6] = CAL_image_ff[39];
                    mid_8[7] = CAL_image_ff[40];
                    mid_8[8] = CAL_image_ff[41];
                    mid_9[0] = CAL_image_ff[8];
                    mid_9[1] = CAL_image_ff[9];
                    mid_9[2] = CAL_image_ff[10];
                    mid_9[3] = CAL_image_ff[24];
                    mid_9[4] = CAL_image_ff[25];
                    mid_9[5] = CAL_image_ff[26];
                    mid_9[6] = CAL_image_ff[40];
                    mid_9[7] = CAL_image_ff[41];
                    mid_9[8] = CAL_image_ff[42];
                    mid_10[0] = CAL_image_ff[9];
                    mid_10[1] = CAL_image_ff[10];
                    mid_10[2] = CAL_image_ff[11];
                    mid_10[3] = CAL_image_ff[25];
                    mid_10[4] = CAL_image_ff[26];
                    mid_10[5] = CAL_image_ff[27];
                    mid_10[6] = CAL_image_ff[41];
                    mid_10[7] = CAL_image_ff[42];
                    mid_10[8] = CAL_image_ff[43];
                    mid_11[0] = CAL_image_ff[10];
                    mid_11[1] = CAL_image_ff[11];
                    mid_11[2] = CAL_image_ff[12];
                    mid_11[3] = CAL_image_ff[26];
                    mid_11[4] = CAL_image_ff[27];
                    mid_11[5] = CAL_image_ff[28];
                    mid_11[6] = CAL_image_ff[42];
                    mid_11[7] = CAL_image_ff[43];
                    mid_11[8] = CAL_image_ff[44];
                    mid_12[0] = CAL_image_ff[11];
                    mid_12[1] = CAL_image_ff[12];
                    mid_12[2] = CAL_image_ff[13];
                    mid_12[3] = CAL_image_ff[27];
                    mid_12[4] = CAL_image_ff[28];
                    mid_12[5] = CAL_image_ff[29];
                    mid_12[6] = CAL_image_ff[43];
                    mid_12[7] = CAL_image_ff[44];
                    mid_12[8] = CAL_image_ff[45];
                    mid_13[0] = CAL_image_ff[12];
                    mid_13[1] = CAL_image_ff[13];
                    mid_13[2] = CAL_image_ff[14];
                    mid_13[3] = CAL_image_ff[28];
                    mid_13[4] = CAL_image_ff[29];
                    mid_13[5] = CAL_image_ff[30];
                    mid_13[6] = CAL_image_ff[44];
                    mid_13[7] = CAL_image_ff[45];
                    mid_13[8] = CAL_image_ff[46];
                    mid_14[0] = CAL_image_ff[13];
                    mid_14[1] = CAL_image_ff[14];
                    mid_14[2] = CAL_image_ff[15];
                    mid_14[3] = CAL_image_ff[29];
                    mid_14[4] = CAL_image_ff[30];
                    mid_14[5] = CAL_image_ff[31];
                    mid_14[6] = CAL_image_ff[45];
                    mid_14[7] = CAL_image_ff[46];
                    mid_14[8] = CAL_image_ff[47];
                    mid_15[0] = CAL_image_ff[14];
                    mid_15[1] = CAL_image_ff[15];
                    mid_15[2] = CAL_image_ff[15];
                    mid_15[3] = CAL_image_ff[30];
                    mid_15[4] = CAL_image_ff[31];
                    mid_15[5] = CAL_image_ff[31];
                    mid_15[6] = CAL_image_ff[46];
                    mid_15[7] = CAL_image_ff[47];
                    mid_15[8] = CAL_image_ff[47];
                end
                else if(clock_cnt == 'd1) begin
                    mid_0[0] = CAL_image_ff[16];
                    mid_0[1] = CAL_image_ff[16];
                    mid_0[2] = CAL_image_ff[17];
                    mid_0[3] = CAL_image_ff[32];
                    mid_0[4] = CAL_image_ff[32];
                    mid_0[5] = CAL_image_ff[33];
                    mid_0[6] = CAL_image_ff[48];
                    mid_0[7] = CAL_image_ff[48];
                    mid_0[8] = CAL_image_ff[49];
                    mid_1[0] = CAL_image_ff[16];
                    mid_1[1] = CAL_image_ff[17];
                    mid_1[2] = CAL_image_ff[18];
                    mid_1[3] = CAL_image_ff[32];
                    mid_1[4] = CAL_image_ff[33];
                    mid_1[5] = CAL_image_ff[34];
                    mid_1[6] = CAL_image_ff[48];
                    mid_1[7] = CAL_image_ff[49];
                    mid_1[8] = CAL_image_ff[50];
                    mid_2[0] = CAL_image_ff[17];
                    mid_2[1] = CAL_image_ff[18];
                    mid_2[2] = CAL_image_ff[19];
                    mid_2[3] = CAL_image_ff[33];
                    mid_2[4] = CAL_image_ff[34];
                    mid_2[5] = CAL_image_ff[35];
                    mid_2[6] = CAL_image_ff[49];
                    mid_2[7] = CAL_image_ff[50];
                    mid_2[8] = CAL_image_ff[51];
                    mid_3[0] = CAL_image_ff[18];
                    mid_3[1] = CAL_image_ff[19];
                    mid_3[2] = CAL_image_ff[20];
                    mid_3[3] = CAL_image_ff[34];
                    mid_3[4] = CAL_image_ff[35];
                    mid_3[5] = CAL_image_ff[36];
                    mid_3[6] = CAL_image_ff[50];
                    mid_3[7] = CAL_image_ff[51];
                    mid_3[8] = CAL_image_ff[52];
                    mid_4[0] = CAL_image_ff[19];
                    mid_4[1] = CAL_image_ff[20];
                    mid_4[2] = CAL_image_ff[21];
                    mid_4[3] = CAL_image_ff[35];
                    mid_4[4] = CAL_image_ff[36];
                    mid_4[5] = CAL_image_ff[37];
                    mid_4[6] = CAL_image_ff[51];
                    mid_4[7] = CAL_image_ff[52];
                    mid_4[8] = CAL_image_ff[53];
                    mid_5[0] = CAL_image_ff[20];
                    mid_5[1] = CAL_image_ff[21];
                    mid_5[2] = CAL_image_ff[22];
                    mid_5[3] = CAL_image_ff[36];
                    mid_5[4] = CAL_image_ff[37];
                    mid_5[5] = CAL_image_ff[38];
                    mid_5[6] = CAL_image_ff[52];
                    mid_5[7] = CAL_image_ff[53];
                    mid_5[8] = CAL_image_ff[54];
                    mid_6[0] = CAL_image_ff[21];
                    mid_6[1] = CAL_image_ff[22];
                    mid_6[2] = CAL_image_ff[23];
                    mid_6[3] = CAL_image_ff[37];
                    mid_6[4] = CAL_image_ff[38];
                    mid_6[5] = CAL_image_ff[39];
                    mid_6[6] = CAL_image_ff[53];
                    mid_6[7] = CAL_image_ff[54];
                    mid_6[8] = CAL_image_ff[55];
                    mid_7[0] = CAL_image_ff[22];
                    mid_7[1] = CAL_image_ff[23];
                    mid_7[2] = CAL_image_ff[24];
                    mid_7[3] = CAL_image_ff[38];
                    mid_7[4] = CAL_image_ff[39];
                    mid_7[5] = CAL_image_ff[40];
                    mid_7[6] = CAL_image_ff[54];
                    mid_7[7] = CAL_image_ff[55];
                    mid_7[8] = CAL_image_ff[56];
                    mid_8[0] = CAL_image_ff[23];
                    mid_8[1] = CAL_image_ff[24];
                    mid_8[2] = CAL_image_ff[25];
                    mid_8[3] = CAL_image_ff[39];
                    mid_8[4] = CAL_image_ff[40];
                    mid_8[5] = CAL_image_ff[41];
                    mid_8[6] = CAL_image_ff[55];
                    mid_8[7] = CAL_image_ff[56];
                    mid_8[8] = CAL_image_ff[57];
                    mid_9[0] = CAL_image_ff[24];
                    mid_9[1] = CAL_image_ff[25];
                    mid_9[2] = CAL_image_ff[26];
                    mid_9[3] = CAL_image_ff[40];
                    mid_9[4] = CAL_image_ff[41];
                    mid_9[5] = CAL_image_ff[42];
                    mid_9[6] = CAL_image_ff[56];
                    mid_9[7] = CAL_image_ff[57];
                    mid_9[8] = CAL_image_ff[58];
                    mid_10[0] = CAL_image_ff[25];
                    mid_10[1] = CAL_image_ff[26];
                    mid_10[2] = CAL_image_ff[27];
                    mid_10[3] = CAL_image_ff[41];
                    mid_10[4] = CAL_image_ff[42];
                    mid_10[5] = CAL_image_ff[43];
                    mid_10[6] = CAL_image_ff[57];
                    mid_10[7] = CAL_image_ff[58];
                    mid_10[8] = CAL_image_ff[59];
                    mid_11[0] = CAL_image_ff[26];
                    mid_11[1] = CAL_image_ff[27];
                    mid_11[2] = CAL_image_ff[28];
                    mid_11[3] = CAL_image_ff[42];
                    mid_11[4] = CAL_image_ff[43];
                    mid_11[5] = CAL_image_ff[44];
                    mid_11[6] = CAL_image_ff[58];
                    mid_11[7] = CAL_image_ff[59];
                    mid_11[8] = CAL_image_ff[60];
                    mid_12[0] = CAL_image_ff[27];
                    mid_12[1] = CAL_image_ff[28];
                    mid_12[2] = CAL_image_ff[29];
                    mid_12[3] = CAL_image_ff[43];
                    mid_12[4] = CAL_image_ff[44];
                    mid_12[5] = CAL_image_ff[45];
                    mid_12[6] = CAL_image_ff[59];
                    mid_12[7] = CAL_image_ff[60];
                    mid_12[8] = CAL_image_ff[61];
                    mid_13[0] = CAL_image_ff[28];
                    mid_13[1] = CAL_image_ff[29];
                    mid_13[2] = CAL_image_ff[30];
                    mid_13[3] = CAL_image_ff[44];
                    mid_13[4] = CAL_image_ff[45];
                    mid_13[5] = CAL_image_ff[46];
                    mid_13[6] = CAL_image_ff[60];
                    mid_13[7] = CAL_image_ff[61];
                    mid_13[8] = CAL_image_ff[62];
                    mid_14[0] = CAL_image_ff[29];
                    mid_14[1] = CAL_image_ff[30];
                    mid_14[2] = CAL_image_ff[31];
                    mid_14[3] = CAL_image_ff[45];
                    mid_14[4] = CAL_image_ff[46];
                    mid_14[5] = CAL_image_ff[47];
                    mid_14[6] = CAL_image_ff[61];
                    mid_14[7] = CAL_image_ff[62];
                    mid_14[8] = CAL_image_ff[63];
                    mid_15[0] = CAL_image_ff[30];
                    mid_15[1] = CAL_image_ff[31];
                    mid_15[2] = CAL_image_ff[31];
                    mid_15[3] = CAL_image_ff[46];
                    mid_15[4] = CAL_image_ff[47];
                    mid_15[5] = CAL_image_ff[47];
                    mid_15[6] = CAL_image_ff[62];
                    mid_15[7] = CAL_image_ff[63];
                    mid_15[8] = CAL_image_ff[63];
                end
                else if(clock_cnt == 'd2) begin
                    mid_0[0] = CAL_image_ff[32];
                    mid_0[1] = CAL_image_ff[32];
                    mid_0[2] = CAL_image_ff[33];
                    mid_0[3] = CAL_image_ff[48];
                    mid_0[4] = CAL_image_ff[48];
                    mid_0[5] = CAL_image_ff[49];
                    mid_0[6] = CAL_image_ff[64];
                    mid_0[7] = CAL_image_ff[64];
                    mid_0[8] = CAL_image_ff[65];
                    mid_1[0] = CAL_image_ff[32];
                    mid_1[1] = CAL_image_ff[33];
                    mid_1[2] = CAL_image_ff[34];
                    mid_1[3] = CAL_image_ff[48];
                    mid_1[4] = CAL_image_ff[49];
                    mid_1[5] = CAL_image_ff[50];
                    mid_1[6] = CAL_image_ff[64];
                    mid_1[7] = CAL_image_ff[65];
                    mid_1[8] = CAL_image_ff[66];
                    mid_2[0] = CAL_image_ff[33];
                    mid_2[1] = CAL_image_ff[34];
                    mid_2[2] = CAL_image_ff[35];
                    mid_2[3] = CAL_image_ff[49];
                    mid_2[4] = CAL_image_ff[50];
                    mid_2[5] = CAL_image_ff[51];
                    mid_2[6] = CAL_image_ff[65];
                    mid_2[7] = CAL_image_ff[66];
                    mid_2[8] = CAL_image_ff[67];
                    mid_3[0] = CAL_image_ff[34];
                    mid_3[1] = CAL_image_ff[35];
                    mid_3[2] = CAL_image_ff[36];
                    mid_3[3] = CAL_image_ff[50];
                    mid_3[4] = CAL_image_ff[51];
                    mid_3[5] = CAL_image_ff[52];
                    mid_3[6] = CAL_image_ff[66];
                    mid_3[7] = CAL_image_ff[67];
                    mid_3[8] = CAL_image_ff[68];
                    mid_4[0] = CAL_image_ff[35];
                    mid_4[1] = CAL_image_ff[36];
                    mid_4[2] = CAL_image_ff[37];
                    mid_4[3] = CAL_image_ff[51];
                    mid_4[4] = CAL_image_ff[52];
                    mid_4[5] = CAL_image_ff[53];
                    mid_4[6] = CAL_image_ff[67];
                    mid_4[7] = CAL_image_ff[68];
                    mid_4[8] = CAL_image_ff[69];
                    mid_5[0] = CAL_image_ff[36];
                    mid_5[1] = CAL_image_ff[37];
                    mid_5[2] = CAL_image_ff[38];
                    mid_5[3] = CAL_image_ff[52];
                    mid_5[4] = CAL_image_ff[53];
                    mid_5[5] = CAL_image_ff[54];
                    mid_5[6] = CAL_image_ff[68];
                    mid_5[7] = CAL_image_ff[69];
                    mid_5[8] = CAL_image_ff[70];
                    mid_6[0] = CAL_image_ff[37];
                    mid_6[1] = CAL_image_ff[38];
                    mid_6[2] = CAL_image_ff[39];
                    mid_6[3] = CAL_image_ff[53];
                    mid_6[4] = CAL_image_ff[54];
                    mid_6[5] = CAL_image_ff[55];
                    mid_6[6] = CAL_image_ff[69];
                    mid_6[7] = CAL_image_ff[70];
                    mid_6[8] = CAL_image_ff[71];
                    mid_7[0] = CAL_image_ff[38];
                    mid_7[1] = CAL_image_ff[39];
                    mid_7[2] = CAL_image_ff[40];
                    mid_7[3] = CAL_image_ff[54];
                    mid_7[4] = CAL_image_ff[55];
                    mid_7[5] = CAL_image_ff[56];
                    mid_7[6] = CAL_image_ff[70];
                    mid_7[7] = CAL_image_ff[71];
                    mid_7[8] = CAL_image_ff[72];
                    mid_8[0] = CAL_image_ff[39];
                    mid_8[1] = CAL_image_ff[40];
                    mid_8[2] = CAL_image_ff[41];
                    mid_8[3] = CAL_image_ff[55];
                    mid_8[4] = CAL_image_ff[56];
                    mid_8[5] = CAL_image_ff[57];
                    mid_8[6] = CAL_image_ff[71];
                    mid_8[7] = CAL_image_ff[72];
                    mid_8[8] = CAL_image_ff[73];
                    mid_9[0] = CAL_image_ff[40];
                    mid_9[1] = CAL_image_ff[41];
                    mid_9[2] = CAL_image_ff[42];
                    mid_9[3] = CAL_image_ff[56];
                    mid_9[4] = CAL_image_ff[57];
                    mid_9[5] = CAL_image_ff[58];
                    mid_9[6] = CAL_image_ff[72];
                    mid_9[7] = CAL_image_ff[73];
                    mid_9[8] = CAL_image_ff[74];
                    mid_10[0] = CAL_image_ff[41];
                    mid_10[1] = CAL_image_ff[42];
                    mid_10[2] = CAL_image_ff[43];
                    mid_10[3] = CAL_image_ff[57];
                    mid_10[4] = CAL_image_ff[58];
                    mid_10[5] = CAL_image_ff[59];
                    mid_10[6] = CAL_image_ff[73];
                    mid_10[7] = CAL_image_ff[74];
                    mid_10[8] = CAL_image_ff[75];
                    mid_11[0] = CAL_image_ff[42];
                    mid_11[1] = CAL_image_ff[43];
                    mid_11[2] = CAL_image_ff[44];
                    mid_11[3] = CAL_image_ff[58];
                    mid_11[4] = CAL_image_ff[59];
                    mid_11[5] = CAL_image_ff[60];
                    mid_11[6] = CAL_image_ff[74];
                    mid_11[7] = CAL_image_ff[75];
                    mid_11[8] = CAL_image_ff[76];
                    mid_12[0] = CAL_image_ff[43];
                    mid_12[1] = CAL_image_ff[44];
                    mid_12[2] = CAL_image_ff[45];
                    mid_12[3] = CAL_image_ff[59];
                    mid_12[4] = CAL_image_ff[60];
                    mid_12[5] = CAL_image_ff[61];
                    mid_12[6] = CAL_image_ff[75];
                    mid_12[7] = CAL_image_ff[76];
                    mid_12[8] = CAL_image_ff[77];
                    mid_13[0] = CAL_image_ff[44];
                    mid_13[1] = CAL_image_ff[45];
                    mid_13[2] = CAL_image_ff[46];
                    mid_13[3] = CAL_image_ff[60];
                    mid_13[4] = CAL_image_ff[61];
                    mid_13[5] = CAL_image_ff[62];
                    mid_13[6] = CAL_image_ff[76];
                    mid_13[7] = CAL_image_ff[77];
                    mid_13[8] = CAL_image_ff[78];
                    mid_14[0] = CAL_image_ff[45];
                    mid_14[1] = CAL_image_ff[46];
                    mid_14[2] = CAL_image_ff[47];
                    mid_14[3] = CAL_image_ff[61];
                    mid_14[4] = CAL_image_ff[62];
                    mid_14[5] = CAL_image_ff[63];
                    mid_14[6] = CAL_image_ff[77];
                    mid_14[7] = CAL_image_ff[78];
                    mid_14[8] = CAL_image_ff[79];
                    mid_15[0] = CAL_image_ff[46];
                    mid_15[1] = CAL_image_ff[47];
                    mid_15[2] = CAL_image_ff[47];
                    mid_15[3] = CAL_image_ff[62];
                    mid_15[4] = CAL_image_ff[63];
                    mid_15[5] = CAL_image_ff[63];
                    mid_15[6] = CAL_image_ff[78];
                    mid_15[7] = CAL_image_ff[79];
                    mid_15[8] = CAL_image_ff[79];
                end
                else if(clock_cnt == 'd3) begin
                    mid_0[0] = CAL_image_ff[48];
                    mid_0[1] = CAL_image_ff[48];
                    mid_0[2] = CAL_image_ff[49];
                    mid_0[3] = CAL_image_ff[64];
                    mid_0[4] = CAL_image_ff[64];
                    mid_0[5] = CAL_image_ff[65];
                    mid_0[6] = CAL_image_ff[80];
                    mid_0[7] = CAL_image_ff[80];
                    mid_0[8] = CAL_image_ff[81];
                    mid_1[0] = CAL_image_ff[48];
                    mid_1[1] = CAL_image_ff[49];
                    mid_1[2] = CAL_image_ff[50];
                    mid_1[3] = CAL_image_ff[64];
                    mid_1[4] = CAL_image_ff[65];
                    mid_1[5] = CAL_image_ff[66];
                    mid_1[6] = CAL_image_ff[80];
                    mid_1[7] = CAL_image_ff[81];
                    mid_1[8] = CAL_image_ff[82];
                    mid_2[0] = CAL_image_ff[49];
                    mid_2[1] = CAL_image_ff[50];
                    mid_2[2] = CAL_image_ff[51];
                    mid_2[3] = CAL_image_ff[65];
                    mid_2[4] = CAL_image_ff[66];
                    mid_2[5] = CAL_image_ff[67];
                    mid_2[6] = CAL_image_ff[81];
                    mid_2[7] = CAL_image_ff[82];
                    mid_2[8] = CAL_image_ff[83];
                    mid_3[0] = CAL_image_ff[50];
                    mid_3[1] = CAL_image_ff[51];
                    mid_3[2] = CAL_image_ff[52];
                    mid_3[3] = CAL_image_ff[66];
                    mid_3[4] = CAL_image_ff[67];
                    mid_3[5] = CAL_image_ff[68];
                    mid_3[6] = CAL_image_ff[82];
                    mid_3[7] = CAL_image_ff[83];
                    mid_3[8] = CAL_image_ff[84];
                    mid_4[0] = CAL_image_ff[51];
                    mid_4[1] = CAL_image_ff[52];
                    mid_4[2] = CAL_image_ff[53];
                    mid_4[3] = CAL_image_ff[67];
                    mid_4[4] = CAL_image_ff[68];
                    mid_4[5] = CAL_image_ff[69];
                    mid_4[6] = CAL_image_ff[83];
                    mid_4[7] = CAL_image_ff[84];
                    mid_4[8] = CAL_image_ff[85];
                    mid_5[0] = CAL_image_ff[52];
                    mid_5[1] = CAL_image_ff[53];
                    mid_5[2] = CAL_image_ff[54];
                    mid_5[3] = CAL_image_ff[68];
                    mid_5[4] = CAL_image_ff[69];
                    mid_5[5] = CAL_image_ff[70];
                    mid_5[6] = CAL_image_ff[84];
                    mid_5[7] = CAL_image_ff[85];
                    mid_5[8] = CAL_image_ff[86];
                    mid_6[0] = CAL_image_ff[53];
                    mid_6[1] = CAL_image_ff[54];
                    mid_6[2] = CAL_image_ff[55];
                    mid_6[3] = CAL_image_ff[69];
                    mid_6[4] = CAL_image_ff[70];
                    mid_6[5] = CAL_image_ff[71];
                    mid_6[6] = CAL_image_ff[85];
                    mid_6[7] = CAL_image_ff[86];
                    mid_6[8] = CAL_image_ff[87];
                    mid_7[0] = CAL_image_ff[54];
                    mid_7[1] = CAL_image_ff[55];
                    mid_7[2] = CAL_image_ff[56];
                    mid_7[3] = CAL_image_ff[70];
                    mid_7[4] = CAL_image_ff[71];
                    mid_7[5] = CAL_image_ff[72];
                    mid_7[6] = CAL_image_ff[86];
                    mid_7[7] = CAL_image_ff[87];
                    mid_7[8] = CAL_image_ff[88];
                    mid_8[0] = CAL_image_ff[55];
                    mid_8[1] = CAL_image_ff[56];
                    mid_8[2] = CAL_image_ff[57];
                    mid_8[3] = CAL_image_ff[71];
                    mid_8[4] = CAL_image_ff[72];
                    mid_8[5] = CAL_image_ff[73];
                    mid_8[6] = CAL_image_ff[87];
                    mid_8[7] = CAL_image_ff[88];
                    mid_8[8] = CAL_image_ff[89];
                    mid_9[0] = CAL_image_ff[56];
                    mid_9[1] = CAL_image_ff[57];
                    mid_9[2] = CAL_image_ff[58];
                    mid_9[3] = CAL_image_ff[72];
                    mid_9[4] = CAL_image_ff[73];
                    mid_9[5] = CAL_image_ff[74];
                    mid_9[6] = CAL_image_ff[88];
                    mid_9[7] = CAL_image_ff[89];
                    mid_9[8] = CAL_image_ff[90];
                    mid_10[0] = CAL_image_ff[57];
                    mid_10[1] = CAL_image_ff[58];
                    mid_10[2] = CAL_image_ff[59];
                    mid_10[3] = CAL_image_ff[73];
                    mid_10[4] = CAL_image_ff[74];
                    mid_10[5] = CAL_image_ff[75];
                    mid_10[6] = CAL_image_ff[89];
                    mid_10[7] = CAL_image_ff[90];
                    mid_10[8] = CAL_image_ff[91];
                    mid_11[0] = CAL_image_ff[58];
                    mid_11[1] = CAL_image_ff[59];
                    mid_11[2] = CAL_image_ff[60];
                    mid_11[3] = CAL_image_ff[74];
                    mid_11[4] = CAL_image_ff[75];
                    mid_11[5] = CAL_image_ff[76];
                    mid_11[6] = CAL_image_ff[90];
                    mid_11[7] = CAL_image_ff[91];
                    mid_11[8] = CAL_image_ff[92];
                    mid_12[0] = CAL_image_ff[59];
                    mid_12[1] = CAL_image_ff[60];
                    mid_12[2] = CAL_image_ff[61];
                    mid_12[3] = CAL_image_ff[75];
                    mid_12[4] = CAL_image_ff[76];
                    mid_12[5] = CAL_image_ff[77];
                    mid_12[6] = CAL_image_ff[91];
                    mid_12[7] = CAL_image_ff[92];
                    mid_12[8] = CAL_image_ff[93];
                    mid_13[0] = CAL_image_ff[60];
                    mid_13[1] = CAL_image_ff[61];
                    mid_13[2] = CAL_image_ff[62];
                    mid_13[3] = CAL_image_ff[76];
                    mid_13[4] = CAL_image_ff[77];
                    mid_13[5] = CAL_image_ff[78];
                    mid_13[6] = CAL_image_ff[92];
                    mid_13[7] = CAL_image_ff[93];
                    mid_13[8] = CAL_image_ff[94];
                    mid_14[0] = CAL_image_ff[61];
                    mid_14[1] = CAL_image_ff[62];
                    mid_14[2] = CAL_image_ff[63];
                    mid_14[3] = CAL_image_ff[77];
                    mid_14[4] = CAL_image_ff[78];
                    mid_14[5] = CAL_image_ff[79];
                    mid_14[6] = CAL_image_ff[93];
                    mid_14[7] = CAL_image_ff[94];
                    mid_14[8] = CAL_image_ff[95];
                    mid_15[0] = CAL_image_ff[62];
                    mid_15[1] = CAL_image_ff[63];
                    mid_15[2] = CAL_image_ff[63];
                    mid_15[3] = CAL_image_ff[78];
                    mid_15[4] = CAL_image_ff[79];
                    mid_15[5] = CAL_image_ff[79];
                    mid_15[6] = CAL_image_ff[94];
                    mid_15[7] = CAL_image_ff[95];
                    mid_15[8] = CAL_image_ff[95];
                end
                else if(clock_cnt == 'd4) begin
                    mid_0[0] = CAL_image_ff[64];
                    mid_0[1] = CAL_image_ff[64];
                    mid_0[2] = CAL_image_ff[65];
                    mid_0[3] = CAL_image_ff[80];
                    mid_0[4] = CAL_image_ff[80];
                    mid_0[5] = CAL_image_ff[81];
                    mid_0[6] = CAL_image_ff[96];
                    mid_0[7] = CAL_image_ff[96];
                    mid_0[8] = CAL_image_ff[97];
                    mid_1[0] = CAL_image_ff[64];
                    mid_1[1] = CAL_image_ff[65];
                    mid_1[2] = CAL_image_ff[66];
                    mid_1[3] = CAL_image_ff[80];
                    mid_1[4] = CAL_image_ff[81];
                    mid_1[5] = CAL_image_ff[82];
                    mid_1[6] = CAL_image_ff[96];
                    mid_1[7] = CAL_image_ff[97];
                    mid_1[8] = CAL_image_ff[98];
                    mid_2[0] = CAL_image_ff[65];
                    mid_2[1] = CAL_image_ff[66];
                    mid_2[2] = CAL_image_ff[67];
                    mid_2[3] = CAL_image_ff[81];
                    mid_2[4] = CAL_image_ff[82];
                    mid_2[5] = CAL_image_ff[83];
                    mid_2[6] = CAL_image_ff[97];
                    mid_2[7] = CAL_image_ff[98];
                    mid_2[8] = CAL_image_ff[99];
                    mid_3[0] = CAL_image_ff[66];
                    mid_3[1] = CAL_image_ff[67];
                    mid_3[2] = CAL_image_ff[68];
                    mid_3[3] = CAL_image_ff[82];
                    mid_3[4] = CAL_image_ff[83];
                    mid_3[5] = CAL_image_ff[84];
                    mid_3[6] = CAL_image_ff[98];
                    mid_3[7] = CAL_image_ff[99];
                    mid_3[8] = CAL_image_ff[100];
                    mid_4[0] = CAL_image_ff[67];
                    mid_4[1] = CAL_image_ff[68];
                    mid_4[2] = CAL_image_ff[69];
                    mid_4[3] = CAL_image_ff[83];
                    mid_4[4] = CAL_image_ff[84];
                    mid_4[5] = CAL_image_ff[85];
                    mid_4[6] = CAL_image_ff[99];
                    mid_4[7] = CAL_image_ff[100];
                    mid_4[8] = CAL_image_ff[101];
                    mid_5[0] = CAL_image_ff[68];
                    mid_5[1] = CAL_image_ff[69];
                    mid_5[2] = CAL_image_ff[70];
                    mid_5[3] = CAL_image_ff[84];
                    mid_5[4] = CAL_image_ff[85];
                    mid_5[5] = CAL_image_ff[86];
                    mid_5[6] = CAL_image_ff[100];
                    mid_5[7] = CAL_image_ff[101];
                    mid_5[8] = CAL_image_ff[102];
                    mid_6[0] = CAL_image_ff[69];
                    mid_6[1] = CAL_image_ff[70];
                    mid_6[2] = CAL_image_ff[71];
                    mid_6[3] = CAL_image_ff[85];
                    mid_6[4] = CAL_image_ff[86];
                    mid_6[5] = CAL_image_ff[87];
                    mid_6[6] = CAL_image_ff[101];
                    mid_6[7] = CAL_image_ff[102];
                    mid_6[8] = CAL_image_ff[103];
                    mid_7[0] = CAL_image_ff[70];
                    mid_7[1] = CAL_image_ff[71];
                    mid_7[2] = CAL_image_ff[72];
                    mid_7[3] = CAL_image_ff[86];
                    mid_7[4] = CAL_image_ff[87];
                    mid_7[5] = CAL_image_ff[88];
                    mid_7[6] = CAL_image_ff[102];
                    mid_7[7] = CAL_image_ff[103];
                    mid_7[8] = CAL_image_ff[104];
                    mid_8[0] = CAL_image_ff[71];
                    mid_8[1] = CAL_image_ff[72];
                    mid_8[2] = CAL_image_ff[73];
                    mid_8[3] = CAL_image_ff[87];
                    mid_8[4] = CAL_image_ff[88];
                    mid_8[5] = CAL_image_ff[89];
                    mid_8[6] = CAL_image_ff[103];
                    mid_8[7] = CAL_image_ff[104];
                    mid_8[8] = CAL_image_ff[105];
                    mid_9[0] = CAL_image_ff[72];
                    mid_9[1] = CAL_image_ff[73];
                    mid_9[2] = CAL_image_ff[74];
                    mid_9[3] = CAL_image_ff[88];
                    mid_9[4] = CAL_image_ff[89];
                    mid_9[5] = CAL_image_ff[90];
                    mid_9[6] = CAL_image_ff[104];
                    mid_9[7] = CAL_image_ff[105];
                    mid_9[8] = CAL_image_ff[106];
                    mid_10[0] = CAL_image_ff[73];
                    mid_10[1] = CAL_image_ff[74];
                    mid_10[2] = CAL_image_ff[75];
                    mid_10[3] = CAL_image_ff[89];
                    mid_10[4] = CAL_image_ff[90];
                    mid_10[5] = CAL_image_ff[91];
                    mid_10[6] = CAL_image_ff[105];
                    mid_10[7] = CAL_image_ff[106];
                    mid_10[8] = CAL_image_ff[107];
                    mid_11[0] = CAL_image_ff[74];
                    mid_11[1] = CAL_image_ff[75];
                    mid_11[2] = CAL_image_ff[76];
                    mid_11[3] = CAL_image_ff[90];
                    mid_11[4] = CAL_image_ff[91];
                    mid_11[5] = CAL_image_ff[92];
                    mid_11[6] = CAL_image_ff[106];
                    mid_11[7] = CAL_image_ff[107];
                    mid_11[8] = CAL_image_ff[108];
                    mid_12[0] = CAL_image_ff[75];
                    mid_12[1] = CAL_image_ff[76];
                    mid_12[2] = CAL_image_ff[77];
                    mid_12[3] = CAL_image_ff[91];
                    mid_12[4] = CAL_image_ff[92];
                    mid_12[5] = CAL_image_ff[93];
                    mid_12[6] = CAL_image_ff[107];
                    mid_12[7] = CAL_image_ff[108];
                    mid_12[8] = CAL_image_ff[109];
                    mid_13[0] = CAL_image_ff[76];
                    mid_13[1] = CAL_image_ff[77];
                    mid_13[2] = CAL_image_ff[78];
                    mid_13[3] = CAL_image_ff[92];
                    mid_13[4] = CAL_image_ff[93];
                    mid_13[5] = CAL_image_ff[94];
                    mid_13[6] = CAL_image_ff[108];
                    mid_13[7] = CAL_image_ff[109];
                    mid_13[8] = CAL_image_ff[110];
                    mid_14[0] = CAL_image_ff[77];
                    mid_14[1] = CAL_image_ff[78];
                    mid_14[2] = CAL_image_ff[79];
                    mid_14[3] = CAL_image_ff[93];
                    mid_14[4] = CAL_image_ff[94];
                    mid_14[5] = CAL_image_ff[95];
                    mid_14[6] = CAL_image_ff[109];
                    mid_14[7] = CAL_image_ff[110];
                    mid_14[8] = CAL_image_ff[111];
                    mid_15[0] = CAL_image_ff[78];
                    mid_15[1] = CAL_image_ff[79];
                    mid_15[2] = CAL_image_ff[79];
                    mid_15[3] = CAL_image_ff[94];
                    mid_15[4] = CAL_image_ff[95];
                    mid_15[5] = CAL_image_ff[95];
                    mid_15[6] = CAL_image_ff[110];
                    mid_15[7] = CAL_image_ff[111];
                    mid_15[8] = CAL_image_ff[111];
                end
                else if(clock_cnt == 'd5) begin
                    mid_0[0] = CAL_image_ff[80];
                    mid_0[1] = CAL_image_ff[80];
                    mid_0[2] = CAL_image_ff[81];
                    mid_0[3] = CAL_image_ff[96];
                    mid_0[4] = CAL_image_ff[96];
                    mid_0[5] = CAL_image_ff[97];
                    mid_0[6] = CAL_image_ff[112];
                    mid_0[7] = CAL_image_ff[112];
                    mid_0[8] = CAL_image_ff[113];
                    mid_1[0] = CAL_image_ff[80];
                    mid_1[1] = CAL_image_ff[81];
                    mid_1[2] = CAL_image_ff[82];
                    mid_1[3] = CAL_image_ff[96];
                    mid_1[4] = CAL_image_ff[97];
                    mid_1[5] = CAL_image_ff[98];
                    mid_1[6] = CAL_image_ff[112];
                    mid_1[7] = CAL_image_ff[113];
                    mid_1[8] = CAL_image_ff[114];
                    mid_2[0] = CAL_image_ff[81];
                    mid_2[1] = CAL_image_ff[82];
                    mid_2[2] = CAL_image_ff[83];
                    mid_2[3] = CAL_image_ff[97];
                    mid_2[4] = CAL_image_ff[98];
                    mid_2[5] = CAL_image_ff[99];
                    mid_2[6] = CAL_image_ff[113];
                    mid_2[7] = CAL_image_ff[114];
                    mid_2[8] = CAL_image_ff[115];
                    mid_3[0] = CAL_image_ff[82];
                    mid_3[1] = CAL_image_ff[83];
                    mid_3[2] = CAL_image_ff[84];
                    mid_3[3] = CAL_image_ff[98];
                    mid_3[4] = CAL_image_ff[99];
                    mid_3[5] = CAL_image_ff[100];
                    mid_3[6] = CAL_image_ff[114];
                    mid_3[7] = CAL_image_ff[115];
                    mid_3[8] = CAL_image_ff[116];
                    mid_4[0] = CAL_image_ff[83];
                    mid_4[1] = CAL_image_ff[84];
                    mid_4[2] = CAL_image_ff[85];
                    mid_4[3] = CAL_image_ff[99];
                    mid_4[4] = CAL_image_ff[100];
                    mid_4[5] = CAL_image_ff[101];
                    mid_4[6] = CAL_image_ff[115];
                    mid_4[7] = CAL_image_ff[116];
                    mid_4[8] = CAL_image_ff[117];
                    mid_5[0] = CAL_image_ff[84];
                    mid_5[1] = CAL_image_ff[85];
                    mid_5[2] = CAL_image_ff[86];
                    mid_5[3] = CAL_image_ff[100];
                    mid_5[4] = CAL_image_ff[101];
                    mid_5[5] = CAL_image_ff[102];
                    mid_5[6] = CAL_image_ff[116];
                    mid_5[7] = CAL_image_ff[117];
                    mid_5[8] = CAL_image_ff[118];
                    mid_6[0] = CAL_image_ff[85];
                    mid_6[1] = CAL_image_ff[86];
                    mid_6[2] = CAL_image_ff[87];
                    mid_6[3] = CAL_image_ff[101];
                    mid_6[4] = CAL_image_ff[102];
                    mid_6[5] = CAL_image_ff[103];
                    mid_6[6] = CAL_image_ff[117];
                    mid_6[7] = CAL_image_ff[118];
                    mid_6[8] = CAL_image_ff[119];
                    mid_7[0] = CAL_image_ff[86];
                    mid_7[1] = CAL_image_ff[87];
                    mid_7[2] = CAL_image_ff[88];
                    mid_7[3] = CAL_image_ff[102];
                    mid_7[4] = CAL_image_ff[103];
                    mid_7[5] = CAL_image_ff[104];
                    mid_7[6] = CAL_image_ff[118];
                    mid_7[7] = CAL_image_ff[119];
                    mid_7[8] = CAL_image_ff[120];
                    mid_8[0] = CAL_image_ff[87];
                    mid_8[1] = CAL_image_ff[88];
                    mid_8[2] = CAL_image_ff[89];
                    mid_8[3] = CAL_image_ff[103];
                    mid_8[4] = CAL_image_ff[104];
                    mid_8[5] = CAL_image_ff[105];
                    mid_8[6] = CAL_image_ff[119];
                    mid_8[7] = CAL_image_ff[120];
                    mid_8[8] = CAL_image_ff[121];
                    mid_9[0] = CAL_image_ff[88];
                    mid_9[1] = CAL_image_ff[89];
                    mid_9[2] = CAL_image_ff[90];
                    mid_9[3] = CAL_image_ff[104];
                    mid_9[4] = CAL_image_ff[105];
                    mid_9[5] = CAL_image_ff[106];
                    mid_9[6] = CAL_image_ff[120];
                    mid_9[7] = CAL_image_ff[121];
                    mid_9[8] = CAL_image_ff[122];
                    mid_10[0] = CAL_image_ff[89];
                    mid_10[1] = CAL_image_ff[90];
                    mid_10[2] = CAL_image_ff[91];
                    mid_10[3] = CAL_image_ff[105];
                    mid_10[4] = CAL_image_ff[106];
                    mid_10[5] = CAL_image_ff[107];
                    mid_10[6] = CAL_image_ff[121];
                    mid_10[7] = CAL_image_ff[122];
                    mid_10[8] = CAL_image_ff[123];
                    mid_11[0] = CAL_image_ff[90];
                    mid_11[1] = CAL_image_ff[91];
                    mid_11[2] = CAL_image_ff[92];
                    mid_11[3] = CAL_image_ff[106];
                    mid_11[4] = CAL_image_ff[107];
                    mid_11[5] = CAL_image_ff[108];
                    mid_11[6] = CAL_image_ff[122];
                    mid_11[7] = CAL_image_ff[123];
                    mid_11[8] = CAL_image_ff[124];
                    mid_12[0] = CAL_image_ff[91];
                    mid_12[1] = CAL_image_ff[92];
                    mid_12[2] = CAL_image_ff[93];
                    mid_12[3] = CAL_image_ff[107];
                    mid_12[4] = CAL_image_ff[108];
                    mid_12[5] = CAL_image_ff[109];
                    mid_12[6] = CAL_image_ff[123];
                    mid_12[7] = CAL_image_ff[124];
                    mid_12[8] = CAL_image_ff[125];
                    mid_13[0] = CAL_image_ff[92];
                    mid_13[1] = CAL_image_ff[93];
                    mid_13[2] = CAL_image_ff[94];
                    mid_13[3] = CAL_image_ff[108];
                    mid_13[4] = CAL_image_ff[109];
                    mid_13[5] = CAL_image_ff[110];
                    mid_13[6] = CAL_image_ff[124];
                    mid_13[7] = CAL_image_ff[125];
                    mid_13[8] = CAL_image_ff[126];
                    mid_14[0] = CAL_image_ff[93];
                    mid_14[1] = CAL_image_ff[94];
                    mid_14[2] = CAL_image_ff[95];
                    mid_14[3] = CAL_image_ff[109];
                    mid_14[4] = CAL_image_ff[110];
                    mid_14[5] = CAL_image_ff[111];
                    mid_14[6] = CAL_image_ff[125];
                    mid_14[7] = CAL_image_ff[126];
                    mid_14[8] = CAL_image_ff[127];
                    mid_15[0] = CAL_image_ff[94];
                    mid_15[1] = CAL_image_ff[95];
                    mid_15[2] = CAL_image_ff[95];
                    mid_15[3] = CAL_image_ff[110];
                    mid_15[4] = CAL_image_ff[111];
                    mid_15[5] = CAL_image_ff[111];
                    mid_15[6] = CAL_image_ff[126];
                    mid_15[7] = CAL_image_ff[127];
                    mid_15[8] = CAL_image_ff[127];
                end
                else if(clock_cnt == 'd6) begin
                    mid_0[0] = CAL_image_ff[96];
                    mid_0[1] = CAL_image_ff[96];
                    mid_0[2] = CAL_image_ff[97];
                    mid_0[3] = CAL_image_ff[112];
                    mid_0[4] = CAL_image_ff[112];
                    mid_0[5] = CAL_image_ff[113];
                    mid_0[6] = CAL_image_ff[128];
                    mid_0[7] = CAL_image_ff[128];
                    mid_0[8] = CAL_image_ff[129];
                    mid_1[0] = CAL_image_ff[96];
                    mid_1[1] = CAL_image_ff[97];
                    mid_1[2] = CAL_image_ff[98];
                    mid_1[3] = CAL_image_ff[112];
                    mid_1[4] = CAL_image_ff[113];
                    mid_1[5] = CAL_image_ff[114];
                    mid_1[6] = CAL_image_ff[128];
                    mid_1[7] = CAL_image_ff[129];
                    mid_1[8] = CAL_image_ff[130];
                    mid_2[0] = CAL_image_ff[97];
                    mid_2[1] = CAL_image_ff[98];
                    mid_2[2] = CAL_image_ff[99];
                    mid_2[3] = CAL_image_ff[113];
                    mid_2[4] = CAL_image_ff[114];
                    mid_2[5] = CAL_image_ff[115];
                    mid_2[6] = CAL_image_ff[129];
                    mid_2[7] = CAL_image_ff[130];
                    mid_2[8] = CAL_image_ff[131];
                    mid_3[0] = CAL_image_ff[98];
                    mid_3[1] = CAL_image_ff[99];
                    mid_3[2] = CAL_image_ff[100];
                    mid_3[3] = CAL_image_ff[114];
                    mid_3[4] = CAL_image_ff[115];
                    mid_3[5] = CAL_image_ff[116];
                    mid_3[6] = CAL_image_ff[130];
                    mid_3[7] = CAL_image_ff[131];
                    mid_3[8] = CAL_image_ff[132];
                    mid_4[0] = CAL_image_ff[99];
                    mid_4[1] = CAL_image_ff[100];
                    mid_4[2] = CAL_image_ff[101];
                    mid_4[3] = CAL_image_ff[115];
                    mid_4[4] = CAL_image_ff[116];
                    mid_4[5] = CAL_image_ff[117];
                    mid_4[6] = CAL_image_ff[131];
                    mid_4[7] = CAL_image_ff[132];
                    mid_4[8] = CAL_image_ff[133];
                    mid_5[0] = CAL_image_ff[100];
                    mid_5[1] = CAL_image_ff[101];
                    mid_5[2] = CAL_image_ff[102];
                    mid_5[3] = CAL_image_ff[116];
                    mid_5[4] = CAL_image_ff[117];
                    mid_5[5] = CAL_image_ff[118];
                    mid_5[6] = CAL_image_ff[132];
                    mid_5[7] = CAL_image_ff[133];
                    mid_5[8] = CAL_image_ff[134];
                    mid_6[0] = CAL_image_ff[101];
                    mid_6[1] = CAL_image_ff[102];
                    mid_6[2] = CAL_image_ff[103];
                    mid_6[3] = CAL_image_ff[117];
                    mid_6[4] = CAL_image_ff[118];
                    mid_6[5] = CAL_image_ff[119];
                    mid_6[6] = CAL_image_ff[133];
                    mid_6[7] = CAL_image_ff[134];
                    mid_6[8] = CAL_image_ff[135];
                    mid_7[0] = CAL_image_ff[102];
                    mid_7[1] = CAL_image_ff[103];
                    mid_7[2] = CAL_image_ff[104];
                    mid_7[3] = CAL_image_ff[118];
                    mid_7[4] = CAL_image_ff[119];
                    mid_7[5] = CAL_image_ff[120];
                    mid_7[6] = CAL_image_ff[134];
                    mid_7[7] = CAL_image_ff[135];
                    mid_7[8] = CAL_image_ff[136];
                    mid_8[0] = CAL_image_ff[103];
                    mid_8[1] = CAL_image_ff[104];
                    mid_8[2] = CAL_image_ff[105];
                    mid_8[3] = CAL_image_ff[119];
                    mid_8[4] = CAL_image_ff[120];
                    mid_8[5] = CAL_image_ff[121];
                    mid_8[6] = CAL_image_ff[135];
                    mid_8[7] = CAL_image_ff[136];
                    mid_8[8] = CAL_image_ff[137];
                    mid_9[0] = CAL_image_ff[104];
                    mid_9[1] = CAL_image_ff[105];
                    mid_9[2] = CAL_image_ff[106];
                    mid_9[3] = CAL_image_ff[120];
                    mid_9[4] = CAL_image_ff[121];
                    mid_9[5] = CAL_image_ff[122];
                    mid_9[6] = CAL_image_ff[136];
                    mid_9[7] = CAL_image_ff[137];
                    mid_9[8] = CAL_image_ff[138];
                    mid_10[0] = CAL_image_ff[105];
                    mid_10[1] = CAL_image_ff[106];
                    mid_10[2] = CAL_image_ff[107];
                    mid_10[3] = CAL_image_ff[121];
                    mid_10[4] = CAL_image_ff[122];
                    mid_10[5] = CAL_image_ff[123];
                    mid_10[6] = CAL_image_ff[137];
                    mid_10[7] = CAL_image_ff[138];
                    mid_10[8] = CAL_image_ff[139];
                    mid_11[0] = CAL_image_ff[106];
                    mid_11[1] = CAL_image_ff[107];
                    mid_11[2] = CAL_image_ff[108];
                    mid_11[3] = CAL_image_ff[122];
                    mid_11[4] = CAL_image_ff[123];
                    mid_11[5] = CAL_image_ff[124];
                    mid_11[6] = CAL_image_ff[138];
                    mid_11[7] = CAL_image_ff[139];
                    mid_11[8] = CAL_image_ff[140];
                    mid_12[0] = CAL_image_ff[107];
                    mid_12[1] = CAL_image_ff[108];
                    mid_12[2] = CAL_image_ff[109];
                    mid_12[3] = CAL_image_ff[123];
                    mid_12[4] = CAL_image_ff[124];
                    mid_12[5] = CAL_image_ff[125];
                    mid_12[6] = CAL_image_ff[139];
                    mid_12[7] = CAL_image_ff[140];
                    mid_12[8] = CAL_image_ff[141];
                    mid_13[0] = CAL_image_ff[108];
                    mid_13[1] = CAL_image_ff[109];
                    mid_13[2] = CAL_image_ff[110];
                    mid_13[3] = CAL_image_ff[124];
                    mid_13[4] = CAL_image_ff[125];
                    mid_13[5] = CAL_image_ff[126];
                    mid_13[6] = CAL_image_ff[140];
                    mid_13[7] = CAL_image_ff[141];
                    mid_13[8] = CAL_image_ff[142];
                    mid_14[0] = CAL_image_ff[109];
                    mid_14[1] = CAL_image_ff[110];
                    mid_14[2] = CAL_image_ff[111];
                    mid_14[3] = CAL_image_ff[125];
                    mid_14[4] = CAL_image_ff[126];
                    mid_14[5] = CAL_image_ff[127];
                    mid_14[6] = CAL_image_ff[141];
                    mid_14[7] = CAL_image_ff[142];
                    mid_14[8] = CAL_image_ff[143];
                    mid_15[0] = CAL_image_ff[110];
                    mid_15[1] = CAL_image_ff[111];
                    mid_15[2] = CAL_image_ff[111];
                    mid_15[3] = CAL_image_ff[126];
                    mid_15[4] = CAL_image_ff[127];
                    mid_15[5] = CAL_image_ff[127];
                    mid_15[6] = CAL_image_ff[142];
                    mid_15[7] = CAL_image_ff[143];
                    mid_15[8] = CAL_image_ff[143];
                end
                else if(clock_cnt == 'd7) begin
                    mid_0[0] = CAL_image_ff[112];
                    mid_0[1] = CAL_image_ff[112];
                    mid_0[2] = CAL_image_ff[113];
                    mid_0[3] = CAL_image_ff[128];
                    mid_0[4] = CAL_image_ff[128];
                    mid_0[5] = CAL_image_ff[129];
                    mid_0[6] = CAL_image_ff[144];
                    mid_0[7] = CAL_image_ff[144];
                    mid_0[8] = CAL_image_ff[145];
                    mid_1[0] = CAL_image_ff[112];
                    mid_1[1] = CAL_image_ff[113];
                    mid_1[2] = CAL_image_ff[114];
                    mid_1[3] = CAL_image_ff[128];
                    mid_1[4] = CAL_image_ff[129];
                    mid_1[5] = CAL_image_ff[130];
                    mid_1[6] = CAL_image_ff[144];
                    mid_1[7] = CAL_image_ff[145];
                    mid_1[8] = CAL_image_ff[146];
                    mid_2[0] = CAL_image_ff[113];
                    mid_2[1] = CAL_image_ff[114];
                    mid_2[2] = CAL_image_ff[115];
                    mid_2[3] = CAL_image_ff[129];
                    mid_2[4] = CAL_image_ff[130];
                    mid_2[5] = CAL_image_ff[131];
                    mid_2[6] = CAL_image_ff[145];
                    mid_2[7] = CAL_image_ff[146];
                    mid_2[8] = CAL_image_ff[147];
                    mid_3[0] = CAL_image_ff[114];
                    mid_3[1] = CAL_image_ff[115];
                    mid_3[2] = CAL_image_ff[116];
                    mid_3[3] = CAL_image_ff[130];
                    mid_3[4] = CAL_image_ff[131];
                    mid_3[5] = CAL_image_ff[132];
                    mid_3[6] = CAL_image_ff[146];
                    mid_3[7] = CAL_image_ff[147];
                    mid_3[8] = CAL_image_ff[148];
                    mid_4[0] = CAL_image_ff[115];
                    mid_4[1] = CAL_image_ff[116];
                    mid_4[2] = CAL_image_ff[117];
                    mid_4[3] = CAL_image_ff[131];
                    mid_4[4] = CAL_image_ff[132];
                    mid_4[5] = CAL_image_ff[133];
                    mid_4[6] = CAL_image_ff[147];
                    mid_4[7] = CAL_image_ff[148];
                    mid_4[8] = CAL_image_ff[149];
                    mid_5[0] = CAL_image_ff[116];
                    mid_5[1] = CAL_image_ff[117];
                    mid_5[2] = CAL_image_ff[118];
                    mid_5[3] = CAL_image_ff[132];
                    mid_5[4] = CAL_image_ff[133];
                    mid_5[5] = CAL_image_ff[134];
                    mid_5[6] = CAL_image_ff[148];
                    mid_5[7] = CAL_image_ff[149];
                    mid_5[8] = CAL_image_ff[150];
                    mid_6[0] = CAL_image_ff[117];
                    mid_6[1] = CAL_image_ff[118];
                    mid_6[2] = CAL_image_ff[119];
                    mid_6[3] = CAL_image_ff[133];
                    mid_6[4] = CAL_image_ff[134];
                    mid_6[5] = CAL_image_ff[135];
                    mid_6[6] = CAL_image_ff[149];
                    mid_6[7] = CAL_image_ff[150];
                    mid_6[8] = CAL_image_ff[151];
                    mid_7[0] = CAL_image_ff[118];
                    mid_7[1] = CAL_image_ff[119];
                    mid_7[2] = CAL_image_ff[120];
                    mid_7[3] = CAL_image_ff[134];
                    mid_7[4] = CAL_image_ff[135];
                    mid_7[5] = CAL_image_ff[136];
                    mid_7[6] = CAL_image_ff[150];
                    mid_7[7] = CAL_image_ff[151];
                    mid_7[8] = CAL_image_ff[152];
                    mid_8[0] = CAL_image_ff[119];
                    mid_8[1] = CAL_image_ff[120];
                    mid_8[2] = CAL_image_ff[121];
                    mid_8[3] = CAL_image_ff[135];
                    mid_8[4] = CAL_image_ff[136];
                    mid_8[5] = CAL_image_ff[137];
                    mid_8[6] = CAL_image_ff[151];
                    mid_8[7] = CAL_image_ff[152];
                    mid_8[8] = CAL_image_ff[153];
                    mid_9[0] = CAL_image_ff[120];
                    mid_9[1] = CAL_image_ff[121];
                    mid_9[2] = CAL_image_ff[122];
                    mid_9[3] = CAL_image_ff[136];
                    mid_9[4] = CAL_image_ff[137];
                    mid_9[5] = CAL_image_ff[138];
                    mid_9[6] = CAL_image_ff[152];
                    mid_9[7] = CAL_image_ff[153];
                    mid_9[8] = CAL_image_ff[154];
                    mid_10[0] = CAL_image_ff[121];
                    mid_10[1] = CAL_image_ff[122];
                    mid_10[2] = CAL_image_ff[123];
                    mid_10[3] = CAL_image_ff[137];
                    mid_10[4] = CAL_image_ff[138];
                    mid_10[5] = CAL_image_ff[139];
                    mid_10[6] = CAL_image_ff[153];
                    mid_10[7] = CAL_image_ff[154];
                    mid_10[8] = CAL_image_ff[155];
                    mid_11[0] = CAL_image_ff[122];
                    mid_11[1] = CAL_image_ff[123];
                    mid_11[2] = CAL_image_ff[124];
                    mid_11[3] = CAL_image_ff[138];
                    mid_11[4] = CAL_image_ff[139];
                    mid_11[5] = CAL_image_ff[140];
                    mid_11[6] = CAL_image_ff[154];
                    mid_11[7] = CAL_image_ff[155];
                    mid_11[8] = CAL_image_ff[156];
                    mid_12[0] = CAL_image_ff[123];
                    mid_12[1] = CAL_image_ff[124];
                    mid_12[2] = CAL_image_ff[125];
                    mid_12[3] = CAL_image_ff[139];
                    mid_12[4] = CAL_image_ff[140];
                    mid_12[5] = CAL_image_ff[141];
                    mid_12[6] = CAL_image_ff[155];
                    mid_12[7] = CAL_image_ff[156];
                    mid_12[8] = CAL_image_ff[157];
                    mid_13[0] = CAL_image_ff[124];
                    mid_13[1] = CAL_image_ff[125];
                    mid_13[2] = CAL_image_ff[126];
                    mid_13[3] = CAL_image_ff[140];
                    mid_13[4] = CAL_image_ff[141];
                    mid_13[5] = CAL_image_ff[142];
                    mid_13[6] = CAL_image_ff[156];
                    mid_13[7] = CAL_image_ff[157];
                    mid_13[8] = CAL_image_ff[158];
                    mid_14[0] = CAL_image_ff[125];
                    mid_14[1] = CAL_image_ff[126];
                    mid_14[2] = CAL_image_ff[127];
                    mid_14[3] = CAL_image_ff[141];
                    mid_14[4] = CAL_image_ff[142];
                    mid_14[5] = CAL_image_ff[143];
                    mid_14[6] = CAL_image_ff[157];
                    mid_14[7] = CAL_image_ff[158];
                    mid_14[8] = CAL_image_ff[159];
                    mid_15[0] = CAL_image_ff[126];
                    mid_15[1] = CAL_image_ff[127];
                    mid_15[2] = CAL_image_ff[127];
                    mid_15[3] = CAL_image_ff[142];
                    mid_15[4] = CAL_image_ff[143];
                    mid_15[5] = CAL_image_ff[143];
                    mid_15[6] = CAL_image_ff[158];
                    mid_15[7] = CAL_image_ff[159];
                    mid_15[8] = CAL_image_ff[159];
                end
                else if(clock_cnt == 'd8) begin
                    mid_0[0] = CAL_image_ff[128];
                    mid_0[1] = CAL_image_ff[128];
                    mid_0[2] = CAL_image_ff[129];
                    mid_0[3] = CAL_image_ff[144];
                    mid_0[4] = CAL_image_ff[144];
                    mid_0[5] = CAL_image_ff[145];
                    mid_0[6] = CAL_image_ff[160];
                    mid_0[7] = CAL_image_ff[160];
                    mid_0[8] = CAL_image_ff[161];
                    mid_1[0] = CAL_image_ff[128];
                    mid_1[1] = CAL_image_ff[129];
                    mid_1[2] = CAL_image_ff[130];
                    mid_1[3] = CAL_image_ff[144];
                    mid_1[4] = CAL_image_ff[145];
                    mid_1[5] = CAL_image_ff[146];
                    mid_1[6] = CAL_image_ff[160];
                    mid_1[7] = CAL_image_ff[161];
                    mid_1[8] = CAL_image_ff[162];
                    mid_2[0] = CAL_image_ff[129];
                    mid_2[1] = CAL_image_ff[130];
                    mid_2[2] = CAL_image_ff[131];
                    mid_2[3] = CAL_image_ff[145];
                    mid_2[4] = CAL_image_ff[146];
                    mid_2[5] = CAL_image_ff[147];
                    mid_2[6] = CAL_image_ff[161];
                    mid_2[7] = CAL_image_ff[162];
                    mid_2[8] = CAL_image_ff[163];
                    mid_3[0] = CAL_image_ff[130];
                    mid_3[1] = CAL_image_ff[131];
                    mid_3[2] = CAL_image_ff[132];
                    mid_3[3] = CAL_image_ff[146];
                    mid_3[4] = CAL_image_ff[147];
                    mid_3[5] = CAL_image_ff[148];
                    mid_3[6] = CAL_image_ff[162];
                    mid_3[7] = CAL_image_ff[163];
                    mid_3[8] = CAL_image_ff[164];
                    mid_4[0] = CAL_image_ff[131];
                    mid_4[1] = CAL_image_ff[132];
                    mid_4[2] = CAL_image_ff[133];
                    mid_4[3] = CAL_image_ff[147];
                    mid_4[4] = CAL_image_ff[148];
                    mid_4[5] = CAL_image_ff[149];
                    mid_4[6] = CAL_image_ff[163];
                    mid_4[7] = CAL_image_ff[164];
                    mid_4[8] = CAL_image_ff[165];
                    mid_5[0] = CAL_image_ff[132];
                    mid_5[1] = CAL_image_ff[133];
                    mid_5[2] = CAL_image_ff[134];
                    mid_5[3] = CAL_image_ff[148];
                    mid_5[4] = CAL_image_ff[149];
                    mid_5[5] = CAL_image_ff[150];
                    mid_5[6] = CAL_image_ff[164];
                    mid_5[7] = CAL_image_ff[165];
                    mid_5[8] = CAL_image_ff[166];
                    mid_6[0] = CAL_image_ff[133];
                    mid_6[1] = CAL_image_ff[134];
                    mid_6[2] = CAL_image_ff[135];
                    mid_6[3] = CAL_image_ff[149];
                    mid_6[4] = CAL_image_ff[150];
                    mid_6[5] = CAL_image_ff[151];
                    mid_6[6] = CAL_image_ff[165];
                    mid_6[7] = CAL_image_ff[166];
                    mid_6[8] = CAL_image_ff[167];
                    mid_7[0] = CAL_image_ff[134];
                    mid_7[1] = CAL_image_ff[135];
                    mid_7[2] = CAL_image_ff[136];
                    mid_7[3] = CAL_image_ff[150];
                    mid_7[4] = CAL_image_ff[151];
                    mid_7[5] = CAL_image_ff[152];
                    mid_7[6] = CAL_image_ff[166];
                    mid_7[7] = CAL_image_ff[167];
                    mid_7[8] = CAL_image_ff[168];
                    mid_8[0] = CAL_image_ff[135];
                    mid_8[1] = CAL_image_ff[136];
                    mid_8[2] = CAL_image_ff[137];
                    mid_8[3] = CAL_image_ff[151];
                    mid_8[4] = CAL_image_ff[152];
                    mid_8[5] = CAL_image_ff[153];
                    mid_8[6] = CAL_image_ff[167];
                    mid_8[7] = CAL_image_ff[168];
                    mid_8[8] = CAL_image_ff[169];
                    mid_9[0] = CAL_image_ff[136];
                    mid_9[1] = CAL_image_ff[137];
                    mid_9[2] = CAL_image_ff[138];
                    mid_9[3] = CAL_image_ff[152];
                    mid_9[4] = CAL_image_ff[153];
                    mid_9[5] = CAL_image_ff[154];
                    mid_9[6] = CAL_image_ff[168];
                    mid_9[7] = CAL_image_ff[169];
                    mid_9[8] = CAL_image_ff[170];
                    mid_10[0] = CAL_image_ff[137];
                    mid_10[1] = CAL_image_ff[138];
                    mid_10[2] = CAL_image_ff[139];
                    mid_10[3] = CAL_image_ff[153];
                    mid_10[4] = CAL_image_ff[154];
                    mid_10[5] = CAL_image_ff[155];
                    mid_10[6] = CAL_image_ff[169];
                    mid_10[7] = CAL_image_ff[170];
                    mid_10[8] = CAL_image_ff[171];
                    mid_11[0] = CAL_image_ff[138];
                    mid_11[1] = CAL_image_ff[139];
                    mid_11[2] = CAL_image_ff[140];
                    mid_11[3] = CAL_image_ff[154];
                    mid_11[4] = CAL_image_ff[155];
                    mid_11[5] = CAL_image_ff[156];
                    mid_11[6] = CAL_image_ff[170];
                    mid_11[7] = CAL_image_ff[171];
                    mid_11[8] = CAL_image_ff[172];
                    mid_12[0] = CAL_image_ff[139];
                    mid_12[1] = CAL_image_ff[140];
                    mid_12[2] = CAL_image_ff[141];
                    mid_12[3] = CAL_image_ff[155];
                    mid_12[4] = CAL_image_ff[156];
                    mid_12[5] = CAL_image_ff[157];
                    mid_12[6] = CAL_image_ff[171];
                    mid_12[7] = CAL_image_ff[172];
                    mid_12[8] = CAL_image_ff[173];
                    mid_13[0] = CAL_image_ff[140];
                    mid_13[1] = CAL_image_ff[141];
                    mid_13[2] = CAL_image_ff[142];
                    mid_13[3] = CAL_image_ff[156];
                    mid_13[4] = CAL_image_ff[157];
                    mid_13[5] = CAL_image_ff[158];
                    mid_13[6] = CAL_image_ff[172];
                    mid_13[7] = CAL_image_ff[173];
                    mid_13[8] = CAL_image_ff[174];
                    mid_14[0] = CAL_image_ff[141];
                    mid_14[1] = CAL_image_ff[142];
                    mid_14[2] = CAL_image_ff[143];
                    mid_14[3] = CAL_image_ff[157];
                    mid_14[4] = CAL_image_ff[158];
                    mid_14[5] = CAL_image_ff[159];
                    mid_14[6] = CAL_image_ff[173];
                    mid_14[7] = CAL_image_ff[174];
                    mid_14[8] = CAL_image_ff[175];
                    mid_15[0] = CAL_image_ff[142];
                    mid_15[1] = CAL_image_ff[143];
                    mid_15[2] = CAL_image_ff[143];
                    mid_15[3] = CAL_image_ff[158];
                    mid_15[4] = CAL_image_ff[159];
                    mid_15[5] = CAL_image_ff[159];
                    mid_15[6] = CAL_image_ff[174];
                    mid_15[7] = CAL_image_ff[175];
                    mid_15[8] = CAL_image_ff[175];
                end
                else if(clock_cnt == 'd9) begin
                    mid_0[0] = CAL_image_ff[144];
                    mid_0[1] = CAL_image_ff[144];
                    mid_0[2] = CAL_image_ff[145];
                    mid_0[3] = CAL_image_ff[160];
                    mid_0[4] = CAL_image_ff[160];
                    mid_0[5] = CAL_image_ff[161];
                    mid_0[6] = CAL_image_ff[176];
                    mid_0[7] = CAL_image_ff[176];
                    mid_0[8] = CAL_image_ff[177];
                    mid_1[0] = CAL_image_ff[144];
                    mid_1[1] = CAL_image_ff[145];
                    mid_1[2] = CAL_image_ff[146];
                    mid_1[3] = CAL_image_ff[160];
                    mid_1[4] = CAL_image_ff[161];
                    mid_1[5] = CAL_image_ff[162];
                    mid_1[6] = CAL_image_ff[176];
                    mid_1[7] = CAL_image_ff[177];
                    mid_1[8] = CAL_image_ff[178];
                    mid_2[0] = CAL_image_ff[145];
                    mid_2[1] = CAL_image_ff[146];
                    mid_2[2] = CAL_image_ff[147];
                    mid_2[3] = CAL_image_ff[161];
                    mid_2[4] = CAL_image_ff[162];
                    mid_2[5] = CAL_image_ff[163];
                    mid_2[6] = CAL_image_ff[177];
                    mid_2[7] = CAL_image_ff[178];
                    mid_2[8] = CAL_image_ff[179];
                    mid_3[0] = CAL_image_ff[146];
                    mid_3[1] = CAL_image_ff[147];
                    mid_3[2] = CAL_image_ff[148];
                    mid_3[3] = CAL_image_ff[162];
                    mid_3[4] = CAL_image_ff[163];
                    mid_3[5] = CAL_image_ff[164];
                    mid_3[6] = CAL_image_ff[178];
                    mid_3[7] = CAL_image_ff[179];
                    mid_3[8] = CAL_image_ff[180];
                    mid_4[0] = CAL_image_ff[147];
                    mid_4[1] = CAL_image_ff[148];
                    mid_4[2] = CAL_image_ff[149];
                    mid_4[3] = CAL_image_ff[163];
                    mid_4[4] = CAL_image_ff[164];
                    mid_4[5] = CAL_image_ff[165];
                    mid_4[6] = CAL_image_ff[179];
                    mid_4[7] = CAL_image_ff[180];
                    mid_4[8] = CAL_image_ff[181];
                    mid_5[0] = CAL_image_ff[148];
                    mid_5[1] = CAL_image_ff[149];
                    mid_5[2] = CAL_image_ff[150];
                    mid_5[3] = CAL_image_ff[164];
                    mid_5[4] = CAL_image_ff[165];
                    mid_5[5] = CAL_image_ff[166];
                    mid_5[6] = CAL_image_ff[180];
                    mid_5[7] = CAL_image_ff[181];
                    mid_5[8] = CAL_image_ff[182];
                    mid_6[0] = CAL_image_ff[149];
                    mid_6[1] = CAL_image_ff[150];
                    mid_6[2] = CAL_image_ff[151];
                    mid_6[3] = CAL_image_ff[165];
                    mid_6[4] = CAL_image_ff[166];
                    mid_6[5] = CAL_image_ff[167];
                    mid_6[6] = CAL_image_ff[181];
                    mid_6[7] = CAL_image_ff[182];
                    mid_6[8] = CAL_image_ff[183];
                    mid_7[0] = CAL_image_ff[150];
                    mid_7[1] = CAL_image_ff[151];
                    mid_7[2] = CAL_image_ff[152];
                    mid_7[3] = CAL_image_ff[166];
                    mid_7[4] = CAL_image_ff[167];
                    mid_7[5] = CAL_image_ff[168];
                    mid_7[6] = CAL_image_ff[182];
                    mid_7[7] = CAL_image_ff[183];
                    mid_7[8] = CAL_image_ff[184];
                    mid_8[0] = CAL_image_ff[151];
                    mid_8[1] = CAL_image_ff[152];
                    mid_8[2] = CAL_image_ff[153];
                    mid_8[3] = CAL_image_ff[167];
                    mid_8[4] = CAL_image_ff[168];
                    mid_8[5] = CAL_image_ff[169];
                    mid_8[6] = CAL_image_ff[183];
                    mid_8[7] = CAL_image_ff[184];
                    mid_8[8] = CAL_image_ff[185];
                    mid_9[0] = CAL_image_ff[152];
                    mid_9[1] = CAL_image_ff[153];
                    mid_9[2] = CAL_image_ff[154];
                    mid_9[3] = CAL_image_ff[168];
                    mid_9[4] = CAL_image_ff[169];
                    mid_9[5] = CAL_image_ff[170];
                    mid_9[6] = CAL_image_ff[184];
                    mid_9[7] = CAL_image_ff[185];
                    mid_9[8] = CAL_image_ff[186];
                    mid_10[0] = CAL_image_ff[153];
                    mid_10[1] = CAL_image_ff[154];
                    mid_10[2] = CAL_image_ff[155];
                    mid_10[3] = CAL_image_ff[169];
                    mid_10[4] = CAL_image_ff[170];
                    mid_10[5] = CAL_image_ff[171];
                    mid_10[6] = CAL_image_ff[185];
                    mid_10[7] = CAL_image_ff[186];
                    mid_10[8] = CAL_image_ff[187];
                    mid_11[0] = CAL_image_ff[154];
                    mid_11[1] = CAL_image_ff[155];
                    mid_11[2] = CAL_image_ff[156];
                    mid_11[3] = CAL_image_ff[170];
                    mid_11[4] = CAL_image_ff[171];
                    mid_11[5] = CAL_image_ff[172];
                    mid_11[6] = CAL_image_ff[186];
                    mid_11[7] = CAL_image_ff[187];
                    mid_11[8] = CAL_image_ff[188];
                    mid_12[0] = CAL_image_ff[155];
                    mid_12[1] = CAL_image_ff[156];
                    mid_12[2] = CAL_image_ff[157];
                    mid_12[3] = CAL_image_ff[171];
                    mid_12[4] = CAL_image_ff[172];
                    mid_12[5] = CAL_image_ff[173];
                    mid_12[6] = CAL_image_ff[187];
                    mid_12[7] = CAL_image_ff[188];
                    mid_12[8] = CAL_image_ff[189];
                    mid_13[0] = CAL_image_ff[156];
                    mid_13[1] = CAL_image_ff[157];
                    mid_13[2] = CAL_image_ff[158];
                    mid_13[3] = CAL_image_ff[172];
                    mid_13[4] = CAL_image_ff[173];
                    mid_13[5] = CAL_image_ff[174];
                    mid_13[6] = CAL_image_ff[188];
                    mid_13[7] = CAL_image_ff[189];
                    mid_13[8] = CAL_image_ff[190];
                    mid_14[0] = CAL_image_ff[157];
                    mid_14[1] = CAL_image_ff[158];
                    mid_14[2] = CAL_image_ff[159];
                    mid_14[3] = CAL_image_ff[173];
                    mid_14[4] = CAL_image_ff[174];
                    mid_14[5] = CAL_image_ff[175];
                    mid_14[6] = CAL_image_ff[189];
                    mid_14[7] = CAL_image_ff[190];
                    mid_14[8] = CAL_image_ff[191];
                    mid_15[0] = CAL_image_ff[158];
                    mid_15[1] = CAL_image_ff[159];
                    mid_15[2] = CAL_image_ff[159];
                    mid_15[3] = CAL_image_ff[174];
                    mid_15[4] = CAL_image_ff[175];
                    mid_15[5] = CAL_image_ff[175];
                    mid_15[6] = CAL_image_ff[190];
                    mid_15[7] = CAL_image_ff[191];
                    mid_15[8] = CAL_image_ff[191];
                end
                else if(clock_cnt == 'd10) begin
                    mid_0[0] = CAL_image_ff[160];
                    mid_0[1] = CAL_image_ff[160];
                    mid_0[2] = CAL_image_ff[161];
                    mid_0[3] = CAL_image_ff[176];
                    mid_0[4] = CAL_image_ff[176];
                    mid_0[5] = CAL_image_ff[177];
                    mid_0[6] = CAL_image_ff[192];
                    mid_0[7] = CAL_image_ff[192];
                    mid_0[8] = CAL_image_ff[193];
                    mid_1[0] = CAL_image_ff[160];
                    mid_1[1] = CAL_image_ff[161];
                    mid_1[2] = CAL_image_ff[162];
                    mid_1[3] = CAL_image_ff[176];
                    mid_1[4] = CAL_image_ff[177];
                    mid_1[5] = CAL_image_ff[178];
                    mid_1[6] = CAL_image_ff[192];
                    mid_1[7] = CAL_image_ff[193];
                    mid_1[8] = CAL_image_ff[194];
                    mid_2[0] = CAL_image_ff[161];
                    mid_2[1] = CAL_image_ff[162];
                    mid_2[2] = CAL_image_ff[163];
                    mid_2[3] = CAL_image_ff[177];
                    mid_2[4] = CAL_image_ff[178];
                    mid_2[5] = CAL_image_ff[179];
                    mid_2[6] = CAL_image_ff[193];
                    mid_2[7] = CAL_image_ff[194];
                    mid_2[8] = CAL_image_ff[195];
                    mid_3[0] = CAL_image_ff[162];
                    mid_3[1] = CAL_image_ff[163];
                    mid_3[2] = CAL_image_ff[164];
                    mid_3[3] = CAL_image_ff[178];
                    mid_3[4] = CAL_image_ff[179];
                    mid_3[5] = CAL_image_ff[180];
                    mid_3[6] = CAL_image_ff[194];
                    mid_3[7] = CAL_image_ff[195];
                    mid_3[8] = CAL_image_ff[196];
                    mid_4[0] = CAL_image_ff[163];
                    mid_4[1] = CAL_image_ff[164];
                    mid_4[2] = CAL_image_ff[165];
                    mid_4[3] = CAL_image_ff[179];
                    mid_4[4] = CAL_image_ff[180];
                    mid_4[5] = CAL_image_ff[181];
                    mid_4[6] = CAL_image_ff[195];
                    mid_4[7] = CAL_image_ff[196];
                    mid_4[8] = CAL_image_ff[197];
                    mid_5[0] = CAL_image_ff[164];
                    mid_5[1] = CAL_image_ff[165];
                    mid_5[2] = CAL_image_ff[166];
                    mid_5[3] = CAL_image_ff[180];
                    mid_5[4] = CAL_image_ff[181];
                    mid_5[5] = CAL_image_ff[182];
                    mid_5[6] = CAL_image_ff[196];
                    mid_5[7] = CAL_image_ff[197];
                    mid_5[8] = CAL_image_ff[198];
                    mid_6[0] = CAL_image_ff[165];
                    mid_6[1] = CAL_image_ff[166];
                    mid_6[2] = CAL_image_ff[167];
                    mid_6[3] = CAL_image_ff[181];
                    mid_6[4] = CAL_image_ff[182];
                    mid_6[5] = CAL_image_ff[183];
                    mid_6[6] = CAL_image_ff[197];
                    mid_6[7] = CAL_image_ff[198];
                    mid_6[8] = CAL_image_ff[199];
                    mid_7[0] = CAL_image_ff[166];
                    mid_7[1] = CAL_image_ff[167];
                    mid_7[2] = CAL_image_ff[168];
                    mid_7[3] = CAL_image_ff[182];
                    mid_7[4] = CAL_image_ff[183];
                    mid_7[5] = CAL_image_ff[184];
                    mid_7[6] = CAL_image_ff[198];
                    mid_7[7] = CAL_image_ff[199];
                    mid_7[8] = CAL_image_ff[200];
                    mid_8[0] = CAL_image_ff[167];
                    mid_8[1] = CAL_image_ff[168];
                    mid_8[2] = CAL_image_ff[169];
                    mid_8[3] = CAL_image_ff[183];
                    mid_8[4] = CAL_image_ff[184];
                    mid_8[5] = CAL_image_ff[185];
                    mid_8[6] = CAL_image_ff[199];
                    mid_8[7] = CAL_image_ff[200];
                    mid_8[8] = CAL_image_ff[201];
                    mid_9[0] = CAL_image_ff[168];
                    mid_9[1] = CAL_image_ff[169];
                    mid_9[2] = CAL_image_ff[170];
                    mid_9[3] = CAL_image_ff[184];
                    mid_9[4] = CAL_image_ff[185];
                    mid_9[5] = CAL_image_ff[186];
                    mid_9[6] = CAL_image_ff[200];
                    mid_9[7] = CAL_image_ff[201];
                    mid_9[8] = CAL_image_ff[202];
                    mid_10[0] = CAL_image_ff[169];
                    mid_10[1] = CAL_image_ff[170];
                    mid_10[2] = CAL_image_ff[171];
                    mid_10[3] = CAL_image_ff[185];
                    mid_10[4] = CAL_image_ff[186];
                    mid_10[5] = CAL_image_ff[187];
                    mid_10[6] = CAL_image_ff[201];
                    mid_10[7] = CAL_image_ff[202];
                    mid_10[8] = CAL_image_ff[203];
                    mid_11[0] = CAL_image_ff[170];
                    mid_11[1] = CAL_image_ff[171];
                    mid_11[2] = CAL_image_ff[172];
                    mid_11[3] = CAL_image_ff[186];
                    mid_11[4] = CAL_image_ff[187];
                    mid_11[5] = CAL_image_ff[188];
                    mid_11[6] = CAL_image_ff[202];
                    mid_11[7] = CAL_image_ff[203];
                    mid_11[8] = CAL_image_ff[204];
                    mid_12[0] = CAL_image_ff[171];
                    mid_12[1] = CAL_image_ff[172];
                    mid_12[2] = CAL_image_ff[173];
                    mid_12[3] = CAL_image_ff[187];
                    mid_12[4] = CAL_image_ff[188];
                    mid_12[5] = CAL_image_ff[189];
                    mid_12[6] = CAL_image_ff[203];
                    mid_12[7] = CAL_image_ff[204];
                    mid_12[8] = CAL_image_ff[205];
                    mid_13[0] = CAL_image_ff[172];
                    mid_13[1] = CAL_image_ff[173];
                    mid_13[2] = CAL_image_ff[174];
                    mid_13[3] = CAL_image_ff[188];
                    mid_13[4] = CAL_image_ff[189];
                    mid_13[5] = CAL_image_ff[190];
                    mid_13[6] = CAL_image_ff[204];
                    mid_13[7] = CAL_image_ff[205];
                    mid_13[8] = CAL_image_ff[206];
                    mid_14[0] = CAL_image_ff[173];
                    mid_14[1] = CAL_image_ff[174];
                    mid_14[2] = CAL_image_ff[175];
                    mid_14[3] = CAL_image_ff[189];
                    mid_14[4] = CAL_image_ff[190];
                    mid_14[5] = CAL_image_ff[191];
                    mid_14[6] = CAL_image_ff[205];
                    mid_14[7] = CAL_image_ff[206];
                    mid_14[8] = CAL_image_ff[207];
                    mid_15[0] = CAL_image_ff[174];
                    mid_15[1] = CAL_image_ff[175];
                    mid_15[2] = CAL_image_ff[175];
                    mid_15[3] = CAL_image_ff[190];
                    mid_15[4] = CAL_image_ff[191];
                    mid_15[5] = CAL_image_ff[191];
                    mid_15[6] = CAL_image_ff[206];
                    mid_15[7] = CAL_image_ff[207];
                    mid_15[8] = CAL_image_ff[207];
                end
                else if(clock_cnt == 'd11) begin
                    mid_0[0] = CAL_image_ff[176];
                    mid_0[1] = CAL_image_ff[176];
                    mid_0[2] = CAL_image_ff[177];
                    mid_0[3] = CAL_image_ff[192];
                    mid_0[4] = CAL_image_ff[192];
                    mid_0[5] = CAL_image_ff[193];
                    mid_0[6] = CAL_image_ff[208];
                    mid_0[7] = CAL_image_ff[208];
                    mid_0[8] = CAL_image_ff[209];
                    mid_1[0] = CAL_image_ff[176];
                    mid_1[1] = CAL_image_ff[177];
                    mid_1[2] = CAL_image_ff[178];
                    mid_1[3] = CAL_image_ff[192];
                    mid_1[4] = CAL_image_ff[193];
                    mid_1[5] = CAL_image_ff[194];
                    mid_1[6] = CAL_image_ff[208];
                    mid_1[7] = CAL_image_ff[209];
                    mid_1[8] = CAL_image_ff[210];
                    mid_2[0] = CAL_image_ff[177];
                    mid_2[1] = CAL_image_ff[178];
                    mid_2[2] = CAL_image_ff[179];
                    mid_2[3] = CAL_image_ff[193];
                    mid_2[4] = CAL_image_ff[194];
                    mid_2[5] = CAL_image_ff[195];
                    mid_2[6] = CAL_image_ff[209];
                    mid_2[7] = CAL_image_ff[210];
                    mid_2[8] = CAL_image_ff[211];
                    mid_3[0] = CAL_image_ff[178];
                    mid_3[1] = CAL_image_ff[179];
                    mid_3[2] = CAL_image_ff[180];
                    mid_3[3] = CAL_image_ff[194];
                    mid_3[4] = CAL_image_ff[195];
                    mid_3[5] = CAL_image_ff[196];
                    mid_3[6] = CAL_image_ff[210];
                    mid_3[7] = CAL_image_ff[211];
                    mid_3[8] = CAL_image_ff[212];
                    mid_4[0] = CAL_image_ff[179];
                    mid_4[1] = CAL_image_ff[180];
                    mid_4[2] = CAL_image_ff[181];
                    mid_4[3] = CAL_image_ff[195];
                    mid_4[4] = CAL_image_ff[196];
                    mid_4[5] = CAL_image_ff[197];
                    mid_4[6] = CAL_image_ff[211];
                    mid_4[7] = CAL_image_ff[212];
                    mid_4[8] = CAL_image_ff[213];
                    mid_5[0] = CAL_image_ff[180];
                    mid_5[1] = CAL_image_ff[181];
                    mid_5[2] = CAL_image_ff[182];
                    mid_5[3] = CAL_image_ff[196];
                    mid_5[4] = CAL_image_ff[197];
                    mid_5[5] = CAL_image_ff[198];
                    mid_5[6] = CAL_image_ff[212];
                    mid_5[7] = CAL_image_ff[213];
                    mid_5[8] = CAL_image_ff[214];
                    mid_6[0] = CAL_image_ff[181];
                    mid_6[1] = CAL_image_ff[182];
                    mid_6[2] = CAL_image_ff[183];
                    mid_6[3] = CAL_image_ff[197];
                    mid_6[4] = CAL_image_ff[198];
                    mid_6[5] = CAL_image_ff[199];
                    mid_6[6] = CAL_image_ff[213];
                    mid_6[7] = CAL_image_ff[214];
                    mid_6[8] = CAL_image_ff[215];
                    mid_7[0] = CAL_image_ff[182];
                    mid_7[1] = CAL_image_ff[183];
                    mid_7[2] = CAL_image_ff[184];
                    mid_7[3] = CAL_image_ff[198];
                    mid_7[4] = CAL_image_ff[199];
                    mid_7[5] = CAL_image_ff[200];
                    mid_7[6] = CAL_image_ff[214];
                    mid_7[7] = CAL_image_ff[215];
                    mid_7[8] = CAL_image_ff[216];
                    mid_8[0] = CAL_image_ff[183];
                    mid_8[1] = CAL_image_ff[184];
                    mid_8[2] = CAL_image_ff[185];
                    mid_8[3] = CAL_image_ff[199];
                    mid_8[4] = CAL_image_ff[200];
                    mid_8[5] = CAL_image_ff[201];
                    mid_8[6] = CAL_image_ff[215];
                    mid_8[7] = CAL_image_ff[216];
                    mid_8[8] = CAL_image_ff[217];
                    mid_9[0] = CAL_image_ff[184];
                    mid_9[1] = CAL_image_ff[185];
                    mid_9[2] = CAL_image_ff[186];
                    mid_9[3] = CAL_image_ff[200];
                    mid_9[4] = CAL_image_ff[201];
                    mid_9[5] = CAL_image_ff[202];
                    mid_9[6] = CAL_image_ff[216];
                    mid_9[7] = CAL_image_ff[217];
                    mid_9[8] = CAL_image_ff[218];
                    mid_10[0] = CAL_image_ff[185];
                    mid_10[1] = CAL_image_ff[186];
                    mid_10[2] = CAL_image_ff[187];
                    mid_10[3] = CAL_image_ff[201];
                    mid_10[4] = CAL_image_ff[202];
                    mid_10[5] = CAL_image_ff[203];
                    mid_10[6] = CAL_image_ff[217];
                    mid_10[7] = CAL_image_ff[218];
                    mid_10[8] = CAL_image_ff[219];
                    mid_11[0] = CAL_image_ff[186];
                    mid_11[1] = CAL_image_ff[187];
                    mid_11[2] = CAL_image_ff[188];
                    mid_11[3] = CAL_image_ff[202];
                    mid_11[4] = CAL_image_ff[203];
                    mid_11[5] = CAL_image_ff[204];
                    mid_11[6] = CAL_image_ff[218];
                    mid_11[7] = CAL_image_ff[219];
                    mid_11[8] = CAL_image_ff[220];
                    mid_12[0] = CAL_image_ff[187];
                    mid_12[1] = CAL_image_ff[188];
                    mid_12[2] = CAL_image_ff[189];
                    mid_12[3] = CAL_image_ff[203];
                    mid_12[4] = CAL_image_ff[204];
                    mid_12[5] = CAL_image_ff[205];
                    mid_12[6] = CAL_image_ff[219];
                    mid_12[7] = CAL_image_ff[220];
                    mid_12[8] = CAL_image_ff[221];
                    mid_13[0] = CAL_image_ff[188];
                    mid_13[1] = CAL_image_ff[189];
                    mid_13[2] = CAL_image_ff[190];
                    mid_13[3] = CAL_image_ff[204];
                    mid_13[4] = CAL_image_ff[205];
                    mid_13[5] = CAL_image_ff[206];
                    mid_13[6] = CAL_image_ff[220];
                    mid_13[7] = CAL_image_ff[221];
                    mid_13[8] = CAL_image_ff[222];
                    mid_14[0] = CAL_image_ff[189];
                    mid_14[1] = CAL_image_ff[190];
                    mid_14[2] = CAL_image_ff[191];
                    mid_14[3] = CAL_image_ff[205];
                    mid_14[4] = CAL_image_ff[206];
                    mid_14[5] = CAL_image_ff[207];
                    mid_14[6] = CAL_image_ff[221];
                    mid_14[7] = CAL_image_ff[222];
                    mid_14[8] = CAL_image_ff[223];
                    mid_15[0] = CAL_image_ff[190];
                    mid_15[1] = CAL_image_ff[191];
                    mid_15[2] = CAL_image_ff[191];
                    mid_15[3] = CAL_image_ff[206];
                    mid_15[4] = CAL_image_ff[207];
                    mid_15[5] = CAL_image_ff[207];
                    mid_15[6] = CAL_image_ff[222];
                    mid_15[7] = CAL_image_ff[223];
                    mid_15[8] = CAL_image_ff[223];
                end
                else if(clock_cnt == 'd12) begin
                    mid_0[0] = CAL_image_ff[192];
                    mid_0[1] = CAL_image_ff[192];
                    mid_0[2] = CAL_image_ff[193];
                    mid_0[3] = CAL_image_ff[208];
                    mid_0[4] = CAL_image_ff[208];
                    mid_0[5] = CAL_image_ff[209];
                    mid_0[6] = CAL_image_ff[224];
                    mid_0[7] = CAL_image_ff[224];
                    mid_0[8] = CAL_image_ff[225];
                    mid_1[0] = CAL_image_ff[192];
                    mid_1[1] = CAL_image_ff[193];
                    mid_1[2] = CAL_image_ff[194];
                    mid_1[3] = CAL_image_ff[208];
                    mid_1[4] = CAL_image_ff[209];
                    mid_1[5] = CAL_image_ff[210];
                    mid_1[6] = CAL_image_ff[224];
                    mid_1[7] = CAL_image_ff[225];
                    mid_1[8] = CAL_image_ff[226];
                    mid_2[0] = CAL_image_ff[193];
                    mid_2[1] = CAL_image_ff[194];
                    mid_2[2] = CAL_image_ff[195];
                    mid_2[3] = CAL_image_ff[209];
                    mid_2[4] = CAL_image_ff[210];
                    mid_2[5] = CAL_image_ff[211];
                    mid_2[6] = CAL_image_ff[225];
                    mid_2[7] = CAL_image_ff[226];
                    mid_2[8] = CAL_image_ff[227];
                    mid_3[0] = CAL_image_ff[194];
                    mid_3[1] = CAL_image_ff[195];
                    mid_3[2] = CAL_image_ff[196];
                    mid_3[3] = CAL_image_ff[210];
                    mid_3[4] = CAL_image_ff[211];
                    mid_3[5] = CAL_image_ff[212];
                    mid_3[6] = CAL_image_ff[226];
                    mid_3[7] = CAL_image_ff[227];
                    mid_3[8] = CAL_image_ff[228];
                    mid_4[0] = CAL_image_ff[195];
                    mid_4[1] = CAL_image_ff[196];
                    mid_4[2] = CAL_image_ff[197];
                    mid_4[3] = CAL_image_ff[211];
                    mid_4[4] = CAL_image_ff[212];
                    mid_4[5] = CAL_image_ff[213];
                    mid_4[6] = CAL_image_ff[227];
                    mid_4[7] = CAL_image_ff[228];
                    mid_4[8] = CAL_image_ff[229];
                    mid_5[0] = CAL_image_ff[196];
                    mid_5[1] = CAL_image_ff[197];
                    mid_5[2] = CAL_image_ff[198];
                    mid_5[3] = CAL_image_ff[212];
                    mid_5[4] = CAL_image_ff[213];
                    mid_5[5] = CAL_image_ff[214];
                    mid_5[6] = CAL_image_ff[228];
                    mid_5[7] = CAL_image_ff[229];
                    mid_5[8] = CAL_image_ff[230];
                    mid_6[0] = CAL_image_ff[197];
                    mid_6[1] = CAL_image_ff[198];
                    mid_6[2] = CAL_image_ff[199];
                    mid_6[3] = CAL_image_ff[213];
                    mid_6[4] = CAL_image_ff[214];
                    mid_6[5] = CAL_image_ff[215];
                    mid_6[6] = CAL_image_ff[229];
                    mid_6[7] = CAL_image_ff[230];
                    mid_6[8] = CAL_image_ff[231];
                    mid_7[0] = CAL_image_ff[198];
                    mid_7[1] = CAL_image_ff[199];
                    mid_7[2] = CAL_image_ff[200];
                    mid_7[3] = CAL_image_ff[214];
                    mid_7[4] = CAL_image_ff[215];
                    mid_7[5] = CAL_image_ff[216];
                    mid_7[6] = CAL_image_ff[230];
                    mid_7[7] = CAL_image_ff[231];
                    mid_7[8] = CAL_image_ff[232];
                    mid_8[0] = CAL_image_ff[199];
                    mid_8[1] = CAL_image_ff[200];
                    mid_8[2] = CAL_image_ff[201];
                    mid_8[3] = CAL_image_ff[215];
                    mid_8[4] = CAL_image_ff[216];
                    mid_8[5] = CAL_image_ff[217];
                    mid_8[6] = CAL_image_ff[231];
                    mid_8[7] = CAL_image_ff[232];
                    mid_8[8] = CAL_image_ff[233];
                    mid_9[0] = CAL_image_ff[200];
                    mid_9[1] = CAL_image_ff[201];
                    mid_9[2] = CAL_image_ff[202];
                    mid_9[3] = CAL_image_ff[216];
                    mid_9[4] = CAL_image_ff[217];
                    mid_9[5] = CAL_image_ff[218];
                    mid_9[6] = CAL_image_ff[232];
                    mid_9[7] = CAL_image_ff[233];
                    mid_9[8] = CAL_image_ff[234];
                    mid_10[0] = CAL_image_ff[201];
                    mid_10[1] = CAL_image_ff[202];
                    mid_10[2] = CAL_image_ff[203];
                    mid_10[3] = CAL_image_ff[217];
                    mid_10[4] = CAL_image_ff[218];
                    mid_10[5] = CAL_image_ff[219];
                    mid_10[6] = CAL_image_ff[233];
                    mid_10[7] = CAL_image_ff[234];
                    mid_10[8] = CAL_image_ff[235];
                    mid_11[0] = CAL_image_ff[202];
                    mid_11[1] = CAL_image_ff[203];
                    mid_11[2] = CAL_image_ff[204];
                    mid_11[3] = CAL_image_ff[218];
                    mid_11[4] = CAL_image_ff[219];
                    mid_11[5] = CAL_image_ff[220];
                    mid_11[6] = CAL_image_ff[234];
                    mid_11[7] = CAL_image_ff[235];
                    mid_11[8] = CAL_image_ff[236];
                    mid_12[0] = CAL_image_ff[203];
                    mid_12[1] = CAL_image_ff[204];
                    mid_12[2] = CAL_image_ff[205];
                    mid_12[3] = CAL_image_ff[219];
                    mid_12[4] = CAL_image_ff[220];
                    mid_12[5] = CAL_image_ff[221];
                    mid_12[6] = CAL_image_ff[235];
                    mid_12[7] = CAL_image_ff[236];
                    mid_12[8] = CAL_image_ff[237];
                    mid_13[0] = CAL_image_ff[204];
                    mid_13[1] = CAL_image_ff[205];
                    mid_13[2] = CAL_image_ff[206];
                    mid_13[3] = CAL_image_ff[220];
                    mid_13[4] = CAL_image_ff[221];
                    mid_13[5] = CAL_image_ff[222];
                    mid_13[6] = CAL_image_ff[236];
                    mid_13[7] = CAL_image_ff[237];
                    mid_13[8] = CAL_image_ff[238];
                    mid_14[0] = CAL_image_ff[205];
                    mid_14[1] = CAL_image_ff[206];
                    mid_14[2] = CAL_image_ff[207];
                    mid_14[3] = CAL_image_ff[221];
                    mid_14[4] = CAL_image_ff[222];
                    mid_14[5] = CAL_image_ff[223];
                    mid_14[6] = CAL_image_ff[237];
                    mid_14[7] = CAL_image_ff[238];
                    mid_14[8] = CAL_image_ff[239];
                    mid_15[0] = CAL_image_ff[206];
                    mid_15[1] = CAL_image_ff[207];
                    mid_15[2] = CAL_image_ff[207];
                    mid_15[3] = CAL_image_ff[222];
                    mid_15[4] = CAL_image_ff[223];
                    mid_15[5] = CAL_image_ff[223];
                    mid_15[6] = CAL_image_ff[238];
                    mid_15[7] = CAL_image_ff[239];
                    mid_15[8] = CAL_image_ff[239];
                end
                else if(clock_cnt == 'd13) begin
                    mid_0[0] = CAL_image_ff[208];
                    mid_0[1] = CAL_image_ff[208];
                    mid_0[2] = CAL_image_ff[209];
                    mid_0[3] = CAL_image_ff[224];
                    mid_0[4] = CAL_image_ff[224];
                    mid_0[5] = CAL_image_ff[225];
                    mid_0[6] = CAL_image_ff[240];
                    mid_0[7] = CAL_image_ff[240];
                    mid_0[8] = CAL_image_ff[241];
                    mid_1[0] = CAL_image_ff[208];
                    mid_1[1] = CAL_image_ff[209];
                    mid_1[2] = CAL_image_ff[210];
                    mid_1[3] = CAL_image_ff[224];
                    mid_1[4] = CAL_image_ff[225];
                    mid_1[5] = CAL_image_ff[226];
                    mid_1[6] = CAL_image_ff[240];
                    mid_1[7] = CAL_image_ff[241];
                    mid_1[8] = CAL_image_ff[242];
                    mid_2[0] = CAL_image_ff[209];
                    mid_2[1] = CAL_image_ff[210];
                    mid_2[2] = CAL_image_ff[211];
                    mid_2[3] = CAL_image_ff[225];
                    mid_2[4] = CAL_image_ff[226];
                    mid_2[5] = CAL_image_ff[227];
                    mid_2[6] = CAL_image_ff[241];
                    mid_2[7] = CAL_image_ff[242];
                    mid_2[8] = CAL_image_ff[243];
                    mid_3[0] = CAL_image_ff[210];
                    mid_3[1] = CAL_image_ff[211];
                    mid_3[2] = CAL_image_ff[212];
                    mid_3[3] = CAL_image_ff[226];
                    mid_3[4] = CAL_image_ff[227];
                    mid_3[5] = CAL_image_ff[228];
                    mid_3[6] = CAL_image_ff[242];
                    mid_3[7] = CAL_image_ff[243];
                    mid_3[8] = CAL_image_ff[244];
                    mid_4[0] = CAL_image_ff[211];
                    mid_4[1] = CAL_image_ff[212];
                    mid_4[2] = CAL_image_ff[213];
                    mid_4[3] = CAL_image_ff[227];
                    mid_4[4] = CAL_image_ff[228];
                    mid_4[5] = CAL_image_ff[229];
                    mid_4[6] = CAL_image_ff[243];
                    mid_4[7] = CAL_image_ff[244];
                    mid_4[8] = CAL_image_ff[245];
                    mid_5[0] = CAL_image_ff[212];
                    mid_5[1] = CAL_image_ff[213];
                    mid_5[2] = CAL_image_ff[214];
                    mid_5[3] = CAL_image_ff[228];
                    mid_5[4] = CAL_image_ff[229];
                    mid_5[5] = CAL_image_ff[230];
                    mid_5[6] = CAL_image_ff[244];
                    mid_5[7] = CAL_image_ff[245];
                    mid_5[8] = CAL_image_ff[246];
                    mid_6[0] = CAL_image_ff[213];
                    mid_6[1] = CAL_image_ff[214];
                    mid_6[2] = CAL_image_ff[215];
                    mid_6[3] = CAL_image_ff[229];
                    mid_6[4] = CAL_image_ff[230];
                    mid_6[5] = CAL_image_ff[231];
                    mid_6[6] = CAL_image_ff[245];
                    mid_6[7] = CAL_image_ff[246];
                    mid_6[8] = CAL_image_ff[247];
                    mid_7[0] = CAL_image_ff[214];
                    mid_7[1] = CAL_image_ff[215];
                    mid_7[2] = CAL_image_ff[216];
                    mid_7[3] = CAL_image_ff[230];
                    mid_7[4] = CAL_image_ff[231];
                    mid_7[5] = CAL_image_ff[232];
                    mid_7[6] = CAL_image_ff[246];
                    mid_7[7] = CAL_image_ff[247];
                    mid_7[8] = CAL_image_ff[248];
                    mid_8[0] = CAL_image_ff[215];
                    mid_8[1] = CAL_image_ff[216];
                    mid_8[2] = CAL_image_ff[217];
                    mid_8[3] = CAL_image_ff[231];
                    mid_8[4] = CAL_image_ff[232];
                    mid_8[5] = CAL_image_ff[233];
                    mid_8[6] = CAL_image_ff[247];
                    mid_8[7] = CAL_image_ff[248];
                    mid_8[8] = CAL_image_ff[249];
                    mid_9[0] = CAL_image_ff[216];
                    mid_9[1] = CAL_image_ff[217];
                    mid_9[2] = CAL_image_ff[218];
                    mid_9[3] = CAL_image_ff[232];
                    mid_9[4] = CAL_image_ff[233];
                    mid_9[5] = CAL_image_ff[234];
                    mid_9[6] = CAL_image_ff[248];
                    mid_9[7] = CAL_image_ff[249];
                    mid_9[8] = CAL_image_ff[250];
                    mid_10[0] = CAL_image_ff[217];
                    mid_10[1] = CAL_image_ff[218];
                    mid_10[2] = CAL_image_ff[219];
                    mid_10[3] = CAL_image_ff[233];
                    mid_10[4] = CAL_image_ff[234];
                    mid_10[5] = CAL_image_ff[235];
                    mid_10[6] = CAL_image_ff[249];
                    mid_10[7] = CAL_image_ff[250];
                    mid_10[8] = CAL_image_ff[251];
                    mid_11[0] = CAL_image_ff[218];
                    mid_11[1] = CAL_image_ff[219];
                    mid_11[2] = CAL_image_ff[220];
                    mid_11[3] = CAL_image_ff[234];
                    mid_11[4] = CAL_image_ff[235];
                    mid_11[5] = CAL_image_ff[236];
                    mid_11[6] = CAL_image_ff[250];
                    mid_11[7] = CAL_image_ff[251];
                    mid_11[8] = CAL_image_ff[252];
                    mid_12[0] = CAL_image_ff[219];
                    mid_12[1] = CAL_image_ff[220];
                    mid_12[2] = CAL_image_ff[221];
                    mid_12[3] = CAL_image_ff[235];
                    mid_12[4] = CAL_image_ff[236];
                    mid_12[5] = CAL_image_ff[237];
                    mid_12[6] = CAL_image_ff[251];
                    mid_12[7] = CAL_image_ff[252];
                    mid_12[8] = CAL_image_ff[253];
                    mid_13[0] = CAL_image_ff[220];
                    mid_13[1] = CAL_image_ff[221];
                    mid_13[2] = CAL_image_ff[222];
                    mid_13[3] = CAL_image_ff[236];
                    mid_13[4] = CAL_image_ff[237];
                    mid_13[5] = CAL_image_ff[238];
                    mid_13[6] = CAL_image_ff[252];
                    mid_13[7] = CAL_image_ff[253];
                    mid_13[8] = CAL_image_ff[254];
                    mid_14[0] = CAL_image_ff[221];
                    mid_14[1] = CAL_image_ff[222];
                    mid_14[2] = CAL_image_ff[223];
                    mid_14[3] = CAL_image_ff[237];
                    mid_14[4] = CAL_image_ff[238];
                    mid_14[5] = CAL_image_ff[239];
                    mid_14[6] = CAL_image_ff[253];
                    mid_14[7] = CAL_image_ff[254];
                    mid_14[8] = CAL_image_ff[255];
                    mid_15[0] = CAL_image_ff[222];
                    mid_15[1] = CAL_image_ff[223];
                    mid_15[2] = CAL_image_ff[223];
                    mid_15[3] = CAL_image_ff[238];
                    mid_15[4] = CAL_image_ff[239];
                    mid_15[5] = CAL_image_ff[239];
                    mid_15[6] = CAL_image_ff[254];
                    mid_15[7] = CAL_image_ff[255];
                    mid_15[8] = CAL_image_ff[255];
                end
                else if(clock_cnt == 'd14) begin
                    mid_0[0] = CAL_image_ff[224];
                    mid_0[1] = CAL_image_ff[224];
                    mid_0[2] = CAL_image_ff[225];
                    mid_0[3] = CAL_image_ff[240];
                    mid_0[4] = CAL_image_ff[240];
                    mid_0[5] = CAL_image_ff[241];
                    mid_0[6] = CAL_image_ff[240];
                    mid_0[7] = CAL_image_ff[240];
                    mid_0[8] = CAL_image_ff[241];
                    mid_1[0] = CAL_image_ff[224];
                    mid_1[1] = CAL_image_ff[225];
                    mid_1[2] = CAL_image_ff[226];
                    mid_1[3] = CAL_image_ff[240];
                    mid_1[4] = CAL_image_ff[241];
                    mid_1[5] = CAL_image_ff[242];
                    mid_1[6] = CAL_image_ff[240];
                    mid_1[7] = CAL_image_ff[241];
                    mid_1[8] = CAL_image_ff[242];
                    mid_2[0] = CAL_image_ff[225];
                    mid_2[1] = CAL_image_ff[226];
                    mid_2[2] = CAL_image_ff[227];
                    mid_2[3] = CAL_image_ff[241];
                    mid_2[4] = CAL_image_ff[242];
                    mid_2[5] = CAL_image_ff[243];
                    mid_2[6] = CAL_image_ff[241];
                    mid_2[7] = CAL_image_ff[242];
                    mid_2[8] = CAL_image_ff[243];
                    mid_3[0] = CAL_image_ff[226];
                    mid_3[1] = CAL_image_ff[227];
                    mid_3[2] = CAL_image_ff[228];
                    mid_3[3] = CAL_image_ff[242];
                    mid_3[4] = CAL_image_ff[243];
                    mid_3[5] = CAL_image_ff[244];
                    mid_3[6] = CAL_image_ff[242];
                    mid_3[7] = CAL_image_ff[243];
                    mid_3[8] = CAL_image_ff[244];
                    mid_4[0] = CAL_image_ff[227];
                    mid_4[1] = CAL_image_ff[228];
                    mid_4[2] = CAL_image_ff[229];
                    mid_4[3] = CAL_image_ff[243];
                    mid_4[4] = CAL_image_ff[244];
                    mid_4[5] = CAL_image_ff[245];
                    mid_4[6] = CAL_image_ff[243];
                    mid_4[7] = CAL_image_ff[244];
                    mid_4[8] = CAL_image_ff[245];
                    mid_5[0] = CAL_image_ff[228];
                    mid_5[1] = CAL_image_ff[229];
                    mid_5[2] = CAL_image_ff[230];
                    mid_5[3] = CAL_image_ff[244];
                    mid_5[4] = CAL_image_ff[245];
                    mid_5[5] = CAL_image_ff[246];
                    mid_5[6] = CAL_image_ff[244];
                    mid_5[7] = CAL_image_ff[245];
                    mid_5[8] = CAL_image_ff[246];
                    mid_6[0] = CAL_image_ff[229];
                    mid_6[1] = CAL_image_ff[230];
                    mid_6[2] = CAL_image_ff[231];
                    mid_6[3] = CAL_image_ff[245];
                    mid_6[4] = CAL_image_ff[246];
                    mid_6[5] = CAL_image_ff[247];
                    mid_6[6] = CAL_image_ff[245];
                    mid_6[7] = CAL_image_ff[246];
                    mid_6[8] = CAL_image_ff[247];
                    mid_7[0] = CAL_image_ff[230];
                    mid_7[1] = CAL_image_ff[231];
                    mid_7[2] = CAL_image_ff[232];
                    mid_7[3] = CAL_image_ff[246];
                    mid_7[4] = CAL_image_ff[247];
                    mid_7[5] = CAL_image_ff[248];
                    mid_7[6] = CAL_image_ff[246];
                    mid_7[7] = CAL_image_ff[247];
                    mid_7[8] = CAL_image_ff[248];
                    mid_8[0] = CAL_image_ff[231];
                    mid_8[1] = CAL_image_ff[232];
                    mid_8[2] = CAL_image_ff[233];
                    mid_8[3] = CAL_image_ff[247];
                    mid_8[4] = CAL_image_ff[248];
                    mid_8[5] = CAL_image_ff[249];
                    mid_8[6] = CAL_image_ff[247];
                    mid_8[7] = CAL_image_ff[248];
                    mid_8[8] = CAL_image_ff[249];
                    mid_9[0] = CAL_image_ff[232];
                    mid_9[1] = CAL_image_ff[233];
                    mid_9[2] = CAL_image_ff[234];
                    mid_9[3] = CAL_image_ff[248];
                    mid_9[4] = CAL_image_ff[249];
                    mid_9[5] = CAL_image_ff[250];
                    mid_9[6] = CAL_image_ff[248];
                    mid_9[7] = CAL_image_ff[249];
                    mid_9[8] = CAL_image_ff[250];
                    mid_10[0] = CAL_image_ff[233];
                    mid_10[1] = CAL_image_ff[234];
                    mid_10[2] = CAL_image_ff[235];
                    mid_10[3] = CAL_image_ff[249];
                    mid_10[4] = CAL_image_ff[250];
                    mid_10[5] = CAL_image_ff[251];
                    mid_10[6] = CAL_image_ff[249];
                    mid_10[7] = CAL_image_ff[250];
                    mid_10[8] = CAL_image_ff[251];
                    mid_11[0] = CAL_image_ff[234];
                    mid_11[1] = CAL_image_ff[235];
                    mid_11[2] = CAL_image_ff[236];
                    mid_11[3] = CAL_image_ff[250];
                    mid_11[4] = CAL_image_ff[251];
                    mid_11[5] = CAL_image_ff[252];
                    mid_11[6] = CAL_image_ff[250];
                    mid_11[7] = CAL_image_ff[251];
                    mid_11[8] = CAL_image_ff[252];
                    mid_12[0] = CAL_image_ff[235];
                    mid_12[1] = CAL_image_ff[236];
                    mid_12[2] = CAL_image_ff[237];
                    mid_12[3] = CAL_image_ff[251];
                    mid_12[4] = CAL_image_ff[252];
                    mid_12[5] = CAL_image_ff[253];
                    mid_12[6] = CAL_image_ff[251];
                    mid_12[7] = CAL_image_ff[252];
                    mid_12[8] = CAL_image_ff[253];
                    mid_13[0] = CAL_image_ff[236];
                    mid_13[1] = CAL_image_ff[237];
                    mid_13[2] = CAL_image_ff[238];
                    mid_13[3] = CAL_image_ff[252];
                    mid_13[4] = CAL_image_ff[253];
                    mid_13[5] = CAL_image_ff[254];
                    mid_13[6] = CAL_image_ff[252];
                    mid_13[7] = CAL_image_ff[253];
                    mid_13[8] = CAL_image_ff[254];
                    mid_14[0] = CAL_image_ff[237];
                    mid_14[1] = CAL_image_ff[238];
                    mid_14[2] = CAL_image_ff[239];
                    mid_14[3] = CAL_image_ff[253];
                    mid_14[4] = CAL_image_ff[254];
                    mid_14[5] = CAL_image_ff[255];
                    mid_14[6] = CAL_image_ff[253];
                    mid_14[7] = CAL_image_ff[254];
                    mid_14[8] = CAL_image_ff[255];
                    mid_15[0] = CAL_image_ff[238];
                    mid_15[1] = CAL_image_ff[239];
                    mid_15[2] = CAL_image_ff[239];
                    mid_15[3] = CAL_image_ff[254];
                    mid_15[4] = CAL_image_ff[255];
                    mid_15[5] = CAL_image_ff[255];
                    mid_15[6] = CAL_image_ff[254];
                    mid_15[7] = CAL_image_ff[255];
                    mid_15[8] = CAL_image_ff[255];
                end
                else begin
                    for( i = 0 ; i < 9 ; i = i + 1) begin
                        mid_0[i] = 0;
                        mid_1[i] = 0;
                        mid_2[i] = 0;
                        mid_3[i] = 0;
                        mid_4[i] = 0;
                        mid_5[i] = 0;
                        mid_6[i] = 0;
                        mid_7[i] = 0;
                        mid_8[i] = 0;
                        mid_9[i] = 0;
                        mid_10[i] = 0;
                        mid_11[i] = 0;
                        mid_12[i] = 0;
                        mid_13[i] = 0;
                        mid_14[i] = 0;
                        mid_15[i] = 0;
                    end
                end
            end
            default: begin
                for( i = 0 ; i < 9 ; i = i + 1) begin
                    mid_0[i] = 0;
                    mid_1[i] = 0;
                    mid_2[i] = 0;
                    mid_3[i] = 0;
                    mid_4[i] = 0;
                    mid_5[i] = 0;
                    mid_6[i] = 0;
                    mid_7[i] = 0;
                    mid_8[i] = 0;
                    mid_9[i] = 0;
                    mid_10[i] = 0;
                    mid_11[i] = 0;
                    mid_12[i] = 0;
                    mid_13[i] = 0;
                    mid_14[i] = 0;
                    mid_15[i] = 0;
                end
            end
        endcase
    end
    else begin
        for( i = 0 ; i < 9 ; i = i + 1) begin
            mid_0[i] = 0;
            mid_1[i] = 0;
            mid_2[i] = 0;
            mid_3[i] = 0;
            mid_4[i] = 0;
            mid_5[i] = 0;
            mid_6[i] = 0;
            mid_7[i] = 0;
            mid_8[i] = 0;
            mid_9[i] = 0;
            mid_10[i] = 0;
            mid_11[i] = 0;
            mid_12[i] = 0;
            mid_13[i] = 0;
            mid_14[i] = 0;
            mid_15[i] = 0;
        end
    end
end


always @(*) begin
    if(current_state == CROSS_CORELATION) begin
        case(curr_image_size)
            2'd0: begin
                case(ouput_index)
                    0: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[0];
                        mul[5] = CAL_image_ff[1];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[4];
                        mul[8] = CAL_image_ff[5]; 
                    end
                    1: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[0];
                        mul[4] = CAL_image_ff[1];
                        mul[5] = CAL_image_ff[2];
                        mul[6] = CAL_image_ff[4];
                        mul[7] = CAL_image_ff[5];
                        mul[8] = CAL_image_ff[6];
                    end
                    2: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[1];
                        mul[4] = CAL_image_ff[2];
                        mul[5] = CAL_image_ff[3];
                        mul[6] = CAL_image_ff[5];
                        mul[7] = CAL_image_ff[6];
                        mul[8] = CAL_image_ff[7];
                    end
                    3: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[2];
                        mul[4] = CAL_image_ff[3];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[6];
                        mul[7] = CAL_image_ff[7];
                        mul[8] = 'd0;
                    end
                    4: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[0];
                        mul[2] = CAL_image_ff[1];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[4];
                        mul[5] = CAL_image_ff[5];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[8];
                        mul[8] = CAL_image_ff[9];
                    end
                    5: begin
                        mul[0] = CAL_image_ff[0];
                        mul[1] = CAL_image_ff[1];
                        mul[2] = CAL_image_ff[2];
                        mul[3] = CAL_image_ff[4];
                        mul[4] = CAL_image_ff[5];
                        mul[5] = CAL_image_ff[6];
                        mul[6] = CAL_image_ff[8];
                        mul[7] = CAL_image_ff[9];
                        mul[8] = CAL_image_ff[10];
                    end
                    6: begin
                        mul[0] = CAL_image_ff[1];
                        mul[1] = CAL_image_ff[2];
                        mul[2] = CAL_image_ff[3];
                        mul[3] = CAL_image_ff[5];
                        mul[4] = CAL_image_ff[6];
                        mul[5] = CAL_image_ff[7];
                        mul[6] = CAL_image_ff[9];
                        mul[7] = CAL_image_ff[10];
                        mul[8] = CAL_image_ff[11];
                    end
                    7: begin
                        mul[0] = CAL_image_ff[2];
                        mul[1] = CAL_image_ff[3];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[6];
                        mul[4] = CAL_image_ff[7];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[10];
                        mul[7] = CAL_image_ff[11];
                        mul[8] = 'd0;
                    end
                    8: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[4];
                        mul[2] = CAL_image_ff[5];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[8];
                        mul[5] = CAL_image_ff[9];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[12];
                        mul[8] = CAL_image_ff[13];
                    end
                    9: begin
                        mul[0] = CAL_image_ff[4];
                        mul[1] = CAL_image_ff[5];
                        mul[2] = CAL_image_ff[6];
                        mul[3] = CAL_image_ff[8];
                        mul[4] = CAL_image_ff[9];
                        mul[5] = CAL_image_ff[10];
                        mul[6] = CAL_image_ff[12];
                        mul[7] = CAL_image_ff[13];
                        mul[8] = CAL_image_ff[14];
                    end
                    10: begin
                        mul[0] = CAL_image_ff[5];
                        mul[1] = CAL_image_ff[6];
                        mul[2] = CAL_image_ff[7];
                        mul[3] = CAL_image_ff[9];
                        mul[4] = CAL_image_ff[10];
                        mul[5] = CAL_image_ff[11];
                        mul[6] = CAL_image_ff[13];
                        mul[7] = CAL_image_ff[14];
                        mul[8] = CAL_image_ff[15];
                    end
                    11: begin
                        mul[0] = CAL_image_ff[6];
                        mul[1] = CAL_image_ff[7];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[10];
                        mul[4] = CAL_image_ff[11];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[14];
                        mul[7] = CAL_image_ff[15];
                        mul[8] = 'd0;
                    end
                    12: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[8];
                        mul[2] = CAL_image_ff[9];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[12];
                        mul[5] = CAL_image_ff[13];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    13: begin
                        mul[0] = CAL_image_ff[8];
                        mul[1] = CAL_image_ff[9];
                        mul[2] = CAL_image_ff[10];
                        mul[3] = CAL_image_ff[12];
                        mul[4] = CAL_image_ff[13];
                        mul[5] = CAL_image_ff[14];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    14: begin
                        mul[0] = CAL_image_ff[9];
                        mul[1] = CAL_image_ff[10];
                        mul[2] = CAL_image_ff[11];
                        mul[3] = CAL_image_ff[13];
                        mul[4] = CAL_image_ff[14];
                        mul[5] = CAL_image_ff[15];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    15: begin
                        mul[0] = CAL_image_ff[10];
                        mul[1] = CAL_image_ff[11];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[14];
                        mul[4] = CAL_image_ff[15];
                        mul[5] = 'd0;
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    default: begin
                        for (i = 0; i < 9 ; i = i + 1) begin
                           mul[i] = 'd0;
                        end
                    end
                endcase
            end
            2'd1: begin
                case(ouput_index)
                    0: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[0];
                        mul[5] = CAL_image_ff[1];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[8];
                        mul[8] = CAL_image_ff[9];
                    end
                    1: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[0];
                        mul[4] = CAL_image_ff[1];
                        mul[5] = CAL_image_ff[2];
                        mul[6] = CAL_image_ff[8];
                        mul[7] = CAL_image_ff[9];
                        mul[8] = CAL_image_ff[10];
                    end
                    2: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[1];
                        mul[4] = CAL_image_ff[2];
                        mul[5] = CAL_image_ff[3];
                        mul[6] = CAL_image_ff[9];
                        mul[7] = CAL_image_ff[10];
                        mul[8] = CAL_image_ff[11];
                    end
                    3: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[2];
                        mul[4] = CAL_image_ff[3];
                        mul[5] = CAL_image_ff[4];
                        mul[6] = CAL_image_ff[10];
                        mul[7] = CAL_image_ff[11];
                        mul[8] = CAL_image_ff[12];
                    end
                    4: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[3];
                        mul[4] = CAL_image_ff[4];
                        mul[5] = CAL_image_ff[5];
                        mul[6] = CAL_image_ff[11];
                        mul[7] = CAL_image_ff[12];
                        mul[8] = CAL_image_ff[13];
                    end
                    5: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[4];
                        mul[4] = CAL_image_ff[5];
                        mul[5] = CAL_image_ff[6];
                        mul[6] = CAL_image_ff[12];
                        mul[7] = CAL_image_ff[13];
                        mul[8] = CAL_image_ff[14];
                    end
                    6: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[5];
                        mul[4] = CAL_image_ff[6];
                        mul[5] = CAL_image_ff[7];
                        mul[6] = CAL_image_ff[13];
                        mul[7] = CAL_image_ff[14];
                        mul[8] = CAL_image_ff[15];
                    end
                    7: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[6];
                        mul[4] = CAL_image_ff[7];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[14];
                        mul[7] = CAL_image_ff[15];
                        mul[8] = 'd0;
                    end
                    8: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[0];
                        mul[2] = CAL_image_ff[1];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[8];
                        mul[5] = CAL_image_ff[9];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[16];
                        mul[8] = CAL_image_ff[17];
                    end
                    9: begin
                        mul[0] = CAL_image_ff[0];
                        mul[1] = CAL_image_ff[1];
                        mul[2] = CAL_image_ff[2];
                        mul[3] = CAL_image_ff[8];
                        mul[4] = CAL_image_ff[9];
                        mul[5] = CAL_image_ff[10];
                        mul[6] = CAL_image_ff[16];
                        mul[7] = CAL_image_ff[17];
                        mul[8] = CAL_image_ff[18];
                    end
                    10: begin
                        mul[0] = CAL_image_ff[1];
                        mul[1] = CAL_image_ff[2];
                        mul[2] = CAL_image_ff[3];
                        mul[3] = CAL_image_ff[9];
                        mul[4] = CAL_image_ff[10];
                        mul[5] = CAL_image_ff[11];
                        mul[6] = CAL_image_ff[17];
                        mul[7] = CAL_image_ff[18];
                        mul[8] = CAL_image_ff[19];
                    end
                    11: begin
                        mul[0] = CAL_image_ff[2];
                        mul[1] = CAL_image_ff[3];
                        mul[2] = CAL_image_ff[4];
                        mul[3] = CAL_image_ff[10];
                        mul[4] = CAL_image_ff[11];
                        mul[5] = CAL_image_ff[12];
                        mul[6] = CAL_image_ff[18];
                        mul[7] = CAL_image_ff[19];
                        mul[8] = CAL_image_ff[20];
                    end
                    12: begin
                        mul[0] = CAL_image_ff[3];
                        mul[1] = CAL_image_ff[4];
                        mul[2] = CAL_image_ff[5];
                        mul[3] = CAL_image_ff[11];
                        mul[4] = CAL_image_ff[12];
                        mul[5] = CAL_image_ff[13];
                        mul[6] = CAL_image_ff[19];
                        mul[7] = CAL_image_ff[20];
                        mul[8] = CAL_image_ff[21];
                    end
                    13: begin
                        mul[0] = CAL_image_ff[4];
                        mul[1] = CAL_image_ff[5];
                        mul[2] = CAL_image_ff[6];
                        mul[3] = CAL_image_ff[12];
                        mul[4] = CAL_image_ff[13];
                        mul[5] = CAL_image_ff[14];
                        mul[6] = CAL_image_ff[20];
                        mul[7] = CAL_image_ff[21];
                        mul[8] = CAL_image_ff[22];
                    end
                    14: begin
                        mul[0] = CAL_image_ff[5];
                        mul[1] = CAL_image_ff[6];
                        mul[2] = CAL_image_ff[7];
                        mul[3] = CAL_image_ff[13];
                        mul[4] = CAL_image_ff[14];
                        mul[5] = CAL_image_ff[15];
                        mul[6] = CAL_image_ff[21];
                        mul[7] = CAL_image_ff[22];
                        mul[8] = CAL_image_ff[23];
                    end
                    15: begin
                        mul[0] = CAL_image_ff[6];
                        mul[1] = CAL_image_ff[7];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[14];
                        mul[4] = CAL_image_ff[15];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[22];
                        mul[7] = CAL_image_ff[23];
                        mul[8] = 'd0;
                    end
                    16: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[8];
                        mul[2] = CAL_image_ff[9];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[16];
                        mul[5] = CAL_image_ff[17];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[24];
                        mul[8] = CAL_image_ff[25];
                    end
                    17: begin
                        mul[0] = CAL_image_ff[8];
                        mul[1] = CAL_image_ff[9];
                        mul[2] = CAL_image_ff[10];
                        mul[3] = CAL_image_ff[16];
                        mul[4] = CAL_image_ff[17];
                        mul[5] = CAL_image_ff[18];
                        mul[6] = CAL_image_ff[24];
                        mul[7] = CAL_image_ff[25];
                        mul[8] = CAL_image_ff[26];
                    end
                    18: begin
                        mul[0] = CAL_image_ff[9];
                        mul[1] = CAL_image_ff[10];
                        mul[2] = CAL_image_ff[11];
                        mul[3] = CAL_image_ff[17];
                        mul[4] = CAL_image_ff[18];
                        mul[5] = CAL_image_ff[19];
                        mul[6] = CAL_image_ff[25];
                        mul[7] = CAL_image_ff[26];
                        mul[8] = CAL_image_ff[27];
                    end
                    19: begin
                        mul[0] = CAL_image_ff[10];
                        mul[1] = CAL_image_ff[11];
                        mul[2] = CAL_image_ff[12];
                        mul[3] = CAL_image_ff[18];
                        mul[4] = CAL_image_ff[19];
                        mul[5] = CAL_image_ff[20];
                        mul[6] = CAL_image_ff[26];
                        mul[7] = CAL_image_ff[27];
                        mul[8] = CAL_image_ff[28];
                    end
                    20: begin
                        mul[0] = CAL_image_ff[11];
                        mul[1] = CAL_image_ff[12];
                        mul[2] = CAL_image_ff[13];
                        mul[3] = CAL_image_ff[19];
                        mul[4] = CAL_image_ff[20];
                        mul[5] = CAL_image_ff[21];
                        mul[6] = CAL_image_ff[27];
                        mul[7] = CAL_image_ff[28];
                        mul[8] = CAL_image_ff[29];
                    end
                    21: begin
                        mul[0] = CAL_image_ff[12];
                        mul[1] = CAL_image_ff[13];
                        mul[2] = CAL_image_ff[14];
                        mul[3] = CAL_image_ff[20];
                        mul[4] = CAL_image_ff[21];
                        mul[5] = CAL_image_ff[22];
                        mul[6] = CAL_image_ff[28];
                        mul[7] = CAL_image_ff[29];
                        mul[8] = CAL_image_ff[30];
                    end
                    22: begin
                        mul[0] = CAL_image_ff[13];
                        mul[1] = CAL_image_ff[14];
                        mul[2] = CAL_image_ff[15];
                        mul[3] = CAL_image_ff[21];
                        mul[4] = CAL_image_ff[22];
                        mul[5] = CAL_image_ff[23];
                        mul[6] = CAL_image_ff[29];
                        mul[7] = CAL_image_ff[30];
                        mul[8] = CAL_image_ff[31];
                    end
                    23: begin
                        mul[0] = CAL_image_ff[14];
                        mul[1] = CAL_image_ff[15];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[22];
                        mul[4] = CAL_image_ff[23];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[30];
                        mul[7] = CAL_image_ff[31];
                        mul[8] = 'd0;
                    end
                    24: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[16];
                        mul[2] = CAL_image_ff[17];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[24];
                        mul[5] = CAL_image_ff[25];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[32];
                        mul[8] = CAL_image_ff[33];
                    end
                    25: begin
                        mul[0] = CAL_image_ff[16];
                        mul[1] = CAL_image_ff[17];
                        mul[2] = CAL_image_ff[18];
                        mul[3] = CAL_image_ff[24];
                        mul[4] = CAL_image_ff[25];
                        mul[5] = CAL_image_ff[26];
                        mul[6] = CAL_image_ff[32];
                        mul[7] = CAL_image_ff[33];
                        mul[8] = CAL_image_ff[34];
                    end
                    26: begin
                        mul[0] = CAL_image_ff[17];
                        mul[1] = CAL_image_ff[18];
                        mul[2] = CAL_image_ff[19];
                        mul[3] = CAL_image_ff[25];
                        mul[4] = CAL_image_ff[26];
                        mul[5] = CAL_image_ff[27];
                        mul[6] = CAL_image_ff[33];
                        mul[7] = CAL_image_ff[34];
                        mul[8] = CAL_image_ff[35];
                    end
                    27: begin
                        mul[0] = CAL_image_ff[18];
                        mul[1] = CAL_image_ff[19];
                        mul[2] = CAL_image_ff[20];
                        mul[3] = CAL_image_ff[26];
                        mul[4] = CAL_image_ff[27];
                        mul[5] = CAL_image_ff[28];
                        mul[6] = CAL_image_ff[34];
                        mul[7] = CAL_image_ff[35];
                        mul[8] = CAL_image_ff[36];
                    end
                    28: begin
                        mul[0] = CAL_image_ff[19];
                        mul[1] = CAL_image_ff[20];
                        mul[2] = CAL_image_ff[21];
                        mul[3] = CAL_image_ff[27];
                        mul[4] = CAL_image_ff[28];
                        mul[5] = CAL_image_ff[29];
                        mul[6] = CAL_image_ff[35];
                        mul[7] = CAL_image_ff[36];
                        mul[8] = CAL_image_ff[37];
                    end
                    29: begin
                        mul[0] = CAL_image_ff[20];
                        mul[1] = CAL_image_ff[21];
                        mul[2] = CAL_image_ff[22];
                        mul[3] = CAL_image_ff[28];
                        mul[4] = CAL_image_ff[29];
                        mul[5] = CAL_image_ff[30];
                        mul[6] = CAL_image_ff[36];
                        mul[7] = CAL_image_ff[37];
                        mul[8] = CAL_image_ff[38];
                    end
                    30: begin
                        mul[0] = CAL_image_ff[21];
                        mul[1] = CAL_image_ff[22];
                        mul[2] = CAL_image_ff[23];
                        mul[3] = CAL_image_ff[29];
                        mul[4] = CAL_image_ff[30];
                        mul[5] = CAL_image_ff[31];
                        mul[6] = CAL_image_ff[37];
                        mul[7] = CAL_image_ff[38];
                        mul[8] = CAL_image_ff[39];
                    end
                    31: begin
                        mul[0] = CAL_image_ff[22];
                        mul[1] = CAL_image_ff[23];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[30];
                        mul[4] = CAL_image_ff[31];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[38];
                        mul[7] = CAL_image_ff[39];
                        mul[8] = 'd0;
                    end
                    32: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[24];
                        mul[2] = CAL_image_ff[25];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[32];
                        mul[5] = CAL_image_ff[33];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[40];
                        mul[8] = CAL_image_ff[41];
                    end
                    33: begin
                        mul[0] = CAL_image_ff[24];
                        mul[1] = CAL_image_ff[25];
                        mul[2] = CAL_image_ff[26];
                        mul[3] = CAL_image_ff[32];
                        mul[4] = CAL_image_ff[33];
                        mul[5] = CAL_image_ff[34];
                        mul[6] = CAL_image_ff[40];
                        mul[7] = CAL_image_ff[41];
                        mul[8] = CAL_image_ff[42];
                    end
                    34: begin
                        mul[0] = CAL_image_ff[25];
                        mul[1] = CAL_image_ff[26];
                        mul[2] = CAL_image_ff[27];
                        mul[3] = CAL_image_ff[33];
                        mul[4] = CAL_image_ff[34];
                        mul[5] = CAL_image_ff[35];
                        mul[6] = CAL_image_ff[41];
                        mul[7] = CAL_image_ff[42];
                        mul[8] = CAL_image_ff[43];
                    end
                    35: begin
                        mul[0] = CAL_image_ff[26];
                        mul[1] = CAL_image_ff[27];
                        mul[2] = CAL_image_ff[28];
                        mul[3] = CAL_image_ff[34];
                        mul[4] = CAL_image_ff[35];
                        mul[5] = CAL_image_ff[36];
                        mul[6] = CAL_image_ff[42];
                        mul[7] = CAL_image_ff[43];
                        mul[8] = CAL_image_ff[44];
                    end
                    36: begin
                        mul[0] = CAL_image_ff[27];
                        mul[1] = CAL_image_ff[28];
                        mul[2] = CAL_image_ff[29];
                        mul[3] = CAL_image_ff[35];
                        mul[4] = CAL_image_ff[36];
                        mul[5] = CAL_image_ff[37];
                        mul[6] = CAL_image_ff[43];
                        mul[7] = CAL_image_ff[44];
                        mul[8] = CAL_image_ff[45];
                    end
                    37: begin
                        mul[0] = CAL_image_ff[28];
                        mul[1] = CAL_image_ff[29];
                        mul[2] = CAL_image_ff[30];
                        mul[3] = CAL_image_ff[36];
                        mul[4] = CAL_image_ff[37];
                        mul[5] = CAL_image_ff[38];
                        mul[6] = CAL_image_ff[44];
                        mul[7] = CAL_image_ff[45];
                        mul[8] = CAL_image_ff[46];
                    end
                    38: begin
                        mul[0] = CAL_image_ff[29];
                        mul[1] = CAL_image_ff[30];
                        mul[2] = CAL_image_ff[31];
                        mul[3] = CAL_image_ff[37];
                        mul[4] = CAL_image_ff[38];
                        mul[5] = CAL_image_ff[39];
                        mul[6] = CAL_image_ff[45];
                        mul[7] = CAL_image_ff[46];
                        mul[8] = CAL_image_ff[47];
                    end
                    39: begin
                        mul[0] = CAL_image_ff[30];
                        mul[1] = CAL_image_ff[31];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[38];
                        mul[4] = CAL_image_ff[39];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[46];
                        mul[7] = CAL_image_ff[47];
                        mul[8] = 'd0;
                    end
                    40: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[32];
                        mul[2] = CAL_image_ff[33];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[40];
                        mul[5] = CAL_image_ff[41];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[48];
                        mul[8] = CAL_image_ff[49];
                    end
                    41: begin
                        mul[0] = CAL_image_ff[32];
                        mul[1] = CAL_image_ff[33];
                        mul[2] = CAL_image_ff[34];
                        mul[3] = CAL_image_ff[40];
                        mul[4] = CAL_image_ff[41];
                        mul[5] = CAL_image_ff[42];
                        mul[6] = CAL_image_ff[48];
                        mul[7] = CAL_image_ff[49];
                        mul[8] = CAL_image_ff[50];
                    end
                    42: begin
                        mul[0] = CAL_image_ff[33];
                        mul[1] = CAL_image_ff[34];
                        mul[2] = CAL_image_ff[35];
                        mul[3] = CAL_image_ff[41];
                        mul[4] = CAL_image_ff[42];
                        mul[5] = CAL_image_ff[43];
                        mul[6] = CAL_image_ff[49];
                        mul[7] = CAL_image_ff[50];
                        mul[8] = CAL_image_ff[51];
                    end
                    43: begin
                        mul[0] = CAL_image_ff[34];
                        mul[1] = CAL_image_ff[35];
                        mul[2] = CAL_image_ff[36];
                        mul[3] = CAL_image_ff[42];
                        mul[4] = CAL_image_ff[43];
                        mul[5] = CAL_image_ff[44];
                        mul[6] = CAL_image_ff[50];
                        mul[7] = CAL_image_ff[51];
                        mul[8] = CAL_image_ff[52];
                    end
                    44: begin
                        mul[0] = CAL_image_ff[35];
                        mul[1] = CAL_image_ff[36];
                        mul[2] = CAL_image_ff[37];
                        mul[3] = CAL_image_ff[43];
                        mul[4] = CAL_image_ff[44];
                        mul[5] = CAL_image_ff[45];
                        mul[6] = CAL_image_ff[51];
                        mul[7] = CAL_image_ff[52];
                        mul[8] = CAL_image_ff[53];
                    end
                    45: begin
                        mul[0] = CAL_image_ff[36];
                        mul[1] = CAL_image_ff[37];
                        mul[2] = CAL_image_ff[38];
                        mul[3] = CAL_image_ff[44];
                        mul[4] = CAL_image_ff[45];
                        mul[5] = CAL_image_ff[46];
                        mul[6] = CAL_image_ff[52];
                        mul[7] = CAL_image_ff[53];
                        mul[8] = CAL_image_ff[54];
                    end
                    46: begin
                        mul[0] = CAL_image_ff[37];
                        mul[1] = CAL_image_ff[38];
                        mul[2] = CAL_image_ff[39];
                        mul[3] = CAL_image_ff[45];
                        mul[4] = CAL_image_ff[46];
                        mul[5] = CAL_image_ff[47];
                        mul[6] = CAL_image_ff[53];
                        mul[7] = CAL_image_ff[54];
                        mul[8] = CAL_image_ff[55];
                    end
                    47: begin
                        mul[0] = CAL_image_ff[38];
                        mul[1] = CAL_image_ff[39];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[46];
                        mul[4] = CAL_image_ff[47];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[54];
                        mul[7] = CAL_image_ff[55];
                        mul[8] = 'd0;
                    end
                    48: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[40];
                        mul[2] = CAL_image_ff[41];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[48];
                        mul[5] = CAL_image_ff[49];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[56];
                        mul[8] = CAL_image_ff[57];
                    end
                    49: begin
                        mul[0] = CAL_image_ff[40];
                        mul[1] = CAL_image_ff[41];
                        mul[2] = CAL_image_ff[42];
                        mul[3] = CAL_image_ff[48];
                        mul[4] = CAL_image_ff[49];
                        mul[5] = CAL_image_ff[50];
                        mul[6] = CAL_image_ff[56];
                        mul[7] = CAL_image_ff[57];
                        mul[8] = CAL_image_ff[58];
                    end
                    50: begin
                        mul[0] = CAL_image_ff[41];
                        mul[1] = CAL_image_ff[42];
                        mul[2] = CAL_image_ff[43];
                        mul[3] = CAL_image_ff[49];
                        mul[4] = CAL_image_ff[50];
                        mul[5] = CAL_image_ff[51];
                        mul[6] = CAL_image_ff[57];
                        mul[7] = CAL_image_ff[58];
                        mul[8] = CAL_image_ff[59];
                    end
                    51: begin
                        mul[0] = CAL_image_ff[42];
                        mul[1] = CAL_image_ff[43];
                        mul[2] = CAL_image_ff[44];
                        mul[3] = CAL_image_ff[50];
                        mul[4] = CAL_image_ff[51];
                        mul[5] = CAL_image_ff[52];
                        mul[6] = CAL_image_ff[58];
                        mul[7] = CAL_image_ff[59];
                        mul[8] = CAL_image_ff[60];
                    end
                    52: begin
                        mul[0] = CAL_image_ff[43];
                        mul[1] = CAL_image_ff[44];
                        mul[2] = CAL_image_ff[45];
                        mul[3] = CAL_image_ff[51];
                        mul[4] = CAL_image_ff[52];
                        mul[5] = CAL_image_ff[53];
                        mul[6] = CAL_image_ff[59];
                        mul[7] = CAL_image_ff[60];
                        mul[8] = CAL_image_ff[61];
                    end
                    53: begin
                        mul[0] = CAL_image_ff[44];
                        mul[1] = CAL_image_ff[45];
                        mul[2] = CAL_image_ff[46];
                        mul[3] = CAL_image_ff[52];
                        mul[4] = CAL_image_ff[53];
                        mul[5] = CAL_image_ff[54];
                        mul[6] = CAL_image_ff[60];
                        mul[7] = CAL_image_ff[61];
                        mul[8] = CAL_image_ff[62];
                    end
                    54: begin
                        mul[0] = CAL_image_ff[45];
                        mul[1] = CAL_image_ff[46];
                        mul[2] = CAL_image_ff[47];
                        mul[3] = CAL_image_ff[53];
                        mul[4] = CAL_image_ff[54];
                        mul[5] = CAL_image_ff[55];
                        mul[6] = CAL_image_ff[61];
                        mul[7] = CAL_image_ff[62];
                        mul[8] = CAL_image_ff[63];
                    end
                    55: begin
                        mul[0] = CAL_image_ff[46];
                        mul[1] = CAL_image_ff[47];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[54];
                        mul[4] = CAL_image_ff[55];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[62];
                        mul[7] = CAL_image_ff[63];
                        mul[8] = 'd0;
                    end
                    56: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[48];
                        mul[2] = CAL_image_ff[49];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[56];
                        mul[5] = CAL_image_ff[57];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    57: begin
                        mul[0] = CAL_image_ff[48];
                        mul[1] = CAL_image_ff[49];
                        mul[2] = CAL_image_ff[50];
                        mul[3] = CAL_image_ff[56];
                        mul[4] = CAL_image_ff[57];
                        mul[5] = CAL_image_ff[58];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    58: begin
                        mul[0] = CAL_image_ff[49];
                        mul[1] = CAL_image_ff[50];
                        mul[2] = CAL_image_ff[51];
                        mul[3] = CAL_image_ff[57];
                        mul[4] = CAL_image_ff[58];
                        mul[5] = CAL_image_ff[59];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    59: begin
                        mul[0] = CAL_image_ff[50];
                        mul[1] = CAL_image_ff[51];
                        mul[2] = CAL_image_ff[52];
                        mul[3] = CAL_image_ff[58];
                        mul[4] = CAL_image_ff[59];
                        mul[5] = CAL_image_ff[60];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    60: begin
                        mul[0] = CAL_image_ff[51];
                        mul[1] = CAL_image_ff[52];
                        mul[2] = CAL_image_ff[53];
                        mul[3] = CAL_image_ff[59];
                        mul[4] = CAL_image_ff[60];
                        mul[5] = CAL_image_ff[61];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    61: begin
                        mul[0] = CAL_image_ff[52];
                        mul[1] = CAL_image_ff[53];
                        mul[2] = CAL_image_ff[54];
                        mul[3] = CAL_image_ff[60];
                        mul[4] = CAL_image_ff[61];
                        mul[5] = CAL_image_ff[62];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    62: begin
                        mul[0] = CAL_image_ff[53];
                        mul[1] = CAL_image_ff[54];
                        mul[2] = CAL_image_ff[55];
                        mul[3] = CAL_image_ff[61];
                        mul[4] = CAL_image_ff[62];
                        mul[5] = CAL_image_ff[63];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    63: begin
                        mul[0] = CAL_image_ff[54];
                        mul[1] = CAL_image_ff[55];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[62];
                        mul[4] = CAL_image_ff[63];
                        mul[5] = 'd0;
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    default: begin
                        for (i = 0; i < 9 ; i = i + 1) begin
                           mul[i] = 'd0;
                        end
                    end
                endcase
            end
            2'd2: begin
                case(ouput_index)
                    0: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[0];
                        mul[5] = CAL_image_ff[1];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[16];
                        mul[8] = CAL_image_ff[17];
                    end
                    1: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[0];
                        mul[4] = CAL_image_ff[1];
                        mul[5] = CAL_image_ff[2];
                        mul[6] = CAL_image_ff[16];
                        mul[7] = CAL_image_ff[17];
                        mul[8] = CAL_image_ff[18];
                    end
                    2: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[1];
                        mul[4] = CAL_image_ff[2];
                        mul[5] = CAL_image_ff[3];
                        mul[6] = CAL_image_ff[17];
                        mul[7] = CAL_image_ff[18];
                        mul[8] = CAL_image_ff[19];
                    end
                    3: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[2];
                        mul[4] = CAL_image_ff[3];
                        mul[5] = CAL_image_ff[4];
                        mul[6] = CAL_image_ff[18];
                        mul[7] = CAL_image_ff[19];
                        mul[8] = CAL_image_ff[20];
                    end
                    4: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[3];
                        mul[4] = CAL_image_ff[4];
                        mul[5] = CAL_image_ff[5];
                        mul[6] = CAL_image_ff[19];
                        mul[7] = CAL_image_ff[20];
                        mul[8] = CAL_image_ff[21];
                    end
                    5: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[4];
                        mul[4] = CAL_image_ff[5];
                        mul[5] = CAL_image_ff[6];
                        mul[6] = CAL_image_ff[20];
                        mul[7] = CAL_image_ff[21];
                        mul[8] = CAL_image_ff[22];
                    end
                    6: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[5];
                        mul[4] = CAL_image_ff[6];
                        mul[5] = CAL_image_ff[7];
                        mul[6] = CAL_image_ff[21];
                        mul[7] = CAL_image_ff[22];
                        mul[8] = CAL_image_ff[23];
                    end
                    7: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[6];
                        mul[4] = CAL_image_ff[7];
                        mul[5] = CAL_image_ff[8];
                        mul[6] = CAL_image_ff[22];
                        mul[7] = CAL_image_ff[23];
                        mul[8] = CAL_image_ff[24];
                    end
                    8: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[7];
                        mul[4] = CAL_image_ff[8];
                        mul[5] = CAL_image_ff[9];
                        mul[6] = CAL_image_ff[23];
                        mul[7] = CAL_image_ff[24];
                        mul[8] = CAL_image_ff[25];
                    end
                    9: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[8];
                        mul[4] = CAL_image_ff[9];
                        mul[5] = CAL_image_ff[10];
                        mul[6] = CAL_image_ff[24];
                        mul[7] = CAL_image_ff[25];
                        mul[8] = CAL_image_ff[26];
                    end
                    10: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[9];
                        mul[4] = CAL_image_ff[10];
                        mul[5] = CAL_image_ff[11];
                        mul[6] = CAL_image_ff[25];
                        mul[7] = CAL_image_ff[26];
                        mul[8] = CAL_image_ff[27];
                    end
                    11: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[10];
                        mul[4] = CAL_image_ff[11];
                        mul[5] = CAL_image_ff[12];
                        mul[6] = CAL_image_ff[26];
                        mul[7] = CAL_image_ff[27];
                        mul[8] = CAL_image_ff[28];
                    end
                    12: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[11];
                        mul[4] = CAL_image_ff[12];
                        mul[5] = CAL_image_ff[13];
                        mul[6] = CAL_image_ff[27];
                        mul[7] = CAL_image_ff[28];
                        mul[8] = CAL_image_ff[29];
                    end
                    13: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[12];
                        mul[4] = CAL_image_ff[13];
                        mul[5] = CAL_image_ff[14];
                        mul[6] = CAL_image_ff[28];
                        mul[7] = CAL_image_ff[29];
                        mul[8] = CAL_image_ff[30];
                    end
                    14: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[13];
                        mul[4] = CAL_image_ff[14];
                        mul[5] = CAL_image_ff[15];
                        mul[6] = CAL_image_ff[29];
                        mul[7] = CAL_image_ff[30];
                        mul[8] = CAL_image_ff[31];
                    end
                    15: begin
                        mul[0] = 'd0;
                        mul[1] = 'd0;
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[14];
                        mul[4] = CAL_image_ff[15];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[30];
                        mul[7] = CAL_image_ff[31];
                        mul[8] = 'd0;
                    end

                    16: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[0];
                        mul[2] = CAL_image_ff[1];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[16];
                        mul[5] = CAL_image_ff[17];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[32];
                        mul[8] = CAL_image_ff[33];
                    end
                    17: begin
                        mul[0] = CAL_image_ff[0];
                        mul[1] = CAL_image_ff[1];
                        mul[2] = CAL_image_ff[2];
                        mul[3] = CAL_image_ff[16];
                        mul[4] = CAL_image_ff[17];
                        mul[5] = CAL_image_ff[18];
                        mul[6] = CAL_image_ff[32];
                        mul[7] = CAL_image_ff[33];
                        mul[8] = CAL_image_ff[34];
                    end
                    18: begin
                        mul[0] = CAL_image_ff[1];
                        mul[1] = CAL_image_ff[2];
                        mul[2] = CAL_image_ff[3];
                        mul[3] = CAL_image_ff[17];
                        mul[4] = CAL_image_ff[18];
                        mul[5] = CAL_image_ff[19];
                        mul[6] = CAL_image_ff[33];
                        mul[7] = CAL_image_ff[34];
                        mul[8] = CAL_image_ff[35];
                    end
                    19: begin
                        mul[0] = CAL_image_ff[2];
                        mul[1] = CAL_image_ff[3];
                        mul[2] = CAL_image_ff[4];
                        mul[3] = CAL_image_ff[18];
                        mul[4] = CAL_image_ff[19];
                        mul[5] = CAL_image_ff[20];
                        mul[6] = CAL_image_ff[34];
                        mul[7] = CAL_image_ff[35];
                        mul[8] = CAL_image_ff[36];
                    end
                    20: begin
                        mul[0] = CAL_image_ff[3];
                        mul[1] = CAL_image_ff[4];
                        mul[2] = CAL_image_ff[5];
                        mul[3] = CAL_image_ff[19];
                        mul[4] = CAL_image_ff[20];
                        mul[5] = CAL_image_ff[21];
                        mul[6] = CAL_image_ff[35];
                        mul[7] = CAL_image_ff[36];
                        mul[8] = CAL_image_ff[37];
                    end
                    21: begin
                        mul[0] = CAL_image_ff[4];
                        mul[1] = CAL_image_ff[5];
                        mul[2] = CAL_image_ff[6];
                        mul[3] = CAL_image_ff[20];
                        mul[4] = CAL_image_ff[21];
                        mul[5] = CAL_image_ff[22];
                        mul[6] = CAL_image_ff[36];
                        mul[7] = CAL_image_ff[37];
                        mul[8] = CAL_image_ff[38];
                    end
                    22: begin
                        mul[0] = CAL_image_ff[5];
                        mul[1] = CAL_image_ff[6];
                        mul[2] = CAL_image_ff[7];
                        mul[3] = CAL_image_ff[21];
                        mul[4] = CAL_image_ff[22];
                        mul[5] = CAL_image_ff[23];
                        mul[6] = CAL_image_ff[37];
                        mul[7] = CAL_image_ff[38];
                        mul[8] = CAL_image_ff[39];
                    end
                    23: begin
                        mul[0] = CAL_image_ff[6];
                        mul[1] = CAL_image_ff[7];
                        mul[2] = CAL_image_ff[8];
                        mul[3] = CAL_image_ff[22];
                        mul[4] = CAL_image_ff[23];
                        mul[5] = CAL_image_ff[24];
                        mul[6] = CAL_image_ff[38];
                        mul[7] = CAL_image_ff[39];
                        mul[8] = CAL_image_ff[40];
                    end
                    24: begin
                        mul[0] = CAL_image_ff[7];
                        mul[1] = CAL_image_ff[8];
                        mul[2] = CAL_image_ff[9];
                        mul[3] = CAL_image_ff[23];
                        mul[4] = CAL_image_ff[24];
                        mul[5] = CAL_image_ff[25];
                        mul[6] = CAL_image_ff[39];
                        mul[7] = CAL_image_ff[40];
                        mul[8] = CAL_image_ff[41];
                    end
                    25: begin
                        mul[0] = CAL_image_ff[8];
                        mul[1] = CAL_image_ff[9];
                        mul[2] = CAL_image_ff[10];
                        mul[3] = CAL_image_ff[24];
                        mul[4] = CAL_image_ff[25];
                        mul[5] = CAL_image_ff[26];
                        mul[6] = CAL_image_ff[40];
                        mul[7] = CAL_image_ff[41];
                        mul[8] = CAL_image_ff[42];
                    end
                    26: begin
                        mul[0] = CAL_image_ff[9];
                        mul[1] = CAL_image_ff[10];
                        mul[2] = CAL_image_ff[11];
                        mul[3] = CAL_image_ff[25];
                        mul[4] = CAL_image_ff[26];
                        mul[5] = CAL_image_ff[27];
                        mul[6] = CAL_image_ff[41];
                        mul[7] = CAL_image_ff[42];
                        mul[8] = CAL_image_ff[43];
                    end
                    27: begin
                        mul[0] = CAL_image_ff[10];
                        mul[1] = CAL_image_ff[11];
                        mul[2] = CAL_image_ff[12];
                        mul[3] = CAL_image_ff[26];
                        mul[4] = CAL_image_ff[27];
                        mul[5] = CAL_image_ff[28];
                        mul[6] = CAL_image_ff[42];
                        mul[7] = CAL_image_ff[43];
                        mul[8] = CAL_image_ff[44];
                    end
                    28: begin
                        mul[0] = CAL_image_ff[11];
                        mul[1] = CAL_image_ff[12];
                        mul[2] = CAL_image_ff[13];
                        mul[3] = CAL_image_ff[27];
                        mul[4] = CAL_image_ff[28];
                        mul[5] = CAL_image_ff[29];
                        mul[6] = CAL_image_ff[43];
                        mul[7] = CAL_image_ff[44];
                        mul[8] = CAL_image_ff[45];
                    end
                    29: begin
                        mul[0] = CAL_image_ff[12];
                        mul[1] = CAL_image_ff[13];
                        mul[2] = CAL_image_ff[14];
                        mul[3] = CAL_image_ff[28];
                        mul[4] = CAL_image_ff[29];
                        mul[5] = CAL_image_ff[30];
                        mul[6] = CAL_image_ff[44];
                        mul[7] = CAL_image_ff[45];
                        mul[8] = CAL_image_ff[46];
                    end
                    30: begin
                        mul[0] = CAL_image_ff[13];
                        mul[1] = CAL_image_ff[14];
                        mul[2] = CAL_image_ff[15];
                        mul[3] = CAL_image_ff[29];
                        mul[4] = CAL_image_ff[30];
                        mul[5] = CAL_image_ff[31];
                        mul[6] = CAL_image_ff[45];
                        mul[7] = CAL_image_ff[46];
                        mul[8] = CAL_image_ff[47];
                    end
                    31: begin
                        mul[0] = CAL_image_ff[14];
                        mul[1] = CAL_image_ff[15];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[30];
                        mul[4] = CAL_image_ff[31];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[46];
                        mul[7] = CAL_image_ff[47];
                        mul[8] = 'd0;
                    end
                    32: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[16];
                        mul[2] = CAL_image_ff[17];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[32];
                        mul[5] = CAL_image_ff[33];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[48];
                        mul[8] = CAL_image_ff[49];
                    end
                    33: begin
                        mul[0] = CAL_image_ff[16];
                        mul[1] = CAL_image_ff[17];
                        mul[2] = CAL_image_ff[18];
                        mul[3] = CAL_image_ff[32];
                        mul[4] = CAL_image_ff[33];
                        mul[5] = CAL_image_ff[34];
                        mul[6] = CAL_image_ff[48];
                        mul[7] = CAL_image_ff[49];
                        mul[8] = CAL_image_ff[50];
                    end
                    34: begin
                        mul[0] = CAL_image_ff[17];
                        mul[1] = CAL_image_ff[18];
                        mul[2] = CAL_image_ff[19];
                        mul[3] = CAL_image_ff[33];
                        mul[4] = CAL_image_ff[34];
                        mul[5] = CAL_image_ff[35];
                        mul[6] = CAL_image_ff[49];
                        mul[7] = CAL_image_ff[50];
                        mul[8] = CAL_image_ff[51];
                    end
                    35: begin
                        mul[0] = CAL_image_ff[18];
                        mul[1] = CAL_image_ff[19];
                        mul[2] = CAL_image_ff[20];
                        mul[3] = CAL_image_ff[34];
                        mul[4] = CAL_image_ff[35];
                        mul[5] = CAL_image_ff[36];
                        mul[6] = CAL_image_ff[50];
                        mul[7] = CAL_image_ff[51];
                        mul[8] = CAL_image_ff[52];
                    end
                    36: begin
                        mul[0] = CAL_image_ff[19];
                        mul[1] = CAL_image_ff[20];
                        mul[2] = CAL_image_ff[21];
                        mul[3] = CAL_image_ff[35];
                        mul[4] = CAL_image_ff[36];
                        mul[5] = CAL_image_ff[37];
                        mul[6] = CAL_image_ff[51];
                        mul[7] = CAL_image_ff[52];
                        mul[8] = CAL_image_ff[53];
                    end
                    37: begin
                        mul[0] = CAL_image_ff[20];
                        mul[1] = CAL_image_ff[21];
                        mul[2] = CAL_image_ff[22];
                        mul[3] = CAL_image_ff[36];
                        mul[4] = CAL_image_ff[37];
                        mul[5] = CAL_image_ff[38];
                        mul[6] = CAL_image_ff[52];
                        mul[7] = CAL_image_ff[53];
                        mul[8] = CAL_image_ff[54];
                    end
                    38: begin
                        mul[0] = CAL_image_ff[21];
                        mul[1] = CAL_image_ff[22];
                        mul[2] = CAL_image_ff[23];
                        mul[3] = CAL_image_ff[37];
                        mul[4] = CAL_image_ff[38];
                        mul[5] = CAL_image_ff[39];
                        mul[6] = CAL_image_ff[53];
                        mul[7] = CAL_image_ff[54];
                        mul[8] = CAL_image_ff[55];
                    end
                    39: begin
                        mul[0] = CAL_image_ff[22];
                        mul[1] = CAL_image_ff[23];
                        mul[2] = CAL_image_ff[24];
                        mul[3] = CAL_image_ff[38];
                        mul[4] = CAL_image_ff[39];
                        mul[5] = CAL_image_ff[40];
                        mul[6] = CAL_image_ff[54];
                        mul[7] = CAL_image_ff[55];
                        mul[8] = CAL_image_ff[56];
                    end
                    40: begin
                        mul[0] = CAL_image_ff[23];
                        mul[1] = CAL_image_ff[24];
                        mul[2] = CAL_image_ff[25];
                        mul[3] = CAL_image_ff[39];
                        mul[4] = CAL_image_ff[40];
                        mul[5] = CAL_image_ff[41];
                        mul[6] = CAL_image_ff[55];
                        mul[7] = CAL_image_ff[56];
                        mul[8] = CAL_image_ff[57];
                    end
                    41: begin
                        mul[0] = CAL_image_ff[24];
                        mul[1] = CAL_image_ff[25];
                        mul[2] = CAL_image_ff[26];
                        mul[3] = CAL_image_ff[40];
                        mul[4] = CAL_image_ff[41];
                        mul[5] = CAL_image_ff[42];
                        mul[6] = CAL_image_ff[56];
                        mul[7] = CAL_image_ff[57];
                        mul[8] = CAL_image_ff[58];
                    end
                    42: begin
                        mul[0] = CAL_image_ff[25];
                        mul[1] = CAL_image_ff[26];
                        mul[2] = CAL_image_ff[27];
                        mul[3] = CAL_image_ff[41];
                        mul[4] = CAL_image_ff[42];
                        mul[5] = CAL_image_ff[43];
                        mul[6] = CAL_image_ff[57];
                        mul[7] = CAL_image_ff[58];
                        mul[8] = CAL_image_ff[59];
                    end
                    43: begin
                        mul[0] = CAL_image_ff[26];
                        mul[1] = CAL_image_ff[27];
                        mul[2] = CAL_image_ff[28];
                        mul[3] = CAL_image_ff[42];
                        mul[4] = CAL_image_ff[43];
                        mul[5] = CAL_image_ff[44];
                        mul[6] = CAL_image_ff[58];
                        mul[7] = CAL_image_ff[59];
                        mul[8] = CAL_image_ff[60];
                    end
                    44: begin
                        mul[0] = CAL_image_ff[27];
                        mul[1] = CAL_image_ff[28];
                        mul[2] = CAL_image_ff[29];
                        mul[3] = CAL_image_ff[43];
                        mul[4] = CAL_image_ff[44];
                        mul[5] = CAL_image_ff[45];
                        mul[6] = CAL_image_ff[59];
                        mul[7] = CAL_image_ff[60];
                        mul[8] = CAL_image_ff[61];
                    end
                    45: begin
                        mul[0] = CAL_image_ff[28];
                        mul[1] = CAL_image_ff[29];
                        mul[2] = CAL_image_ff[30];
                        mul[3] = CAL_image_ff[44];
                        mul[4] = CAL_image_ff[45];
                        mul[5] = CAL_image_ff[46];
                        mul[6] = CAL_image_ff[60];
                        mul[7] = CAL_image_ff[61];
                        mul[8] = CAL_image_ff[62];
                    end
                    46: begin
                        mul[0] = CAL_image_ff[29];
                        mul[1] = CAL_image_ff[30];
                        mul[2] = CAL_image_ff[31];
                        mul[3] = CAL_image_ff[45];
                        mul[4] = CAL_image_ff[46];
                        mul[5] = CAL_image_ff[47];
                        mul[6] = CAL_image_ff[61];
                        mul[7] = CAL_image_ff[62];
                        mul[8] = CAL_image_ff[63];
                    end
                    47: begin
                        mul[0] = CAL_image_ff[30];
                        mul[1] = CAL_image_ff[31];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[46];
                        mul[4] = CAL_image_ff[47];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[62];
                        mul[7] = CAL_image_ff[63];
                        mul[8] = 'd0;
                    end
                    48: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[32];
                        mul[2] = CAL_image_ff[33];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[48];
                        mul[5] = CAL_image_ff[49];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[64];
                        mul[8] = CAL_image_ff[65];
                    end
                    49: begin
                        mul[0] = CAL_image_ff[32];
                        mul[1] = CAL_image_ff[33];
                        mul[2] = CAL_image_ff[34];
                        mul[3] = CAL_image_ff[48];
                        mul[4] = CAL_image_ff[49];
                        mul[5] = CAL_image_ff[50];
                        mul[6] = CAL_image_ff[64];
                        mul[7] = CAL_image_ff[65];
                        mul[8] = CAL_image_ff[66];
                    end
                    50: begin
                        mul[0] = CAL_image_ff[33];
                        mul[1] = CAL_image_ff[34];
                        mul[2] = CAL_image_ff[35];
                        mul[3] = CAL_image_ff[49];
                        mul[4] = CAL_image_ff[50];
                        mul[5] = CAL_image_ff[51];
                        mul[6] = CAL_image_ff[65];
                        mul[7] = CAL_image_ff[66];
                        mul[8] = CAL_image_ff[67];
                    end
                    51: begin
                        mul[0] = CAL_image_ff[34];
                        mul[1] = CAL_image_ff[35];
                        mul[2] = CAL_image_ff[36];
                        mul[3] = CAL_image_ff[50];
                        mul[4] = CAL_image_ff[51];
                        mul[5] = CAL_image_ff[52];
                        mul[6] = CAL_image_ff[66];
                        mul[7] = CAL_image_ff[67];
                        mul[8] = CAL_image_ff[68];
                    end
                    52: begin
                        mul[0] = CAL_image_ff[35];
                        mul[1] = CAL_image_ff[36];
                        mul[2] = CAL_image_ff[37];
                        mul[3] = CAL_image_ff[51];
                        mul[4] = CAL_image_ff[52];
                        mul[5] = CAL_image_ff[53];
                        mul[6] = CAL_image_ff[67];
                        mul[7] = CAL_image_ff[68];
                        mul[8] = CAL_image_ff[69];
                    end
                    53: begin
                        mul[0] = CAL_image_ff[36];
                        mul[1] = CAL_image_ff[37];
                        mul[2] = CAL_image_ff[38];
                        mul[3] = CAL_image_ff[52];
                        mul[4] = CAL_image_ff[53];
                        mul[5] = CAL_image_ff[54];
                        mul[6] = CAL_image_ff[68];
                        mul[7] = CAL_image_ff[69];
                        mul[8] = CAL_image_ff[70];
                    end
                    54: begin
                        mul[0] = CAL_image_ff[37];
                        mul[1] = CAL_image_ff[38];
                        mul[2] = CAL_image_ff[39];
                        mul[3] = CAL_image_ff[53];
                        mul[4] = CAL_image_ff[54];
                        mul[5] = CAL_image_ff[55];
                        mul[6] = CAL_image_ff[69];
                        mul[7] = CAL_image_ff[70];
                        mul[8] = CAL_image_ff[71];
                    end
                    55: begin
                        mul[0] = CAL_image_ff[38];
                        mul[1] = CAL_image_ff[39];
                        mul[2] = CAL_image_ff[40];
                        mul[3] = CAL_image_ff[54];
                        mul[4] = CAL_image_ff[55];
                        mul[5] = CAL_image_ff[56];
                        mul[6] = CAL_image_ff[70];
                        mul[7] = CAL_image_ff[71];
                        mul[8] = CAL_image_ff[72];
                    end
                    56: begin
                        mul[0] = CAL_image_ff[39];
                        mul[1] = CAL_image_ff[40];
                        mul[2] = CAL_image_ff[41];
                        mul[3] = CAL_image_ff[55];
                        mul[4] = CAL_image_ff[56];
                        mul[5] = CAL_image_ff[57];
                        mul[6] = CAL_image_ff[71];
                        mul[7] = CAL_image_ff[72];
                        mul[8] = CAL_image_ff[73];
                    end
                    57: begin
                        mul[0] = CAL_image_ff[40];
                        mul[1] = CAL_image_ff[41];
                        mul[2] = CAL_image_ff[42];
                        mul[3] = CAL_image_ff[56];
                        mul[4] = CAL_image_ff[57];
                        mul[5] = CAL_image_ff[58];
                        mul[6] = CAL_image_ff[72];
                        mul[7] = CAL_image_ff[73];
                        mul[8] = CAL_image_ff[74];
                    end
                    58: begin
                        mul[0] = CAL_image_ff[41];
                        mul[1] = CAL_image_ff[42];
                        mul[2] = CAL_image_ff[43];
                        mul[3] = CAL_image_ff[57];
                        mul[4] = CAL_image_ff[58];
                        mul[5] = CAL_image_ff[59];
                        mul[6] = CAL_image_ff[73];
                        mul[7] = CAL_image_ff[74];
                        mul[8] = CAL_image_ff[75];
                    end
                    59: begin
                        mul[0] = CAL_image_ff[42];
                        mul[1] = CAL_image_ff[43];
                        mul[2] = CAL_image_ff[44];
                        mul[3] = CAL_image_ff[58];
                        mul[4] = CAL_image_ff[59];
                        mul[5] = CAL_image_ff[60];
                        mul[6] = CAL_image_ff[74];
                        mul[7] = CAL_image_ff[75];
                        mul[8] = CAL_image_ff[76];
                    end
                    60: begin
                        mul[0] = CAL_image_ff[43];
                        mul[1] = CAL_image_ff[44];
                        mul[2] = CAL_image_ff[45];
                        mul[3] = CAL_image_ff[59];
                        mul[4] = CAL_image_ff[60];
                        mul[5] = CAL_image_ff[61];
                        mul[6] = CAL_image_ff[75];
                        mul[7] = CAL_image_ff[76];
                        mul[8] = CAL_image_ff[77];
                    end
                    61: begin
                        mul[0] = CAL_image_ff[44];
                        mul[1] = CAL_image_ff[45];
                        mul[2] = CAL_image_ff[46];
                        mul[3] = CAL_image_ff[60];
                        mul[4] = CAL_image_ff[61];
                        mul[5] = CAL_image_ff[62];
                        mul[6] = CAL_image_ff[76];
                        mul[7] = CAL_image_ff[77];
                        mul[8] = CAL_image_ff[78];
                    end
                    62: begin
                        mul[0] = CAL_image_ff[45];
                        mul[1] = CAL_image_ff[46];
                        mul[2] = CAL_image_ff[47];
                        mul[3] = CAL_image_ff[61];
                        mul[4] = CAL_image_ff[62];
                        mul[5] = CAL_image_ff[63];
                        mul[6] = CAL_image_ff[77];
                        mul[7] = CAL_image_ff[78];
                        mul[8] = CAL_image_ff[79];
                    end
                    63: begin
                        mul[0] = CAL_image_ff[46];
                        mul[1] = CAL_image_ff[47];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[62];
                        mul[4] = CAL_image_ff[63];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[78];
                        mul[7] = CAL_image_ff[79];
                        mul[8] = 'd0;
                    end
                    64: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[48];
                        mul[2] = CAL_image_ff[49];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[64];
                        mul[5] = CAL_image_ff[65];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[80];
                        mul[8] = CAL_image_ff[81];
                    end
                    65: begin
                        mul[0] = CAL_image_ff[48];
                        mul[1] = CAL_image_ff[49];
                        mul[2] = CAL_image_ff[50];
                        mul[3] = CAL_image_ff[64];
                        mul[4] = CAL_image_ff[65];
                        mul[5] = CAL_image_ff[66];
                        mul[6] = CAL_image_ff[80];
                        mul[7] = CAL_image_ff[81];
                        mul[8] = CAL_image_ff[82];
                    end
                    66: begin
                        mul[0] = CAL_image_ff[49];
                        mul[1] = CAL_image_ff[50];
                        mul[2] = CAL_image_ff[51];
                        mul[3] = CAL_image_ff[65];
                        mul[4] = CAL_image_ff[66];
                        mul[5] = CAL_image_ff[67];
                        mul[6] = CAL_image_ff[81];
                        mul[7] = CAL_image_ff[82];
                        mul[8] = CAL_image_ff[83];
                    end
                    67: begin
                        mul[0] = CAL_image_ff[50];
                        mul[1] = CAL_image_ff[51];
                        mul[2] = CAL_image_ff[52];
                        mul[3] = CAL_image_ff[66];
                        mul[4] = CAL_image_ff[67];
                        mul[5] = CAL_image_ff[68];
                        mul[6] = CAL_image_ff[82];
                        mul[7] = CAL_image_ff[83];
                        mul[8] = CAL_image_ff[84];
                    end
                    68: begin
                        mul[0] = CAL_image_ff[51];
                        mul[1] = CAL_image_ff[52];
                        mul[2] = CAL_image_ff[53];
                        mul[3] = CAL_image_ff[67];
                        mul[4] = CAL_image_ff[68];
                        mul[5] = CAL_image_ff[69];
                        mul[6] = CAL_image_ff[83];
                        mul[7] = CAL_image_ff[84];
                        mul[8] = CAL_image_ff[85];
                    end
                    69: begin
                        mul[0] = CAL_image_ff[52];
                        mul[1] = CAL_image_ff[53];
                        mul[2] = CAL_image_ff[54];
                        mul[3] = CAL_image_ff[68];
                        mul[4] = CAL_image_ff[69];
                        mul[5] = CAL_image_ff[70];
                        mul[6] = CAL_image_ff[84];
                        mul[7] = CAL_image_ff[85];
                        mul[8] = CAL_image_ff[86];
                    end
                    70: begin
                        mul[0] = CAL_image_ff[53];
                        mul[1] = CAL_image_ff[54];
                        mul[2] = CAL_image_ff[55];
                        mul[3] = CAL_image_ff[69];
                        mul[4] = CAL_image_ff[70];
                        mul[5] = CAL_image_ff[71];
                        mul[6] = CAL_image_ff[85];
                        mul[7] = CAL_image_ff[86];
                        mul[8] = CAL_image_ff[87];
                    end
                    71: begin
                        mul[0] = CAL_image_ff[54];
                        mul[1] = CAL_image_ff[55];
                        mul[2] = CAL_image_ff[56];
                        mul[3] = CAL_image_ff[70];
                        mul[4] = CAL_image_ff[71];
                        mul[5] = CAL_image_ff[72];
                        mul[6] = CAL_image_ff[86];
                        mul[7] = CAL_image_ff[87];
                        mul[8] = CAL_image_ff[88];
                    end
                    72: begin
                        mul[0] = CAL_image_ff[55];
                        mul[1] = CAL_image_ff[56];
                        mul[2] = CAL_image_ff[57];
                        mul[3] = CAL_image_ff[71];
                        mul[4] = CAL_image_ff[72];
                        mul[5] = CAL_image_ff[73];
                        mul[6] = CAL_image_ff[87];
                        mul[7] = CAL_image_ff[88];
                        mul[8] = CAL_image_ff[89];
                    end
                    73: begin
                        mul[0] = CAL_image_ff[56];
                        mul[1] = CAL_image_ff[57];
                        mul[2] = CAL_image_ff[58];
                        mul[3] = CAL_image_ff[72];
                        mul[4] = CAL_image_ff[73];
                        mul[5] = CAL_image_ff[74];
                        mul[6] = CAL_image_ff[88];
                        mul[7] = CAL_image_ff[89];
                        mul[8] = CAL_image_ff[90];
                    end
                    74: begin
                        mul[0] = CAL_image_ff[57];
                        mul[1] = CAL_image_ff[58];
                        mul[2] = CAL_image_ff[59];
                        mul[3] = CAL_image_ff[73];
                        mul[4] = CAL_image_ff[74];
                        mul[5] = CAL_image_ff[75];
                        mul[6] = CAL_image_ff[89];
                        mul[7] = CAL_image_ff[90];
                        mul[8] = CAL_image_ff[91];
                    end
                    75: begin
                        mul[0] = CAL_image_ff[58];
                        mul[1] = CAL_image_ff[59];
                        mul[2] = CAL_image_ff[60];
                        mul[3] = CAL_image_ff[74];
                        mul[4] = CAL_image_ff[75];
                        mul[5] = CAL_image_ff[76];
                        mul[6] = CAL_image_ff[90];
                        mul[7] = CAL_image_ff[91];
                        mul[8] = CAL_image_ff[92];
                    end
                    76: begin
                        mul[0] = CAL_image_ff[59];
                        mul[1] = CAL_image_ff[60];
                        mul[2] = CAL_image_ff[61];
                        mul[3] = CAL_image_ff[75];
                        mul[4] = CAL_image_ff[76];
                        mul[5] = CAL_image_ff[77];
                        mul[6] = CAL_image_ff[91];
                        mul[7] = CAL_image_ff[92];
                        mul[8] = CAL_image_ff[93];
                    end
                    77: begin
                        mul[0] = CAL_image_ff[60];
                        mul[1] = CAL_image_ff[61];
                        mul[2] = CAL_image_ff[62];
                        mul[3] = CAL_image_ff[76];
                        mul[4] = CAL_image_ff[77];
                        mul[5] = CAL_image_ff[78];
                        mul[6] = CAL_image_ff[92];
                        mul[7] = CAL_image_ff[93];
                        mul[8] = CAL_image_ff[94];
                    end
                    78: begin
                        mul[0] = CAL_image_ff[61];
                        mul[1] = CAL_image_ff[62];
                        mul[2] = CAL_image_ff[63];
                        mul[3] = CAL_image_ff[77];
                        mul[4] = CAL_image_ff[78];
                        mul[5] = CAL_image_ff[79];
                        mul[6] = CAL_image_ff[93];
                        mul[7] = CAL_image_ff[94];
                        mul[8] = CAL_image_ff[95];
                    end
                    79: begin
                        mul[0] = CAL_image_ff[62];
                        mul[1] = CAL_image_ff[63];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[78];
                        mul[4] = CAL_image_ff[79];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[94];
                        mul[7] = CAL_image_ff[95];
                        mul[8] = 'd0;
                    end
                    80: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[64];
                        mul[2] = CAL_image_ff[65];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[80];
                        mul[5] = CAL_image_ff[81];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[96];
                        mul[8] = CAL_image_ff[97];
                    end
                    81: begin
                        mul[0] = CAL_image_ff[64];
                        mul[1] = CAL_image_ff[65];
                        mul[2] = CAL_image_ff[66];
                        mul[3] = CAL_image_ff[80];
                        mul[4] = CAL_image_ff[81];
                        mul[5] = CAL_image_ff[82];
                        mul[6] = CAL_image_ff[96];
                        mul[7] = CAL_image_ff[97];
                        mul[8] = CAL_image_ff[98];
                    end
                    82: begin
                        mul[0] = CAL_image_ff[65];
                        mul[1] = CAL_image_ff[66];
                        mul[2] = CAL_image_ff[67];
                        mul[3] = CAL_image_ff[81];
                        mul[4] = CAL_image_ff[82];
                        mul[5] = CAL_image_ff[83];
                        mul[6] = CAL_image_ff[97];
                        mul[7] = CAL_image_ff[98];
                        mul[8] = CAL_image_ff[99];
                    end
                    83: begin
                        mul[0] = CAL_image_ff[66];
                        mul[1] = CAL_image_ff[67];
                        mul[2] = CAL_image_ff[68];
                        mul[3] = CAL_image_ff[82];
                        mul[4] = CAL_image_ff[83];
                        mul[5] = CAL_image_ff[84];
                        mul[6] = CAL_image_ff[98];
                        mul[7] = CAL_image_ff[99];
                        mul[8] = CAL_image_ff[100];
                    end
                    84: begin
                        mul[0] = CAL_image_ff[67];
                        mul[1] = CAL_image_ff[68];
                        mul[2] = CAL_image_ff[69];
                        mul[3] = CAL_image_ff[83];
                        mul[4] = CAL_image_ff[84];
                        mul[5] = CAL_image_ff[85];
                        mul[6] = CAL_image_ff[99];
                        mul[7] = CAL_image_ff[100];
                        mul[8] = CAL_image_ff[101];
                    end
                    85: begin
                        mul[0] = CAL_image_ff[68];
                        mul[1] = CAL_image_ff[69];
                        mul[2] = CAL_image_ff[70];
                        mul[3] = CAL_image_ff[84];
                        mul[4] = CAL_image_ff[85];
                        mul[5] = CAL_image_ff[86];
                        mul[6] = CAL_image_ff[100];
                        mul[7] = CAL_image_ff[101];
                        mul[8] = CAL_image_ff[102];
                    end
                    86: begin
                        mul[0] = CAL_image_ff[69];
                        mul[1] = CAL_image_ff[70];
                        mul[2] = CAL_image_ff[71];
                        mul[3] = CAL_image_ff[85];
                        mul[4] = CAL_image_ff[86];
                        mul[5] = CAL_image_ff[87];
                        mul[6] = CAL_image_ff[101];
                        mul[7] = CAL_image_ff[102];
                        mul[8] = CAL_image_ff[103];
                    end
                    87: begin
                        mul[0] = CAL_image_ff[70];
                        mul[1] = CAL_image_ff[71];
                        mul[2] = CAL_image_ff[72];
                        mul[3] = CAL_image_ff[86];
                        mul[4] = CAL_image_ff[87];
                        mul[5] = CAL_image_ff[88];
                        mul[6] = CAL_image_ff[102];
                        mul[7] = CAL_image_ff[103];
                        mul[8] = CAL_image_ff[104];
                    end
                    88: begin
                        mul[0] = CAL_image_ff[71];
                        mul[1] = CAL_image_ff[72];
                        mul[2] = CAL_image_ff[73];
                        mul[3] = CAL_image_ff[87];
                        mul[4] = CAL_image_ff[88];
                        mul[5] = CAL_image_ff[89];
                        mul[6] = CAL_image_ff[103];
                        mul[7] = CAL_image_ff[104];
                        mul[8] = CAL_image_ff[105];
                    end
                    89: begin
                        mul[0] = CAL_image_ff[72];
                        mul[1] = CAL_image_ff[73];
                        mul[2] = CAL_image_ff[74];
                        mul[3] = CAL_image_ff[88];
                        mul[4] = CAL_image_ff[89];
                        mul[5] = CAL_image_ff[90];
                        mul[6] = CAL_image_ff[104];
                        mul[7] = CAL_image_ff[105];
                        mul[8] = CAL_image_ff[106];
                    end
                    90: begin
                        mul[0] = CAL_image_ff[73];
                        mul[1] = CAL_image_ff[74];
                        mul[2] = CAL_image_ff[75];
                        mul[3] = CAL_image_ff[89];
                        mul[4] = CAL_image_ff[90];
                        mul[5] = CAL_image_ff[91];
                        mul[6] = CAL_image_ff[105];
                        mul[7] = CAL_image_ff[106];
                        mul[8] = CAL_image_ff[107];
                    end
                    91: begin
                        mul[0] = CAL_image_ff[74];
                        mul[1] = CAL_image_ff[75];
                        mul[2] = CAL_image_ff[76];
                        mul[3] = CAL_image_ff[90];
                        mul[4] = CAL_image_ff[91];
                        mul[5] = CAL_image_ff[92];
                        mul[6] = CAL_image_ff[106];
                        mul[7] = CAL_image_ff[107];
                        mul[8] = CAL_image_ff[108];
                    end
                    92: begin
                        mul[0] = CAL_image_ff[75];
                        mul[1] = CAL_image_ff[76];
                        mul[2] = CAL_image_ff[77];
                        mul[3] = CAL_image_ff[91];
                        mul[4] = CAL_image_ff[92];
                        mul[5] = CAL_image_ff[93];
                        mul[6] = CAL_image_ff[107];
                        mul[7] = CAL_image_ff[108];
                        mul[8] = CAL_image_ff[109];
                    end
                    93: begin
                        mul[0] = CAL_image_ff[76];
                        mul[1] = CAL_image_ff[77];
                        mul[2] = CAL_image_ff[78];
                        mul[3] = CAL_image_ff[92];
                        mul[4] = CAL_image_ff[93];
                        mul[5] = CAL_image_ff[94];
                        mul[6] = CAL_image_ff[108];
                        mul[7] = CAL_image_ff[109];
                        mul[8] = CAL_image_ff[110];
                    end
                    94: begin
                        mul[0] = CAL_image_ff[77];
                        mul[1] = CAL_image_ff[78];
                        mul[2] = CAL_image_ff[79];
                        mul[3] = CAL_image_ff[93];
                        mul[4] = CAL_image_ff[94];
                        mul[5] = CAL_image_ff[95];
                        mul[6] = CAL_image_ff[109];
                        mul[7] = CAL_image_ff[110];
                        mul[8] = CAL_image_ff[111];
                    end
                    95: begin
                        mul[0] = CAL_image_ff[78];
                        mul[1] = CAL_image_ff[79];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[94];
                        mul[4] = CAL_image_ff[95];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[110];
                        mul[7] = CAL_image_ff[111];
                        mul[8] = 'd0;
                    end
                    96: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[80];
                        mul[2] = CAL_image_ff[81];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[96];
                        mul[5] = CAL_image_ff[97];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[112];
                        mul[8] = CAL_image_ff[113];
                    end
                    97: begin
                        mul[0] = CAL_image_ff[80];
                        mul[1] = CAL_image_ff[81];
                        mul[2] = CAL_image_ff[82];
                        mul[3] = CAL_image_ff[96];
                        mul[4] = CAL_image_ff[97];
                        mul[5] = CAL_image_ff[98];
                        mul[6] = CAL_image_ff[112];
                        mul[7] = CAL_image_ff[113];
                        mul[8] = CAL_image_ff[114];
                    end
                    98: begin
                        mul[0] = CAL_image_ff[81];
                        mul[1] = CAL_image_ff[82];
                        mul[2] = CAL_image_ff[83];
                        mul[3] = CAL_image_ff[97];
                        mul[4] = CAL_image_ff[98];
                        mul[5] = CAL_image_ff[99];
                        mul[6] = CAL_image_ff[113];
                        mul[7] = CAL_image_ff[114];
                        mul[8] = CAL_image_ff[115];
                    end
                    99: begin
                        mul[0] = CAL_image_ff[82];
                        mul[1] = CAL_image_ff[83];
                        mul[2] = CAL_image_ff[84];
                        mul[3] = CAL_image_ff[98];
                        mul[4] = CAL_image_ff[99];
                        mul[5] = CAL_image_ff[100];
                        mul[6] = CAL_image_ff[114];
                        mul[7] = CAL_image_ff[115];
                        mul[8] = CAL_image_ff[116];
                    end
                    100: begin
                        mul[0] = CAL_image_ff[83];
                        mul[1] = CAL_image_ff[84];
                        mul[2] = CAL_image_ff[85];
                        mul[3] = CAL_image_ff[99];
                        mul[4] = CAL_image_ff[100];
                        mul[5] = CAL_image_ff[101];
                        mul[6] = CAL_image_ff[115];
                        mul[7] = CAL_image_ff[116];
                        mul[8] = CAL_image_ff[117];
                    end
                    101: begin
                        mul[0] = CAL_image_ff[84];
                        mul[1] = CAL_image_ff[85];
                        mul[2] = CAL_image_ff[86];
                        mul[3] = CAL_image_ff[100];
                        mul[4] = CAL_image_ff[101];
                        mul[5] = CAL_image_ff[102];
                        mul[6] = CAL_image_ff[116];
                        mul[7] = CAL_image_ff[117];
                        mul[8] = CAL_image_ff[118];
                    end
                    102: begin
                        mul[0] = CAL_image_ff[85];
                        mul[1] = CAL_image_ff[86];
                        mul[2] = CAL_image_ff[87];
                        mul[3] = CAL_image_ff[101];
                        mul[4] = CAL_image_ff[102];
                        mul[5] = CAL_image_ff[103];
                        mul[6] = CAL_image_ff[117];
                        mul[7] = CAL_image_ff[118];
                        mul[8] = CAL_image_ff[119];
                    end
                    103: begin
                        mul[0] = CAL_image_ff[86];
                        mul[1] = CAL_image_ff[87];
                        mul[2] = CAL_image_ff[88];
                        mul[3] = CAL_image_ff[102];
                        mul[4] = CAL_image_ff[103];
                        mul[5] = CAL_image_ff[104];
                        mul[6] = CAL_image_ff[118];
                        mul[7] = CAL_image_ff[119];
                        mul[8] = CAL_image_ff[120];
                    end
                    104: begin
                        mul[0] = CAL_image_ff[87];
                        mul[1] = CAL_image_ff[88];
                        mul[2] = CAL_image_ff[89];
                        mul[3] = CAL_image_ff[103];
                        mul[4] = CAL_image_ff[104];
                        mul[5] = CAL_image_ff[105];
                        mul[6] = CAL_image_ff[119];
                        mul[7] = CAL_image_ff[120];
                        mul[8] = CAL_image_ff[121];
                    end
                    105: begin
                        mul[0] = CAL_image_ff[88];
                        mul[1] = CAL_image_ff[89];
                        mul[2] = CAL_image_ff[90];
                        mul[3] = CAL_image_ff[104];
                        mul[4] = CAL_image_ff[105];
                        mul[5] = CAL_image_ff[106];
                        mul[6] = CAL_image_ff[120];
                        mul[7] = CAL_image_ff[121];
                        mul[8] = CAL_image_ff[122];
                    end
                    106: begin
                        mul[0] = CAL_image_ff[89];
                        mul[1] = CAL_image_ff[90];
                        mul[2] = CAL_image_ff[91];
                        mul[3] = CAL_image_ff[105];
                        mul[4] = CAL_image_ff[106];
                        mul[5] = CAL_image_ff[107];
                        mul[6] = CAL_image_ff[121];
                        mul[7] = CAL_image_ff[122];
                        mul[8] = CAL_image_ff[123];
                    end
                    107: begin
                        mul[0] = CAL_image_ff[90];
                        mul[1] = CAL_image_ff[91];
                        mul[2] = CAL_image_ff[92];
                        mul[3] = CAL_image_ff[106];
                        mul[4] = CAL_image_ff[107];
                        mul[5] = CAL_image_ff[108];
                        mul[6] = CAL_image_ff[122];
                        mul[7] = CAL_image_ff[123];
                        mul[8] = CAL_image_ff[124];
                    end
                    108: begin
                        mul[0] = CAL_image_ff[91];
                        mul[1] = CAL_image_ff[92];
                        mul[2] = CAL_image_ff[93];
                        mul[3] = CAL_image_ff[107];
                        mul[4] = CAL_image_ff[108];
                        mul[5] = CAL_image_ff[109];
                        mul[6] = CAL_image_ff[123];
                        mul[7] = CAL_image_ff[124];
                        mul[8] = CAL_image_ff[125];
                    end
                    109: begin
                        mul[0] = CAL_image_ff[92];
                        mul[1] = CAL_image_ff[93];
                        mul[2] = CAL_image_ff[94];
                        mul[3] = CAL_image_ff[108];
                        mul[4] = CAL_image_ff[109];
                        mul[5] = CAL_image_ff[110];
                        mul[6] = CAL_image_ff[124];
                        mul[7] = CAL_image_ff[125];
                        mul[8] = CAL_image_ff[126];
                    end
                    110: begin
                        mul[0] = CAL_image_ff[93];
                        mul[1] = CAL_image_ff[94];
                        mul[2] = CAL_image_ff[95];
                        mul[3] = CAL_image_ff[109];
                        mul[4] = CAL_image_ff[110];
                        mul[5] = CAL_image_ff[111];
                        mul[6] = CAL_image_ff[125];
                        mul[7] = CAL_image_ff[126];
                        mul[8] = CAL_image_ff[127];
                    end
                    111: begin
                        mul[0] = CAL_image_ff[94];
                        mul[1] = CAL_image_ff[95];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[110];
                        mul[4] = CAL_image_ff[111];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[126];
                        mul[7] = CAL_image_ff[127];
                        mul[8] = 'd0;
                    end
                    112: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[96];
                        mul[2] = CAL_image_ff[97];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[112];
                        mul[5] = CAL_image_ff[113];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[128];
                        mul[8] = CAL_image_ff[129];
                    end
                    113: begin
                        mul[0] = CAL_image_ff[96];
                        mul[1] = CAL_image_ff[97];
                        mul[2] = CAL_image_ff[98];
                        mul[3] = CAL_image_ff[112];
                        mul[4] = CAL_image_ff[113];
                        mul[5] = CAL_image_ff[114];
                        mul[6] = CAL_image_ff[128];
                        mul[7] = CAL_image_ff[129];
                        mul[8] = CAL_image_ff[130];
                    end
                    114: begin
                        mul[0] = CAL_image_ff[97];
                        mul[1] = CAL_image_ff[98];
                        mul[2] = CAL_image_ff[99];
                        mul[3] = CAL_image_ff[113];
                        mul[4] = CAL_image_ff[114];
                        mul[5] = CAL_image_ff[115];
                        mul[6] = CAL_image_ff[129];
                        mul[7] = CAL_image_ff[130];
                        mul[8] = CAL_image_ff[131];
                    end
                    115: begin
                        mul[0] = CAL_image_ff[98];
                        mul[1] = CAL_image_ff[99];
                        mul[2] = CAL_image_ff[100];
                        mul[3] = CAL_image_ff[114];
                        mul[4] = CAL_image_ff[115];
                        mul[5] = CAL_image_ff[116];
                        mul[6] = CAL_image_ff[130];
                        mul[7] = CAL_image_ff[131];
                        mul[8] = CAL_image_ff[132];
                    end
                    116: begin
                        mul[0] = CAL_image_ff[99];
                        mul[1] = CAL_image_ff[100];
                        mul[2] = CAL_image_ff[101];
                        mul[3] = CAL_image_ff[115];
                        mul[4] = CAL_image_ff[116];
                        mul[5] = CAL_image_ff[117];
                        mul[6] = CAL_image_ff[131];
                        mul[7] = CAL_image_ff[132];
                        mul[8] = CAL_image_ff[133];
                    end
                    117: begin
                        mul[0] = CAL_image_ff[100];
                        mul[1] = CAL_image_ff[101];
                        mul[2] = CAL_image_ff[102];
                        mul[3] = CAL_image_ff[116];
                        mul[4] = CAL_image_ff[117];
                        mul[5] = CAL_image_ff[118];
                        mul[6] = CAL_image_ff[132];
                        mul[7] = CAL_image_ff[133];
                        mul[8] = CAL_image_ff[134];
                    end
                    118: begin
                        mul[0] = CAL_image_ff[101];
                        mul[1] = CAL_image_ff[102];
                        mul[2] = CAL_image_ff[103];
                        mul[3] = CAL_image_ff[117];
                        mul[4] = CAL_image_ff[118];
                        mul[5] = CAL_image_ff[119];
                        mul[6] = CAL_image_ff[133];
                        mul[7] = CAL_image_ff[134];
                        mul[8] = CAL_image_ff[135];
                    end
                    119: begin
                        mul[0] = CAL_image_ff[102];
                        mul[1] = CAL_image_ff[103];
                        mul[2] = CAL_image_ff[104];
                        mul[3] = CAL_image_ff[118];
                        mul[4] = CAL_image_ff[119];
                        mul[5] = CAL_image_ff[120];
                        mul[6] = CAL_image_ff[134];
                        mul[7] = CAL_image_ff[135];
                        mul[8] = CAL_image_ff[136];
                    end
                    120: begin
                        mul[0] = CAL_image_ff[103];
                        mul[1] = CAL_image_ff[104];
                        mul[2] = CAL_image_ff[105];
                        mul[3] = CAL_image_ff[119];
                        mul[4] = CAL_image_ff[120];
                        mul[5] = CAL_image_ff[121];
                        mul[6] = CAL_image_ff[135];
                        mul[7] = CAL_image_ff[136];
                        mul[8] = CAL_image_ff[137];
                    end
                    121: begin
                        mul[0] = CAL_image_ff[104];
                        mul[1] = CAL_image_ff[105];
                        mul[2] = CAL_image_ff[106];
                        mul[3] = CAL_image_ff[120];
                        mul[4] = CAL_image_ff[121];
                        mul[5] = CAL_image_ff[122];
                        mul[6] = CAL_image_ff[136];
                        mul[7] = CAL_image_ff[137];
                        mul[8] = CAL_image_ff[138];
                    end
                    122: begin
                        mul[0] = CAL_image_ff[105];
                        mul[1] = CAL_image_ff[106];
                        mul[2] = CAL_image_ff[107];
                        mul[3] = CAL_image_ff[121];
                        mul[4] = CAL_image_ff[122];
                        mul[5] = CAL_image_ff[123];
                        mul[6] = CAL_image_ff[137];
                        mul[7] = CAL_image_ff[138];
                        mul[8] = CAL_image_ff[139];
                    end
                    123: begin
                        mul[0] = CAL_image_ff[106];
                        mul[1] = CAL_image_ff[107];
                        mul[2] = CAL_image_ff[108];
                        mul[3] = CAL_image_ff[122];
                        mul[4] = CAL_image_ff[123];
                        mul[5] = CAL_image_ff[124];
                        mul[6] = CAL_image_ff[138];
                        mul[7] = CAL_image_ff[139];
                        mul[8] = CAL_image_ff[140];
                    end
                    124: begin
                        mul[0] = CAL_image_ff[107];
                        mul[1] = CAL_image_ff[108];
                        mul[2] = CAL_image_ff[109];
                        mul[3] = CAL_image_ff[123];
                        mul[4] = CAL_image_ff[124];
                        mul[5] = CAL_image_ff[125];
                        mul[6] = CAL_image_ff[139];
                        mul[7] = CAL_image_ff[140];
                        mul[8] = CAL_image_ff[141];
                    end
                    125: begin
                        mul[0] = CAL_image_ff[108];
                        mul[1] = CAL_image_ff[109];
                        mul[2] = CAL_image_ff[110];
                        mul[3] = CAL_image_ff[124];
                        mul[4] = CAL_image_ff[125];
                        mul[5] = CAL_image_ff[126];
                        mul[6] = CAL_image_ff[140];
                        mul[7] = CAL_image_ff[141];
                        mul[8] = CAL_image_ff[142];
                    end
                    126: begin
                        mul[0] = CAL_image_ff[109];
                        mul[1] = CAL_image_ff[110];
                        mul[2] = CAL_image_ff[111];
                        mul[3] = CAL_image_ff[125];
                        mul[4] = CAL_image_ff[126];
                        mul[5] = CAL_image_ff[127];
                        mul[6] = CAL_image_ff[141];
                        mul[7] = CAL_image_ff[142];
                        mul[8] = CAL_image_ff[143];
                    end
                    127: begin
                        mul[0] = CAL_image_ff[110];
                        mul[1] = CAL_image_ff[111];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[126];
                        mul[4] = CAL_image_ff[127];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[142];
                        mul[7] = CAL_image_ff[143];
                        mul[8] = 'd0;
                    end
                    128: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[112];
                        mul[2] = CAL_image_ff[113];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[128];
                        mul[5] = CAL_image_ff[129];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[144];
                        mul[8] = CAL_image_ff[145];
                    end
                    129: begin
                        mul[0] = CAL_image_ff[112];
                        mul[1] = CAL_image_ff[113];
                        mul[2] = CAL_image_ff[114];
                        mul[3] = CAL_image_ff[128];
                        mul[4] = CAL_image_ff[129];
                        mul[5] = CAL_image_ff[130];
                        mul[6] = CAL_image_ff[144];
                        mul[7] = CAL_image_ff[145];
                        mul[8] = CAL_image_ff[146];
                    end
                    130: begin
                        mul[0] = CAL_image_ff[113];
                        mul[1] = CAL_image_ff[114];
                        mul[2] = CAL_image_ff[115];
                        mul[3] = CAL_image_ff[129];
                        mul[4] = CAL_image_ff[130];
                        mul[5] = CAL_image_ff[131];
                        mul[6] = CAL_image_ff[145];
                        mul[7] = CAL_image_ff[146];
                        mul[8] = CAL_image_ff[147];
                    end
                    131: begin
                        mul[0] = CAL_image_ff[114];
                        mul[1] = CAL_image_ff[115];
                        mul[2] = CAL_image_ff[116];
                        mul[3] = CAL_image_ff[130];
                        mul[4] = CAL_image_ff[131];
                        mul[5] = CAL_image_ff[132];
                        mul[6] = CAL_image_ff[146];
                        mul[7] = CAL_image_ff[147];
                        mul[8] = CAL_image_ff[148];
                    end
                    132: begin
                        mul[0] = CAL_image_ff[115];
                        mul[1] = CAL_image_ff[116];
                        mul[2] = CAL_image_ff[117];
                        mul[3] = CAL_image_ff[131];
                        mul[4] = CAL_image_ff[132];
                        mul[5] = CAL_image_ff[133];
                        mul[6] = CAL_image_ff[147];
                        mul[7] = CAL_image_ff[148];
                        mul[8] = CAL_image_ff[149];
                    end
                    133: begin
                        mul[0] = CAL_image_ff[116];
                        mul[1] = CAL_image_ff[117];
                        mul[2] = CAL_image_ff[118];
                        mul[3] = CAL_image_ff[132];
                        mul[4] = CAL_image_ff[133];
                        mul[5] = CAL_image_ff[134];
                        mul[6] = CAL_image_ff[148];
                        mul[7] = CAL_image_ff[149];
                        mul[8] = CAL_image_ff[150];
                    end
                    134: begin
                        mul[0] = CAL_image_ff[117];
                        mul[1] = CAL_image_ff[118];
                        mul[2] = CAL_image_ff[119];
                        mul[3] = CAL_image_ff[133];
                        mul[4] = CAL_image_ff[134];
                        mul[5] = CAL_image_ff[135];
                        mul[6] = CAL_image_ff[149];
                        mul[7] = CAL_image_ff[150];
                        mul[8] = CAL_image_ff[151];
                    end
                    135: begin
                        mul[0] = CAL_image_ff[118];
                        mul[1] = CAL_image_ff[119];
                        mul[2] = CAL_image_ff[120];
                        mul[3] = CAL_image_ff[134];
                        mul[4] = CAL_image_ff[135];
                        mul[5] = CAL_image_ff[136];
                        mul[6] = CAL_image_ff[150];
                        mul[7] = CAL_image_ff[151];
                        mul[8] = CAL_image_ff[152];
                    end
                    136: begin
                        mul[0] = CAL_image_ff[119];
                        mul[1] = CAL_image_ff[120];
                        mul[2] = CAL_image_ff[121];
                        mul[3] = CAL_image_ff[135];
                        mul[4] = CAL_image_ff[136];
                        mul[5] = CAL_image_ff[137];
                        mul[6] = CAL_image_ff[151];
                        mul[7] = CAL_image_ff[152];
                        mul[8] = CAL_image_ff[153];
                    end
                    137: begin
                        mul[0] = CAL_image_ff[120];
                        mul[1] = CAL_image_ff[121];
                        mul[2] = CAL_image_ff[122];
                        mul[3] = CAL_image_ff[136];
                        mul[4] = CAL_image_ff[137];
                        mul[5] = CAL_image_ff[138];
                        mul[6] = CAL_image_ff[152];
                        mul[7] = CAL_image_ff[153];
                        mul[8] = CAL_image_ff[154];
                    end
                    138: begin
                        mul[0] = CAL_image_ff[121];
                        mul[1] = CAL_image_ff[122];
                        mul[2] = CAL_image_ff[123];
                        mul[3] = CAL_image_ff[137];
                        mul[4] = CAL_image_ff[138];
                        mul[5] = CAL_image_ff[139];
                        mul[6] = CAL_image_ff[153];
                        mul[7] = CAL_image_ff[154];
                        mul[8] = CAL_image_ff[155];
                    end
                    139: begin
                        mul[0] = CAL_image_ff[122];
                        mul[1] = CAL_image_ff[123];
                        mul[2] = CAL_image_ff[124];
                        mul[3] = CAL_image_ff[138];
                        mul[4] = CAL_image_ff[139];
                        mul[5] = CAL_image_ff[140];
                        mul[6] = CAL_image_ff[154];
                        mul[7] = CAL_image_ff[155];
                        mul[8] = CAL_image_ff[156];
                    end
                    140: begin
                        mul[0] = CAL_image_ff[123];
                        mul[1] = CAL_image_ff[124];
                        mul[2] = CAL_image_ff[125];
                        mul[3] = CAL_image_ff[139];
                        mul[4] = CAL_image_ff[140];
                        mul[5] = CAL_image_ff[141];
                        mul[6] = CAL_image_ff[155];
                        mul[7] = CAL_image_ff[156];
                        mul[8] = CAL_image_ff[157];
                    end
                    141: begin
                        mul[0] = CAL_image_ff[124];
                        mul[1] = CAL_image_ff[125];
                        mul[2] = CAL_image_ff[126];
                        mul[3] = CAL_image_ff[140];
                        mul[4] = CAL_image_ff[141];
                        mul[5] = CAL_image_ff[142];
                        mul[6] = CAL_image_ff[156];
                        mul[7] = CAL_image_ff[157];
                        mul[8] = CAL_image_ff[158];
                    end
                    142: begin
                        mul[0] = CAL_image_ff[125];
                        mul[1] = CAL_image_ff[126];
                        mul[2] = CAL_image_ff[127];
                        mul[3] = CAL_image_ff[141];
                        mul[4] = CAL_image_ff[142];
                        mul[5] = CAL_image_ff[143];
                        mul[6] = CAL_image_ff[157];
                        mul[7] = CAL_image_ff[158];
                        mul[8] = CAL_image_ff[159];
                    end
                    143: begin
                        mul[0] = CAL_image_ff[126];
                        mul[1] = CAL_image_ff[127];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[142];
                        mul[4] = CAL_image_ff[143];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[158];
                        mul[7] = CAL_image_ff[159];
                        mul[8] = 'd0;
                    end
                    144: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[128];
                        mul[2] = CAL_image_ff[129];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[144];
                        mul[5] = CAL_image_ff[145];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[160];
                        mul[8] = CAL_image_ff[161];
                    end
                    145: begin
                        mul[0] = CAL_image_ff[128];
                        mul[1] = CAL_image_ff[129];
                        mul[2] = CAL_image_ff[130];
                        mul[3] = CAL_image_ff[144];
                        mul[4] = CAL_image_ff[145];
                        mul[5] = CAL_image_ff[146];
                        mul[6] = CAL_image_ff[160];
                        mul[7] = CAL_image_ff[161];
                        mul[8] = CAL_image_ff[162];
                    end
                    146: begin
                        mul[0] = CAL_image_ff[129];
                        mul[1] = CAL_image_ff[130];
                        mul[2] = CAL_image_ff[131];
                        mul[3] = CAL_image_ff[145];
                        mul[4] = CAL_image_ff[146];
                        mul[5] = CAL_image_ff[147];
                        mul[6] = CAL_image_ff[161];
                        mul[7] = CAL_image_ff[162];
                        mul[8] = CAL_image_ff[163];
                    end
                    147: begin
                        mul[0] = CAL_image_ff[130];
                        mul[1] = CAL_image_ff[131];
                        mul[2] = CAL_image_ff[132];
                        mul[3] = CAL_image_ff[146];
                        mul[4] = CAL_image_ff[147];
                        mul[5] = CAL_image_ff[148];
                        mul[6] = CAL_image_ff[162];
                        mul[7] = CAL_image_ff[163];
                        mul[8] = CAL_image_ff[164];
                    end
                    148: begin
                        mul[0] = CAL_image_ff[131];
                        mul[1] = CAL_image_ff[132];
                        mul[2] = CAL_image_ff[133];
                        mul[3] = CAL_image_ff[147];
                        mul[4] = CAL_image_ff[148];
                        mul[5] = CAL_image_ff[149];
                        mul[6] = CAL_image_ff[163];
                        mul[7] = CAL_image_ff[164];
                        mul[8] = CAL_image_ff[165];
                    end
                    149: begin
                        mul[0] = CAL_image_ff[132];
                        mul[1] = CAL_image_ff[133];
                        mul[2] = CAL_image_ff[134];
                        mul[3] = CAL_image_ff[148];
                        mul[4] = CAL_image_ff[149];
                        mul[5] = CAL_image_ff[150];
                        mul[6] = CAL_image_ff[164];
                        mul[7] = CAL_image_ff[165];
                        mul[8] = CAL_image_ff[166];
                    end
                    150: begin
                        mul[0] = CAL_image_ff[133];
                        mul[1] = CAL_image_ff[134];
                        mul[2] = CAL_image_ff[135];
                        mul[3] = CAL_image_ff[149];
                        mul[4] = CAL_image_ff[150];
                        mul[5] = CAL_image_ff[151];
                        mul[6] = CAL_image_ff[165];
                        mul[7] = CAL_image_ff[166];
                        mul[8] = CAL_image_ff[167];
                    end
                    151: begin
                        mul[0] = CAL_image_ff[134];
                        mul[1] = CAL_image_ff[135];
                        mul[2] = CAL_image_ff[136];
                        mul[3] = CAL_image_ff[150];
                        mul[4] = CAL_image_ff[151];
                        mul[5] = CAL_image_ff[152];
                        mul[6] = CAL_image_ff[166];
                        mul[7] = CAL_image_ff[167];
                        mul[8] = CAL_image_ff[168];
                    end
                    152: begin
                        mul[0] = CAL_image_ff[135];
                        mul[1] = CAL_image_ff[136];
                        mul[2] = CAL_image_ff[137];
                        mul[3] = CAL_image_ff[151];
                        mul[4] = CAL_image_ff[152];
                        mul[5] = CAL_image_ff[153];
                        mul[6] = CAL_image_ff[167];
                        mul[7] = CAL_image_ff[168];
                        mul[8] = CAL_image_ff[169];
                    end
                    153: begin
                        mul[0] = CAL_image_ff[136];
                        mul[1] = CAL_image_ff[137];
                        mul[2] = CAL_image_ff[138];
                        mul[3] = CAL_image_ff[152];
                        mul[4] = CAL_image_ff[153];
                        mul[5] = CAL_image_ff[154];
                        mul[6] = CAL_image_ff[168];
                        mul[7] = CAL_image_ff[169];
                        mul[8] = CAL_image_ff[170];
                    end
                    154: begin
                        mul[0] = CAL_image_ff[137];
                        mul[1] = CAL_image_ff[138];
                        mul[2] = CAL_image_ff[139];
                        mul[3] = CAL_image_ff[153];
                        mul[4] = CAL_image_ff[154];
                        mul[5] = CAL_image_ff[155];
                        mul[6] = CAL_image_ff[169];
                        mul[7] = CAL_image_ff[170];
                        mul[8] = CAL_image_ff[171];
                    end
                    155: begin
                        mul[0] = CAL_image_ff[138];
                        mul[1] = CAL_image_ff[139];
                        mul[2] = CAL_image_ff[140];
                        mul[3] = CAL_image_ff[154];
                        mul[4] = CAL_image_ff[155];
                        mul[5] = CAL_image_ff[156];
                        mul[6] = CAL_image_ff[170];
                        mul[7] = CAL_image_ff[171];
                        mul[8] = CAL_image_ff[172];
                    end
                    156: begin
                        mul[0] = CAL_image_ff[139];
                        mul[1] = CAL_image_ff[140];
                        mul[2] = CAL_image_ff[141];
                        mul[3] = CAL_image_ff[155];
                        mul[4] = CAL_image_ff[156];
                        mul[5] = CAL_image_ff[157];
                        mul[6] = CAL_image_ff[171];
                        mul[7] = CAL_image_ff[172];
                        mul[8] = CAL_image_ff[173];
                    end
                    157: begin
                        mul[0] = CAL_image_ff[140];
                        mul[1] = CAL_image_ff[141];
                        mul[2] = CAL_image_ff[142];
                        mul[3] = CAL_image_ff[156];
                        mul[4] = CAL_image_ff[157];
                        mul[5] = CAL_image_ff[158];
                        mul[6] = CAL_image_ff[172];
                        mul[7] = CAL_image_ff[173];
                        mul[8] = CAL_image_ff[174];
                    end
                    158: begin
                        mul[0] = CAL_image_ff[141];
                        mul[1] = CAL_image_ff[142];
                        mul[2] = CAL_image_ff[143];
                        mul[3] = CAL_image_ff[157];
                        mul[4] = CAL_image_ff[158];
                        mul[5] = CAL_image_ff[159];
                        mul[6] = CAL_image_ff[173];
                        mul[7] = CAL_image_ff[174];
                        mul[8] = CAL_image_ff[175];
                    end
                    159: begin
                        mul[0] = CAL_image_ff[142];
                        mul[1] = CAL_image_ff[143];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[158];
                        mul[4] = CAL_image_ff[159];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[174];
                        mul[7] = CAL_image_ff[175];
                        mul[8] = 'd0;
                    end
                    160: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[144];
                        mul[2] = CAL_image_ff[145];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[160];
                        mul[5] = CAL_image_ff[161];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[176];
                        mul[8] = CAL_image_ff[177];
                    end
                    161: begin
                        mul[0] = CAL_image_ff[144];
                        mul[1] = CAL_image_ff[145];
                        mul[2] = CAL_image_ff[146];
                        mul[3] = CAL_image_ff[160];
                        mul[4] = CAL_image_ff[161];
                        mul[5] = CAL_image_ff[162];
                        mul[6] = CAL_image_ff[176];
                        mul[7] = CAL_image_ff[177];
                        mul[8] = CAL_image_ff[178];
                    end
                    162: begin
                        mul[0] = CAL_image_ff[145];
                        mul[1] = CAL_image_ff[146];
                        mul[2] = CAL_image_ff[147];
                        mul[3] = CAL_image_ff[161];
                        mul[4] = CAL_image_ff[162];
                        mul[5] = CAL_image_ff[163];
                        mul[6] = CAL_image_ff[177];
                        mul[7] = CAL_image_ff[178];
                        mul[8] = CAL_image_ff[179];
                    end
                    163: begin
                        mul[0] = CAL_image_ff[146];
                        mul[1] = CAL_image_ff[147];
                        mul[2] = CAL_image_ff[148];
                        mul[3] = CAL_image_ff[162];
                        mul[4] = CAL_image_ff[163];
                        mul[5] = CAL_image_ff[164];
                        mul[6] = CAL_image_ff[178];
                        mul[7] = CAL_image_ff[179];
                        mul[8] = CAL_image_ff[180];
                    end
                    164: begin
                        mul[0] = CAL_image_ff[147];
                        mul[1] = CAL_image_ff[148];
                        mul[2] = CAL_image_ff[149];
                        mul[3] = CAL_image_ff[163];
                        mul[4] = CAL_image_ff[164];
                        mul[5] = CAL_image_ff[165];
                        mul[6] = CAL_image_ff[179];
                        mul[7] = CAL_image_ff[180];
                        mul[8] = CAL_image_ff[181];
                    end
                    165: begin
                        mul[0] = CAL_image_ff[148];
                        mul[1] = CAL_image_ff[149];
                        mul[2] = CAL_image_ff[150];
                        mul[3] = CAL_image_ff[164];
                        mul[4] = CAL_image_ff[165];
                        mul[5] = CAL_image_ff[166];
                        mul[6] = CAL_image_ff[180];
                        mul[7] = CAL_image_ff[181];
                        mul[8] = CAL_image_ff[182];
                    end
                    166: begin
                        mul[0] = CAL_image_ff[149];
                        mul[1] = CAL_image_ff[150];
                        mul[2] = CAL_image_ff[151];
                        mul[3] = CAL_image_ff[165];
                        mul[4] = CAL_image_ff[166];
                        mul[5] = CAL_image_ff[167];
                        mul[6] = CAL_image_ff[181];
                        mul[7] = CAL_image_ff[182];
                        mul[8] = CAL_image_ff[183];
                    end
                    167: begin
                        mul[0] = CAL_image_ff[150];
                        mul[1] = CAL_image_ff[151];
                        mul[2] = CAL_image_ff[152];
                        mul[3] = CAL_image_ff[166];
                        mul[4] = CAL_image_ff[167];
                        mul[5] = CAL_image_ff[168];
                        mul[6] = CAL_image_ff[182];
                        mul[7] = CAL_image_ff[183];
                        mul[8] = CAL_image_ff[184];
                    end
                    168: begin
                        mul[0] = CAL_image_ff[151];
                        mul[1] = CAL_image_ff[152];
                        mul[2] = CAL_image_ff[153];
                        mul[3] = CAL_image_ff[167];
                        mul[4] = CAL_image_ff[168];
                        mul[5] = CAL_image_ff[169];
                        mul[6] = CAL_image_ff[183];
                        mul[7] = CAL_image_ff[184];
                        mul[8] = CAL_image_ff[185];
                    end
                    169: begin
                        mul[0] = CAL_image_ff[152];
                        mul[1] = CAL_image_ff[153];
                        mul[2] = CAL_image_ff[154];
                        mul[3] = CAL_image_ff[168];
                        mul[4] = CAL_image_ff[169];
                        mul[5] = CAL_image_ff[170];
                        mul[6] = CAL_image_ff[184];
                        mul[7] = CAL_image_ff[185];
                        mul[8] = CAL_image_ff[186];
                    end
                    170: begin
                        mul[0] = CAL_image_ff[153];
                        mul[1] = CAL_image_ff[154];
                        mul[2] = CAL_image_ff[155];
                        mul[3] = CAL_image_ff[169];
                        mul[4] = CAL_image_ff[170];
                        mul[5] = CAL_image_ff[171];
                        mul[6] = CAL_image_ff[185];
                        mul[7] = CAL_image_ff[186];
                        mul[8] = CAL_image_ff[187];
                    end
                    171: begin
                        mul[0] = CAL_image_ff[154];
                        mul[1] = CAL_image_ff[155];
                        mul[2] = CAL_image_ff[156];
                        mul[3] = CAL_image_ff[170];
                        mul[4] = CAL_image_ff[171];
                        mul[5] = CAL_image_ff[172];
                        mul[6] = CAL_image_ff[186];
                        mul[7] = CAL_image_ff[187];
                        mul[8] = CAL_image_ff[188];
                    end
                    172: begin
                        mul[0] = CAL_image_ff[155];
                        mul[1] = CAL_image_ff[156];
                        mul[2] = CAL_image_ff[157];
                        mul[3] = CAL_image_ff[171];
                        mul[4] = CAL_image_ff[172];
                        mul[5] = CAL_image_ff[173];
                        mul[6] = CAL_image_ff[187];
                        mul[7] = CAL_image_ff[188];
                        mul[8] = CAL_image_ff[189];
                    end
                    173: begin
                        mul[0] = CAL_image_ff[156];
                        mul[1] = CAL_image_ff[157];
                        mul[2] = CAL_image_ff[158];
                        mul[3] = CAL_image_ff[172];
                        mul[4] = CAL_image_ff[173];
                        mul[5] = CAL_image_ff[174];
                        mul[6] = CAL_image_ff[188];
                        mul[7] = CAL_image_ff[189];
                        mul[8] = CAL_image_ff[190];
                    end
                    174: begin
                        mul[0] = CAL_image_ff[157];
                        mul[1] = CAL_image_ff[158];
                        mul[2] = CAL_image_ff[159];
                        mul[3] = CAL_image_ff[173];
                        mul[4] = CAL_image_ff[174];
                        mul[5] = CAL_image_ff[175];
                        mul[6] = CAL_image_ff[189];
                        mul[7] = CAL_image_ff[190];
                        mul[8] = CAL_image_ff[191];
                    end
                    175: begin
                        mul[0] = CAL_image_ff[158];
                        mul[1] = CAL_image_ff[159];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[174];
                        mul[4] = CAL_image_ff[175];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[190];
                        mul[7] = CAL_image_ff[191];
                        mul[8] = 'd0;
                    end
                    176: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[160];
                        mul[2] = CAL_image_ff[161];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[176];
                        mul[5] = CAL_image_ff[177];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[192];
                        mul[8] = CAL_image_ff[193];
                    end
                    177: begin
                        mul[0] = CAL_image_ff[160];
                        mul[1] = CAL_image_ff[161];
                        mul[2] = CAL_image_ff[162];
                        mul[3] = CAL_image_ff[176];
                        mul[4] = CAL_image_ff[177];
                        mul[5] = CAL_image_ff[178];
                        mul[6] = CAL_image_ff[192];
                        mul[7] = CAL_image_ff[193];
                        mul[8] = CAL_image_ff[194];
                    end
                    178: begin
                        mul[0] = CAL_image_ff[161];
                        mul[1] = CAL_image_ff[162];
                        mul[2] = CAL_image_ff[163];
                        mul[3] = CAL_image_ff[177];
                        mul[4] = CAL_image_ff[178];
                        mul[5] = CAL_image_ff[179];
                        mul[6] = CAL_image_ff[193];
                        mul[7] = CAL_image_ff[194];
                        mul[8] = CAL_image_ff[195];
                    end
                    179: begin
                        mul[0] = CAL_image_ff[162];
                        mul[1] = CAL_image_ff[163];
                        mul[2] = CAL_image_ff[164];
                        mul[3] = CAL_image_ff[178];
                        mul[4] = CAL_image_ff[179];
                        mul[5] = CAL_image_ff[180];
                        mul[6] = CAL_image_ff[194];
                        mul[7] = CAL_image_ff[195];
                        mul[8] = CAL_image_ff[196];
                    end
                    180: begin
                        mul[0] = CAL_image_ff[163];
                        mul[1] = CAL_image_ff[164];
                        mul[2] = CAL_image_ff[165];
                        mul[3] = CAL_image_ff[179];
                        mul[4] = CAL_image_ff[180];
                        mul[5] = CAL_image_ff[181];
                        mul[6] = CAL_image_ff[195];
                        mul[7] = CAL_image_ff[196];
                        mul[8] = CAL_image_ff[197];
                    end
                    181: begin
                        mul[0] = CAL_image_ff[164];
                        mul[1] = CAL_image_ff[165];
                        mul[2] = CAL_image_ff[166];
                        mul[3] = CAL_image_ff[180];
                        mul[4] = CAL_image_ff[181];
                        mul[5] = CAL_image_ff[182];
                        mul[6] = CAL_image_ff[196];
                        mul[7] = CAL_image_ff[197];
                        mul[8] = CAL_image_ff[198];
                    end
                    182: begin
                        mul[0] = CAL_image_ff[165];
                        mul[1] = CAL_image_ff[166];
                        mul[2] = CAL_image_ff[167];
                        mul[3] = CAL_image_ff[181];
                        mul[4] = CAL_image_ff[182];
                        mul[5] = CAL_image_ff[183];
                        mul[6] = CAL_image_ff[197];
                        mul[7] = CAL_image_ff[198];
                        mul[8] = CAL_image_ff[199];
                    end
                    183: begin
                        mul[0] = CAL_image_ff[166];
                        mul[1] = CAL_image_ff[167];
                        mul[2] = CAL_image_ff[168];
                        mul[3] = CAL_image_ff[182];
                        mul[4] = CAL_image_ff[183];
                        mul[5] = CAL_image_ff[184];
                        mul[6] = CAL_image_ff[198];
                        mul[7] = CAL_image_ff[199];
                        mul[8] = CAL_image_ff[200];
                    end
                    184: begin
                        mul[0] = CAL_image_ff[167];
                        mul[1] = CAL_image_ff[168];
                        mul[2] = CAL_image_ff[169];
                        mul[3] = CAL_image_ff[183];
                        mul[4] = CAL_image_ff[184];
                        mul[5] = CAL_image_ff[185];
                        mul[6] = CAL_image_ff[199];
                        mul[7] = CAL_image_ff[200];
                        mul[8] = CAL_image_ff[201];
                    end
                    185: begin
                        mul[0] = CAL_image_ff[168];
                        mul[1] = CAL_image_ff[169];
                        mul[2] = CAL_image_ff[170];
                        mul[3] = CAL_image_ff[184];
                        mul[4] = CAL_image_ff[185];
                        mul[5] = CAL_image_ff[186];
                        mul[6] = CAL_image_ff[200];
                        mul[7] = CAL_image_ff[201];
                        mul[8] = CAL_image_ff[202];
                    end
                    186: begin
                        mul[0] = CAL_image_ff[169];
                        mul[1] = CAL_image_ff[170];
                        mul[2] = CAL_image_ff[171];
                        mul[3] = CAL_image_ff[185];
                        mul[4] = CAL_image_ff[186];
                        mul[5] = CAL_image_ff[187];
                        mul[6] = CAL_image_ff[201];
                        mul[7] = CAL_image_ff[202];
                        mul[8] = CAL_image_ff[203];
                    end
                    187: begin
                        mul[0] = CAL_image_ff[170];
                        mul[1] = CAL_image_ff[171];
                        mul[2] = CAL_image_ff[172];
                        mul[3] = CAL_image_ff[186];
                        mul[4] = CAL_image_ff[187];
                        mul[5] = CAL_image_ff[188];
                        mul[6] = CAL_image_ff[202];
                        mul[7] = CAL_image_ff[203];
                        mul[8] = CAL_image_ff[204];
                    end
                    188: begin
                        mul[0] = CAL_image_ff[171];
                        mul[1] = CAL_image_ff[172];
                        mul[2] = CAL_image_ff[173];
                        mul[3] = CAL_image_ff[187];
                        mul[4] = CAL_image_ff[188];
                        mul[5] = CAL_image_ff[189];
                        mul[6] = CAL_image_ff[203];
                        mul[7] = CAL_image_ff[204];
                        mul[8] = CAL_image_ff[205];
                    end
                    189: begin
                        mul[0] = CAL_image_ff[172];
                        mul[1] = CAL_image_ff[173];
                        mul[2] = CAL_image_ff[174];
                        mul[3] = CAL_image_ff[188];
                        mul[4] = CAL_image_ff[189];
                        mul[5] = CAL_image_ff[190];
                        mul[6] = CAL_image_ff[204];
                        mul[7] = CAL_image_ff[205];
                        mul[8] = CAL_image_ff[206];
                    end
                    190: begin
                        mul[0] = CAL_image_ff[173];
                        mul[1] = CAL_image_ff[174];
                        mul[2] = CAL_image_ff[175];
                        mul[3] = CAL_image_ff[189];
                        mul[4] = CAL_image_ff[190];
                        mul[5] = CAL_image_ff[191];
                        mul[6] = CAL_image_ff[205];
                        mul[7] = CAL_image_ff[206];
                        mul[8] = CAL_image_ff[207];
                    end
                    191: begin
                        mul[0] = CAL_image_ff[174];
                        mul[1] = CAL_image_ff[175];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[190];
                        mul[4] = CAL_image_ff[191];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[206];
                        mul[7] = CAL_image_ff[207];
                        mul[8] = 'd0;
                    end
                    192: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[176];
                        mul[2] = CAL_image_ff[177];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[192];
                        mul[5] = CAL_image_ff[193];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[208];
                        mul[8] = CAL_image_ff[209];
                    end
                    193: begin
                        mul[0] = CAL_image_ff[176];
                        mul[1] = CAL_image_ff[177];
                        mul[2] = CAL_image_ff[178];
                        mul[3] = CAL_image_ff[192];
                        mul[4] = CAL_image_ff[193];
                        mul[5] = CAL_image_ff[194];
                        mul[6] = CAL_image_ff[208];
                        mul[7] = CAL_image_ff[209];
                        mul[8] = CAL_image_ff[210];
                    end
                    194: begin
                        mul[0] = CAL_image_ff[177];
                        mul[1] = CAL_image_ff[178];
                        mul[2] = CAL_image_ff[179];
                        mul[3] = CAL_image_ff[193];
                        mul[4] = CAL_image_ff[194];
                        mul[5] = CAL_image_ff[195];
                        mul[6] = CAL_image_ff[209];
                        mul[7] = CAL_image_ff[210];
                        mul[8] = CAL_image_ff[211];
                    end
                    195: begin
                        mul[0] = CAL_image_ff[178];
                        mul[1] = CAL_image_ff[179];
                        mul[2] = CAL_image_ff[180];
                        mul[3] = CAL_image_ff[194];
                        mul[4] = CAL_image_ff[195];
                        mul[5] = CAL_image_ff[196];
                        mul[6] = CAL_image_ff[210];
                        mul[7] = CAL_image_ff[211];
                        mul[8] = CAL_image_ff[212];
                    end
                    196: begin
                        mul[0] = CAL_image_ff[179];
                        mul[1] = CAL_image_ff[180];
                        mul[2] = CAL_image_ff[181];
                        mul[3] = CAL_image_ff[195];
                        mul[4] = CAL_image_ff[196];
                        mul[5] = CAL_image_ff[197];
                        mul[6] = CAL_image_ff[211];
                        mul[7] = CAL_image_ff[212];
                        mul[8] = CAL_image_ff[213];
                    end
                    197: begin
                        mul[0] = CAL_image_ff[180];
                        mul[1] = CAL_image_ff[181];
                        mul[2] = CAL_image_ff[182];
                        mul[3] = CAL_image_ff[196];
                        mul[4] = CAL_image_ff[197];
                        mul[5] = CAL_image_ff[198];
                        mul[6] = CAL_image_ff[212];
                        mul[7] = CAL_image_ff[213];
                        mul[8] = CAL_image_ff[214];
                    end
                    198: begin
                        mul[0] = CAL_image_ff[181];
                        mul[1] = CAL_image_ff[182];
                        mul[2] = CAL_image_ff[183];
                        mul[3] = CAL_image_ff[197];
                        mul[4] = CAL_image_ff[198];
                        mul[5] = CAL_image_ff[199];
                        mul[6] = CAL_image_ff[213];
                        mul[7] = CAL_image_ff[214];
                        mul[8] = CAL_image_ff[215];
                    end
                    199: begin
                        mul[0] = CAL_image_ff[182];
                        mul[1] = CAL_image_ff[183];
                        mul[2] = CAL_image_ff[184];
                        mul[3] = CAL_image_ff[198];
                        mul[4] = CAL_image_ff[199];
                        mul[5] = CAL_image_ff[200];
                        mul[6] = CAL_image_ff[214];
                        mul[7] = CAL_image_ff[215];
                        mul[8] = CAL_image_ff[216];
                    end
                    200: begin
                        mul[0] = CAL_image_ff[183];
                        mul[1] = CAL_image_ff[184];
                        mul[2] = CAL_image_ff[185];
                        mul[3] = CAL_image_ff[199];
                        mul[4] = CAL_image_ff[200];
                        mul[5] = CAL_image_ff[201];
                        mul[6] = CAL_image_ff[215];
                        mul[7] = CAL_image_ff[216];
                        mul[8] = CAL_image_ff[217];
                    end
                    201: begin
                        mul[0] = CAL_image_ff[184];
                        mul[1] = CAL_image_ff[185];
                        mul[2] = CAL_image_ff[186];
                        mul[3] = CAL_image_ff[200];
                        mul[4] = CAL_image_ff[201];
                        mul[5] = CAL_image_ff[202];
                        mul[6] = CAL_image_ff[216];
                        mul[7] = CAL_image_ff[217];
                        mul[8] = CAL_image_ff[218];
                    end
                    202: begin
                        mul[0] = CAL_image_ff[185];
                        mul[1] = CAL_image_ff[186];
                        mul[2] = CAL_image_ff[187];
                        mul[3] = CAL_image_ff[201];
                        mul[4] = CAL_image_ff[202];
                        mul[5] = CAL_image_ff[203];
                        mul[6] = CAL_image_ff[217];
                        mul[7] = CAL_image_ff[218];
                        mul[8] = CAL_image_ff[219];
                    end
                    203: begin
                        mul[0] = CAL_image_ff[186];
                        mul[1] = CAL_image_ff[187];
                        mul[2] = CAL_image_ff[188];
                        mul[3] = CAL_image_ff[202];
                        mul[4] = CAL_image_ff[203];
                        mul[5] = CAL_image_ff[204];
                        mul[6] = CAL_image_ff[218];
                        mul[7] = CAL_image_ff[219];
                        mul[8] = CAL_image_ff[220];
                    end
                    204: begin
                        mul[0] = CAL_image_ff[187];
                        mul[1] = CAL_image_ff[188];
                        mul[2] = CAL_image_ff[189];
                        mul[3] = CAL_image_ff[203];
                        mul[4] = CAL_image_ff[204];
                        mul[5] = CAL_image_ff[205];
                        mul[6] = CAL_image_ff[219];
                        mul[7] = CAL_image_ff[220];
                        mul[8] = CAL_image_ff[221];
                    end
                    205: begin
                        mul[0] = CAL_image_ff[188];
                        mul[1] = CAL_image_ff[189];
                        mul[2] = CAL_image_ff[190];
                        mul[3] = CAL_image_ff[204];
                        mul[4] = CAL_image_ff[205];
                        mul[5] = CAL_image_ff[206];
                        mul[6] = CAL_image_ff[220];
                        mul[7] = CAL_image_ff[221];
                        mul[8] = CAL_image_ff[222];
                    end
                    206: begin
                        mul[0] = CAL_image_ff[189];
                        mul[1] = CAL_image_ff[190];
                        mul[2] = CAL_image_ff[191];
                        mul[3] = CAL_image_ff[205];
                        mul[4] = CAL_image_ff[206];
                        mul[5] = CAL_image_ff[207];
                        mul[6] = CAL_image_ff[221];
                        mul[7] = CAL_image_ff[222];
                        mul[8] = CAL_image_ff[223];
                    end
                    207: begin
                        mul[0] = CAL_image_ff[190];
                        mul[1] = CAL_image_ff[191];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[206];
                        mul[4] = CAL_image_ff[207];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[222];
                        mul[7] = CAL_image_ff[223];
                        mul[8] = 'd0;
                    end
                    208: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[192];
                        mul[2] = CAL_image_ff[193];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[208];
                        mul[5] = CAL_image_ff[209];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[224];
                        mul[8] = CAL_image_ff[225];
                    end
                    209: begin
                        mul[0] = CAL_image_ff[192];
                        mul[1] = CAL_image_ff[193];
                        mul[2] = CAL_image_ff[194];
                        mul[3] = CAL_image_ff[208];
                        mul[4] = CAL_image_ff[209];
                        mul[5] = CAL_image_ff[210];
                        mul[6] = CAL_image_ff[224];
                        mul[7] = CAL_image_ff[225];
                        mul[8] = CAL_image_ff[226];
                    end
                    210: begin
                        mul[0] = CAL_image_ff[193];
                        mul[1] = CAL_image_ff[194];
                        mul[2] = CAL_image_ff[195];
                        mul[3] = CAL_image_ff[209];
                        mul[4] = CAL_image_ff[210];
                        mul[5] = CAL_image_ff[211];
                        mul[6] = CAL_image_ff[225];
                        mul[7] = CAL_image_ff[226];
                        mul[8] = CAL_image_ff[227];
                    end
                    211: begin
                        mul[0] = CAL_image_ff[194];
                        mul[1] = CAL_image_ff[195];
                        mul[2] = CAL_image_ff[196];
                        mul[3] = CAL_image_ff[210];
                        mul[4] = CAL_image_ff[211];
                        mul[5] = CAL_image_ff[212];
                        mul[6] = CAL_image_ff[226];
                        mul[7] = CAL_image_ff[227];
                        mul[8] = CAL_image_ff[228];
                    end
                    212: begin
                        mul[0] = CAL_image_ff[195];
                        mul[1] = CAL_image_ff[196];
                        mul[2] = CAL_image_ff[197];
                        mul[3] = CAL_image_ff[211];
                        mul[4] = CAL_image_ff[212];
                        mul[5] = CAL_image_ff[213];
                        mul[6] = CAL_image_ff[227];
                        mul[7] = CAL_image_ff[228];
                        mul[8] = CAL_image_ff[229];
                    end
                    213: begin
                        mul[0] = CAL_image_ff[196];
                        mul[1] = CAL_image_ff[197];
                        mul[2] = CAL_image_ff[198];
                        mul[3] = CAL_image_ff[212];
                        mul[4] = CAL_image_ff[213];
                        mul[5] = CAL_image_ff[214];
                        mul[6] = CAL_image_ff[228];
                        mul[7] = CAL_image_ff[229];
                        mul[8] = CAL_image_ff[230];
                    end
                    214: begin
                        mul[0] = CAL_image_ff[197];
                        mul[1] = CAL_image_ff[198];
                        mul[2] = CAL_image_ff[199];
                        mul[3] = CAL_image_ff[213];
                        mul[4] = CAL_image_ff[214];
                        mul[5] = CAL_image_ff[215];
                        mul[6] = CAL_image_ff[229];
                        mul[7] = CAL_image_ff[230];
                        mul[8] = CAL_image_ff[231];
                    end
                    215: begin
                        mul[0] = CAL_image_ff[198];
                        mul[1] = CAL_image_ff[199];
                        mul[2] = CAL_image_ff[200];
                        mul[3] = CAL_image_ff[214];
                        mul[4] = CAL_image_ff[215];
                        mul[5] = CAL_image_ff[216];
                        mul[6] = CAL_image_ff[230];
                        mul[7] = CAL_image_ff[231];
                        mul[8] = CAL_image_ff[232];
                    end
                    216: begin
                        mul[0] = CAL_image_ff[199];
                        mul[1] = CAL_image_ff[200];
                        mul[2] = CAL_image_ff[201];
                        mul[3] = CAL_image_ff[215];
                        mul[4] = CAL_image_ff[216];
                        mul[5] = CAL_image_ff[217];
                        mul[6] = CAL_image_ff[231];
                        mul[7] = CAL_image_ff[232];
                        mul[8] = CAL_image_ff[233];
                    end
                    217: begin
                        mul[0] = CAL_image_ff[200];
                        mul[1] = CAL_image_ff[201];
                        mul[2] = CAL_image_ff[202];
                        mul[3] = CAL_image_ff[216];
                        mul[4] = CAL_image_ff[217];
                        mul[5] = CAL_image_ff[218];
                        mul[6] = CAL_image_ff[232];
                        mul[7] = CAL_image_ff[233];
                        mul[8] = CAL_image_ff[234];
                    end
                    218: begin
                        mul[0] = CAL_image_ff[201];
                        mul[1] = CAL_image_ff[202];
                        mul[2] = CAL_image_ff[203];
                        mul[3] = CAL_image_ff[217];
                        mul[4] = CAL_image_ff[218];
                        mul[5] = CAL_image_ff[219];
                        mul[6] = CAL_image_ff[233];
                        mul[7] = CAL_image_ff[234];
                        mul[8] = CAL_image_ff[235];
                    end
                    219: begin
                        mul[0] = CAL_image_ff[202];
                        mul[1] = CAL_image_ff[203];
                        mul[2] = CAL_image_ff[204];
                        mul[3] = CAL_image_ff[218];
                        mul[4] = CAL_image_ff[219];
                        mul[5] = CAL_image_ff[220];
                        mul[6] = CAL_image_ff[234];
                        mul[7] = CAL_image_ff[235];
                        mul[8] = CAL_image_ff[236];
                    end
                    220: begin
                        mul[0] = CAL_image_ff[203];
                        mul[1] = CAL_image_ff[204];
                        mul[2] = CAL_image_ff[205];
                        mul[3] = CAL_image_ff[219];
                        mul[4] = CAL_image_ff[220];
                        mul[5] = CAL_image_ff[221];
                        mul[6] = CAL_image_ff[235];
                        mul[7] = CAL_image_ff[236];
                        mul[8] = CAL_image_ff[237];
                    end
                    221: begin
                        mul[0] = CAL_image_ff[204];
                        mul[1] = CAL_image_ff[205];
                        mul[2] = CAL_image_ff[206];
                        mul[3] = CAL_image_ff[220];
                        mul[4] = CAL_image_ff[221];
                        mul[5] = CAL_image_ff[222];
                        mul[6] = CAL_image_ff[236];
                        mul[7] = CAL_image_ff[237];
                        mul[8] = CAL_image_ff[238];
                    end
                    222: begin
                        mul[0] = CAL_image_ff[205];
                        mul[1] = CAL_image_ff[206];
                        mul[2] = CAL_image_ff[207];
                        mul[3] = CAL_image_ff[221];
                        mul[4] = CAL_image_ff[222];
                        mul[5] = CAL_image_ff[223];
                        mul[6] = CAL_image_ff[237];
                        mul[7] = CAL_image_ff[238];
                        mul[8] = CAL_image_ff[239];
                    end
                    223: begin
                        mul[0] = CAL_image_ff[206];
                        mul[1] = CAL_image_ff[207];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[222];
                        mul[4] = CAL_image_ff[223];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[238];
                        mul[7] = CAL_image_ff[239];
                        mul[8] = 'd0;
                    end
                    224: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[208];
                        mul[2] = CAL_image_ff[209];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[224];
                        mul[5] = CAL_image_ff[225];
                        mul[6] = 'd0;
                        mul[7] = CAL_image_ff[240];
                        mul[8] = CAL_image_ff[241];
                    end
                    225: begin
                        mul[0] = CAL_image_ff[208];
                        mul[1] = CAL_image_ff[209];
                        mul[2] = CAL_image_ff[210];
                        mul[3] = CAL_image_ff[224];
                        mul[4] = CAL_image_ff[225];
                        mul[5] = CAL_image_ff[226];
                        mul[6] = CAL_image_ff[240];
                        mul[7] = CAL_image_ff[241];
                        mul[8] = CAL_image_ff[242];
                    end
                    226: begin
                        mul[0] = CAL_image_ff[209];
                        mul[1] = CAL_image_ff[210];
                        mul[2] = CAL_image_ff[211];
                        mul[3] = CAL_image_ff[225];
                        mul[4] = CAL_image_ff[226];
                        mul[5] = CAL_image_ff[227];
                        mul[6] = CAL_image_ff[241];
                        mul[7] = CAL_image_ff[242];
                        mul[8] = CAL_image_ff[243];
                    end
                    227: begin
                        mul[0] = CAL_image_ff[210];
                        mul[1] = CAL_image_ff[211];
                        mul[2] = CAL_image_ff[212];
                        mul[3] = CAL_image_ff[226];
                        mul[4] = CAL_image_ff[227];
                        mul[5] = CAL_image_ff[228];
                        mul[6] = CAL_image_ff[242];
                        mul[7] = CAL_image_ff[243];
                        mul[8] = CAL_image_ff[244];
                    end
                    228: begin
                        mul[0] = CAL_image_ff[211];
                        mul[1] = CAL_image_ff[212];
                        mul[2] = CAL_image_ff[213];
                        mul[3] = CAL_image_ff[227];
                        mul[4] = CAL_image_ff[228];
                        mul[5] = CAL_image_ff[229];
                        mul[6] = CAL_image_ff[243];
                        mul[7] = CAL_image_ff[244];
                        mul[8] = CAL_image_ff[245];
                    end
                    229: begin
                        mul[0] = CAL_image_ff[212];
                        mul[1] = CAL_image_ff[213];
                        mul[2] = CAL_image_ff[214];
                        mul[3] = CAL_image_ff[228];
                        mul[4] = CAL_image_ff[229];
                        mul[5] = CAL_image_ff[230];
                        mul[6] = CAL_image_ff[244];
                        mul[7] = CAL_image_ff[245];
                        mul[8] = CAL_image_ff[246];
                    end
                    230: begin
                        mul[0] = CAL_image_ff[213];
                        mul[1] = CAL_image_ff[214];
                        mul[2] = CAL_image_ff[215];
                        mul[3] = CAL_image_ff[229];
                        mul[4] = CAL_image_ff[230];
                        mul[5] = CAL_image_ff[231];
                        mul[6] = CAL_image_ff[245];
                        mul[7] = CAL_image_ff[246];
                        mul[8] = CAL_image_ff[247];
                    end
                    231: begin
                        mul[0] = CAL_image_ff[214];
                        mul[1] = CAL_image_ff[215];
                        mul[2] = CAL_image_ff[216];
                        mul[3] = CAL_image_ff[230];
                        mul[4] = CAL_image_ff[231];
                        mul[5] = CAL_image_ff[232];
                        mul[6] = CAL_image_ff[246];
                        mul[7] = CAL_image_ff[247];
                        mul[8] = CAL_image_ff[248];
                    end
                    232: begin
                        mul[0] = CAL_image_ff[215];
                        mul[1] = CAL_image_ff[216];
                        mul[2] = CAL_image_ff[217];
                        mul[3] = CAL_image_ff[231];
                        mul[4] = CAL_image_ff[232];
                        mul[5] = CAL_image_ff[233];
                        mul[6] = CAL_image_ff[247];
                        mul[7] = CAL_image_ff[248];
                        mul[8] = CAL_image_ff[249];
                    end
                    233: begin
                        mul[0] = CAL_image_ff[216];
                        mul[1] = CAL_image_ff[217];
                        mul[2] = CAL_image_ff[218];
                        mul[3] = CAL_image_ff[232];
                        mul[4] = CAL_image_ff[233];
                        mul[5] = CAL_image_ff[234];
                        mul[6] = CAL_image_ff[248];
                        mul[7] = CAL_image_ff[249];
                        mul[8] = CAL_image_ff[250];
                    end
                    234: begin
                        mul[0] = CAL_image_ff[217];
                        mul[1] = CAL_image_ff[218];
                        mul[2] = CAL_image_ff[219];
                        mul[3] = CAL_image_ff[233];
                        mul[4] = CAL_image_ff[234];
                        mul[5] = CAL_image_ff[235];
                        mul[6] = CAL_image_ff[249];
                        mul[7] = CAL_image_ff[250];
                        mul[8] = CAL_image_ff[251];
                    end
                    235: begin
                        mul[0] = CAL_image_ff[218];
                        mul[1] = CAL_image_ff[219];
                        mul[2] = CAL_image_ff[220];
                        mul[3] = CAL_image_ff[234];
                        mul[4] = CAL_image_ff[235];
                        mul[5] = CAL_image_ff[236];
                        mul[6] = CAL_image_ff[250];
                        mul[7] = CAL_image_ff[251];
                        mul[8] = CAL_image_ff[252];
                    end
                    236: begin
                        mul[0] = CAL_image_ff[219];
                        mul[1] = CAL_image_ff[220];
                        mul[2] = CAL_image_ff[221];
                        mul[3] = CAL_image_ff[235];
                        mul[4] = CAL_image_ff[236];
                        mul[5] = CAL_image_ff[237];
                        mul[6] = CAL_image_ff[251];
                        mul[7] = CAL_image_ff[252];
                        mul[8] = CAL_image_ff[253];
                    end
                    237: begin
                        mul[0] = CAL_image_ff[220];
                        mul[1] = CAL_image_ff[221];
                        mul[2] = CAL_image_ff[222];
                        mul[3] = CAL_image_ff[236];
                        mul[4] = CAL_image_ff[237];
                        mul[5] = CAL_image_ff[238];
                        mul[6] = CAL_image_ff[252];
                        mul[7] = CAL_image_ff[253];
                        mul[8] = CAL_image_ff[254];
                    end
                    238: begin
                        mul[0] = CAL_image_ff[221];
                        mul[1] = CAL_image_ff[222];
                        mul[2] = CAL_image_ff[223];
                        mul[3] = CAL_image_ff[237];
                        mul[4] = CAL_image_ff[238];
                        mul[5] = CAL_image_ff[239];
                        mul[6] = CAL_image_ff[253];
                        mul[7] = CAL_image_ff[254];
                        mul[8] = CAL_image_ff[255];
                    end
                    239: begin
                        mul[0] = CAL_image_ff[222];
                        mul[1] = CAL_image_ff[223];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[238];
                        mul[4] = CAL_image_ff[239];
                        mul[5] = 'd0;
                        mul[6] = CAL_image_ff[254];
                        mul[7] = CAL_image_ff[255];
                        mul[8] = 'd0;
                    end
                    240: begin
                        mul[0] = 'd0;
                        mul[1] = CAL_image_ff[224];
                        mul[2] = CAL_image_ff[225];
                        mul[3] = 'd0;
                        mul[4] = CAL_image_ff[240];
                        mul[5] = CAL_image_ff[241];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    241: begin
                        mul[0] = CAL_image_ff[224];
                        mul[1] = CAL_image_ff[225];
                        mul[2] = CAL_image_ff[226];
                        mul[3] = CAL_image_ff[240];
                        mul[4] = CAL_image_ff[241];
                        mul[5] = CAL_image_ff[242];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    242: begin
                        mul[0] = CAL_image_ff[225];
                        mul[1] = CAL_image_ff[226];
                        mul[2] = CAL_image_ff[227];
                        mul[3] = CAL_image_ff[241];
                        mul[4] = CAL_image_ff[242];
                        mul[5] = CAL_image_ff[243];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    243: begin
                        mul[0] = CAL_image_ff[226];
                        mul[1] = CAL_image_ff[227];
                        mul[2] = CAL_image_ff[228];
                        mul[3] = CAL_image_ff[242];
                        mul[4] = CAL_image_ff[243];
                        mul[5] = CAL_image_ff[244];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    244: begin
                        mul[0] = CAL_image_ff[227];
                        mul[1] = CAL_image_ff[228];
                        mul[2] = CAL_image_ff[229];
                        mul[3] = CAL_image_ff[243];
                        mul[4] = CAL_image_ff[244];
                        mul[5] = CAL_image_ff[245];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    245: begin
                        mul[0] = CAL_image_ff[228];
                        mul[1] = CAL_image_ff[229];
                        mul[2] = CAL_image_ff[230];
                        mul[3] = CAL_image_ff[244];
                        mul[4] = CAL_image_ff[245];
                        mul[5] = CAL_image_ff[246];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    246: begin
                        mul[0] = CAL_image_ff[229];
                        mul[1] = CAL_image_ff[230];
                        mul[2] = CAL_image_ff[231];
                        mul[3] = CAL_image_ff[245];
                        mul[4] = CAL_image_ff[246];
                        mul[5] = CAL_image_ff[247];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    247: begin
                        mul[0] = CAL_image_ff[230];
                        mul[1] = CAL_image_ff[231];
                        mul[2] = CAL_image_ff[232];
                        mul[3] = CAL_image_ff[246];
                        mul[4] = CAL_image_ff[247];
                        mul[5] = CAL_image_ff[248];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    248: begin
                        mul[0] = CAL_image_ff[231];
                        mul[1] = CAL_image_ff[232];
                        mul[2] = CAL_image_ff[233];
                        mul[3] = CAL_image_ff[247];
                        mul[4] = CAL_image_ff[248];
                        mul[5] = CAL_image_ff[249];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    249: begin
                        mul[0] = CAL_image_ff[232];
                        mul[1] = CAL_image_ff[233];
                        mul[2] = CAL_image_ff[234];
                        mul[3] = CAL_image_ff[248];
                        mul[4] = CAL_image_ff[249];
                        mul[5] = CAL_image_ff[250];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    250: begin
                        mul[0] = CAL_image_ff[233];
                        mul[1] = CAL_image_ff[234];
                        mul[2] = CAL_image_ff[235];
                        mul[3] = CAL_image_ff[249];
                        mul[4] = CAL_image_ff[250];
                        mul[5] = CAL_image_ff[251];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    251: begin
                        mul[0] = CAL_image_ff[234];
                        mul[1] = CAL_image_ff[235];
                        mul[2] = CAL_image_ff[236];
                        mul[3] = CAL_image_ff[250];
                        mul[4] = CAL_image_ff[251];
                        mul[5] = CAL_image_ff[252];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    252: begin
                        mul[0] = CAL_image_ff[235];
                        mul[1] = CAL_image_ff[236];
                        mul[2] = CAL_image_ff[237];
                        mul[3] = CAL_image_ff[251];
                        mul[4] = CAL_image_ff[252];
                        mul[5] = CAL_image_ff[253];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    253: begin
                        mul[0] = CAL_image_ff[236];
                        mul[1] = CAL_image_ff[237];
                        mul[2] = CAL_image_ff[238];
                        mul[3] = CAL_image_ff[252];
                        mul[4] = CAL_image_ff[253];
                        mul[5] = CAL_image_ff[254];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    254: begin
                        mul[0] = CAL_image_ff[237];
                        mul[1] = CAL_image_ff[238];
                        mul[2] = CAL_image_ff[239];
                        mul[3] = CAL_image_ff[253];
                        mul[4] = CAL_image_ff[254];
                        mul[5] = CAL_image_ff[255];
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    255: begin
                        mul[0] = CAL_image_ff[238];
                        mul[1] = CAL_image_ff[239];
                        mul[2] = 'd0;
                        mul[3] = CAL_image_ff[254];
                        mul[4] = CAL_image_ff[255];
                        mul[5] = 'd0;
                        mul[6] = 'd0;
                        mul[7] = 'd0;
                        mul[8] = 'd0;
                    end
                    default: begin
                        for (i = 0; i < 9 ; i = i + 1) begin
                           mul[i] = 'd0;
                        end
                    end
                endcase
            end
            default: begin
                for (i = 0; i < 9 ; i = i + 1) begin
                    mul[i] = 'd0;
                end
            end
        endcase
    end
    else begin
        for (i = 0; i < 9 ; i = i + 1) begin
            mul[i] = 'd0;
        end
    end
end

// 再修
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        final_ans <= 'd0;
        mul_cnt <= 'd0;
        ouput_index <= 'd0;
    end
    else if(current_state == CROSS_CORELATION) begin
        if(ouput_index == 0) begin
            if(mul_cnt == 'd9) begin
                temp_out <= final_ans;
                final_ans <= 'd0;
                mul_cnt <= 'd0;
                ouput_index <= ouput_index + 1;
            end
            else begin
                mul_cnt <= mul_cnt + 1; 
                final_ans <= (img_pixel * template_pixel) + final_ans;
            end
        end
        else begin
            if(mul_cnt == 'd19) begin
                temp_out <= final_ans;
                final_ans <= 'd0;
                mul_cnt <= 'd0;
                ouput_index <= ouput_index + 1;
            end
            else begin
                mul_cnt <= mul_cnt + 1; 
                final_ans <= (img_pixel * template_pixel) + final_ans;
            end
        end
    end
    else begin
        final_ans <= 'd0;
        mul_cnt <= 'd0;
        ouput_index <= 'd0;
    end
end

always @(posedge clk) begin
    if(in_valid) set_cnt <= 0;
    else if(current_state == CROSS_CORELATION && mul_cnt == 'd19 && ouput_index == output_limit) begin
        set_cnt <= set_cnt + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <= 0;
        out_value <= 0;
        outbit_index <= 5'b11111;
    end
    else if(current_state == CROSS_CORELATION) begin
        if(ouput_index == 0 && mul_cnt == 'd9) begin
            out_valid <= 1'b1;
            out_value <= final_ans[19];
            outbit_index <= 'd18;
        end
        else if(outbit_index < 'd19) begin
            out_valid <= 1'b1;
            out_value <= temp_out[outbit_index]; 

            outbit_index <= outbit_index - 1'b1;
            if(outbit_index == 0) begin
                // if(ouput_index == output_limit) begin
                //     out_valid <= 0;
                //     out_value <= 0;
                // end
                outbit_index <= 5'd19;
            end
            
        end
        else if(mul_cnt == 'd19) begin
            if(ouput_index == output_limit) begin
                out_valid <= 0;
                out_value <= 0;
                
            end
            else begin
                out_valid <= 1'b1;
                out_value <= final_ans[outbit_index];
                outbit_index <= 'd18;
            end
        end
    end
    else begin
        out_valid <= 0;
        out_value <= 0;
        outbit_index <= 5'd19;
    end
end

always @(*) begin
    if(current_state == CROSS_CORELATION) begin
        case(mul_cnt)
            0, 1, 2, 3, 4, 5, 6, 7, 8: begin
                img_pixel = mul[mul_cnt];
                template_pixel = template_ff[mul_cnt];
            end
            default: begin
                img_pixel = 'd0;
                template_pixel = 'd0;
            end
        endcase
    end
    else begin
        img_pixel = 'd0;
        template_pixel = 'd0;
    end
end

MAX_CMP max_cmp0(.in_0(CAL_image_ff[maxcmp_index]), .in_1(CAL_image_ff[maxcmp_index+1]), .in_2(CAL_image_ff[maxcmp_index+maxcmp_add]), .in_3(CAL_image_ff[maxcmp_index+maxcmp_add+1]), .max_value(max_outup0));
MAX_CMP max_cmp1(.in_0(CAL_image_ff[maxcmp_index+2]), .in_1(CAL_image_ff[maxcmp_index+3]), .in_2(CAL_image_ff[maxcmp_index+maxcmp_add+2]), .in_3(CAL_image_ff[maxcmp_index+maxcmp_add+3]), .max_value(max_outup1));
MAX_CMP max_cmp2(.in_0(CAL_image_ff[maxcmp_index+4]), .in_1(CAL_image_ff[maxcmp_index+5]), .in_2(CAL_image_ff[maxcmp_index+maxcmp_add+4]), .in_3(CAL_image_ff[maxcmp_index+maxcmp_add+5]), .max_value(max_outup2));
MAX_CMP max_cmp3(.in_0(CAL_image_ff[maxcmp_index+6]), .in_1(CAL_image_ff[maxcmp_index+7]), .in_2(CAL_image_ff[maxcmp_index+maxcmp_add+6]), .in_3(CAL_image_ff[maxcmp_index+maxcmp_add+7]), .max_value(max_outup3));


SORT s0(.in_0(mid_0[0]), .in_1(mid_0[1]), .in_2(mid_0[2]), .in_3(mid_0[3]), .in_4(mid_0[4]), .in_5(mid_0[5]), .in_6(mid_0[6]), .in_7(mid_0[7]), .in_8(mid_0[8]), .result(mid_res[0]));
SORT s1(.in_0(mid_1[0]), .in_1(mid_1[1]), .in_2(mid_1[2]), .in_3(mid_1[3]), .in_4(mid_1[4]), .in_5(mid_1[5]), .in_6(mid_1[6]), .in_7(mid_1[7]), .in_8(mid_1[8]), .result(mid_res[1]));
SORT s2(.in_0(mid_2[0]), .in_1(mid_2[1]), .in_2(mid_2[2]), .in_3(mid_2[3]), .in_4(mid_2[4]), .in_5(mid_2[5]), .in_6(mid_2[6]), .in_7(mid_2[7]), .in_8(mid_2[8]), .result(mid_res[2]));
SORT s3(.in_0(mid_3[0]), .in_1(mid_3[1]), .in_2(mid_3[2]), .in_3(mid_3[3]), .in_4(mid_3[4]), .in_5(mid_3[5]), .in_6(mid_3[6]), .in_7(mid_3[7]), .in_8(mid_3[8]), .result(mid_res[3]));
SORT s4(.in_0(mid_4[0]), .in_1(mid_4[1]), .in_2(mid_4[2]), .in_3(mid_4[3]), .in_4(mid_4[4]), .in_5(mid_4[5]), .in_6(mid_4[6]), .in_7(mid_4[7]), .in_8(mid_4[8]), .result(mid_res[4]));
SORT s5(.in_0(mid_5[0]), .in_1(mid_5[1]), .in_2(mid_5[2]), .in_3(mid_5[3]), .in_4(mid_5[4]), .in_5(mid_5[5]), .in_6(mid_5[6]), .in_7(mid_5[7]), .in_8(mid_5[8]), .result(mid_res[5]));
SORT s6(.in_0(mid_6[0]), .in_1(mid_6[1]), .in_2(mid_6[2]), .in_3(mid_6[3]), .in_4(mid_6[4]), .in_5(mid_6[5]), .in_6(mid_6[6]), .in_7(mid_6[7]), .in_8(mid_6[8]), .result(mid_res[6]));
SORT s7(.in_0(mid_7[0]), .in_1(mid_7[1]), .in_2(mid_7[2]), .in_3(mid_7[3]), .in_4(mid_7[4]), .in_5(mid_7[5]), .in_6(mid_7[6]), .in_7(mid_7[7]), .in_8(mid_7[8]), .result(mid_res[7]));
SORT s8(.in_0(mid_8[0]), .in_1(mid_8[1]), .in_2(mid_8[2]), .in_3(mid_8[3]), .in_4(mid_8[4]), .in_5(mid_8[5]), .in_6(mid_8[6]), .in_7(mid_8[7]), .in_8(mid_8[8]), .result(mid_res[8]));
SORT s9(.in_0(mid_9[0]), .in_1(mid_9[1]), .in_2(mid_9[2]), .in_3(mid_9[3]), .in_4(mid_9[4]), .in_5(mid_9[5]), .in_6(mid_9[6]), .in_7(mid_9[7]), .in_8(mid_9[8]), .result(mid_res[9]));
SORT s10(.in_0(mid_10[0]), .in_1(mid_10[1]), .in_2(mid_10[2]), .in_3(mid_10[3]), .in_4(mid_10[4]), .in_5(mid_10[5]), .in_6(mid_10[6]), .in_7(mid_10[7]), .in_8(mid_10[8]), .result(mid_res[10]));
SORT s11(.in_0(mid_11[0]), .in_1(mid_11[1]), .in_2(mid_11[2]), .in_3(mid_11[3]), .in_4(mid_11[4]), .in_5(mid_11[5]), .in_6(mid_11[6]), .in_7(mid_11[7]), .in_8(mid_11[8]), .result(mid_res[11]));
SORT s12(.in_0(mid_12[0]), .in_1(mid_12[1]), .in_2(mid_12[2]), .in_3(mid_12[3]), .in_4(mid_12[4]), .in_5(mid_12[5]), .in_6(mid_12[6]), .in_7(mid_12[7]), .in_8(mid_12[8]), .result(mid_res[12]));
SORT s13(.in_0(mid_13[0]), .in_1(mid_13[1]), .in_2(mid_13[2]), .in_3(mid_13[3]), .in_4(mid_13[4]), .in_5(mid_13[5]), .in_6(mid_13[6]), .in_7(mid_13[7]), .in_8(mid_13[8]), .result(mid_res[13]));
SORT s14(.in_0(mid_14[0]), .in_1(mid_14[1]), .in_2(mid_14[2]), .in_3(mid_14[3]), .in_4(mid_14[4]), .in_5(mid_14[5]), .in_6(mid_14[6]), .in_7(mid_14[7]), .in_8(mid_14[8]), .result(mid_res[14]));
SORT s15(.in_0(mid_15[0]), .in_1(mid_15[1]), .in_2(mid_15[2]), .in_3(mid_15[3]), .in_4(mid_15[4]), .in_5(mid_15[5]), .in_6(mid_15[6]), .in_7(mid_15[7]), .in_8(mid_15[8]), .result(mid_res[15]));
   
endmodule






module DIV3_TABLE(
    input [7:0] dividend,
    output reg [7:0] quotient, 
    output reg [1:0] remainder
);
    always @(*)begin
        case(dividend)
            'd0, 'd3, 'd6, 'd9, 'd12, 'd15, 'd18, 'd21, 'd24, 'd27, 'd30, 'd33, 'd36,
            'd39, 'd42, 'd45, 'd48, 'd51, 'd54, 'd57, 'd60, 'd63, 'd66, 'd69, 'd72,
            'd75, 'd78, 'd81, 'd84, 'd87, 'd90, 'd93, 'd96, 'd99, 'd102, 'd105, 'd108,
            'd111, 'd114, 'd117, 'd120, 'd123, 'd126, 'd129, 'd132, 'd135, 'd138,
            'd141, 'd144, 'd147, 'd150, 'd153, 'd156, 'd159, 'd162, 'd165, 'd168,
            'd171, 'd174, 'd177, 'd180, 'd183, 'd186, 'd189, 'd192, 'd195, 'd198,
            'd201, 'd204, 'd207, 'd210, 'd213, 'd216, 'd219, 'd222, 'd225, 'd228,
            'd231, 'd234, 'd237, 'd240, 'd243, 'd246, 'd249, 'd252, 'd255: begin
                remainder = 'd0;
                case(dividend)
                    'd0: quotient = 'd0;
                    'd3: quotient = 'd1;
                    'd6: quotient = 'd2;
                    'd9: quotient = 'd3;
                    'd12: quotient = 'd4;
                    'd15: quotient = 'd5;
                    'd18: quotient = 'd6;
                    'd21: quotient = 'd7;
                    'd24: quotient = 'd8;
                    'd27: quotient = 'd9;
                    'd30: quotient = 'd10;
                    'd33: quotient = 'd11;
                    'd36: quotient = 'd12;
                    'd39: quotient = 'd13;
                    'd42: quotient = 'd14;
                    'd45: quotient = 'd15;
                    'd48: quotient = 'd16;
                    'd51: quotient = 'd17;
                    'd54: quotient = 'd18;
                    'd57: quotient = 'd19;
                    'd60: quotient = 'd20;
                    'd63: quotient = 'd21;
                    'd66: quotient = 'd22;
                    'd69: quotient = 'd23;
                    'd72: quotient = 'd24;
                    'd75: quotient = 'd25;
                    'd78: quotient = 'd26;
                    'd81: quotient = 'd27;
                    'd84: quotient = 'd28;
                    'd87: quotient = 'd29;
                    'd90: quotient = 'd30;
                    'd93: quotient = 'd31;
                    'd96: quotient = 'd32;
                    'd99: quotient = 'd33;
                    'd102: quotient = 'd34;
                    'd105: quotient = 'd35;
                    'd108: quotient = 'd36;
                    'd111: quotient = 'd37;
                    'd114: quotient = 'd38;
                    'd117: quotient = 'd39;
                    'd120: quotient = 'd40;
                    'd123: quotient = 'd41;
                    'd126: quotient = 'd42;
                    'd129: quotient = 'd43;
                    'd132: quotient = 'd44;
                    'd135: quotient = 'd45;
                    'd138: quotient = 'd46;
                    'd141: quotient = 'd47;
                    'd144: quotient = 'd48;
                    'd147: quotient = 'd49;
                    'd150: quotient = 'd50;
                    'd153: quotient = 'd51;
                    'd156: quotient = 'd52;
                    'd159: quotient = 'd53;
                    'd162: quotient = 'd54;
                    'd165: quotient = 'd55;
                    'd168: quotient = 'd56;
                    'd171: quotient = 'd57;
                    'd174: quotient = 'd58;
                    'd177: quotient = 'd59;
                    'd180: quotient = 'd60;
                    'd183: quotient = 'd61;
                    'd186: quotient = 'd62;
                    'd189: quotient = 'd63;
                    'd192: quotient = 'd64;
                    'd195: quotient = 'd65;
                    'd198: quotient = 'd66;
                    'd201: quotient = 'd67;
                    'd204: quotient = 'd68;
                    'd207: quotient = 'd69;
                    'd210: quotient = 'd70;
                    'd213: quotient = 'd71;
                    'd216: quotient = 'd72;
                    'd219: quotient = 'd73;
                    'd222: quotient = 'd74;
                    'd225: quotient = 'd75;
                    'd228: quotient = 'd76;
                    'd231: quotient = 'd77;
                    'd234: quotient = 'd78;
                    'd237: quotient = 'd79;
                    'd240: quotient = 'd80;
                    'd243: quotient = 'd81;
                    'd246: quotient = 'd82;
                    'd249: quotient = 'd83;
                    'd252: quotient = 'd84;
                    'd255: quotient = 'd85;
                    default: quotient = 'dx;
                endcase
            end
            'd1, 'd4, 'd7, 'd10, 'd13, 'd16, 'd19, 'd22, 'd25, 'd28, 'd31, 'd34, 'd37,
            'd40, 'd43, 'd46, 'd49, 'd52, 'd55, 'd58, 'd61, 'd64, 'd67, 'd70, 'd73,
            'd76, 'd79, 'd82, 'd85, 'd88, 'd91, 'd94, 'd97, 'd100, 'd103, 'd106, 'd109,
            'd112, 'd115, 'd118, 'd121, 'd124, 'd127, 'd130, 'd133, 'd136, 'd139,
            'd142, 'd145, 'd148, 'd151, 'd154, 'd157, 'd160, 'd163, 'd166, 'd169,
            'd172, 'd175, 'd178, 'd181, 'd184, 'd187, 'd190, 'd193, 'd196, 'd199,
            'd202, 'd205, 'd208, 'd211, 'd214, 'd217, 'd220, 'd223, 'd226, 'd229,
            'd232, 'd235, 'd238, 'd241, 'd244, 'd247, 'd250, 'd253: begin
                remainder = 'd1;
                case(dividend)
                    'd1: quotient = 'd0;
                    'd4: quotient = 'd1;
                    'd7: quotient = 'd2;
                    'd10: quotient = 'd3;
                    'd13: quotient = 'd4;
                    'd16: quotient = 'd5;
                    'd19: quotient = 'd6;
                    'd22: quotient = 'd7;
                    'd25: quotient = 'd8;
                    'd28: quotient = 'd9;
                    'd31: quotient = 'd10;
                    'd34: quotient = 'd11;
                    'd37: quotient = 'd12;
                    'd40: quotient = 'd13;
                    'd43: quotient = 'd14;
                    'd46: quotient = 'd15;
                    'd49: quotient = 'd16;
                    'd52: quotient = 'd17;
                    'd55: quotient = 'd18;
                    'd58: quotient = 'd19;
                    'd61: quotient = 'd20;
                    'd64: quotient = 'd21;
                    'd67: quotient = 'd22;
                    'd70: quotient = 'd23;
                    'd73: quotient = 'd24;
                    'd76: quotient = 'd25;
                    'd79: quotient = 'd26;
                    'd82: quotient = 'd27;
                    'd85: quotient = 'd28;
                    'd88: quotient = 'd29;
                    'd91: quotient = 'd30;
                    'd94: quotient = 'd31;
                    'd97: quotient = 'd32;
                    'd100: quotient = 'd33;
                    'd103: quotient = 'd34;
                    'd106: quotient = 'd35;
                    'd109: quotient = 'd36;
                    'd112: quotient = 'd37;
                    'd115: quotient = 'd38;
                    'd118: quotient = 'd39;
                    'd121: quotient = 'd40;
                    'd124: quotient = 'd41;
                    'd127: quotient = 'd42;
                    'd130: quotient = 'd43;
                    'd133: quotient = 'd44;
                    'd136: quotient = 'd45;
                    'd139: quotient = 'd46;
                    'd142: quotient = 'd47;
                    'd145: quotient = 'd48;
                    'd148: quotient = 'd49;
                    'd151: quotient = 'd50;
                    'd154: quotient = 'd51;
                    'd157: quotient = 'd52;
                    'd160: quotient = 'd53;
                    'd163: quotient = 'd54;
                    'd166: quotient = 'd55;
                    'd169: quotient = 'd56;
                    'd172: quotient = 'd57;
                    'd175: quotient = 'd58;
                    'd178: quotient = 'd59;
                    'd181: quotient = 'd60;
                    'd184: quotient = 'd61;
                    'd187: quotient = 'd62;
                    'd190: quotient = 'd63;
                    'd193: quotient = 'd64;
                    'd196: quotient = 'd65;
                    'd199: quotient = 'd66;
                    'd202: quotient = 'd67;
                    'd205: quotient = 'd68;
                    'd208: quotient = 'd69;
                    'd211: quotient = 'd70;
                    'd214: quotient = 'd71;
                    'd217: quotient = 'd72;
                    'd220: quotient = 'd73;
                    'd223: quotient = 'd74;
                    'd226: quotient = 'd75;
                    'd229: quotient = 'd76;
                    'd232: quotient = 'd77;
                    'd235: quotient = 'd78;
                    'd238: quotient = 'd79;
                    'd241: quotient = 'd80;
                    'd244: quotient = 'd81;
                    'd247: quotient = 'd82;
                    'd250: quotient = 'd83;
                    'd253: quotient = 'd84;
                    default: quotient = 'dx;
                endcase
            end
            
            'd2, 'd5, 'd8, 'd11, 'd14, 'd17, 'd20, 'd23, 'd26, 'd29, 'd32, 'd35, 'd38,
            'd41, 'd44, 'd47, 'd50, 'd53, 'd56, 'd59, 'd62, 'd65, 'd68, 'd71, 'd74,
            'd77, 'd80, 'd83, 'd86, 'd89, 'd92, 'd95, 'd98, 'd101, 'd104, 'd107, 'd110,
            'd113, 'd116, 'd119, 'd122, 'd125, 'd128, 'd131, 'd134, 'd137, 'd140,
            'd143, 'd146, 'd149, 'd152, 'd155, 'd158, 'd161, 'd164, 'd167, 'd170,
            'd173, 'd176, 'd179, 'd182, 'd185, 'd188, 'd191, 'd194, 'd197, 'd200,
            'd203, 'd206, 'd209, 'd212, 'd215, 'd218, 'd221, 'd224, 'd227, 'd230,
            'd233, 'd236, 'd239, 'd242, 'd245, 'd248, 'd251, 'd254: begin
                remainder = 'd2;
                case(dividend)
                    'd2: quotient = 'd0;
                    'd5: quotient = 'd1;
                    'd8: quotient = 'd2;
                    'd11: quotient = 'd3;
                    'd14: quotient = 'd4;
                    'd17: quotient = 'd5;
                    'd20: quotient = 'd6;
                    'd23: quotient = 'd7;
                    'd26: quotient = 'd8;
                    'd29: quotient = 'd9;
                    'd32: quotient = 'd10;
                    'd35: quotient = 'd11;
                    'd38: quotient = 'd12;
                    'd41: quotient = 'd13;
                    'd44: quotient = 'd14;
                    'd47: quotient = 'd15;
                    'd50: quotient = 'd16;
                    'd53: quotient = 'd17;
                    'd56: quotient = 'd18;
                    'd59: quotient = 'd19;
                    'd62: quotient = 'd20;
                    'd65: quotient = 'd21;
                    'd68: quotient = 'd22;
                    'd71: quotient = 'd23;
                    'd74: quotient = 'd24;
                    'd77: quotient = 'd25;
                    'd80: quotient = 'd26;
                    'd83: quotient = 'd27;
                    'd86: quotient = 'd28;
                    'd89: quotient = 'd29;
                    'd92: quotient = 'd30;
                    'd95: quotient = 'd31;
                    'd98: quotient = 'd32;
                    'd101: quotient = 'd33;
                    'd104: quotient = 'd34;
                    'd107: quotient = 'd35;
                    'd110: quotient = 'd36;
                    'd113: quotient = 'd37;
                    'd116: quotient = 'd38;
                    'd119: quotient = 'd39;
                    'd122: quotient = 'd40;
                    'd125: quotient = 'd41;
                    'd128: quotient = 'd42;
                    'd131: quotient = 'd43;
                    'd134: quotient = 'd44;
                    'd137: quotient = 'd45;
                    'd140: quotient = 'd46;
                    'd143: quotient = 'd47;
                    'd146: quotient = 'd48;
                    'd149: quotient = 'd49;
                    'd152: quotient = 'd50;
                    'd155: quotient = 'd51;
                    'd158: quotient = 'd52;
                    'd161: quotient = 'd53;
                    'd164: quotient = 'd54;
                    'd167: quotient = 'd55;
                    'd170: quotient = 'd56;
                    'd173: quotient = 'd57;
                    'd176: quotient = 'd58;
                    'd179: quotient = 'd59;
                    'd182: quotient = 'd60;
                    'd185: quotient = 'd61;
                    'd188: quotient = 'd62;
                    'd191: quotient = 'd63;
                    'd194: quotient = 'd64;
                    'd197: quotient = 'd65;
                    'd200: quotient = 'd66;
                    'd203: quotient = 'd67;
                    'd206: quotient = 'd68;
                    'd209: quotient = 'd69;
                    'd212: quotient = 'd70;
                    'd215: quotient = 'd71;
                    'd218: quotient = 'd72;
                    'd221: quotient = 'd73;
                    'd224: quotient = 'd74;
                    'd227: quotient = 'd75;
                    'd230: quotient = 'd76;
                    'd233: quotient = 'd77;
                    'd236: quotient = 'd78;
                    'd239: quotient = 'd79;
                    'd242: quotient = 'd80;
                    'd245: quotient = 'd81;
                    'd248: quotient = 'd82;
                    'd251: quotient = 'd83;
                    'd254: quotient = 'd84;
                    default: quotient = 'dx;
                endcase
            end
            default: begin
                remainder = 'dx;
                quotient = 'dx;
            end
        endcase
    end

endmodule

module MAX_CMP(
    in_0, in_1, in_2, in_3,
    max_value
);

input [7:0] in_0, in_1, in_2, in_3;
output wire [7:0] max_value;

wire [7:0] max_1, max_2;

assign max_1 = (in_0 > in_1) ? in_0 : in_1;
assign max_2 = (in_2 > in_3) ? in_2 : in_3;
assign max_value = (max_1 > max_2) ? max_1 : max_2;

endmodule

module SORT(
    in_0, in_1, in_2, in_3, in_4,
    in_5, in_6, in_7, in_8,
    result
);

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input [7:0] in_0, in_1, in_2, in_3, in_4, in_5, in_6, in_7, in_8;
output wire [7:0] result;

//================================================================
//    Wire & Registers 
//================================================================
wire [7:0] stage0_0, stage0_1, stage0_2, stage0_3, stage0_4, stage0_5, stage0_6, stage0_7, stage0_8;
wire [7:0] stage1_0, stage1_1, stage1_2, stage1_3, stage1_4, stage1_5, stage1_6, stage1_7, stage1_8;
wire [7:0] stage2_0, stage2_1, stage2_2, stage2_3, stage2_4, stage2_5, stage2_6, stage2_7, stage2_8;
wire [7:0] stage3_0, stage3_1, stage3_2, stage3_3, stage3_4, stage3_5, stage3_6, stage3_7;
wire [7:0] stage4_0, stage4_1, stage4_2, stage4_3, stage4_4, stage4_5;
wire [7:0] stage5_0, stage5_1, stage5_2, stage5_3, stage5_4, stage5_5;

//================================================================
//    DESIGN
//================================================================

// Layer 0:
assign {stage0_0, stage0_3} = (in_0 > in_3) ? {in_0 , in_3} : {in_3 , in_0};
assign {stage0_1, stage0_7} = (in_1 > in_7) ? {in_1 , in_7} : {in_7 , in_1};
assign {stage0_2, stage0_5} = (in_2 > in_5) ? {in_2 , in_5} : {in_5 , in_2};
assign {stage0_4, stage0_8} = (in_4 > in_8) ? {in_4 , in_8} : {in_8 , in_4};
assign stage0_6 = in_6;

// Layer 1: 
assign {stage1_0, stage1_7} = (stage0_0 > stage0_7) ? {stage0_0, stage0_7} : {stage0_7, stage0_0};
assign {stage1_2, stage1_4} = (stage0_2 > stage0_4) ? {stage0_2, stage0_4} : {stage0_4, stage0_2};
assign {stage1_3, stage1_8} = (stage0_3 > stage0_8) ? {stage0_3, stage0_8} : {stage0_8, stage0_3};
assign {stage1_5, stage1_6} = (stage0_5 > stage0_6) ? {stage0_5, stage0_6} : {stage0_6, stage0_5};
assign stage1_1 = stage0_1;

// Layer 2: 
assign {stage2_0, stage2_2} = (stage1_0 > stage1_2) ? {stage1_0, stage1_2} : {stage1_2, stage1_0};
assign {stage2_1, stage2_3} = (stage1_1 > stage1_3) ? {stage1_1, stage1_3} : {stage1_3, stage1_1};
assign {stage2_4, stage2_5} = (stage1_4 > stage1_5) ? {stage1_4, stage1_5} : {stage1_5, stage1_4};
assign {stage2_7, stage2_8} = (stage1_7 > stage1_8) ? {stage1_7, stage1_8} : {stage1_8, stage1_7};
assign stage2_6 = stage1_6;

// Layer 3:
assign {stage3_1, stage3_4} = (stage2_1 > stage2_4) ? {stage2_1, stage2_4} : {stage2_4, stage2_1};
assign {stage3_3, stage3_6} = (stage2_3 > stage2_6) ? {stage2_3, stage2_6} : {stage2_6, stage2_3};
assign {stage3_5, stage3_7} = (stage2_5 > stage2_7) ? {stage2_5, stage2_7} : {stage2_7, stage2_5};
assign {stage3_0, stage3_2} = {stage2_0, stage2_2};

// Layer 4: 
assign {stage4_2, stage4_4} = (stage3_2 > stage3_4) ? {stage3_2, stage3_4} : {stage3_4, stage3_2};
assign {stage4_3, stage4_5} = (stage3_3 > stage3_5) ? {stage3_3, stage3_5} : {stage3_5, stage3_3};
assign {stage4_0, stage4_1} = {stage3_0, stage3_1};

// Layer 5: 
assign {stage5_2, stage5_3} = (stage4_2 > stage4_3) ? {stage4_2, stage4_3} : {stage4_3, stage4_2};
assign {stage5_4, stage5_5} = (stage4_4 > stage4_5) ? {stage4_4, stage4_5} : {stage4_5, stage4_4};

// Layer 6: result
assign result = (stage5_3 > stage5_4) ? stage5_4 : stage5_3;

endmodule
