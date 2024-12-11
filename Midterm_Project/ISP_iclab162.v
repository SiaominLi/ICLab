module ISP(
    // Input Signals
    input clk,
    input rst_n,
    input in_valid,
    input [3:0] in_pic_no,
    input       in_mode,
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

reg mode_ff;
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

reg [13:0] contract_6x6;
reg [12:0] contract_4x4;
reg [9:0] contract_2x2;

reg [1:0] max_contrast;

reg [1:0] focus_table [0:15];

reg all_zero_flag;
reg [8:0] exposure_table [0:15];


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
            else if(mode_ff && ratio_ff == 'd2 && exposure_table[pic_num][7:0] != 'd0) n_state = IDLE;
            else if(~mode_ff && focus_table[pic_num] != 'd3) n_state = IDLE;
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
            ratio_ff <= (in_mode) ? in_ratio_mode : 'd2;
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

always @(posedge clk) begin
    if(rvalid_s_inf && rready_s_inf) all_zero_flag <= all_zero_flag & (~|rdata_s_inf);
    else if(c_state == IDLE) all_zero_flag <= 1'b1;
end

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
always @(*) begin
    if(c_state == READ_CAL) begin
        if(dram_read_cnt > 'd64 && dram_read_cnt < 'd129) begin //cal G
            // Layer 0:
            add_exp_lay0[0] = ((cal_pic[0] >> 1) + (cal_pic[1] >> 1)) + ((cal_pic[2] >> 1) + (cal_pic[3] >> 1));
            add_exp_lay0[1] = ((cal_pic[4] >> 1) + (cal_pic[5] >> 1)) + ((cal_pic[6] >> 1) + (cal_pic[7] >> 1));
            add_exp_lay0[2] = ((cal_pic[8] >> 1) + (cal_pic[9] >> 1)) + ((cal_pic[10] >> 1) + (cal_pic[11] >> 1));
            add_exp_lay0[3] = ((cal_pic[12] >> 1) + (cal_pic[13] >> 1)) + ((cal_pic[14] >> 1) + (cal_pic[15] >> 1));
        end
        else if((dram_read_cnt > 'd0 && dram_read_cnt < 'd65) || (dram_read_cnt > 'd128 && dram_read_cnt < 'd193)) begin // cal R & B
            // Layer 0:
            add_exp_lay0[0] = ((cal_pic[0] >> 2) + (cal_pic[1] >> 2)) + ((cal_pic[2] >> 2) + (cal_pic[3] >> 2));
            add_exp_lay0[1] = ((cal_pic[4] >> 2) + (cal_pic[5] >> 2)) + ((cal_pic[6] >> 2) + (cal_pic[7] >> 2));
            add_exp_lay0[2] = ((cal_pic[8] >> 2) + (cal_pic[9] >> 2)) + ((cal_pic[10] >> 2) + (cal_pic[11] >> 2));
            add_exp_lay0[3] = ((cal_pic[12] >> 2) + (cal_pic[13] >> 2)) + ((cal_pic[14] >> 2) + (cal_pic[15] >> 2));
        end
        else begin
            add_exp_lay0[0] = 'd0;
            add_exp_lay0[1] = 'd0;
            add_exp_lay0[2] = 'd0;
            add_exp_lay0[3] = 'd0;
        end
    end
    else begin
        add_exp_lay0[0] = 'd0;
        add_exp_lay0[1] = 'd0;
        add_exp_lay0[2] = 'd0;
        add_exp_lay0[3] = 'd0;
    end
end

/*add_exp_lay1*/
always @(*) begin
    // Layer 1:
    add_exp_lay1[0] = add_exp_lay0[0] + add_exp_lay0[1];
    add_exp_lay1[1] = add_exp_lay0[2] + add_exp_lay0[3];
end

/*add_exp_lay2*/
always @(*) begin
    // Layer 2:
    add_exp_lay2 = add_exp_lay1[0] + add_exp_lay1[1];
end

/*focus_pic_loc*/
always @(posedge clk) begin
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
            'd164, 'd166, 'd168, 'd170, 'd172, 'd174: begin // left-reght
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

/*contract_6x6*/
always @(posedge clk) begin
    if(c_state == READ_CAL) begin
        case(dram_read_cnt)
            'd166, 'd168, 'd170, 'd172, 'd174, 'd176, 'd169, 'd171, 'd173, 'd175, 'd177: 
                contract_6x6 <= (contract_6x6 + (cmp_sub_res[0] + cmp_sub_res[1])) + ((cmp_sub_res[2] + cmp_sub_res[3]) + (cmp_sub_res[4] + cmp_sub_res[5]));
            'd178: contract_6x6 <= contract_6x6[13:2] / 'd9;
        endcase
    end
    else contract_6x6 <= 'd0;
end

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

/*cmp_sub_res*/
always @(posedge clk) begin
    // $display("counter = %d",dram_read_cnt);
    // $display("com1 = %d, com2 = %d",cmp1[0], cmp2[0]);
    for(i = 0; i < 6; i = i + 1) cmp_sub_res[i] <= (cmp1[i] > cmp2[i]) ? (cmp1[i] - cmp2[i]) : (cmp2[i] - cmp1[i]);
end

/*max_contrast*/
always @(posedge clk) begin
    if(c_state == READ_CAL && dram_read_cnt == 'd179) begin
        if(contract_4x4 > contract_2x2) max_contrast <= (contract_6x6 > contract_4x4) ? 2'd2 : 2'd1;
        else max_contrast <= (contract_6x6 > contract_2x2) ? 2'd2 : 2'd0;
    end
    else if(c_state == IDLE) max_contrast <= 2'd0;
end

/*focus_table*/
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) for(j = 0; j < 16; j = j + 1) focus_table[j] <= 'd3;
    else begin
        if(dram_read_cnt == 'd180) focus_table[pic_num] <= max_contrast;
    end
end

/*exposure_table*/
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) for(j = 0; j < 16; j = j + 1) exposure_table[j] <= 'd0;
    else begin
        if(mode_ff && dram_read_cnt == 'd193) exposure_table[pic_num] <= {all_zero_flag, total_exp_avg[17:10]};
    end
end


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
        default: pic_addr = 32'h0; 
    endcase
end

/* Output */
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        out_valid <= 1'b0;
        out_data <= 8'b00000000;
    end
    else begin
        if(mode_ff) begin
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
            else if(dram_read_cnt == 'd193) begin
                out_valid <= 1'b1;
                out_data <= total_exp_avg >> 10;
            end
            else begin
                out_valid <= 1'b0;
                out_data <= 8'd0;
            end    
        end
        else begin
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
            else if(dram_read_cnt == 'd193) begin
                out_valid <= 1'b1;
                out_data <= {6'd0, max_contrast};
            end
            else begin
                out_valid <= 1'b0;
                out_data <= 8'd0;
            end     
        end
    end
end
endmodule


