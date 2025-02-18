module ISP(
    // Input Signals
    input clk,
    input rst_n,
    input in_valid,
    input [3:0] in_pic_no,
    input [1:0] in_mode,
    input [1:0] in_ratio_mode,

    // Output Signals
    output reg out_valid,
    output reg [7:0] out_data,
    
    // DRAM Signals
    // ------------------------
    // <<<<< AXI WRITE >>>>>
    // ------------------------
    // (1) 	axi write address channel 
    // src master
    output [3:0]  awid_s_inf,
    output [31:0] awaddr_s_inf,
    output [2:0]  awsize_s_inf,
    output [1:0]  awburst_s_inf,
    output [7:0]  awlen_s_inf,
    output    reg    awvalid_s_inf,
    // src slave
    input         awready_s_inf,
    // -----------------------------
  
    // (2)	axi write data channel 
    // src master
    output [127:0] wdata_s_inf,
    output     reg    wlast_s_inf,
    output     reg  wvalid_s_inf,
    // src slave
    input          wready_s_inf,
  
    // axi write response channel 
    // src slave
    input [3:0]    bid_s_inf,
    input [1:0]    bresp_s_inf,
    input          bvalid_s_inf,
    // src master 
    output    reg     bready_s_inf,

  
    // ------------------------
    // <<<<< AXI READ >>>>>
    // ------------------------
    // (1)	axi read address channel
    // src master
    output [3:0]   arid_s_inf,
    output [31:0] araddr_s_inf,
    output [7:0]   arlen_s_inf,
    output [2:0]  arsize_s_inf,
    output reg [1:0]   arburst_s_inf,
    output    reg     arvalid_s_inf,
    // src slave
    input          arready_s_inf,
    // -----------------------------
  
    // (2)	axi read data channel 
    // slave
    input [3:0]    rid_s_inf,
    input [127:0]  rdata_s_inf,
    input [1:0]    rresp_s_inf,
    input          rlast_s_inf,
    input          rvalid_s_inf,
    // master
    output     reg    rready_s_inf
    
);

// parameter & integer declaration =================
integer i, j;

localparam  IDLE = 3'd0,
            QUERY_TABLE = 3'd1,
            WAIT_READ = 3'd2,
            READ_CAL = 3'd3;

reg [1:0] c_state, n_state;

// reg & wire declaration ==========================
reg first_write_flag;

reg [1:0] mode_ff;
reg [1:0] ratio_ff;
reg [3:0] pic_num;
reg [31:0] pic_addr;

reg [7:0] cal_pic[0:15];

reg [47:0] focus_pic[0:5];

reg [7:0] cmp1[0:5], cmp2[0:5];
reg [7:0] cmp_sub_res[0:5];
reg [7:0] dram_read_cnt; 

reg [8:0] add_exp_lay0 [0:3];
reg [9:0] add_exp_lay1 [0:1];
reg [10:0] add_exp_lay2;

reg [17:0] total_exp_avg;
reg [3:0] focus_pic_loc;
reg [3:0] contrast_pic_row;

reg [8:0] contract_6x6_lay0 [0:2];
reg [10:0] contract_6x6_lay1;
reg [13:0] contract_6x6;
reg [12:0] contract_4x4;
reg [9:0] contract_2x2;

reg [1:0] max_contrast;

reg [1:0] focus_table [0:15];

reg all_zero_flag;
reg [8:0] exposure_table [0:15];

// reg [1:0] RGB_ptr;
reg [7:0] curr_min [0:2];
reg [7:0] curr_max [0:2];

reg [7:0] min_max_table [0:15];

wire [7:0] stage0_0, stage0_1, stage0_2, stage0_3, stage0_4, stage0_5, stage0_6, stage0_7, stage0_8, stage0_9, stage0_10, stage0_11, stage0_12, stage0_13, stage0_14, stage0_15;
reg [7:0] stage1_0, stage1_1, stage1_2, stage1_3, stage1_4, stage1_5, stage1_6, stage1_7, stage1_8, stage1_9, stage1_10, stage1_11, stage1_12, stage1_13, stage1_14, stage1_15;
reg [7:0] stage2_0, stage2_1, stage2_2, stage2_3, stage2_4, stage2_5, stage2_6, stage2_7, stage2_8, stage2_12, stage2_14, stage2_15;
reg [7:0] max_value16, stage3_1, stage3_14, min_value16;

reg [8:0] add_avg_lay0 [0:2];
reg [9:0] add_avg_lay1;
reg [9:0] add_avg_div3;

// reg [10:0] dividend_stage[0:8];
// reg [3:0] divisor9;
// reg [6:0] quotient_stage[0:8];

reg [14:0] dividend_stage;
wire [3:0] divisor9;
assign divisor9 = 4'b1001;

// design ==========================================

//===============================================//
//        Read DRAM with AXI4 protocol 	         //
//===============================================//
assign arid_s_inf    = 0;
assign arlen_s_inf   = (c_state == IDLE) ? 'd0 : 191;
assign arsize_s_inf  = (c_state == IDLE) ? 'd0 : 3'b100;
assign arburst_s_inf = (c_state == IDLE) ? 'd0 : 2'b01;

assign araddr_s_inf = (arvalid_s_inf) ? pic_addr : 0;

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) arvalid_s_inf <= 0;
	else if(arvalid_s_inf && arready_s_inf) arvalid_s_inf <= 0;
	else if(c_state == QUERY_TABLE && n_state == WAIT_READ) arvalid_s_inf <= 1;
	else if(c_state == WAIT_READ && rlast_s_inf) arvalid_s_inf <= 1;
end

always @(posedge clk or negedge rst_n) begin
	if(~rst_n) rready_s_inf <= 0;
    else if(rvalid_s_inf && rready_s_inf && first_write_flag) rready_s_inf <= 0;
    else if(first_write_flag && wready_s_inf) rready_s_inf <= 1;
	else if(arvalid_s_inf && arready_s_inf) rready_s_inf <= 1;
	else if(rlast_s_inf) rready_s_inf <= 0;
end

//===============================================//
//         Write DRAM with AXI4 protocol         //
//===============================================//
assign awid_s_inf    = 0;
assign awlen_s_inf   = (c_state == IDLE) ? 'd0 : 191;
assign awsize_s_inf  = (c_state == IDLE) ? 'd0 : 3'b100;
assign awburst_s_inf = (c_state == IDLE) ? 'd0 : 2'b01;

assign awaddr_s_inf = (awvalid_s_inf) ? pic_addr : 0;

always @(posedge clk or negedge rst_n) begin
	if(~rst_n) awvalid_s_inf <= 0;
    else if(awvalid_s_inf && awready_s_inf) awvalid_s_inf <= 0;
	else if(c_state == QUERY_TABLE && n_state == WAIT_READ) awvalid_s_inf <= 1;
end

assign wdata_s_inf = {cal_pic[15], cal_pic[14], cal_pic[13], cal_pic[12], cal_pic[11], cal_pic[10], cal_pic[9], cal_pic[8], cal_pic[7], cal_pic[6], cal_pic[5], cal_pic[4], cal_pic[3], cal_pic[2], cal_pic[1], cal_pic[0]};

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) wlast_s_inf <= 0;
	else if(wlast_s_inf && wready_s_inf) wlast_s_inf <= 0;
    else if(wvalid_s_inf && dram_read_cnt == 'd191) wlast_s_inf <= 1;
end

always @(posedge clk or negedge rst_n) begin
	if(~rst_n) wvalid_s_inf <= 0;
	else if(wready_s_inf && (wlast_s_inf || first_write_flag)) wvalid_s_inf <= 0;
	// else if((awvalid_s_inf && awready_s_inf) || wready_s_inf) wvalid_s_inf <= 1;
    else if(rvalid_s_inf)  wvalid_s_inf <= 1;
end

always @(posedge clk or negedge rst_n) begin
	if(~rst_n) first_write_flag <= 0;
    else if(c_state == IDLE) first_write_flag <= 1;
    else if(first_write_flag && wready_s_inf) first_write_flag <= 0;
end

always @(posedge clk or negedge rst_n) begin
	if(~rst_n) bready_s_inf <= 0;
    else if(awvalid_s_inf && awready_s_inf) bready_s_inf <= 1;
    else if(bvalid_s_inf) bready_s_inf <= 0;
end

/* FSM */
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) c_state <= IDLE;
    else c_state <= n_state;
end

always @(*) begin
    case (c_state)
        IDLE: n_state = (in_valid) ? QUERY_TABLE : IDLE;
        QUERY_TABLE: begin
            if(exposure_table[pic_num][8] == 1) n_state = IDLE;
            else if(mode_ff == 'd0 && focus_table[pic_num] != 'd3) n_state = IDLE;
            else if(mode_ff == 'd1 && ratio_ff == 'd2 && exposure_table[pic_num][7:0] != 'd0) n_state = IDLE;
            else if(mode_ff == 'd2 && min_max_table[pic_num] != 'd0) n_state = IDLE;
            else n_state = WAIT_READ;
        end
        // n_state = (out_valid) ? IDLE : WAIT_READ;
        // HANDSHAKE: n_state =
        WAIT_READ: begin
            if(rvalid_s_inf) n_state = READ_CAL;
            else n_state = WAIT_READ;
        end
        READ_CAL: begin
            if(out_valid) n_state = IDLE;
			else n_state = READ_CAL;
        end
        // OUT: n_state =
        default: n_state = IDLE;
    endcase
end

/*Recieve data*/
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        mode_ff <= 'd0;
        ratio_ff <= 'd0;
        pic_num <= 'd0;
    end
    else begin
        if(in_valid) begin 
            mode_ff <= in_mode;
            ratio_ff <= (in_mode == 'd1) ? in_ratio_mode : 'd2;
            pic_num <= in_pic_no;
        end
    end
end

/*dram_read_cnt*/
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) dram_read_cnt <= 1'b0;
    else begin
        if((rvalid_s_inf && rready_s_inf) || (c_state == READ_CAL && !first_write_flag)) dram_read_cnt <= dram_read_cnt + 1'b1;
        else if (c_state == IDLE) dram_read_cnt <= 1'b0;
    end
end

/*all_zero_flag*/
always @(posedge clk) begin
    if(rvalid_s_inf && rready_s_inf) all_zero_flag <= all_zero_flag & (~|rdata_s_inf);
    else if(c_state == IDLE) all_zero_flag <= 1'b1;
end

// /*RGB_ptr*/
// always @(posedge clk) begin
//     if(c_state == IDLE) RGB_ptr <= 'd0;
//     if(dram_read_cnt > 'd0 && dram_read_cnt < 'd65) RGB_ptr <= 'd0; // cal R
//     else if(dram_read_cnt > 'd64 && dram_read_cnt < 'd129) RGB_ptr <= 'd1; //cal G
//     else if(dram_read_cnt > 'd128 && dram_read_cnt < 'd193) RGB_ptr <= 'd2; // cal B
// end

/*cal_pic*/
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) for(i = 0; i < 16; i = i + 1) cal_pic[i] <= 'd0;
    else begin
        if(rvalid_s_inf && rready_s_inf) begin
            case(ratio_ff)
                'd0: begin
                    cal_pic[0] <= rdata_s_inf[7:0] >> 2;
                    cal_pic[1] <= rdata_s_inf[15:8] >> 2;
                    cal_pic[2] <= rdata_s_inf[23:16] >> 2;
                    cal_pic[3] <= rdata_s_inf[31:24] >> 2;
                    cal_pic[4] <= rdata_s_inf[39:32] >> 2;
                    cal_pic[5] <= rdata_s_inf[47:40] >> 2;
                    cal_pic[6] <= rdata_s_inf[55:48] >> 2;
                    cal_pic[7] <= rdata_s_inf[63:56] >> 2;
                    cal_pic[8] <= rdata_s_inf[71:64] >> 2;
                    cal_pic[9] <= rdata_s_inf[79:72] >> 2;
                    cal_pic[10] <= rdata_s_inf[87:80] >> 2;
                    cal_pic[11] <= rdata_s_inf[95:88] >> 2;
                    cal_pic[12] <= rdata_s_inf[103:96] >> 2;
                    cal_pic[13] <= rdata_s_inf[111:104] >> 2;
                    cal_pic[14] <= rdata_s_inf[119:112] >> 2;
                    cal_pic[15] <= rdata_s_inf[127:120] >> 2;
                end
                'd1: begin
                    cal_pic[0] <= rdata_s_inf[7:0] >> 1;
                    cal_pic[1] <= rdata_s_inf[15:8] >> 1;
                    cal_pic[2] <= rdata_s_inf[23:16] >> 1;
                    cal_pic[3] <= rdata_s_inf[31:24] >> 1;
                    cal_pic[4] <= rdata_s_inf[39:32] >> 1;
                    cal_pic[5] <= rdata_s_inf[47:40] >> 1;
                    cal_pic[6] <= rdata_s_inf[55:48] >> 1;
                    cal_pic[7] <= rdata_s_inf[63:56] >> 1;
                    cal_pic[8] <= rdata_s_inf[71:64] >> 1;
                    cal_pic[9] <= rdata_s_inf[79:72] >> 1;
                    cal_pic[10] <= rdata_s_inf[87:80] >> 1;
                    cal_pic[11] <= rdata_s_inf[95:88] >> 1;
                    cal_pic[12] <= rdata_s_inf[103:96] >> 1;
                    cal_pic[13] <= rdata_s_inf[111:104] >> 1;
                    cal_pic[14] <= rdata_s_inf[119:112] >> 1;
                    cal_pic[15] <= rdata_s_inf[127:120] >> 1;
                end
                'd2: begin
                    cal_pic[0] <= rdata_s_inf[7:0];
                    cal_pic[1] <= rdata_s_inf[15:8];
                    cal_pic[2] <= rdata_s_inf[23:16];
                    cal_pic[3] <= rdata_s_inf[31:24];
                    cal_pic[4] <= rdata_s_inf[39:32];
                    cal_pic[5] <= rdata_s_inf[47:40];
                    cal_pic[6] <= rdata_s_inf[55:48];
                    cal_pic[7] <= rdata_s_inf[63:56];
                    cal_pic[8] <= rdata_s_inf[71:64];
                    cal_pic[9] <= rdata_s_inf[79:72];
                    cal_pic[10] <= rdata_s_inf[87:80];
                    cal_pic[11] <= rdata_s_inf[95:88];
                    cal_pic[12] <= rdata_s_inf[103:96];
                    cal_pic[13] <= rdata_s_inf[111:104];
                    cal_pic[14] <= rdata_s_inf[119:112];
                    cal_pic[15] <= rdata_s_inf[127:120];
                end
                'd3: begin
                    cal_pic[0] <= (rdata_s_inf[7]) ? 'd255 : (rdata_s_inf[7:0] << 1);
                    cal_pic[1] <= (rdata_s_inf[15]) ? 'd255 : (rdata_s_inf[15:8] << 1);
                    cal_pic[2] <= (rdata_s_inf[23]) ? 'd255 : (rdata_s_inf[23:16] << 1);
                    cal_pic[3] <= (rdata_s_inf[31]) ? 'd255 : (rdata_s_inf[31:24] << 1);
                    cal_pic[4] <= (rdata_s_inf[39]) ? 'd255 : (rdata_s_inf[39:32] << 1);
                    cal_pic[5] <= (rdata_s_inf[47]) ? 'd255 : (rdata_s_inf[47:40] << 1);
                    cal_pic[6] <= (rdata_s_inf[55]) ? 'd255 : (rdata_s_inf[55:48] << 1);
                    cal_pic[7] <= (rdata_s_inf[63]) ? 'd255 : (rdata_s_inf[63:56] << 1);
                    cal_pic[8] <= (rdata_s_inf[71]) ? 'd255 : (rdata_s_inf[71:64] << 1);
                    cal_pic[9] <= (rdata_s_inf[79]) ? 'd255 : (rdata_s_inf[79:72] << 1);
                    cal_pic[10] <= (rdata_s_inf[87]) ? 'd255 : (rdata_s_inf[87:80] << 1);
                    cal_pic[11] <= (rdata_s_inf[95]) ? 'd255 : (rdata_s_inf[95:88] << 1);
                    cal_pic[12] <= (rdata_s_inf[103]) ? 'd255 : (rdata_s_inf[103:96] << 1);
                    cal_pic[13] <= (rdata_s_inf[111]) ? 'd255 : (rdata_s_inf[111:104] << 1);
                    cal_pic[14] <= (rdata_s_inf[119]) ? 'd255 : (rdata_s_inf[119:112] << 1);
                    cal_pic[15] <= (rdata_s_inf[127]) ? 'd255 : (rdata_s_inf[127:120] << 1);
                end
            endcase
        end
        else if(c_state == IDLE) for(i = 0; i < 16; i = i + 1) cal_pic[i] <= 'd0;
    end
end

/*add_exp_lay0*/
always @(posedge clk or negedge rst_n) begin // Layer 1:
    if (~rst_n) begin
        add_exp_lay0[0] <= 'd0;
        add_exp_lay0[1] <= 'd0;
        add_exp_lay0[2] <= 'd0;
        add_exp_lay0[3] <= 'd0;
    end
    else begin
        if(c_state == READ_CAL) begin
            if(dram_read_cnt > 'd64 && dram_read_cnt < 'd129) begin //cal G
                // Layer 0:
                add_exp_lay0[0] <= ((cal_pic[0] >> 1) + (cal_pic[1] >> 1)) + ((cal_pic[2] >> 1) + (cal_pic[3] >> 1));
                add_exp_lay0[1] <= ((cal_pic[4] >> 1) + (cal_pic[5] >> 1)) + ((cal_pic[6] >> 1) + (cal_pic[7] >> 1));
                add_exp_lay0[2] <= ((cal_pic[8] >> 1) + (cal_pic[9] >> 1)) + ((cal_pic[10] >> 1) + (cal_pic[11] >> 1));
                add_exp_lay0[3] <= ((cal_pic[12] >> 1) + (cal_pic[13] >> 1)) + ((cal_pic[14] >> 1) + (cal_pic[15] >> 1));
            end
            else if((dram_read_cnt > 'd0 && dram_read_cnt < 'd65) || (dram_read_cnt > 'd128 && dram_read_cnt < 'd193)) begin // cal R & B
                // Layer 0:
                add_exp_lay0[0] <= ((cal_pic[0] >> 2) + (cal_pic[1] >> 2)) + ((cal_pic[2] >> 2) + (cal_pic[3] >> 2));
                add_exp_lay0[1] <= ((cal_pic[4] >> 2) + (cal_pic[5] >> 2)) + ((cal_pic[6] >> 2) + (cal_pic[7] >> 2));
                add_exp_lay0[2] <= ((cal_pic[8] >> 2) + (cal_pic[9] >> 2)) + ((cal_pic[10] >> 2) + (cal_pic[11] >> 2));
                add_exp_lay0[3] <= ((cal_pic[12] >> 2) + (cal_pic[13] >> 2)) + ((cal_pic[14] >> 2) + (cal_pic[15] >> 2));
            end
            else begin
                add_exp_lay0[0] <= 'd0;
                add_exp_lay0[1] <= 'd0;
                add_exp_lay0[2] <= 'd0;
                add_exp_lay0[3] <= 'd0;
            end
        end
        else begin
            add_exp_lay0[0] <= 'd0;
            add_exp_lay0[1] <= 'd0;
            add_exp_lay0[2] <= 'd0;
            add_exp_lay0[3] <= 'd0;
        end
    end
end

/*add_exp_lay1*/
always @(posedge clk or negedge rst_n) begin // Layer 1:
    if (~rst_n) begin
        add_exp_lay1[0] <= 'd0;
        add_exp_lay1[1] <= 'd0;
    end
    else begin
        if(c_state == READ_CAL && !first_write_flag) begin
            add_exp_lay1[0] <= add_exp_lay0[0] + add_exp_lay0[1];
            add_exp_lay1[1] <= add_exp_lay0[2] + add_exp_lay0[3];
        end
        else begin
            add_exp_lay1[0] <= 'd0;
            add_exp_lay1[1] <= 'd0;
        end
    end
end

/*add_exp_lay2*/
always @(posedge clk or negedge rst_n) begin // Layer 2:
    if (~rst_n) add_exp_lay2 <= 'd0;
    else begin
        if(c_state == READ_CAL && !first_write_flag) add_exp_lay2 <= add_exp_lay1[0] + add_exp_lay1[1];
        else add_exp_lay2 <= 'd0;
    end
end

/*focus_pic_loc*/

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) focus_pic_loc <= 'd0;
    else begin
        if(c_state == READ_CAL) begin
            case(dram_read_cnt)
                'd28, 'd30, 'd32, 'd34, 'd36, 'd38: focus_pic_loc <= focus_pic_loc + 1'b1;
                'd39: focus_pic_loc <= 'd0;
                'd92, 'd94, 'd96, 'd98, 'd100, 'd102: focus_pic_loc <= focus_pic_loc + 1'b1;
                'd103: focus_pic_loc <= 'd0;
                'd156, 'd158, 'd160, 'd162, 'd164, 'd166: focus_pic_loc <= focus_pic_loc + 1'b1;
                'd167: focus_pic_loc <= 'd0;
            endcase
        end
        else focus_pic_loc <= 'd0;
    end
end

/*focus_pic*/
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) for(i = 0; i < 6; i = i + 1) focus_pic[i] <= 'd0;
    else begin
        case(dram_read_cnt)
            'd27, 'd29, 'd31, 'd33, 'd35, 'd37: begin //cal R (odd numbers)
                focus_pic[focus_pic_loc][47:40] <= cal_pic[13] >> 2;
                focus_pic[focus_pic_loc][39:32] <= cal_pic[14] >> 2;
                focus_pic[focus_pic_loc][31:24] <= cal_pic[15] >> 2;
            end
            'd28, 'd30, 'd32, 'd34, 'd36, 'd38: begin //cal R (even numbers)
                focus_pic[focus_pic_loc][23:16] <= cal_pic[0] >> 2;
                focus_pic[focus_pic_loc][15:8] <= cal_pic[1] >> 2;
                focus_pic[focus_pic_loc][7:0] <= cal_pic[2] >> 2;
            end
            'd91, 'd93, 'd95, 'd97, 'd99, 'd101: begin //cal G (odd numbers)
                focus_pic[focus_pic_loc][47:40] <= focus_pic[focus_pic_loc][47:40] + (cal_pic[13] >> 1);
                focus_pic[focus_pic_loc][39:32] <= focus_pic[focus_pic_loc][39:32] + (cal_pic[14] >> 1);
                focus_pic[focus_pic_loc][31:24] <= focus_pic[focus_pic_loc][31:24] + (cal_pic[15] >> 1);
            end
            'd92, 'd94, 'd96, 'd98, 'd100, 'd102: begin //cal G (even numbers)
                focus_pic[focus_pic_loc][23:16] <= focus_pic[focus_pic_loc][23:16] + (cal_pic[0] >> 1);
                focus_pic[focus_pic_loc][15:8] <= focus_pic[focus_pic_loc][15:8] + (cal_pic[1] >> 1);
                focus_pic[focus_pic_loc][7:0] <= focus_pic[focus_pic_loc][7:0] + (cal_pic[2] >> 1);
            end
            'd155, 'd157, 'd159, 'd161, 'd163, 'd165: begin //cal B (odd numbers)
                focus_pic[focus_pic_loc][47:40] <= focus_pic[focus_pic_loc][47:40] + (cal_pic[13] >> 2);
                focus_pic[focus_pic_loc][39:32] <= focus_pic[focus_pic_loc][39:32] + (cal_pic[14] >> 2);
                focus_pic[focus_pic_loc][31:24] <= focus_pic[focus_pic_loc][31:24] + (cal_pic[15] >> 2);
            end
            'd156, 'd158, 'd160, 'd162, 'd164, 'd166: begin //cal B (even numbers)
                focus_pic[focus_pic_loc][23:16] <= focus_pic[focus_pic_loc][23:16] + (cal_pic[0] >> 2);
                focus_pic[focus_pic_loc][15:8] <= focus_pic[focus_pic_loc][15:8] + (cal_pic[1] >> 2);
                focus_pic[focus_pic_loc][7:0] <= focus_pic[focus_pic_loc][7:0] + (cal_pic[2] >> 2);
            end
        endcase
    end 
end

/*contrast_pic_row*/
always @(posedge clk) begin
    if(c_state == READ_CAL) begin
        case(dram_read_cnt)
            'd165, 'd167, 'd169, 'd171, 'd173: contrast_pic_row <= contrast_pic_row + 1'b1;
        endcase
    end
    else contrast_pic_row <= 'd0;
end

/*cmp1 & cmp2*/
always @(posedge clk) begin
    if(c_state == READ_CAL) begin
        case(dram_read_cnt)
            'd164, 'd166, 'd168, 'd170, 'd172, 'd174: begin // left-right
                cmp1[0] <= focus_pic[contrast_pic_row][47:40];
                cmp2[0] <= focus_pic[contrast_pic_row][39:32];
                cmp1[1] <= focus_pic[contrast_pic_row][39:32];
                cmp2[1] <= focus_pic[contrast_pic_row][31:24];
                cmp1[2] <= focus_pic[contrast_pic_row][31:24];
                cmp2[2] <= focus_pic[contrast_pic_row][23:16];
                cmp1[3] <= focus_pic[contrast_pic_row][23:16];
                cmp2[3] <= focus_pic[contrast_pic_row][15:8];
                cmp1[4] <= focus_pic[contrast_pic_row][15:8];
                cmp2[4] <= focus_pic[contrast_pic_row][7:0];
                cmp1[5] <= 'd0;
                cmp2[5] <= 'd0;
            end
            'd167, 'd169, 'd171, 'd173, 'd175: begin // up - down
                cmp1[0] <= focus_pic[contrast_pic_row][47:40];
                cmp2[0] <= focus_pic[contrast_pic_row-1][47:40];
                cmp1[1] <= focus_pic[contrast_pic_row][39:32];
                cmp2[1] <= focus_pic[contrast_pic_row-1][39:32];
                cmp1[2] <= focus_pic[contrast_pic_row][31:24];
                cmp2[2] <= focus_pic[contrast_pic_row-1][31:24];
                cmp1[3] <= focus_pic[contrast_pic_row][23:16];
                cmp2[3] <= focus_pic[contrast_pic_row-1][23:16];
                cmp1[4] <= focus_pic[contrast_pic_row][15:8];
                cmp2[4] <= focus_pic[contrast_pic_row-1][15:8];
                cmp1[5] <= focus_pic[contrast_pic_row][7:0];
                cmp2[5] <= focus_pic[contrast_pic_row-1][7:0];
            end
            default: begin
                for(i = 0; i < 6; i = i + 1) begin
                    cmp1[i] <= 'd0;
                    cmp2[i] <= 'd0;
                end
            end
        endcase
    end
    else begin
        for(i = 0; i < 6; i = i + 1) begin
            cmp1[i] <= 'd0;
            cmp2[i] <= 'd0;
        end
    end
end

/*contract_6x6_lay0*/
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        contract_6x6_lay0[0] <= 9'd0;
        contract_6x6_lay0[1] <= 9'd0;
        contract_6x6_lay0[2] <= 9'd0;
    end
    else begin 
        if(c_state == READ_CAL) begin
            case(dram_read_cnt)
                'd166, 'd168, 'd170, 'd172, 'd174, 'd176, 'd169, 'd171, 'd173, 'd175, 'd177: begin
                    contract_6x6_lay0[0] <= cmp_sub_res[0] + cmp_sub_res[1];
                    contract_6x6_lay0[1] <= cmp_sub_res[2] + cmp_sub_res[3];
                    contract_6x6_lay0[2] <= cmp_sub_res[4] + cmp_sub_res[5];
                end
            endcase
        end
        else begin
            contract_6x6_lay0[0] <= 9'd0;
            contract_6x6_lay0[1] <= 9'd0;
            contract_6x6_lay0[2] <= 9'd0;
        end
    end
end

/*contract_6x6_lay1*/
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) contract_6x6_lay1 <= 11'd0;
    else begin
        if(c_state == READ_CAL) begin
            case(dram_read_cnt)
                'd167, 'd169, 'd171, 'd173, 'd175, 'd177, 'd170, 'd172, 'd174, 'd176, 'd178: 
                    contract_6x6_lay1 <= (contract_6x6_lay0[0] + contract_6x6_lay0[1]) + contract_6x6_lay0[2];
            endcase
        end
        else contract_6x6_lay1 <= 11'd0;
    end
end

/*contract_6x6*/
always @(posedge clk) begin
    if(c_state == READ_CAL) begin
        case(dram_read_cnt)
            'd168, 'd170, 'd172, 'd174, 'd176, 'd178, 'd171, 'd173, 'd175, 'd177, 'd179: 
                contract_6x6 <= contract_6x6_lay1 + contract_6x6;
            // 'd180: contract_6x6 <= contract_6x6[13:2] / 'd9;
        endcase
    end
    else contract_6x6 <= 'd0;
end

/*dividend_stage*/
always @(posedge clk or negedge rst_n) begin 
    if(~rst_n) begin
        dividend_stage <= 0;
    end 
    else begin
        if(dram_read_cnt == 'd180) begin
            dividend_stage <= {2'd0, contract_6x6[13:2], 2'd0};
        end
        else if (dram_read_cnt >= 'd181 && dram_read_cnt < 'd189) begin
            // theorem [14:10]
            if (dividend_stage[13:9] >= divisor9) begin
                dividend_stage <= {(dividend_stage[13:9] - divisor9), dividend_stage[8:0], 1'b1};
                // dividend_stage[14:10] <= dividend_stage[13:9] - divisor9;
                // dividend_stage[9:1] <= dividend_stage[8:0];
                // dividend_stage[0] <= 1'b1;
            end
            else dividend_stage <= dividend_stage << 1;
        end
        else dividend_stage <= 'd0;
    end
end

// always @(posedge clk or negedge rst_n) begin
//     if(~rst_n) begin
//         for (i = 0; i < 9; i = i + 1) begin
//             dividend_stage[i] <= 0;
//             quotient_stage[i] <= 0;
//         end
//         divisor9 <= 4'b1001;
//     end 
//     else begin
//         if(dram_read_cnt >= 'd180 && dram_read_cnt <= 'd189) begin
//             dividend_stage[0] <= contract_6x6[13:2];
//             quotient_stage[0] <= 0;

//             if (dividend_stage[0][10:7] >= divisor9) begin
//                 quotient_stage[1] <= quotient_stage[0] + 'd1;
//                 dividend_stage[1] <= dividend_stage[0] - {divisor9, 7'b0};
//             end 
//             else begin
//                 quotient_stage[1] <= quotient_stage[0];
//                 dividend_stage[1] <= dividend_stage[0];
//             end
//             if (dividend_stage[1][10:6] >= divisor9) begin
//                 quotient_stage[2] <= (quotient_stage[1] << 1) + 'd1;
//                 dividend_stage[2] <= dividend_stage[1] - {1'b0, divisor9, 6'b0};
//             end 
//             else begin
//                 quotient_stage[2] <= quotient_stage[1] << 1;
//                 dividend_stage[2] <= dividend_stage[1];
//             end
//             if (dividend_stage[2][9:5] >= divisor9) begin
//                 quotient_stage[3] <= (quotient_stage[2] << 1) + 'd1;
//                 dividend_stage[3] <= dividend_stage[2] - {2'b0, divisor9, 5'b0};
//             end 
//             else begin
//                 quotient_stage[3] <= quotient_stage[2] << 1;
//                 dividend_stage[3] <= dividend_stage[2];
//             end
//             if (dividend_stage[3][8:4] >= divisor9) begin
//                 quotient_stage[4] <= (quotient_stage[3] << 1) + 'd1;
//                 dividend_stage[4] <= dividend_stage[3] - {3'b0, divisor9, 4'b0};
//             end 
//             else begin
//                 quotient_stage[4] <= quotient_stage[3] << 1;
//                 dividend_stage[4] <= dividend_stage[3];
//             end
//             if (dividend_stage[4][7:3] >= divisor9) begin
//                 quotient_stage[5] <= (quotient_stage[4] << 1) + 'd1;
//                 dividend_stage[5] <= dividend_stage[4] - {4'b0, divisor9, 3'b0};
//             end 
//             else begin
//                 quotient_stage[5] <= quotient_stage[4] << 1;
//                 dividend_stage[5] <= dividend_stage[4];
//             end
//             if (dividend_stage[5][6:2] >= divisor9) begin
//                 quotient_stage[6] <= (quotient_stage[5] << 1) + 'd1;
//                 dividend_stage[6] <= dividend_stage[5] - {5'b0, divisor9, 2'b0};
//             end 
//             else begin
//                 quotient_stage[6] <= quotient_stage[5] << 1;
//                 dividend_stage[6] <= dividend_stage[5];
//             end
//             if (dividend_stage[6][5:1] >= divisor9) begin
//                 quotient_stage[7] <= (quotient_stage[6] << 1) + 'd1;
//                 dividend_stage[7] <= dividend_stage[6] - {6'b0, divisor9, 1'b0};
//             end 
//             else begin
//                 quotient_stage[7] <= quotient_stage[6] << 1;
//                 dividend_stage[7] <= dividend_stage[6];
//             end
//             if (dividend_stage[7][4:0] >= divisor9) begin
//                 quotient_stage[8] <= (quotient_stage[7] << 1) + 'd1;
//                 dividend_stage[8] <= dividend_stage[7] - {7'b0, divisor9};
//             end 
//             else begin
//                 quotient_stage[8] <= quotient_stage[7] << 1;
//                 dividend_stage[8] <= dividend_stage[7];
//             end
//         end
//     end
// end


/*contract_4x4*/
always @(posedge clk) begin
    if(c_state == READ_CAL) begin
        case(dram_read_cnt)
            'd168, 'd170, 'd172, 'd174:
                contract_4x4 <= (contract_4x4 + cmp_sub_res[1]) + (cmp_sub_res[2] + cmp_sub_res[3]);
            'd171, 'd173, 'd175: 
                contract_4x4 <= contract_4x4 + (cmp_sub_res[1] + cmp_sub_res[2]) + (cmp_sub_res[3] + cmp_sub_res[4]);
            'd178: contract_4x4 <= {4'd0, contract_4x4[12:4]};
        endcase
    end
    else contract_4x4 <= 'd0;
end

/*contract_2x2*/
always @(posedge clk) begin
    if(c_state == READ_CAL) begin
        case(dram_read_cnt)
            'd170, 'd172: contract_2x2 <= contract_2x2 + cmp_sub_res[2];
            'd173: contract_2x2 <= contract_2x2 + (cmp_sub_res[2] + cmp_sub_res[3]);
            'd178: contract_2x2 <= {2'd0, contract_2x2[9:2]};
        endcase
    end
    else contract_2x2 <= 'd0;
end


/*total_exp_avg*/
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) total_exp_avg <= 'd0;
    else begin
        if(c_state == READ_CAL && !first_write_flag) total_exp_avg <= total_exp_avg + add_exp_lay2;
        else if(c_state == IDLE) total_exp_avg <= 'd0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) for(i = 0; i < 6; i = i + 1) cmp_sub_res[i] <= 'd0;
    // $display("counter = %d",dram_read_cnt);
    // $display("com1 = %d, com2 = %d",cmp1[0], cmp2[0]);
    else for(i = 0; i < 6; i = i + 1) cmp_sub_res[i] <= (cmp1[i] > cmp2[i]) ? (cmp1[i] - cmp2[i]) : (cmp2[i] - cmp1[i]);
end

/*max_contrast*/
always @(posedge clk) begin
    if(c_state == READ_CAL && dram_read_cnt == 'd189) begin
        if(contract_4x4 > contract_2x2) max_contrast <= (dividend_stage[6:0] > contract_4x4) ? 2'd2 : 2'd1;
        else max_contrast <= (dividend_stage[6:0] > contract_2x2) ? 2'd2 : 2'd0;
    end
    else if(c_state == IDLE) max_contrast <= 2'd0;
end

// ------------------------------------------------
//                 Min and Max 
// ------------------------------------------------

// Layer 0: [(0,5),(1,4),(2,12),(3,13),(6,7),(8,9),(10,15),(11,14)]
assign {stage0_0, stage0_5} = (cal_pic[0] > cal_pic[5]) ? {cal_pic[0], cal_pic[5]} : {cal_pic[5], cal_pic[0]};
assign {stage0_1, stage0_4} = (cal_pic[1] > cal_pic[4]) ? {cal_pic[1], cal_pic[4]} : {cal_pic[4], cal_pic[1]};
assign {stage0_2, stage0_12} = (cal_pic[2] > cal_pic[12]) ? {cal_pic[2], cal_pic[12]} : {cal_pic[12], cal_pic[2]};
assign {stage0_3, stage0_13} = (cal_pic[3] > cal_pic[13]) ? {cal_pic[3], cal_pic[13]} : {cal_pic[13], cal_pic[3]};
assign {stage0_6, stage0_7} = (cal_pic[6] > cal_pic[7]) ? {cal_pic[6], cal_pic[7]} : {cal_pic[7], cal_pic[6]};
assign {stage0_8, stage0_9} = (cal_pic[8] > cal_pic[9]) ? {cal_pic[8], cal_pic[9]} : {cal_pic[9], cal_pic[8]};
assign {stage0_10, stage0_15} = (cal_pic[10] > cal_pic[15]) ? {cal_pic[10], cal_pic[15]} : {cal_pic[15], cal_pic[10]};
assign {stage0_11, stage0_14} = (cal_pic[11] > cal_pic[14]) ? {cal_pic[11], cal_pic[14]} : {cal_pic[14], cal_pic[11]};

always @(posedge clk) begin
    // Layer 1: [(0,2),(1,10),(3,6),(4,7),(5,14),(8,11),(9,12),(13,15)]
    {stage1_0, stage1_2} <= (stage0_0 > stage0_2) ? {stage0_0, stage0_2} : {stage0_2, stage0_0};
    {stage1_1, stage1_10} <= (stage0_1 > stage0_10) ? {stage0_1, stage0_10} : {stage0_10, stage0_1};
    {stage1_3, stage1_6} <= (stage0_3 > stage0_6) ? {stage0_3, stage0_6} : {stage0_6, stage0_3};
    {stage1_4, stage1_7} <= (stage0_4 > stage0_7) ? {stage0_4, stage0_7} : {stage0_7, stage0_4};
    {stage1_5, stage1_14} <= (stage0_5 > stage0_14) ? {stage0_5, stage0_14} : {stage0_14, stage0_5};
    {stage1_8, stage1_11} <= (stage0_8 > stage0_11) ? {stage0_8, stage0_11} : {stage0_11, stage0_8};
    {stage1_9, stage1_12} <= (stage0_9 > stage0_12) ? {stage0_9, stage0_12} : {stage0_12, stage0_9};
    {stage1_13, stage1_15} <= (stage0_13 > stage0_15) ? {stage0_13, stage0_15} : {stage0_15, stage0_13};
end

always @(posedge clk) begin
    // Layer 2: [(0,8),(1,3),(7,15),(12,14)]
    {stage2_0, stage2_8} <= (stage1_0 > stage1_8) ? {stage1_0, stage1_8} : {stage1_8, stage1_0};
    {stage2_1, stage2_3} <= (stage1_1 > stage1_3) ? {stage1_1, stage1_3} : {stage1_3, stage1_1};
    {stage2_7, stage2_15} <= (stage1_7 > stage1_15) ? {stage1_7, stage1_15} : {stage1_15, stage1_7};
    {stage2_12, stage2_14} <= (stage1_12 > stage1_14) ? {stage1_12, stage1_14} : {stage1_14, stage1_12};
end

always @(posedge clk) begin
    // Layer 3: [(0,1),(14,15)]
    {max_value16, stage3_1} <= (stage2_0 > stage2_1) ? {stage2_0, stage2_1} : {stage2_1, stage2_0};
    {stage3_14, min_value16} <= (stage2_14 > stage2_15) ? {stage2_14, stage2_15} : {stage2_15, stage2_14};
end
// always @(posedge clk or negedge rst_n) begin
//     if(~rst_n) begin
//         min_res <= 'd255;
//         max_res <= 'd0;
//     end
//     else begin
//         if(c_state == IDLE) begin
//             min_res <= 'd255;
//             max_res <= 'd0;
//         end
//         else if(mode_ff != 0 && dram_read_cnt > 'd0) begin
//             min_res <= stage3_15;
//             max_res <= stage3_0;
//         end
//     end
// end

// SORTING_NET_16 sorter (
//     .cal_pic[0](cal_pic[0]), .cal_pic[1](cal_pic[1]), .cal_pic[2](cal_pic[2]), .cal_pic[3](cal_pic[3]),
//     .cal_pic[4](cal_pic[4]), .cal_pic[5](cal_pic[5]), .cal_pic[6](cal_pic[6]), .cal_pic[7](cal_pic[7]),
//     .cal_pic[8](cal_pic[8]), .cal_pic[9](cal_pic[9]), .cal_pic[10](cal_pic[10]), .cal_pic[11](cal_pic[11]),
//     .cal_pic[12](cal_pic[12]), .cal_pic[13](cal_pic[13]), .cal_pic[14](cal_pic[14]), .cal_pic[15](cal_pic[15]),
//     .min_res(min_value16), 
//     .max_res(max_value16)  
// );
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        curr_min[0] <= 'd255;
        curr_max[0] <= 'd0;
        curr_min[1] <= 'd255;
        curr_max[1] <= 'd0;
        curr_min[2] <= 'd255;
        curr_max[2] <= 'd0;
    end
    else begin
        if(c_state == IDLE) begin
            curr_min[0] <= 'd255;
            curr_max[0] <= 'd0;
            curr_min[1] <= 'd255;
            curr_max[1] <= 'd0;
            curr_min[2] <= 'd255;
            curr_max[2] <= 'd0;
        end
        else if(dram_read_cnt > 'd3) begin
            if(dram_read_cnt > 'd3 && dram_read_cnt < 'd68) begin //R
                curr_min[0] <= (min_value16 < curr_min[0]) ? min_value16 : curr_min[0]; //min
                curr_max[0] <= (max_value16 > curr_max[0]) ? max_value16 : curr_max[0]; //max
            end
            else if(dram_read_cnt > 'd68 && dram_read_cnt < 'd133) begin //G
                curr_min[1] <= (min_value16 < curr_min[1]) ? min_value16 : curr_min[1]; //min
                curr_max[1] <= (max_value16 > curr_max[1]) ? max_value16 : curr_max[1]; //max
            end
            else if(dram_read_cnt > 'd132 && dram_read_cnt < 'd197) begin //B
                curr_min[2] <= (min_value16 < curr_min[2]) ? min_value16 : curr_min[2]; //min
                curr_max[2] <= (max_value16 > curr_max[2]) ? max_value16 : curr_max[2]; //max
            end
        end
    end
end

/*add_avg_lay0*/
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) for(j = 0; j < 3; j = j + 1) add_avg_lay0[j] <= 'd0;
    else begin
        if(dram_read_cnt == 'd197) begin
            add_avg_lay0[0] <= curr_max[0] + curr_max[1];
            add_avg_lay0[1] <= curr_max[2] + curr_min[0];
            add_avg_lay0[2] <= curr_min[1] + curr_min[2];
        end
    end
end

/*add_avg_lay1*/
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) add_avg_lay1 <= 'd0;
    else begin
        if(dram_read_cnt == 'd198) begin
            add_avg_lay1 <= (add_avg_lay0[0] + add_avg_lay0[1] + add_avg_lay0[2]) >> 1;
        end
    end
end
always @(*) begin
    case (add_avg_lay1)
        10'd0  : add_avg_div3 = 10'd0;
        10'd1  : add_avg_div3 = 10'd0;
        10'd2  : add_avg_div3 = 10'd0;
        10'd3  : add_avg_div3 = 10'd1;
        10'd4  : add_avg_div3 = 10'd1;
        10'd5  : add_avg_div3 = 10'd1;
        10'd6  : add_avg_div3 = 10'd2;
        10'd7  : add_avg_div3 = 10'd2;
        10'd8  : add_avg_div3 = 10'd2;
        10'd9  : add_avg_div3 = 10'd3;
        10'd10  : add_avg_div3 = 10'd3;
        10'd11  : add_avg_div3 = 10'd3;
        10'd12  : add_avg_div3 = 10'd4;
        10'd13  : add_avg_div3 = 10'd4;
        10'd14  : add_avg_div3 = 10'd4;
        10'd15  : add_avg_div3 = 10'd5;
        10'd16  : add_avg_div3 = 10'd5;
        10'd17  : add_avg_div3 = 10'd5;
        10'd18  : add_avg_div3 = 10'd6;
        10'd19  : add_avg_div3 = 10'd6;
        10'd20  : add_avg_div3 = 10'd6;
        10'd21  : add_avg_div3 = 10'd7;
        10'd22  : add_avg_div3 = 10'd7;
        10'd23  : add_avg_div3 = 10'd7;
        10'd24  : add_avg_div3 = 10'd8;
        10'd25  : add_avg_div3 = 10'd8;
        10'd26  : add_avg_div3 = 10'd8;
        10'd27  : add_avg_div3 = 10'd9;
        10'd28  : add_avg_div3 = 10'd9;
        10'd29  : add_avg_div3 = 10'd9;
        10'd30  : add_avg_div3 = 10'd10;
        10'd31  : add_avg_div3 = 10'd10;
        10'd32  : add_avg_div3 = 10'd10;
        10'd33  : add_avg_div3 = 10'd11;
        10'd34  : add_avg_div3 = 10'd11;
        10'd35  : add_avg_div3 = 10'd11;
        10'd36  : add_avg_div3 = 10'd12;
        10'd37  : add_avg_div3 = 10'd12;
        10'd38  : add_avg_div3 = 10'd12;
        10'd39  : add_avg_div3 = 10'd13;
        10'd40  : add_avg_div3 = 10'd13;
        10'd41  : add_avg_div3 = 10'd13;
        10'd42  : add_avg_div3 = 10'd14;
        10'd43  : add_avg_div3 = 10'd14;
        10'd44  : add_avg_div3 = 10'd14;
        10'd45  : add_avg_div3 = 10'd15;
        10'd46  : add_avg_div3 = 10'd15;
        10'd47  : add_avg_div3 = 10'd15;
        10'd48  : add_avg_div3 = 10'd16;
        10'd49  : add_avg_div3 = 10'd16;
        10'd50  : add_avg_div3 = 10'd16;
        10'd51  : add_avg_div3 = 10'd17;
        10'd52  : add_avg_div3 = 10'd17;
        10'd53  : add_avg_div3 = 10'd17;
        10'd54  : add_avg_div3 = 10'd18;
        10'd55  : add_avg_div3 = 10'd18;
        10'd56  : add_avg_div3 = 10'd18;
        10'd57  : add_avg_div3 = 10'd19;
        10'd58  : add_avg_div3 = 10'd19;
        10'd59  : add_avg_div3 = 10'd19;
        10'd60  : add_avg_div3 = 10'd20;
        10'd61  : add_avg_div3 = 10'd20;
        10'd62  : add_avg_div3 = 10'd20;
        10'd63  : add_avg_div3 = 10'd21;
        10'd64  : add_avg_div3 = 10'd21;
        10'd65  : add_avg_div3 = 10'd21;
        10'd66  : add_avg_div3 = 10'd22;
        10'd67  : add_avg_div3 = 10'd22;
        10'd68  : add_avg_div3 = 10'd22;
        10'd69  : add_avg_div3 = 10'd23;
        10'd70  : add_avg_div3 = 10'd23;
        10'd71  : add_avg_div3 = 10'd23;
        10'd72  : add_avg_div3 = 10'd24;
        10'd73  : add_avg_div3 = 10'd24;
        10'd74  : add_avg_div3 = 10'd24;
        10'd75  : add_avg_div3 = 10'd25;
        10'd76  : add_avg_div3 = 10'd25;
        10'd77  : add_avg_div3 = 10'd25;
        10'd78  : add_avg_div3 = 10'd26;
        10'd79  : add_avg_div3 = 10'd26;
        10'd80  : add_avg_div3 = 10'd26;
        10'd81  : add_avg_div3 = 10'd27;
        10'd82  : add_avg_div3 = 10'd27;
        10'd83  : add_avg_div3 = 10'd27;
        10'd84  : add_avg_div3 = 10'd28;
        10'd85  : add_avg_div3 = 10'd28;
        10'd86  : add_avg_div3 = 10'd28;
        10'd87  : add_avg_div3 = 10'd29;
        10'd88  : add_avg_div3 = 10'd29;
        10'd89  : add_avg_div3 = 10'd29;
        10'd90  : add_avg_div3 = 10'd30;
        10'd91  : add_avg_div3 = 10'd30;
        10'd92  : add_avg_div3 = 10'd30;
        10'd93  : add_avg_div3 = 10'd31;
        10'd94  : add_avg_div3 = 10'd31;
        10'd95  : add_avg_div3 = 10'd31;
        10'd96  : add_avg_div3 = 10'd32;
        10'd97  : add_avg_div3 = 10'd32;
        10'd98  : add_avg_div3 = 10'd32;
        10'd99  : add_avg_div3 = 10'd33;
        10'd100  : add_avg_div3 = 10'd33;
        10'd101  : add_avg_div3 = 10'd33;
        10'd102  : add_avg_div3 = 10'd34;
        10'd103  : add_avg_div3 = 10'd34;
        10'd104  : add_avg_div3 = 10'd34;
        10'd105  : add_avg_div3 = 10'd35;
        10'd106  : add_avg_div3 = 10'd35;
        10'd107  : add_avg_div3 = 10'd35;
        10'd108  : add_avg_div3 = 10'd36;
        10'd109  : add_avg_div3 = 10'd36;
        10'd110  : add_avg_div3 = 10'd36;
        10'd111  : add_avg_div3 = 10'd37;
        10'd112  : add_avg_div3 = 10'd37;
        10'd113  : add_avg_div3 = 10'd37;
        10'd114  : add_avg_div3 = 10'd38;
        10'd115  : add_avg_div3 = 10'd38;
        10'd116  : add_avg_div3 = 10'd38;
        10'd117  : add_avg_div3 = 10'd39;
        10'd118  : add_avg_div3 = 10'd39;
        10'd119  : add_avg_div3 = 10'd39;
        10'd120  : add_avg_div3 = 10'd40;
        10'd121  : add_avg_div3 = 10'd40;
        10'd122  : add_avg_div3 = 10'd40;
        10'd123  : add_avg_div3 = 10'd41;
        10'd124  : add_avg_div3 = 10'd41;
        10'd125  : add_avg_div3 = 10'd41;
        10'd126  : add_avg_div3 = 10'd42;
        10'd127  : add_avg_div3 = 10'd42;
        10'd128  : add_avg_div3 = 10'd42;
        10'd129  : add_avg_div3 = 10'd43;
        10'd130  : add_avg_div3 = 10'd43;
        10'd131  : add_avg_div3 = 10'd43;
        10'd132  : add_avg_div3 = 10'd44;
        10'd133  : add_avg_div3 = 10'd44;
        10'd134  : add_avg_div3 = 10'd44;
        10'd135  : add_avg_div3 = 10'd45;
        10'd136  : add_avg_div3 = 10'd45;
        10'd137  : add_avg_div3 = 10'd45;
        10'd138  : add_avg_div3 = 10'd46;
        10'd139  : add_avg_div3 = 10'd46;
        10'd140  : add_avg_div3 = 10'd46;
        10'd141  : add_avg_div3 = 10'd47;
        10'd142  : add_avg_div3 = 10'd47;
        10'd143  : add_avg_div3 = 10'd47;
        10'd144  : add_avg_div3 = 10'd48;
        10'd145  : add_avg_div3 = 10'd48;
        10'd146  : add_avg_div3 = 10'd48;
        10'd147  : add_avg_div3 = 10'd49;
        10'd148  : add_avg_div3 = 10'd49;
        10'd149  : add_avg_div3 = 10'd49;
        10'd150  : add_avg_div3 = 10'd50;
        10'd151  : add_avg_div3 = 10'd50;
        10'd152  : add_avg_div3 = 10'd50;
        10'd153  : add_avg_div3 = 10'd51;
        10'd154  : add_avg_div3 = 10'd51;
        10'd155  : add_avg_div3 = 10'd51;
        10'd156  : add_avg_div3 = 10'd52;
        10'd157  : add_avg_div3 = 10'd52;
        10'd158  : add_avg_div3 = 10'd52;
        10'd159  : add_avg_div3 = 10'd53;
        10'd160  : add_avg_div3 = 10'd53;
        10'd161  : add_avg_div3 = 10'd53;
        10'd162  : add_avg_div3 = 10'd54;
        10'd163  : add_avg_div3 = 10'd54;
        10'd164  : add_avg_div3 = 10'd54;
        10'd165  : add_avg_div3 = 10'd55;
        10'd166  : add_avg_div3 = 10'd55;
        10'd167  : add_avg_div3 = 10'd55;
        10'd168  : add_avg_div3 = 10'd56;
        10'd169  : add_avg_div3 = 10'd56;
        10'd170  : add_avg_div3 = 10'd56;
        10'd171  : add_avg_div3 = 10'd57;
        10'd172  : add_avg_div3 = 10'd57;
        10'd173  : add_avg_div3 = 10'd57;
        10'd174  : add_avg_div3 = 10'd58;
        10'd175  : add_avg_div3 = 10'd58;
        10'd176  : add_avg_div3 = 10'd58;
        10'd177  : add_avg_div3 = 10'd59;
        10'd178  : add_avg_div3 = 10'd59;
        10'd179  : add_avg_div3 = 10'd59;
        10'd180  : add_avg_div3 = 10'd60;
        10'd181  : add_avg_div3 = 10'd60;
        10'd182  : add_avg_div3 = 10'd60;
        10'd183  : add_avg_div3 = 10'd61;
        10'd184  : add_avg_div3 = 10'd61;
        10'd185  : add_avg_div3 = 10'd61;
        10'd186  : add_avg_div3 = 10'd62;
        10'd187  : add_avg_div3 = 10'd62;
        10'd188  : add_avg_div3 = 10'd62;
        10'd189  : add_avg_div3 = 10'd63;
        10'd190  : add_avg_div3 = 10'd63;
        10'd191  : add_avg_div3 = 10'd63;
        10'd192  : add_avg_div3 = 10'd64;
        10'd193  : add_avg_div3 = 10'd64;
        10'd194  : add_avg_div3 = 10'd64;
        10'd195  : add_avg_div3 = 10'd65;
        10'd196  : add_avg_div3 = 10'd65;
        10'd197  : add_avg_div3 = 10'd65;
        10'd198  : add_avg_div3 = 10'd66;
        10'd199  : add_avg_div3 = 10'd66;
        10'd200  : add_avg_div3 = 10'd66;
        10'd201  : add_avg_div3 = 10'd67;
        10'd202  : add_avg_div3 = 10'd67;
        10'd203  : add_avg_div3 = 10'd67;
        10'd204  : add_avg_div3 = 10'd68;
        10'd205  : add_avg_div3 = 10'd68;
        10'd206  : add_avg_div3 = 10'd68;
        10'd207  : add_avg_div3 = 10'd69;
        10'd208  : add_avg_div3 = 10'd69;
        10'd209  : add_avg_div3 = 10'd69;
        10'd210  : add_avg_div3 = 10'd70;
        10'd211  : add_avg_div3 = 10'd70;
        10'd212  : add_avg_div3 = 10'd70;
        10'd213  : add_avg_div3 = 10'd71;
        10'd214  : add_avg_div3 = 10'd71;
        10'd215  : add_avg_div3 = 10'd71;
        10'd216  : add_avg_div3 = 10'd72;
        10'd217  : add_avg_div3 = 10'd72;
        10'd218  : add_avg_div3 = 10'd72;
        10'd219  : add_avg_div3 = 10'd73;
        10'd220  : add_avg_div3 = 10'd73;
        10'd221  : add_avg_div3 = 10'd73;
        10'd222  : add_avg_div3 = 10'd74;
        10'd223  : add_avg_div3 = 10'd74;
        10'd224  : add_avg_div3 = 10'd74;
        10'd225  : add_avg_div3 = 10'd75;
        10'd226  : add_avg_div3 = 10'd75;
        10'd227  : add_avg_div3 = 10'd75;
        10'd228  : add_avg_div3 = 10'd76;
        10'd229  : add_avg_div3 = 10'd76;
        10'd230  : add_avg_div3 = 10'd76;
        10'd231  : add_avg_div3 = 10'd77;
        10'd232  : add_avg_div3 = 10'd77;
        10'd233  : add_avg_div3 = 10'd77;
        10'd234  : add_avg_div3 = 10'd78;
        10'd235  : add_avg_div3 = 10'd78;
        10'd236  : add_avg_div3 = 10'd78;
        10'd237  : add_avg_div3 = 10'd79;
        10'd238  : add_avg_div3 = 10'd79;
        10'd239  : add_avg_div3 = 10'd79;
        10'd240  : add_avg_div3 = 10'd80;
        10'd241  : add_avg_div3 = 10'd80;
        10'd242  : add_avg_div3 = 10'd80;
        10'd243  : add_avg_div3 = 10'd81;
        10'd244  : add_avg_div3 = 10'd81;
        10'd245  : add_avg_div3 = 10'd81;
        10'd246  : add_avg_div3 = 10'd82;
        10'd247  : add_avg_div3 = 10'd82;
        10'd248  : add_avg_div3 = 10'd82;
        10'd249  : add_avg_div3 = 10'd83;
        10'd250  : add_avg_div3 = 10'd83;
        10'd251  : add_avg_div3 = 10'd83;
        10'd252  : add_avg_div3 = 10'd84;
        10'd253  : add_avg_div3 = 10'd84;
        10'd254  : add_avg_div3 = 10'd84;
        10'd255  : add_avg_div3 = 10'd85;
        10'd256  : add_avg_div3 = 10'd85;
        10'd257  : add_avg_div3 = 10'd85;
        10'd258  : add_avg_div3 = 10'd86;
        10'd259  : add_avg_div3 = 10'd86;
        10'd260  : add_avg_div3 = 10'd86;
        10'd261  : add_avg_div3 = 10'd87;
        10'd262  : add_avg_div3 = 10'd87;
        10'd263  : add_avg_div3 = 10'd87;
        10'd264  : add_avg_div3 = 10'd88;
        10'd265  : add_avg_div3 = 10'd88;
        10'd266  : add_avg_div3 = 10'd88;
        10'd267  : add_avg_div3 = 10'd89;
        10'd268  : add_avg_div3 = 10'd89;
        10'd269  : add_avg_div3 = 10'd89;
        10'd270  : add_avg_div3 = 10'd90;
        10'd271  : add_avg_div3 = 10'd90;
        10'd272  : add_avg_div3 = 10'd90;
        10'd273  : add_avg_div3 = 10'd91;
        10'd274  : add_avg_div3 = 10'd91;
        10'd275  : add_avg_div3 = 10'd91;
        10'd276  : add_avg_div3 = 10'd92;
        10'd277  : add_avg_div3 = 10'd92;
        10'd278  : add_avg_div3 = 10'd92;
        10'd279  : add_avg_div3 = 10'd93;
        10'd280  : add_avg_div3 = 10'd93;
        10'd281  : add_avg_div3 = 10'd93;
        10'd282  : add_avg_div3 = 10'd94;
        10'd283  : add_avg_div3 = 10'd94;
        10'd284  : add_avg_div3 = 10'd94;
        10'd285  : add_avg_div3 = 10'd95;
        10'd286  : add_avg_div3 = 10'd95;
        10'd287  : add_avg_div3 = 10'd95;
        10'd288  : add_avg_div3 = 10'd96;
        10'd289  : add_avg_div3 = 10'd96;
        10'd290  : add_avg_div3 = 10'd96;
        10'd291  : add_avg_div3 = 10'd97;
        10'd292  : add_avg_div3 = 10'd97;
        10'd293  : add_avg_div3 = 10'd97;
        10'd294  : add_avg_div3 = 10'd98;
        10'd295  : add_avg_div3 = 10'd98;
        10'd296  : add_avg_div3 = 10'd98;
        10'd297  : add_avg_div3 = 10'd99;
        10'd298  : add_avg_div3 = 10'd99;
        10'd299  : add_avg_div3 = 10'd99;
        10'd300  : add_avg_div3 = 10'd100;
        10'd301  : add_avg_div3 = 10'd100;
        10'd302  : add_avg_div3 = 10'd100;
        10'd303  : add_avg_div3 = 10'd101;
        10'd304  : add_avg_div3 = 10'd101;
        10'd305  : add_avg_div3 = 10'd101;
        10'd306  : add_avg_div3 = 10'd102;
        10'd307  : add_avg_div3 = 10'd102;
        10'd308  : add_avg_div3 = 10'd102;
        10'd309  : add_avg_div3 = 10'd103;
        10'd310  : add_avg_div3 = 10'd103;
        10'd311  : add_avg_div3 = 10'd103;
        10'd312  : add_avg_div3 = 10'd104;
        10'd313  : add_avg_div3 = 10'd104;
        10'd314  : add_avg_div3 = 10'd104;
        10'd315  : add_avg_div3 = 10'd105;
        10'd316  : add_avg_div3 = 10'd105;
        10'd317  : add_avg_div3 = 10'd105;
        10'd318  : add_avg_div3 = 10'd106;
        10'd319  : add_avg_div3 = 10'd106;
        10'd320  : add_avg_div3 = 10'd106;
        10'd321  : add_avg_div3 = 10'd107;
        10'd322  : add_avg_div3 = 10'd107;
        10'd323  : add_avg_div3 = 10'd107;
        10'd324  : add_avg_div3 = 10'd108;
        10'd325  : add_avg_div3 = 10'd108;
        10'd326  : add_avg_div3 = 10'd108;
        10'd327  : add_avg_div3 = 10'd109;
        10'd328  : add_avg_div3 = 10'd109;
        10'd329  : add_avg_div3 = 10'd109;
        10'd330  : add_avg_div3 = 10'd110;
        10'd331  : add_avg_div3 = 10'd110;
        10'd332  : add_avg_div3 = 10'd110;
        10'd333  : add_avg_div3 = 10'd111;
        10'd334  : add_avg_div3 = 10'd111;
        10'd335  : add_avg_div3 = 10'd111;
        10'd336  : add_avg_div3 = 10'd112;
        10'd337  : add_avg_div3 = 10'd112;
        10'd338  : add_avg_div3 = 10'd112;
        10'd339  : add_avg_div3 = 10'd113;
        10'd340  : add_avg_div3 = 10'd113;
        10'd341  : add_avg_div3 = 10'd113;
        10'd342  : add_avg_div3 = 10'd114;
        10'd343  : add_avg_div3 = 10'd114;
        10'd344  : add_avg_div3 = 10'd114;
        10'd345  : add_avg_div3 = 10'd115;
        10'd346  : add_avg_div3 = 10'd115;
        10'd347  : add_avg_div3 = 10'd115;
        10'd348  : add_avg_div3 = 10'd116;
        10'd349  : add_avg_div3 = 10'd116;
        10'd350  : add_avg_div3 = 10'd116;
        10'd351  : add_avg_div3 = 10'd117;
        10'd352  : add_avg_div3 = 10'd117;
        10'd353  : add_avg_div3 = 10'd117;
        10'd354  : add_avg_div3 = 10'd118;
        10'd355  : add_avg_div3 = 10'd118;
        10'd356  : add_avg_div3 = 10'd118;
        10'd357  : add_avg_div3 = 10'd119;
        10'd358  : add_avg_div3 = 10'd119;
        10'd359  : add_avg_div3 = 10'd119;
        10'd360  : add_avg_div3 = 10'd120;
        10'd361  : add_avg_div3 = 10'd120;
        10'd362  : add_avg_div3 = 10'd120;
        10'd363  : add_avg_div3 = 10'd121;
        10'd364  : add_avg_div3 = 10'd121;
        10'd365  : add_avg_div3 = 10'd121;
        10'd366  : add_avg_div3 = 10'd122;
        10'd367  : add_avg_div3 = 10'd122;
        10'd368  : add_avg_div3 = 10'd122;
        10'd369  : add_avg_div3 = 10'd123;
        10'd370  : add_avg_div3 = 10'd123;
        10'd371  : add_avg_div3 = 10'd123;
        10'd372  : add_avg_div3 = 10'd124;
        10'd373  : add_avg_div3 = 10'd124;
        10'd374  : add_avg_div3 = 10'd124;
        10'd375  : add_avg_div3 = 10'd125;
        10'd376  : add_avg_div3 = 10'd125;
        10'd377  : add_avg_div3 = 10'd125;
        10'd378  : add_avg_div3 = 10'd126;
        10'd379  : add_avg_div3 = 10'd126;
        10'd380  : add_avg_div3 = 10'd126;
        10'd381  : add_avg_div3 = 10'd127;
        10'd382  : add_avg_div3 = 10'd127;
        10'd383  : add_avg_div3 = 10'd127;
        10'd384  : add_avg_div3 = 10'd128;
        10'd385  : add_avg_div3 = 10'd128;
        10'd386  : add_avg_div3 = 10'd128;
        10'd387  : add_avg_div3 = 10'd129;
        10'd388  : add_avg_div3 = 10'd129;
        10'd389  : add_avg_div3 = 10'd129;
        10'd390  : add_avg_div3 = 10'd130;
        10'd391  : add_avg_div3 = 10'd130;
        10'd392  : add_avg_div3 = 10'd130;
        10'd393  : add_avg_div3 = 10'd131;
        10'd394  : add_avg_div3 = 10'd131;
        10'd395  : add_avg_div3 = 10'd131;
        10'd396  : add_avg_div3 = 10'd132;
        10'd397  : add_avg_div3 = 10'd132;
        10'd398  : add_avg_div3 = 10'd132;
        10'd399  : add_avg_div3 = 10'd133;
        10'd400  : add_avg_div3 = 10'd133;
        10'd401  : add_avg_div3 = 10'd133;
        10'd402  : add_avg_div3 = 10'd134;
        10'd403  : add_avg_div3 = 10'd134;
        10'd404  : add_avg_div3 = 10'd134;
        10'd405  : add_avg_div3 = 10'd135;
        10'd406  : add_avg_div3 = 10'd135;
        10'd407  : add_avg_div3 = 10'd135;
        10'd408  : add_avg_div3 = 10'd136;
        10'd409  : add_avg_div3 = 10'd136;
        10'd410  : add_avg_div3 = 10'd136;
        10'd411  : add_avg_div3 = 10'd137;
        10'd412  : add_avg_div3 = 10'd137;
        10'd413  : add_avg_div3 = 10'd137;
        10'd414  : add_avg_div3 = 10'd138;
        10'd415  : add_avg_div3 = 10'd138;
        10'd416  : add_avg_div3 = 10'd138;
        10'd417  : add_avg_div3 = 10'd139;
        10'd418  : add_avg_div3 = 10'd139;
        10'd419  : add_avg_div3 = 10'd139;
        10'd420  : add_avg_div3 = 10'd140;
        10'd421  : add_avg_div3 = 10'd140;
        10'd422  : add_avg_div3 = 10'd140;
        10'd423  : add_avg_div3 = 10'd141;
        10'd424  : add_avg_div3 = 10'd141;
        10'd425  : add_avg_div3 = 10'd141;
        10'd426  : add_avg_div3 = 10'd142;
        10'd427  : add_avg_div3 = 10'd142;
        10'd428  : add_avg_div3 = 10'd142;
        10'd429  : add_avg_div3 = 10'd143;
        10'd430  : add_avg_div3 = 10'd143;
        10'd431  : add_avg_div3 = 10'd143;
        10'd432  : add_avg_div3 = 10'd144;
        10'd433  : add_avg_div3 = 10'd144;
        10'd434  : add_avg_div3 = 10'd144;
        10'd435  : add_avg_div3 = 10'd145;
        10'd436  : add_avg_div3 = 10'd145;
        10'd437  : add_avg_div3 = 10'd145;
        10'd438  : add_avg_div3 = 10'd146;
        10'd439  : add_avg_div3 = 10'd146;
        10'd440  : add_avg_div3 = 10'd146;
        10'd441  : add_avg_div3 = 10'd147;
        10'd442  : add_avg_div3 = 10'd147;
        10'd443  : add_avg_div3 = 10'd147;
        10'd444  : add_avg_div3 = 10'd148;
        10'd445  : add_avg_div3 = 10'd148;
        10'd446  : add_avg_div3 = 10'd148;
        10'd447  : add_avg_div3 = 10'd149;
        10'd448  : add_avg_div3 = 10'd149;
        10'd449  : add_avg_div3 = 10'd149;
        10'd450  : add_avg_div3 = 10'd150;
        10'd451  : add_avg_div3 = 10'd150;
        10'd452  : add_avg_div3 = 10'd150;
        10'd453  : add_avg_div3 = 10'd151;
        10'd454  : add_avg_div3 = 10'd151;
        10'd455  : add_avg_div3 = 10'd151;
        10'd456  : add_avg_div3 = 10'd152;
        10'd457  : add_avg_div3 = 10'd152;
        10'd458  : add_avg_div3 = 10'd152;
        10'd459  : add_avg_div3 = 10'd153;
        10'd460  : add_avg_div3 = 10'd153;
        10'd461  : add_avg_div3 = 10'd153;
        10'd462  : add_avg_div3 = 10'd154;
        10'd463  : add_avg_div3 = 10'd154;
        10'd464  : add_avg_div3 = 10'd154;
        10'd465  : add_avg_div3 = 10'd155;
        10'd466  : add_avg_div3 = 10'd155;
        10'd467  : add_avg_div3 = 10'd155;
        10'd468  : add_avg_div3 = 10'd156;
        10'd469  : add_avg_div3 = 10'd156;
        10'd470  : add_avg_div3 = 10'd156;
        10'd471  : add_avg_div3 = 10'd157;
        10'd472  : add_avg_div3 = 10'd157;
        10'd473  : add_avg_div3 = 10'd157;
        10'd474  : add_avg_div3 = 10'd158;
        10'd475  : add_avg_div3 = 10'd158;
        10'd476  : add_avg_div3 = 10'd158;
        10'd477  : add_avg_div3 = 10'd159;
        10'd478  : add_avg_div3 = 10'd159;
        10'd479  : add_avg_div3 = 10'd159;
        10'd480  : add_avg_div3 = 10'd160;
        10'd481  : add_avg_div3 = 10'd160;
        10'd482  : add_avg_div3 = 10'd160;
        10'd483  : add_avg_div3 = 10'd161;
        10'd484  : add_avg_div3 = 10'd161;
        10'd485  : add_avg_div3 = 10'd161;
        10'd486  : add_avg_div3 = 10'd162;
        10'd487  : add_avg_div3 = 10'd162;
        10'd488  : add_avg_div3 = 10'd162;
        10'd489  : add_avg_div3 = 10'd163;
        10'd490  : add_avg_div3 = 10'd163;
        10'd491  : add_avg_div3 = 10'd163;
        10'd492  : add_avg_div3 = 10'd164;
        10'd493  : add_avg_div3 = 10'd164;
        10'd494  : add_avg_div3 = 10'd164;
        10'd495  : add_avg_div3 = 10'd165;
        10'd496  : add_avg_div3 = 10'd165;
        10'd497  : add_avg_div3 = 10'd165;
        10'd498  : add_avg_div3 = 10'd166;
        10'd499  : add_avg_div3 = 10'd166;
        10'd500  : add_avg_div3 = 10'd166;
        10'd501  : add_avg_div3 = 10'd167;
        10'd502  : add_avg_div3 = 10'd167;
        10'd503  : add_avg_div3 = 10'd167;
        10'd504  : add_avg_div3 = 10'd168;
        10'd505  : add_avg_div3 = 10'd168;
        10'd506  : add_avg_div3 = 10'd168;
        10'd507  : add_avg_div3 = 10'd169;
        10'd508  : add_avg_div3 = 10'd169;
        10'd509  : add_avg_div3 = 10'd169;
        10'd510  : add_avg_div3 = 10'd170;
        10'd511  : add_avg_div3 = 10'd170;
        10'd512  : add_avg_div3 = 10'd170;
        10'd513  : add_avg_div3 = 10'd171;
        10'd514  : add_avg_div3 = 10'd171;
        10'd515  : add_avg_div3 = 10'd171;
        10'd516  : add_avg_div3 = 10'd172;
        10'd517  : add_avg_div3 = 10'd172;
        10'd518  : add_avg_div3 = 10'd172;
        10'd519  : add_avg_div3 = 10'd173;
        10'd520  : add_avg_div3 = 10'd173;
        10'd521  : add_avg_div3 = 10'd173;
        10'd522  : add_avg_div3 = 10'd174;
        10'd523  : add_avg_div3 = 10'd174;
        10'd524  : add_avg_div3 = 10'd174;
        10'd525  : add_avg_div3 = 10'd175;
        10'd526  : add_avg_div3 = 10'd175;
        10'd527  : add_avg_div3 = 10'd175;
        10'd528  : add_avg_div3 = 10'd176;
        10'd529  : add_avg_div3 = 10'd176;
        10'd530  : add_avg_div3 = 10'd176;
        10'd531  : add_avg_div3 = 10'd177;
        10'd532  : add_avg_div3 = 10'd177;
        10'd533  : add_avg_div3 = 10'd177;
        10'd534  : add_avg_div3 = 10'd178;
        10'd535  : add_avg_div3 = 10'd178;
        10'd536  : add_avg_div3 = 10'd178;
        10'd537  : add_avg_div3 = 10'd179;
        10'd538  : add_avg_div3 = 10'd179;
        10'd539  : add_avg_div3 = 10'd179;
        10'd540  : add_avg_div3 = 10'd180;
        10'd541  : add_avg_div3 = 10'd180;
        10'd542  : add_avg_div3 = 10'd180;
        10'd543  : add_avg_div3 = 10'd181;
        10'd544  : add_avg_div3 = 10'd181;
        10'd545  : add_avg_div3 = 10'd181;
        10'd546  : add_avg_div3 = 10'd182;
        10'd547  : add_avg_div3 = 10'd182;
        10'd548  : add_avg_div3 = 10'd182;
        10'd549  : add_avg_div3 = 10'd183;
        10'd550  : add_avg_div3 = 10'd183;
        10'd551  : add_avg_div3 = 10'd183;
        10'd552  : add_avg_div3 = 10'd184;
        10'd553  : add_avg_div3 = 10'd184;
        10'd554  : add_avg_div3 = 10'd184;
        10'd555  : add_avg_div3 = 10'd185;
        10'd556  : add_avg_div3 = 10'd185;
        10'd557  : add_avg_div3 = 10'd185;
        10'd558  : add_avg_div3 = 10'd186;
        10'd559  : add_avg_div3 = 10'd186;
        10'd560  : add_avg_div3 = 10'd186;
        10'd561  : add_avg_div3 = 10'd187;
        10'd562  : add_avg_div3 = 10'd187;
        10'd563  : add_avg_div3 = 10'd187;
        10'd564  : add_avg_div3 = 10'd188;
        10'd565  : add_avg_div3 = 10'd188;
        10'd566  : add_avg_div3 = 10'd188;
        10'd567  : add_avg_div3 = 10'd189;
        10'd568  : add_avg_div3 = 10'd189;
        10'd569  : add_avg_div3 = 10'd189;
        10'd570  : add_avg_div3 = 10'd190;
        10'd571  : add_avg_div3 = 10'd190;
        10'd572  : add_avg_div3 = 10'd190;
        10'd573  : add_avg_div3 = 10'd191;
        10'd574  : add_avg_div3 = 10'd191;
        10'd575  : add_avg_div3 = 10'd191;
        10'd576  : add_avg_div3 = 10'd192;
        10'd577  : add_avg_div3 = 10'd192;
        10'd578  : add_avg_div3 = 10'd192;
        10'd579  : add_avg_div3 = 10'd193;
        10'd580  : add_avg_div3 = 10'd193;
        10'd581  : add_avg_div3 = 10'd193;
        10'd582  : add_avg_div3 = 10'd194;
        10'd583  : add_avg_div3 = 10'd194;
        10'd584  : add_avg_div3 = 10'd194;
        10'd585  : add_avg_div3 = 10'd195;
        10'd586  : add_avg_div3 = 10'd195;
        10'd587  : add_avg_div3 = 10'd195;
        10'd588  : add_avg_div3 = 10'd196;
        10'd589  : add_avg_div3 = 10'd196;
        10'd590  : add_avg_div3 = 10'd196;
        10'd591  : add_avg_div3 = 10'd197;
        10'd592  : add_avg_div3 = 10'd197;
        10'd593  : add_avg_div3 = 10'd197;
        10'd594  : add_avg_div3 = 10'd198;
        10'd595  : add_avg_div3 = 10'd198;
        10'd596  : add_avg_div3 = 10'd198;
        10'd597  : add_avg_div3 = 10'd199;
        10'd598  : add_avg_div3 = 10'd199;
        10'd599  : add_avg_div3 = 10'd199;
        10'd600  : add_avg_div3 = 10'd200;
        10'd601  : add_avg_div3 = 10'd200;
        10'd602  : add_avg_div3 = 10'd200;
        10'd603  : add_avg_div3 = 10'd201;
        10'd604  : add_avg_div3 = 10'd201;
        10'd605  : add_avg_div3 = 10'd201;
        10'd606  : add_avg_div3 = 10'd202;
        10'd607  : add_avg_div3 = 10'd202;
        10'd608  : add_avg_div3 = 10'd202;
        10'd609  : add_avg_div3 = 10'd203;
        10'd610  : add_avg_div3 = 10'd203;
        10'd611  : add_avg_div3 = 10'd203;
        10'd612  : add_avg_div3 = 10'd204;
        10'd613  : add_avg_div3 = 10'd204;
        10'd614  : add_avg_div3 = 10'd204;
        10'd615  : add_avg_div3 = 10'd205;
        10'd616  : add_avg_div3 = 10'd205;
        10'd617  : add_avg_div3 = 10'd205;
        10'd618  : add_avg_div3 = 10'd206;
        10'd619  : add_avg_div3 = 10'd206;
        10'd620  : add_avg_div3 = 10'd206;
        10'd621  : add_avg_div3 = 10'd207;
        10'd622  : add_avg_div3 = 10'd207;
        10'd623  : add_avg_div3 = 10'd207;
        10'd624  : add_avg_div3 = 10'd208;
        10'd625  : add_avg_div3 = 10'd208;
        10'd626  : add_avg_div3 = 10'd208;
        10'd627  : add_avg_div3 = 10'd209;
        10'd628  : add_avg_div3 = 10'd209;
        10'd629  : add_avg_div3 = 10'd209;
        10'd630  : add_avg_div3 = 10'd210;
        10'd631  : add_avg_div3 = 10'd210;
        10'd632  : add_avg_div3 = 10'd210;
        10'd633  : add_avg_div3 = 10'd211;
        10'd634  : add_avg_div3 = 10'd211;
        10'd635  : add_avg_div3 = 10'd211;
        10'd636  : add_avg_div3 = 10'd212;
        10'd637  : add_avg_div3 = 10'd212;
        10'd638  : add_avg_div3 = 10'd212;
        10'd639  : add_avg_div3 = 10'd213;
        10'd640  : add_avg_div3 = 10'd213;
        10'd641  : add_avg_div3 = 10'd213;
        10'd642  : add_avg_div3 = 10'd214;
        10'd643  : add_avg_div3 = 10'd214;
        10'd644  : add_avg_div3 = 10'd214;
        10'd645  : add_avg_div3 = 10'd215;
        10'd646  : add_avg_div3 = 10'd215;
        10'd647  : add_avg_div3 = 10'd215;
        10'd648  : add_avg_div3 = 10'd216;
        10'd649  : add_avg_div3 = 10'd216;
        10'd650  : add_avg_div3 = 10'd216;
        10'd651  : add_avg_div3 = 10'd217;
        10'd652  : add_avg_div3 = 10'd217;
        10'd653  : add_avg_div3 = 10'd217;
        10'd654  : add_avg_div3 = 10'd218;
        10'd655  : add_avg_div3 = 10'd218;
        10'd656  : add_avg_div3 = 10'd218;
        10'd657  : add_avg_div3 = 10'd219;
        10'd658  : add_avg_div3 = 10'd219;
        10'd659  : add_avg_div3 = 10'd219;
        10'd660  : add_avg_div3 = 10'd220;
        10'd661  : add_avg_div3 = 10'd220;
        10'd662  : add_avg_div3 = 10'd220;
        10'd663  : add_avg_div3 = 10'd221;
        10'd664  : add_avg_div3 = 10'd221;
        10'd665  : add_avg_div3 = 10'd221;
        10'd666  : add_avg_div3 = 10'd222;
        10'd667  : add_avg_div3 = 10'd222;
        10'd668  : add_avg_div3 = 10'd222;
        10'd669  : add_avg_div3 = 10'd223;
        10'd670  : add_avg_div3 = 10'd223;
        10'd671  : add_avg_div3 = 10'd223;
        10'd672  : add_avg_div3 = 10'd224;
        10'd673  : add_avg_div3 = 10'd224;
        10'd674  : add_avg_div3 = 10'd224;
        10'd675  : add_avg_div3 = 10'd225;
        10'd676  : add_avg_div3 = 10'd225;
        10'd677  : add_avg_div3 = 10'd225;
        10'd678  : add_avg_div3 = 10'd226;
        10'd679  : add_avg_div3 = 10'd226;
        10'd680  : add_avg_div3 = 10'd226;
        10'd681  : add_avg_div3 = 10'd227;
        10'd682  : add_avg_div3 = 10'd227;
        10'd683  : add_avg_div3 = 10'd227;
        10'd684  : add_avg_div3 = 10'd228;
        10'd685  : add_avg_div3 = 10'd228;
        10'd686  : add_avg_div3 = 10'd228;
        10'd687  : add_avg_div3 = 10'd229;
        10'd688  : add_avg_div3 = 10'd229;
        10'd689  : add_avg_div3 = 10'd229;
        10'd690  : add_avg_div3 = 10'd230;
        10'd691  : add_avg_div3 = 10'd230;
        10'd692  : add_avg_div3 = 10'd230;
        10'd693  : add_avg_div3 = 10'd231;
        10'd694  : add_avg_div3 = 10'd231;
        10'd695  : add_avg_div3 = 10'd231;
        10'd696  : add_avg_div3 = 10'd232;
        10'd697  : add_avg_div3 = 10'd232;
        10'd698  : add_avg_div3 = 10'd232;
        10'd699  : add_avg_div3 = 10'd233;
        10'd700  : add_avg_div3 = 10'd233;
        10'd701  : add_avg_div3 = 10'd233;
        10'd702  : add_avg_div3 = 10'd234;
        10'd703  : add_avg_div3 = 10'd234;
        10'd704  : add_avg_div3 = 10'd234;
        10'd705  : add_avg_div3 = 10'd235;
        10'd706  : add_avg_div3 = 10'd235;
        10'd707  : add_avg_div3 = 10'd235;
        10'd708  : add_avg_div3 = 10'd236;
        10'd709  : add_avg_div3 = 10'd236;
        10'd710  : add_avg_div3 = 10'd236;
        10'd711  : add_avg_div3 = 10'd237;
        10'd712  : add_avg_div3 = 10'd237;
        10'd713  : add_avg_div3 = 10'd237;
        10'd714  : add_avg_div3 = 10'd238;
        10'd715  : add_avg_div3 = 10'd238;
        10'd716  : add_avg_div3 = 10'd238;
        10'd717  : add_avg_div3 = 10'd239;
        10'd718  : add_avg_div3 = 10'd239;
        10'd719  : add_avg_div3 = 10'd239;
        10'd720  : add_avg_div3 = 10'd240;
        10'd721  : add_avg_div3 = 10'd240;
        10'd722  : add_avg_div3 = 10'd240;
        10'd723  : add_avg_div3 = 10'd241;
        10'd724  : add_avg_div3 = 10'd241;
        10'd725  : add_avg_div3 = 10'd241;
        10'd726  : add_avg_div3 = 10'd242;
        10'd727  : add_avg_div3 = 10'd242;
        10'd728  : add_avg_div3 = 10'd242;
        10'd729  : add_avg_div3 = 10'd243;
        10'd730  : add_avg_div3 = 10'd243;
        10'd731  : add_avg_div3 = 10'd243;
        10'd732  : add_avg_div3 = 10'd244;
        10'd733  : add_avg_div3 = 10'd244;
        10'd734  : add_avg_div3 = 10'd244;
        10'd735  : add_avg_div3 = 10'd245;
        10'd736  : add_avg_div3 = 10'd245;
        10'd737  : add_avg_div3 = 10'd245;
        10'd738  : add_avg_div3 = 10'd246;
        10'd739  : add_avg_div3 = 10'd246;
        10'd740  : add_avg_div3 = 10'd246;
        10'd741  : add_avg_div3 = 10'd247;
        10'd742  : add_avg_div3 = 10'd247;
        10'd743  : add_avg_div3 = 10'd247;
        10'd744  : add_avg_div3 = 10'd248;
        10'd745  : add_avg_div3 = 10'd248;
        10'd746  : add_avg_div3 = 10'd248;
        10'd747  : add_avg_div3 = 10'd249;
        10'd748  : add_avg_div3 = 10'd249;
        10'd749  : add_avg_div3 = 10'd249;
        10'd750  : add_avg_div3 = 10'd250;
        10'd751  : add_avg_div3 = 10'd250;
        10'd752  : add_avg_div3 = 10'd250;
        10'd753  : add_avg_div3 = 10'd251;
        10'd754  : add_avg_div3 = 10'd251;
        10'd755  : add_avg_div3 = 10'd251;
        10'd756  : add_avg_div3 = 10'd252;
        10'd757  : add_avg_div3 = 10'd252;
        10'd758  : add_avg_div3 = 10'd252;
        10'd759  : add_avg_div3 = 10'd253;
        10'd760  : add_avg_div3 = 10'd253;
        10'd761  : add_avg_div3 = 10'd253;
        10'd762  : add_avg_div3 = 10'd254;
        10'd763  : add_avg_div3 = 10'd254;
        10'd764  : add_avg_div3 = 10'd254;
        10'd765  : add_avg_div3 = 10'd255;
        10'd766  : add_avg_div3 = 10'd255;
        10'd767  : add_avg_div3 = 10'd255;
        10'd768  : add_avg_div3 = 10'd256;
        10'd769  : add_avg_div3 = 10'd256;
        10'd770  : add_avg_div3 = 10'd256;
        10'd771  : add_avg_div3 = 10'd257;
        10'd772  : add_avg_div3 = 10'd257;
        10'd773  : add_avg_div3 = 10'd257;
        10'd774  : add_avg_div3 = 10'd258;
        10'd775  : add_avg_div3 = 10'd258;
        10'd776  : add_avg_div3 = 10'd258;
        10'd777  : add_avg_div3 = 10'd259;
        10'd778  : add_avg_div3 = 10'd259;
        10'd779  : add_avg_div3 = 10'd259;
        10'd780  : add_avg_div3 = 10'd260;
        10'd781  : add_avg_div3 = 10'd260;
        10'd782  : add_avg_div3 = 10'd260;
        10'd783  : add_avg_div3 = 10'd261;
        10'd784  : add_avg_div3 = 10'd261;
        10'd785  : add_avg_div3 = 10'd261;
        10'd786  : add_avg_div3 = 10'd262;
        10'd787  : add_avg_div3 = 10'd262;
        10'd788  : add_avg_div3 = 10'd262;
        10'd789  : add_avg_div3 = 10'd263;
        10'd790  : add_avg_div3 = 10'd263;
        10'd791  : add_avg_div3 = 10'd263;
        10'd792  : add_avg_div3 = 10'd264;
        10'd793  : add_avg_div3 = 10'd264;
        10'd794  : add_avg_div3 = 10'd264;
        10'd795  : add_avg_div3 = 10'd265;
        10'd796  : add_avg_div3 = 10'd265;
        10'd797  : add_avg_div3 = 10'd265;
        10'd798  : add_avg_div3 = 10'd266;
        10'd799  : add_avg_div3 = 10'd266;
        10'd800  : add_avg_div3 = 10'd266;
        10'd801  : add_avg_div3 = 10'd267;
        10'd802  : add_avg_div3 = 10'd267;
        10'd803  : add_avg_div3 = 10'd267;
        10'd804  : add_avg_div3 = 10'd268;
        10'd805  : add_avg_div3 = 10'd268;
        10'd806  : add_avg_div3 = 10'd268;
        10'd807  : add_avg_div3 = 10'd269;
        10'd808  : add_avg_div3 = 10'd269;
        10'd809  : add_avg_div3 = 10'd269;
        10'd810  : add_avg_div3 = 10'd270;
        10'd811  : add_avg_div3 = 10'd270;
        10'd812  : add_avg_div3 = 10'd270;
        10'd813  : add_avg_div3 = 10'd271;
        10'd814  : add_avg_div3 = 10'd271;
        10'd815  : add_avg_div3 = 10'd271;
        10'd816  : add_avg_div3 = 10'd272;
        10'd817  : add_avg_div3 = 10'd272;
        10'd818  : add_avg_div3 = 10'd272;
        10'd819  : add_avg_div3 = 10'd273;
        10'd820  : add_avg_div3 = 10'd273;
        10'd821  : add_avg_div3 = 10'd273;
        10'd822  : add_avg_div3 = 10'd274;
        10'd823  : add_avg_div3 = 10'd274;
        10'd824  : add_avg_div3 = 10'd274;
        10'd825  : add_avg_div3 = 10'd275;
        10'd826  : add_avg_div3 = 10'd275;
        10'd827  : add_avg_div3 = 10'd275;
        10'd828  : add_avg_div3 = 10'd276;
        10'd829  : add_avg_div3 = 10'd276;
        10'd830  : add_avg_div3 = 10'd276;
        10'd831  : add_avg_div3 = 10'd277;
        10'd832  : add_avg_div3 = 10'd277;
        10'd833  : add_avg_div3 = 10'd277;
        10'd834  : add_avg_div3 = 10'd278;
        10'd835  : add_avg_div3 = 10'd278;
        10'd836  : add_avg_div3 = 10'd278;
        10'd837  : add_avg_div3 = 10'd279;
        10'd838  : add_avg_div3 = 10'd279;
        10'd839  : add_avg_div3 = 10'd279;
        10'd840  : add_avg_div3 = 10'd280;
        10'd841  : add_avg_div3 = 10'd280;
        10'd842  : add_avg_div3 = 10'd280;
        10'd843  : add_avg_div3 = 10'd281;
        10'd844  : add_avg_div3 = 10'd281;
        10'd845  : add_avg_div3 = 10'd281;
        10'd846  : add_avg_div3 = 10'd282;
        10'd847  : add_avg_div3 = 10'd282;
        10'd848  : add_avg_div3 = 10'd282;
        10'd849  : add_avg_div3 = 10'd283;
        10'd850  : add_avg_div3 = 10'd283;
        10'd851  : add_avg_div3 = 10'd283;
        10'd852  : add_avg_div3 = 10'd284;
        10'd853  : add_avg_div3 = 10'd284;
        10'd854  : add_avg_div3 = 10'd284;
        10'd855  : add_avg_div3 = 10'd285;
        10'd856  : add_avg_div3 = 10'd285;
        10'd857  : add_avg_div3 = 10'd285;
        10'd858  : add_avg_div3 = 10'd286;
        10'd859  : add_avg_div3 = 10'd286;
        10'd860  : add_avg_div3 = 10'd286;
        10'd861  : add_avg_div3 = 10'd287;
        10'd862  : add_avg_div3 = 10'd287;
        10'd863  : add_avg_div3 = 10'd287;
        10'd864  : add_avg_div3 = 10'd288;
        10'd865  : add_avg_div3 = 10'd288;
        10'd866  : add_avg_div3 = 10'd288;
        10'd867  : add_avg_div3 = 10'd289;
        10'd868  : add_avg_div3 = 10'd289;
        10'd869  : add_avg_div3 = 10'd289;
        10'd870  : add_avg_div3 = 10'd290;
        10'd871  : add_avg_div3 = 10'd290;
        10'd872  : add_avg_div3 = 10'd290;
        10'd873  : add_avg_div3 = 10'd291;
        10'd874  : add_avg_div3 = 10'd291;
        10'd875  : add_avg_div3 = 10'd291;
        10'd876  : add_avg_div3 = 10'd292;
        10'd877  : add_avg_div3 = 10'd292;
        10'd878  : add_avg_div3 = 10'd292;
        10'd879  : add_avg_div3 = 10'd293;
        10'd880  : add_avg_div3 = 10'd293;
        10'd881  : add_avg_div3 = 10'd293;
        10'd882  : add_avg_div3 = 10'd294;
        10'd883  : add_avg_div3 = 10'd294;
        10'd884  : add_avg_div3 = 10'd294;
        10'd885  : add_avg_div3 = 10'd295;
        10'd886  : add_avg_div3 = 10'd295;
        10'd887  : add_avg_div3 = 10'd295;
        10'd888  : add_avg_div3 = 10'd296;
        10'd889  : add_avg_div3 = 10'd296;
        10'd890  : add_avg_div3 = 10'd296;
        10'd891  : add_avg_div3 = 10'd297;
        10'd892  : add_avg_div3 = 10'd297;
        10'd893  : add_avg_div3 = 10'd297;
        10'd894  : add_avg_div3 = 10'd298;
        10'd895  : add_avg_div3 = 10'd298;
        10'd896  : add_avg_div3 = 10'd298;
        10'd897  : add_avg_div3 = 10'd299;
        10'd898  : add_avg_div3 = 10'd299;
        10'd899  : add_avg_div3 = 10'd299;
        10'd900  : add_avg_div3 = 10'd300;
        10'd901  : add_avg_div3 = 10'd300;
        10'd902  : add_avg_div3 = 10'd300;
        10'd903  : add_avg_div3 = 10'd301;
        10'd904  : add_avg_div3 = 10'd301;
        10'd905  : add_avg_div3 = 10'd301;
        10'd906  : add_avg_div3 = 10'd302;
        10'd907  : add_avg_div3 = 10'd302;
        10'd908  : add_avg_div3 = 10'd302;
        10'd909  : add_avg_div3 = 10'd303;
        10'd910  : add_avg_div3 = 10'd303;
        10'd911  : add_avg_div3 = 10'd303;
        10'd912  : add_avg_div3 = 10'd304;
        10'd913  : add_avg_div3 = 10'd304;
        10'd914  : add_avg_div3 = 10'd304;
        10'd915  : add_avg_div3 = 10'd305;
        10'd916  : add_avg_div3 = 10'd305;
        10'd917  : add_avg_div3 = 10'd305;
        10'd918  : add_avg_div3 = 10'd306;
        10'd919  : add_avg_div3 = 10'd306;
        10'd920  : add_avg_div3 = 10'd306;
        10'd921  : add_avg_div3 = 10'd307;
        10'd922  : add_avg_div3 = 10'd307;
        10'd923  : add_avg_div3 = 10'd307;
        10'd924  : add_avg_div3 = 10'd308;
        10'd925  : add_avg_div3 = 10'd308;
        10'd926  : add_avg_div3 = 10'd308;
        10'd927  : add_avg_div3 = 10'd309;
        10'd928  : add_avg_div3 = 10'd309;
        10'd929  : add_avg_div3 = 10'd309;
        10'd930  : add_avg_div3 = 10'd310;
        10'd931  : add_avg_div3 = 10'd310;
        10'd932  : add_avg_div3 = 10'd310;
        10'd933  : add_avg_div3 = 10'd311;
        10'd934  : add_avg_div3 = 10'd311;
        10'd935  : add_avg_div3 = 10'd311;
        10'd936  : add_avg_div3 = 10'd312;
        10'd937  : add_avg_div3 = 10'd312;
        10'd938  : add_avg_div3 = 10'd312;
        10'd939  : add_avg_div3 = 10'd313;
        10'd940  : add_avg_div3 = 10'd313;
        10'd941  : add_avg_div3 = 10'd313;
        10'd942  : add_avg_div3 = 10'd314;
        10'd943  : add_avg_div3 = 10'd314;
        10'd944  : add_avg_div3 = 10'd314;
        10'd945  : add_avg_div3 = 10'd315;
        10'd946  : add_avg_div3 = 10'd315;
        10'd947  : add_avg_div3 = 10'd315;
        10'd948  : add_avg_div3 = 10'd316;
        10'd949  : add_avg_div3 = 10'd316;
        10'd950  : add_avg_div3 = 10'd316;
        10'd951  : add_avg_div3 = 10'd317;
        10'd952  : add_avg_div3 = 10'd317;
        10'd953  : add_avg_div3 = 10'd317;
        10'd954  : add_avg_div3 = 10'd318;
        10'd955  : add_avg_div3 = 10'd318;
        10'd956  : add_avg_div3 = 10'd318;
        10'd957  : add_avg_div3 = 10'd319;
        10'd958  : add_avg_div3 = 10'd319;
        10'd959  : add_avg_div3 = 10'd319;
        10'd960  : add_avg_div3 = 10'd320;
        10'd961  : add_avg_div3 = 10'd320;
        10'd962  : add_avg_div3 = 10'd320;
        10'd963  : add_avg_div3 = 10'd321;
        10'd964  : add_avg_div3 = 10'd321;
        10'd965  : add_avg_div3 = 10'd321;
        10'd966  : add_avg_div3 = 10'd322;
        10'd967  : add_avg_div3 = 10'd322;
        10'd968  : add_avg_div3 = 10'd322;
        10'd969  : add_avg_div3 = 10'd323;
        10'd970  : add_avg_div3 = 10'd323;
        10'd971  : add_avg_div3 = 10'd323;
        10'd972  : add_avg_div3 = 10'd324;
        10'd973  : add_avg_div3 = 10'd324;
        10'd974  : add_avg_div3 = 10'd324;
        10'd975  : add_avg_div3 = 10'd325;
        10'd976  : add_avg_div3 = 10'd325;
        10'd977  : add_avg_div3 = 10'd325;
        10'd978  : add_avg_div3 = 10'd326;
        10'd979  : add_avg_div3 = 10'd326;
        10'd980  : add_avg_div3 = 10'd326;
        10'd981  : add_avg_div3 = 10'd327;
        10'd982  : add_avg_div3 = 10'd327;
        10'd983  : add_avg_div3 = 10'd327;
        10'd984  : add_avg_div3 = 10'd328;
        10'd985  : add_avg_div3 = 10'd328;
        10'd986  : add_avg_div3 = 10'd328;
        10'd987  : add_avg_div3 = 10'd329;
        10'd988  : add_avg_div3 = 10'd329;
        10'd989  : add_avg_div3 = 10'd329;
        10'd990  : add_avg_div3 = 10'd330;
        10'd991  : add_avg_div3 = 10'd330;
        10'd992  : add_avg_div3 = 10'd330;
        10'd993  : add_avg_div3 = 10'd331;
        10'd994  : add_avg_div3 = 10'd331;
        10'd995  : add_avg_div3 = 10'd331;
        10'd996  : add_avg_div3 = 10'd332;
        10'd997  : add_avg_div3 = 10'd332;
        10'd998  : add_avg_div3 = 10'd332;
        10'd999  : add_avg_div3 = 10'd333;
        10'd1000  : add_avg_div3 = 10'd333;
        10'd1001  : add_avg_div3 = 10'd333;
        10'd1002  : add_avg_div3 = 10'd334;
        10'd1003  : add_avg_div3 = 10'd334;
        10'd1004  : add_avg_div3 = 10'd334;
        10'd1005  : add_avg_div3 = 10'd335;
        10'd1006  : add_avg_div3 = 10'd335;
        10'd1007  : add_avg_div3 = 10'd335;
        10'd1008  : add_avg_div3 = 10'd336;
        10'd1009  : add_avg_div3 = 10'd336;
        10'd1010  : add_avg_div3 = 10'd336;
        10'd1011  : add_avg_div3 = 10'd337;
        10'd1012  : add_avg_div3 = 10'd337;
        10'd1013  : add_avg_div3 = 10'd337;
        10'd1014  : add_avg_div3 = 10'd338;
        10'd1015  : add_avg_div3 = 10'd338;
        10'd1016  : add_avg_div3 = 10'd338;
        10'd1017  : add_avg_div3 = 10'd339;
        10'd1018  : add_avg_div3 = 10'd339;
        10'd1019  : add_avg_div3 = 10'd339;
        10'd1020  : add_avg_div3 = 10'd340;
        10'd1021  : add_avg_div3 = 10'd340;
        10'd1022  : add_avg_div3 = 10'd340;
        10'd1023  : add_avg_div3 = 10'd341;
    endcase
end

/*min_max_table*/
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) for(j = 0; j < 16; j = j + 1) min_max_table[j] <= 'd0;
    else begin
        if(dram_read_cnt == 'd199) begin
            min_max_table[pic_num] <= add_avg_div3;
        end
    end
end

/*focus_table*/
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) for(j = 0; j < 16; j = j + 1) focus_table[j] <= 'd3;
    else begin
        if(dram_read_cnt == 'd190) focus_table[pic_num] <= max_contrast;
    end
end

/*exposure_table*/
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) for(j = 0; j < 16; j = j + 1) exposure_table[j] <= 'd0;
    else begin
        if(dram_read_cnt == 'd196) exposure_table[pic_num] <= {all_zero_flag, total_exp_avg[17:10]};
    end
end

// ------------------------------------------------
//          Mapping pic_num to pic_addr
// ------------------------------------------------
always @(*) begin
    case (pic_num)
        4'd0: pic_addr = 32'h10000;
        4'd1: pic_addr = 32'h10C00;
        4'd2: pic_addr = 32'h11800;
        4'd3: pic_addr = 32'h12400;
        4'd4: pic_addr = 32'h13000;
        4'd5: pic_addr = 32'h13C00;
        4'd6: pic_addr = 32'h14800;
        4'd7: pic_addr = 32'h15400;
        4'd8: pic_addr = 32'h16000;
        4'd9: pic_addr = 32'h16C00;
        4'd10: pic_addr = 32'h17800;
        4'd11: pic_addr = 32'h18400;
        4'd12: pic_addr = 32'h19000;
        4'd13: pic_addr = 32'h19C00;
        4'd14: pic_addr = 32'h1A800;
        4'd15: pic_addr = 32'h1B400;
        // default: pic_addr = 32'h0; 
    endcase
end

/* Output */
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        out_valid <= 1'b0;
        out_data <= 8'b00000000;
    end
    else begin
        if(mode_ff == 'd0) begin
            if(c_state == QUERY_TABLE) begin
                if(exposure_table[pic_num][8] == 1) begin
                    out_valid <= 1'b1;
                    out_data <= 8'd0;
                end
                else if(focus_table[pic_num] != 'd3) begin
                    out_valid <= 1'b1;
                    out_data <= focus_table[pic_num];
                end
                else begin
                    out_valid <= 1'b0;
                    out_data <= 8'd0;
                end
            end
            else if(dram_read_cnt == 'd199) begin
                out_valid <= 1'b1;
                out_data <= {6'd0, max_contrast};
            end
            else begin
                out_valid <= 1'b0;
                out_data <= 8'd0;
            end     
        end
        else if(mode_ff == 'd1) begin
            if(c_state == QUERY_TABLE) begin
                if(exposure_table[pic_num][8] == 1) begin
                    out_valid <= 1'b1;
                    out_data <= 8'd0;
                end
                else if(ratio_ff == 'd2 && exposure_table[pic_num][7:0] != 'd0) begin
                    out_valid <= 1'b1;
                    out_data <= exposure_table[pic_num][7:0];
                end
                else begin
                    out_valid <= 1'b0;
                    out_data <= 8'd0;
                end
            end
            else if(dram_read_cnt == 'd199) begin
                out_valid <= 1'b1;
                out_data <= exposure_table[pic_num][7:0];
            end
            else begin
                out_valid <= 1'b0;
                out_data <= 8'd0;
            end    
        end
        else if(mode_ff == 'd2) begin
            if(c_state == QUERY_TABLE) begin
                if(exposure_table[pic_num][8] == 1) begin
                    out_valid <= 1'b1;
                    out_data <= 8'd0;
                end
                else if(min_max_table[pic_num] != 'd0) begin
                    out_valid <= 1'b1;
                    out_data <= min_max_table[pic_num];
                end
                else begin
                    out_valid <= 1'b0;
                    out_data <= 8'd0;
                end
            end
            else if(dram_read_cnt == 'd200) begin
                out_valid <= 1'b1;
                out_data <= min_max_table[pic_num];
            end
            else begin
                out_valid <= 1'b0;
                out_data <= 8'd0;
            end     
        end
    end
end
endmodule