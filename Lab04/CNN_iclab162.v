//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2023 Fall
//   Lab04 Exercise		: Convolution Neural Network 
//   Author     		: Yu-Chi Lin (a6121461214.st12@nycu.edu.tw)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CNN.v
//   Module Name : CNN
//   Release version : V1.0 (Release Date: 2024-10)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module CNN(
    //Input Port
    clk,
    rst_n,
    in_valid,
    Img,
    Kernel_ch1,
    Kernel_ch2,
	Weight,
    Opt,

    //output Port
    out_valid,
    out
);


//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

// IEEE floating point parameter
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

// parameter IDLE = 3'd0;
// parameter IN = 3'd1;
// parameter CAL = 3'd2;
// parameter OUT = 3'd3;

input rst_n, clk, in_valid;
input [inst_sig_width+inst_exp_width:0] Img, Kernel_ch1, Kernel_ch2, Weight;
input Opt;

output reg  out_valid;
output reg [inst_sig_width+inst_exp_width:0] out;

//---------------------------------------------------------------------
//   Reg & Wires
//---------------------------------------------------------------------
reg Opt_reg;
reg [inst_sig_width+inst_exp_width:0] Weight_reg  [0:23];
reg [inst_sig_width+inst_exp_width:0] Kernel_reg1 [0:11];
reg [inst_sig_width+inst_exp_width:0] Kernel_reg2 [0:11];
reg [inst_sig_width+inst_exp_width:0] Img_reg [0:74];

reg [inst_sig_width+inst_exp_width:0] Img_padding_reg [0:146];

integer i;
reg [146:0] img_pixel_num;
reg [inst_sig_width+inst_exp_width:0] mul_1[0:7] ;
reg [inst_sig_width+inst_exp_width:0] mul_2[0:7] ;
wire [inst_sig_width+inst_exp_width:0] mul_res[0:7];
wire[7:0] status_inst;
wire [2:0] inst_rnd;
assign inst_rnd = 0;

wire [inst_sig_width+inst_exp_width:0] conv_sum[0:7];
wire [inst_sig_width+inst_exp_width:0] sum_res[0:1];
wire [inst_sig_width+inst_exp_width:0] add0[0:1], add1[0:1], add_res[0:1];
reg [inst_sig_width+inst_exp_width:0] partial_out_ch1[0:35], partial_out_ch2[0:35];
reg [35:0] partial_out_num;


wire zctr;
assign zctr = 0;
reg [inst_sig_width+inst_exp_width:0] cmp0_1, cmp0_2, cmp1_1, cmp1_2;
reg [inst_sig_width+inst_exp_width:0] cmp0_z0, cmp0_z1, cmp1_z0, cmp1_z1;
reg [inst_sig_width+inst_exp_width:0] kernel_1_max[0:3], kernel_2_max[0:3];
reg [35:0] pooling_cnt;
reg [3:0] max_arr_ptr;

reg [inst_sig_width+inst_exp_width:0] exp_input[0:1];
wire[inst_sig_width+inst_exp_width:0] exp_res[0:1];
// reg [inst_sig_width+inst_exp_width:0] numerator[0:1], denominator[0:1]; // 0 for kernel1 | 1 for kernel2
wire [31:0] ONE;
assign ONE = 32'h 3f800000; // 1 in IEEE 754

reg [inst_sig_width+inst_exp_width:0] addsub0[0:1], addsub1[0:1], addsub_res[0:1];
reg op1, op2;

reg [inst_sig_width+inst_exp_width:0] div_up, div_down, div_res;
reg [inst_sig_width+inst_exp_width:0] activate[0:7];

reg [2:0] fully_cnt;
reg fully_connect_flag;
reg [inst_sig_width+inst_exp_width:0] fully_connect[0:2];

reg [inst_sig_width+inst_exp_width:0] e[0:2];
reg soft_flag;

reg [1:0] c_state, n_state;
reg [74:0] input_cnt;

 
parameter LOAD_and_PADDING = 2'd0,
          LOAD_and_CONV = 2'd1,
          POOLIG_ACTIVA = 2'd2,
          FULLY = 2'd3;
        //   SEND_OUTPUT = 2'd3;
//---------------------------------------------------------------------
// IPs
//---------------------------------------------------------------------

/* Multiplier */
DW_fp_mult #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
           mul0 ( .a(mul_1[0]), .b(mul_2[0]), .rnd(inst_rnd), .z(mul_res[0]), .status(status_inst));
DW_fp_mult #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
           mul1 ( .a(mul_1[1]), .b(mul_2[1]), .rnd(inst_rnd), .z(mul_res[1]), .status(status_inst));
DW_fp_mult #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
           mul2 ( .a(mul_1[2]), .b(mul_2[2]), .rnd(inst_rnd), .z(mul_res[2]), .status(status_inst));
DW_fp_mult #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
           mul3 ( .a(mul_1[3]), .b(mul_2[3]), .rnd(inst_rnd), .z(mul_res[3]), .status(status_inst));

DW_fp_mult #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
           mul4 ( .a(mul_1[4]), .b(mul_2[4]), .rnd(inst_rnd), .z(mul_res[4]), .status(status_inst));
DW_fp_mult #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
           mul5 ( .a(mul_1[5]), .b(mul_2[5]), .rnd(inst_rnd), .z(mul_res[5]), .status(status_inst));
DW_fp_mult #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
           mul6 ( .a(mul_1[6]), .b(mul_2[6]), .rnd(inst_rnd), .z(mul_res[6]), .status(status_inst));
DW_fp_mult #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
           mul7 ( .a(mul_1[7]), .b(mul_2[7]), .rnd(inst_rnd), .z(mul_res[7]), .status(status_inst));

/* Sumer */
DW_fp_sum4 #( inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
            sumer0 (.a(conv_sum[0]), .b(conv_sum[1]), .c(conv_sum[2]), .d(conv_sum[3]), .rnd(inst_rnd), .z(sum_res[0]), .status(status_inst) );
DW_fp_sum4 #( inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
            sumer1 (.a(conv_sum[4]), .b(conv_sum[5]), .c(conv_sum[6]), .d(conv_sum[7]), .rnd(inst_rnd), .z(sum_res[1]), .status(status_inst) );

/* Adder */
DW_fp_add #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
            adder0 ( .a(add0[0]), .b(add0[1]), .rnd(inst_rnd), .z(add_res[0]), .status(status_inst) );
DW_fp_add #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
            adder1 ( .a(add1[0]), .b(add1[1]), .rnd(inst_rnd), .z(add_res[1]), .status(status_inst) );

/* Comparater */
DW_fp_cmp #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
          cmp_0 ( .a(cmp0_1), .b(cmp0_2), .zctr(zctr), .aeqb(), .altb(), .agtb(), .unordered(unordered_inst) , .z0(cmp0_z0), .z1(cmp0_z1), .status0(status_inst), .status1(status_inst) );
DW_fp_cmp #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
          cmp_1 ( .a(cmp1_1), .b(cmp1_2), .zctr(zctr), .aeqb(), .altb(), .agtb(), .unordered(unordered_inst) , .z0(cmp1_z0), .z1(cmp1_z1), .status0(status_inst), .status1(status_inst) );

/* Exponential */
DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch)
          exp0 (.a(exp_input[0]),.z(exp_res[0]),.status(status_inst) );
DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch)
          exp1 (.a(exp_input[1]),.z(exp_res[1]),.status(status_inst) );

/* SubAdder */
DW_fp_addsub #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
          addsub_1 ( .a(addsub0[0]), .b(addsub0[1]), .rnd(inst_rnd),.op(op1), .z(addsub_res[0]), .status(status_inst) );
DW_fp_addsub #( inst_sig_width, inst_exp_width, inst_ieee_compliance)
          addsub_2 ( .a(addsub1[0]), .b(addsub1[1]), .rnd(inst_rnd),.op(op2), .z(addsub_res[1]), .status(status_inst) );

/* Divider */
DW_fp_div #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_faithful_round)
          Div_1( .a(div_up), .b(div_down), .rnd(inst_rnd), .z(div_res), .status(status_inst));
//---------------------------------------------------------------------
// Design
//---------------------------------------------------------------------

/* ----------------------------FSM---------------------------- */
always@(posedge clk or negedge rst_n ) begin 
    if(!rst_n )
        c_state <= LOAD_and_PADDING;
    else
        c_state <= n_state;
end

always@(*) begin  //next state logic
    n_state = c_state;
    
    case(c_state)
        LOAD_and_PADDING : begin
            if(input_cnt == 3) n_state = LOAD_and_CONV;
        end
        LOAD_and_CONV : begin
            if(img_pixel_num == 'd100) n_state = POOLIG_ACTIVA;
        end
        POOLIG_ACTIVA: begin
            if(img_pixel_num == 'd142) n_state = FULLY;
        end
        FULLY : begin 
            if(fully_cnt == 'd7) n_state = LOAD_and_PADDING;
        end
    endcase
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        // out_valid <= 0;
        // out <= 0;
        input_cnt <= 0;
    end
    else begin
        case(c_state)
            LOAD_and_PADDING: begin
                // out_valid <= 0;
                // out       <= 0;
                input_cnt <= 0;
                if(in_valid) begin
                    if(input_cnt == 0) Opt_reg <= Opt ;
                    Weight_reg[input_cnt] <= Weight;
                    Kernel_reg1[input_cnt] <= Kernel_ch1;
                    Kernel_reg2[input_cnt] <= Kernel_ch2;
                    Img_reg[input_cnt] <= Img;

                    input_cnt <= input_cnt + 1;
                end
            end
            LOAD_and_CONV: begin // start CAL
                if(input_cnt < 24) Weight_reg[input_cnt] <= Weight;
                if(input_cnt < 12) begin
                    Kernel_reg1[input_cnt] <= Kernel_ch1;
                    Kernel_reg2[input_cnt] <= Kernel_ch2;
                end
                if(input_cnt < 75) Img_reg[input_cnt] <= Img;

                input_cnt <= input_cnt + 1;
            end
        endcase
    end
end

/* --------------------------Padding-------------------------- */
//Opt_reg = 0 -> zero | Opt_reg = 1 -> Replication
always @(*) begin  //Img_padding_reg [48:0]
    Img_padding_reg[ 0] = (Opt_reg)? Img_reg [ 0]: 0;
    Img_padding_reg[ 1] = (Opt_reg)? Img_reg [ 0]: 0;
    Img_padding_reg[ 2] = (Opt_reg)? Img_reg [ 1]: 0;
    Img_padding_reg[ 3] = (Opt_reg)? Img_reg [ 2]: 0;
    Img_padding_reg[ 4] = (Opt_reg)? Img_reg [ 3]: 0;
    Img_padding_reg[ 5] = (Opt_reg)? Img_reg [ 4]: 0;
    Img_padding_reg[ 6] = (Opt_reg)? Img_reg [ 4]: 0;
    Img_padding_reg[ 7] = (Opt_reg)? Img_reg [ 0]: 0;
    Img_padding_reg[ 8] = Img_reg [ 0];
    Img_padding_reg[ 9] = Img_reg [ 1];
    Img_padding_reg[10] = Img_reg [ 2];
    Img_padding_reg[11] = Img_reg [ 3];
    Img_padding_reg[12] = Img_reg [ 4];
    Img_padding_reg[13] = (Opt_reg)? Img_reg [ 4]: 0;
    Img_padding_reg[14] = (Opt_reg)? Img_reg [ 5]: 0;
    Img_padding_reg[15] = Img_reg [ 5];
    Img_padding_reg[16] = Img_reg [ 6];
    Img_padding_reg[17] = Img_reg [ 7];
    Img_padding_reg[18] = Img_reg [ 8];
    Img_padding_reg[19] = Img_reg [ 9];
    Img_padding_reg[20] = (Opt_reg)? Img_reg [ 9]: 0;
    Img_padding_reg[21] = (Opt_reg)? Img_reg [10]: 0;
    Img_padding_reg[22] = Img_reg [10];
    Img_padding_reg[23] = Img_reg [11];
    Img_padding_reg[24] = Img_reg [12];
    Img_padding_reg[25] = Img_reg [13];
    Img_padding_reg[26] = Img_reg [14];
    Img_padding_reg[27] = (Opt_reg)? Img_reg [14]: 0;
    Img_padding_reg[28] = (Opt_reg)? Img_reg [15]: 0;
    Img_padding_reg[29] = Img_reg [15];
    Img_padding_reg[30] = Img_reg [16];
    Img_padding_reg[31] = Img_reg [17];
    Img_padding_reg[32] = Img_reg [18];
    Img_padding_reg[33] = Img_reg [19];
    Img_padding_reg[34] = (Opt_reg)? Img_reg [19]: 0;
    Img_padding_reg[35] = (Opt_reg)? Img_reg [20]: 0;
    Img_padding_reg[36] = Img_reg [20];
    Img_padding_reg[37] = Img_reg [21];
    Img_padding_reg[38] = Img_reg [22];
    Img_padding_reg[39] = Img_reg [23];
    Img_padding_reg[40] = Img_reg [24];
    Img_padding_reg[41] = (Opt_reg)? Img_reg [24]: 0;
    Img_padding_reg[42] = (Opt_reg)? Img_reg [20]: 0;
    Img_padding_reg[43] = (Opt_reg)? Img_reg [20]: 0;
    Img_padding_reg[44] = (Opt_reg)? Img_reg [21]: 0;
    Img_padding_reg[45] = (Opt_reg)? Img_reg [22]: 0;
    Img_padding_reg[46] = (Opt_reg)? Img_reg [23]: 0;
    Img_padding_reg[47] = (Opt_reg)? Img_reg [24]: 0;
    Img_padding_reg[48] = (Opt_reg)? Img_reg [24]: 0;
end
always @(*) begin  //Img_padding_reg [97:49]
    Img_padding_reg[49] = (Opt_reg)? Img_reg [25]: 0;
    Img_padding_reg[50] = (Opt_reg)? Img_reg [25]: 0;
    Img_padding_reg[51] = (Opt_reg)? Img_reg [26]: 0;
    Img_padding_reg[52] = (Opt_reg)? Img_reg [27]: 0;
    Img_padding_reg[53] = (Opt_reg)? Img_reg [28]: 0;
    Img_padding_reg[54] = (Opt_reg)? Img_reg [29]: 0;
    Img_padding_reg[55] = (Opt_reg)? Img_reg [29]: 0;
    Img_padding_reg[56] = (Opt_reg)? Img_reg [25]: 0;
    Img_padding_reg[57] = Img_reg [25];
    Img_padding_reg[58] = Img_reg [26];
    Img_padding_reg[59] = Img_reg [27];
    Img_padding_reg[60] = Img_reg [28];
    Img_padding_reg[61] = Img_reg [29];
    Img_padding_reg[62] = (Opt_reg)? Img_reg [29]: 0;
    Img_padding_reg[63] = (Opt_reg)? Img_reg [30]: 0;
    Img_padding_reg[64] = Img_reg [30];
    Img_padding_reg[65] = Img_reg [31];
    Img_padding_reg[66] = Img_reg [32];
    Img_padding_reg[67] = Img_reg [33];
    Img_padding_reg[68] = Img_reg [34];
    Img_padding_reg[69] = (Opt_reg)? Img_reg [34]: 0;
    Img_padding_reg[70] = (Opt_reg)? Img_reg [35]: 0;
    Img_padding_reg[71] = Img_reg [35];
    Img_padding_reg[72] = Img_reg [36];
    Img_padding_reg[73] = Img_reg [37];
    Img_padding_reg[74] = Img_reg [38];
    Img_padding_reg[75] = Img_reg [39];
    Img_padding_reg[76] = (Opt_reg)? Img_reg [39]: 0;
    Img_padding_reg[77] = (Opt_reg)? Img_reg [40]: 0;
    Img_padding_reg[78] = Img_reg [40];
    Img_padding_reg[79] = Img_reg [41];
    Img_padding_reg[80] = Img_reg [42];
    Img_padding_reg[81] = Img_reg [43];
    Img_padding_reg[82] = Img_reg [44];
    Img_padding_reg[83] = (Opt_reg)? Img_reg [44]: 0;
    Img_padding_reg[84] = (Opt_reg)? Img_reg [45]: 0;
    Img_padding_reg[85] = Img_reg [45];
    Img_padding_reg[86] = Img_reg [46];
    Img_padding_reg[87] = Img_reg [47];
    Img_padding_reg[88] = Img_reg [48];
    Img_padding_reg[89] = Img_reg [49];
    Img_padding_reg[90] = (Opt_reg)? Img_reg [49]: 0;
    Img_padding_reg[91] = (Opt_reg)? Img_reg [45]: 0;
    Img_padding_reg[92] = (Opt_reg)? Img_reg [45]: 0;
    Img_padding_reg[93] = (Opt_reg)? Img_reg [46]: 0;
    Img_padding_reg[94] = (Opt_reg)? Img_reg [47]: 0;
    Img_padding_reg[95] = (Opt_reg)? Img_reg [48]: 0;
    Img_padding_reg[96] = (Opt_reg)? Img_reg [49]: 0;
    Img_padding_reg[97] = (Opt_reg)? Img_reg [49]: 0;
end
always @(*) begin  //Img_padding_reg [98:146]
    Img_padding_reg[98]  = (Opt_reg)? Img_reg [50]: 0;
    Img_padding_reg[99]  = (Opt_reg)? Img_reg [50]: 0;
    Img_padding_reg[100] = (Opt_reg)? Img_reg [51]: 0;
    Img_padding_reg[101] = (Opt_reg)? Img_reg [52]: 0;
    Img_padding_reg[102] = (Opt_reg)? Img_reg [53]: 0;
    Img_padding_reg[103] = (Opt_reg)? Img_reg [54]: 0;
    Img_padding_reg[104] = (Opt_reg)? Img_reg [54]: 0;
    Img_padding_reg[105] = (Opt_reg)? Img_reg [50]: 0;
    Img_padding_reg[106] = Img_reg [50];
    Img_padding_reg[107] = Img_reg [51];
    Img_padding_reg[108] = Img_reg [52];
    Img_padding_reg[109] = Img_reg [53];
    Img_padding_reg[110] = Img_reg [54];
    Img_padding_reg[111] = (Opt_reg)? Img_reg [54]: 0;
    Img_padding_reg[112] = (Opt_reg)? Img_reg [55]: 0;
    Img_padding_reg[113] = Img_reg [55];
    Img_padding_reg[114] = Img_reg [56];
    Img_padding_reg[115] = Img_reg [57];
    Img_padding_reg[116] = Img_reg [58];
    Img_padding_reg[117] = Img_reg [59];
    Img_padding_reg[118] = (Opt_reg)? Img_reg [59]: 0;
    Img_padding_reg[119] = (Opt_reg)? Img_reg [60]: 0;
    Img_padding_reg[120] = Img_reg [60];
    Img_padding_reg[121] = Img_reg [61];
    Img_padding_reg[122] = Img_reg [62];
    Img_padding_reg[123] = Img_reg [63];
    Img_padding_reg[124] = Img_reg [64];
    Img_padding_reg[125] = (Opt_reg)? Img_reg [64]: 0;
    Img_padding_reg[126] = (Opt_reg)? Img_reg [65]: 0;
    Img_padding_reg[127] = Img_reg [65];
    Img_padding_reg[128] = Img_reg [66];
    Img_padding_reg[129] = Img_reg [67];
    Img_padding_reg[130] = Img_reg [68];
    Img_padding_reg[131] = Img_reg [69];
    Img_padding_reg[132] = (Opt_reg)? Img_reg [69]: 0;
    Img_padding_reg[133] = (Opt_reg)? Img_reg [70]: 0;
    Img_padding_reg[134] = Img_reg [70];
    Img_padding_reg[135] = Img_reg [71];
    Img_padding_reg[136] = Img_reg [72];
    Img_padding_reg[137] = Img_reg [73];
    Img_padding_reg[138] = Img_reg [74];
    Img_padding_reg[139] = (Opt_reg)? Img_reg [74]: 0;
    Img_padding_reg[140] = (Opt_reg)? Img_reg [70]: 0;
    Img_padding_reg[141] = (Opt_reg)? Img_reg [70]: 0;
    Img_padding_reg[142] = (Opt_reg)? Img_reg [71]: 0;
    Img_padding_reg[143] = (Opt_reg)? Img_reg [72]: 0;
    Img_padding_reg[144] = (Opt_reg)? Img_reg [73]: 0;
    Img_padding_reg[145] = (Opt_reg)? Img_reg [74]: 0;
    Img_padding_reg[146] = (Opt_reg)? Img_reg [74]: 0;
end
/* ----------------------------------------------------------- */


/* -----------Control img_pixel_num, partial_out_num---------- */
always@(posedge clk) begin
    case(c_state)
        LOAD_and_PADDING: begin // initial
            img_pixel_num <= 0;
            partial_out_num <= 0;
        end
        LOAD_and_CONV, POOLIG_ACTIVA : begin
            case(img_pixel_num)
                'd5, 'd12, 'd19, 'd26, 'd33, 'd54, 'd61, 'd68,
                'd75, 'd82, 'd103, 'd110, 'd117, 'd124, 'd131 : img_pixel_num <= img_pixel_num + 2;
                'd40, 'd89: img_pixel_num <= img_pixel_num + 9;
                // 'd138
                default: img_pixel_num <= img_pixel_num + 1;
            endcase

            if(partial_out_num == 'd35) partial_out_num <= 0;
            else if(sum_res[0] != 0)  partial_out_num <= partial_out_num + 1;
        end
    endcase
end

/* -------------------Control mul_1, mul_2-------------------- */
always@(posedge clk) begin
    case(c_state)
        LOAD_and_PADDING: begin // initial
            for(i = 0 ; i < 8 ; i = i + 1) begin
                mul_1[i] <= 0;
                mul_2[i] <= 0;
            end
        end
        LOAD_and_CONV, POOLIG_ACTIVA : begin
            mul_1[0] <= Img_padding_reg[img_pixel_num];
            mul_1[1] <= Img_padding_reg[img_pixel_num + 1];
            mul_1[2] <= Img_padding_reg[img_pixel_num + 7];
            mul_1[3] <= Img_padding_reg[img_pixel_num + 8];
            mul_1[4] <= Img_padding_reg[img_pixel_num];
            mul_1[5] <= Img_padding_reg[img_pixel_num + 1];
            mul_1[6] <= Img_padding_reg[img_pixel_num + 7];
            mul_1[7] <= Img_padding_reg[img_pixel_num + 8];

            if( img_pixel_num < 41 ) begin
                mul_2[0] <= Kernel_reg1[0];
                mul_2[1] <= Kernel_reg1[1];
                mul_2[2] <= Kernel_reg1[2];
                mul_2[3] <= Kernel_reg1[3];
                mul_2[4] <= Kernel_reg2[0];
                mul_2[5] <= Kernel_reg2[1];
                mul_2[6] <= Kernel_reg2[2];
                mul_2[7] <= Kernel_reg2[3];
            end
            else if( img_pixel_num < 90 ) begin
                mul_2[0] <= Kernel_reg1[4];
                mul_2[1] <= Kernel_reg1[5];
                mul_2[2] <= Kernel_reg1[6];
                mul_2[3] <= Kernel_reg1[7];
                mul_2[4] <= Kernel_reg2[4];
                mul_2[5] <= Kernel_reg2[5];
                mul_2[6] <= Kernel_reg2[6];
                mul_2[7] <= Kernel_reg2[7];
            end
            else if( img_pixel_num < 139 ) begin
                mul_2[0] <= Kernel_reg1[8];
                mul_2[1] <= Kernel_reg1[9];
                mul_2[2] <= Kernel_reg1[10];
                mul_2[3] <= Kernel_reg1[11];
                mul_2[4] <= Kernel_reg2[8];
                mul_2[5] <= Kernel_reg2[9];
                mul_2[6] <= Kernel_reg2[10];
                mul_2[7] <= Kernel_reg2[11];
            end
            else begin
                for(i = 0 ; i < 8 ; i = i + 1) begin
                    mul_1[i] <= 0;
                    mul_2[i] <= 0;
                end
            end
        end
        FULLY : begin
            mul_1[0] <= activate[0];
            mul_1[1] <= activate[1];
            mul_1[2] <= activate[2];
            mul_1[3] <= activate[3];
            mul_1[4] <= activate[4];
            mul_1[5] <= activate[5];
            mul_1[6] <= activate[6];
            mul_1[7] <= activate[7];

            if( fully_cnt == 0 ) begin
                mul_2[0] <= Weight_reg[0];
                mul_2[1] <= Weight_reg[1];
                mul_2[2] <= Weight_reg[2];
                mul_2[3] <= Weight_reg[3];
                mul_2[4] <= Weight_reg[4];
                mul_2[5] <= Weight_reg[5];
                mul_2[6] <= Weight_reg[6];
                mul_2[7] <= Weight_reg[7];
            end
            else if( fully_cnt == 1 ) begin
                mul_2[0] <= Weight_reg[8];
                mul_2[1] <= Weight_reg[9];
                mul_2[2] <= Weight_reg[10];
                mul_2[3] <= Weight_reg[11];
                mul_2[4] <= Weight_reg[12];
                mul_2[5] <= Weight_reg[13];
                mul_2[6] <= Weight_reg[14];
                mul_2[7] <= Weight_reg[15];
            end
            else if( fully_cnt == 2 ) begin
                mul_2[0] <= Weight_reg[16];
                mul_2[1] <= Weight_reg[17];
                mul_2[2] <= Weight_reg[18];
                mul_2[3] <= Weight_reg[19];
                mul_2[4] <= Weight_reg[20];
                mul_2[5] <= Weight_reg[21];
                mul_2[6] <= Weight_reg[22];
                mul_2[7] <= Weight_reg[23];
            end
            else begin
                for(i = 0 ; i < 8 ; i = i + 1) begin
                    mul_1[i] <= 0;
                    mul_2[i] <= 0;
                end
            end
        end
    endcase
end

assign conv_sum[0] = soft_flag ? e[0] : mul_res[0];
assign conv_sum[1] = soft_flag ? e[1] : mul_res[1];
assign conv_sum[2] = soft_flag ? e[2] : mul_res[2];
assign conv_sum[3] = soft_flag ? 0 : mul_res[3];
assign conv_sum[4] = mul_res[4];
assign conv_sum[5] = mul_res[5];
assign conv_sum[6] = mul_res[6];
assign conv_sum[7] = mul_res[7];


assign add0[0] = (fully_connect_flag) ? sum_res[1] : partial_out_ch1[partial_out_num];
assign add0[1] = sum_res[0];
assign add1[0] = (fully_connect_flag) ? 0 : partial_out_ch2[partial_out_num];
assign add1[1] = (fully_connect_flag) ? 0 : sum_res[1];


always@(posedge clk) begin
    case(c_state)
        LOAD_and_PADDING: begin // initial
            for(i = 0 ; i < 36 ; i = i + 1) begin
                partial_out_ch1[i] <= 0;
                partial_out_ch2[i] <= 0;
            end
        end
        LOAD_and_CONV, POOLIG_ACTIVA : begin
            partial_out_ch1[partial_out_num] <= add_res[0];
            partial_out_ch2[partial_out_num] <= add_res[1];
        end
    endcase
end


/* --------------------Control pooling_cnt ------------------- */
always @(posedge clk) begin
    case(c_state)
        LOAD_and_PADDING: begin // initial
            pooling_cnt <= 0;
            max_arr_ptr <= 0;
        end
        POOLIG_ACTIVA : begin
            case(img_pixel_num)
                'd100: begin
                    pooling_cnt <= 0;
                    max_arr_ptr <= 0;
                end
                'd101: begin
                    pooling_cnt <= 2;
                    max_arr_ptr <= 0;
                end
                'd106, 'd107, 'd108: begin
                    pooling_cnt <= img_pixel_num - 100;
                    max_arr_ptr <= 0;
                end
                'd113, 'd114, 'd115: begin
                    pooling_cnt <= img_pixel_num - 101;
                    max_arr_ptr <= 0;
                end

                'd103: begin
                    pooling_cnt <= 3;
                    max_arr_ptr <= 1;
                end
                'd105: begin
                    pooling_cnt <= 5;
                    max_arr_ptr <= 1;
                end
                'd109, 'd110: begin
                    pooling_cnt <= img_pixel_num - 100;
                    max_arr_ptr <= 1;
                end
                'd112, 'd116, 'd117: begin
                    pooling_cnt <= img_pixel_num - 101;
                    max_arr_ptr <= 1;
                end
                'd119: begin
                    pooling_cnt <= img_pixel_num - 102;
                    max_arr_ptr <= 1;
                end

                'd121: begin
                    pooling_cnt <= 18;
                    max_arr_ptr <= 2;
                end
                'd122: begin
                    pooling_cnt <= 20;
                    max_arr_ptr <= 2;
                end
                'd127, 'd128, 'd129: begin
                    pooling_cnt <= img_pixel_num - 103;
                    max_arr_ptr <= 2;
                end
                'd134, 'd135, 'd136: begin
                    pooling_cnt <= img_pixel_num - 104;
                    max_arr_ptr <= 2;
                end

                'd123: begin
                    pooling_cnt <= 21;
                    max_arr_ptr <= 3;
                end
                'd126: begin
                    pooling_cnt <= 23;
                    max_arr_ptr <= 3;
                end
                'd130, 'd131: begin
                    pooling_cnt <= img_pixel_num - 103;
                    max_arr_ptr <= 3;
                end
                'd133: begin
                    pooling_cnt <= img_pixel_num - 104;
                    max_arr_ptr <= 3;
                end
                'd137, 'd138, 'd139: begin
                    pooling_cnt <= img_pixel_num - 104;
                    max_arr_ptr <= 3;
                end
            endcase
        end
    endcase
end


/* --------------------Control kernel_?_max ------------------ */
always@(posedge clk) begin
    case(c_state)
        LOAD_and_PADDING: begin // initial
            kernel_1_max[0] <= partial_out_ch1[0];
            kernel_1_max[1] <= partial_out_ch1[3];
            kernel_1_max[2] <= partial_out_ch1[18];
            kernel_1_max[3] <= partial_out_ch1[21];

            kernel_2_max[0] <= partial_out_ch2[0];
            kernel_2_max[1] <= partial_out_ch2[3];
            kernel_2_max[2] <= partial_out_ch2[18];
            kernel_2_max[3] <= partial_out_ch2[21];
        end
        POOLIG_ACTIVA : begin
            case(img_pixel_num)
                'd101, 'd105, 'd122, 'd126,
                'd102, 'd107, 'd108, 'd109, 'd114, 'd115, 'd116,
                'd106, 'd110, 'd112, 'd113, 'd117, 'd119, 'd120,
                'd123, 'd128, 'd129, 'd130, 'd135, 'd136, 'd137,
                'd127, 'd131, 'd133, 'd134, 'd138, 'd139, 'd140: begin
                    kernel_1_max[max_arr_ptr] <= zctr ? cmp0_z0 : cmp0_z1;
                    kernel_2_max[max_arr_ptr] <= zctr ? cmp1_z0 : cmp1_z1;
                end
            endcase
        end
    endcase
end

/* -------------------- max pooling compare ------------------ */
always @(*) begin
    case(img_pixel_num)
        'd101, 'd105, 'd122, 'd126: begin
            cmp0_1 = partial_out_ch1[pooling_cnt];
            cmp0_2 = partial_out_ch1[pooling_cnt + 1];

            cmp1_1 = partial_out_ch2[pooling_cnt];
            cmp1_2 = partial_out_ch2[pooling_cnt + 1];
        end

        'd102, 'd107, 'd108, 'd109, 'd114, 'd115, 'd116,
        'd106, 'd110, 'd112, 'd113, 'd117, 'd119, 'd120,
        'd123, 'd128, 'd129, 'd130, 'd135, 'd136, 'd137,
        'd127, 'd131, 'd133, 'd134, 'd138, 'd139, 'd140: begin
            cmp0_1 = partial_out_ch1[pooling_cnt];
            cmp0_2 = kernel_1_max[max_arr_ptr];

            cmp1_1 = partial_out_ch2[pooling_cnt];
            cmp1_2 = kernel_2_max[max_arr_ptr];
        end
        default: begin
            cmp0_1 = 0;
            cmp0_2 = 0;
            cmp1_1 = 0;
            cmp1_2 = 0;
        end
    endcase
end

/* -------------------- Activation Function ------------------ */
always @(*) begin // Opt_reg = 0 : sigmoid | Opt_reg = 1 : tanh
    // 114, 117, 135, 138
    case(c_state)
        FULLY : begin
            case(fully_cnt)
                3: begin
                    exp_input[0] = fully_connect[0];
                    exp_input[1] = fully_connect[1];
                    div_up = 0;
                    div_down = 0;
                    addsub0[0] = 0;
                    addsub0[1] = 0;
                    addsub1[0] = 0;
                    addsub1[1] = 0;
                    op1 = 1'b0;
                    op2 = 1'b0;
                end
                4: begin
                    exp_input[0] = fully_connect[2];
                    exp_input[1] = 0;
                    div_up = 0;
                    div_down = 0;
                    addsub0[0] = 0;
                    addsub0[1] = 0;
                    addsub1[0] = 0;
                    addsub1[1] = 0;
                    op1 = 1'b0;
                    op2 = 1'b0;
                end
                5: begin
                    exp_input[0] = 0;
                    exp_input[1] = 0;
                    div_up = e[0];
                    div_down = sum_res[0];
                    addsub0[0] = 0;
                    addsub0[1] = 0;
                    addsub1[0] = 0;
                    addsub1[1] = 0;
                    op1 = 1'b0;
                    op2 = 1'b0;
                end
                6: begin
                    exp_input[0] = 0;
                    exp_input[1] = 0;
                    div_up = e[1];
                    div_down = sum_res[0];
                    addsub0[0] = 0;
                    addsub0[1] = 0;
                    addsub1[0] = 0;
                    addsub1[1] = 0;
                    op1 = 1'b0;
                    op2 = 1'b0;
                end
                7: begin
                    exp_input[0] = 0;
                    exp_input[1] = 0;
                    div_up = e[2];
                    div_down = sum_res[0];
                    addsub0[0] = 0;
                    addsub0[1] = 0;
                    addsub1[0] = 0;
                    addsub1[1] = 0;
                    op1 = 1'b0;
                    op2 = 1'b0;
                end
                default: begin
                    exp_input[0] = 0;
                    exp_input[1] = 0;
                    div_up = 0;
                    div_down = 0;
                    addsub0[0] = 0;
                    addsub0[1] = 0;
                    addsub1[0] = 0;
                    addsub1[1] = 0;
                    op1 = 1'b0;
                    op2 = 1'b0;
                end
            endcase
        end
        POOLIG_ACTIVA: begin
            case(img_pixel_num)
                'd121: begin
                    exp_input[0][31] = ~kernel_1_max[0][31];
                    exp_input[0][30:0] = kernel_1_max[0][30:0];

                    if(Opt_reg) begin // tanh
                        exp_input[1] = kernel_1_max[0];

                        addsub0[0] = exp_res[1];
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;

                        addsub1[0] = exp_res[1];
                        addsub1[1] = exp_res[0];
                        op2 = 1'b1;

                        div_up = addsub_res[1];
                        div_down = addsub_res[0];
                    end
                    else begin // sigmoid
                        exp_input[1] = 0;
                        op2 = 1'b0;
                        addsub1[0] = 0;
                        addsub1[1] = 0;

                        addsub0[0] = ONE;
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;
                        
                        div_up = ONE;
                        div_down = addsub_res[0];
                    end
                end
                'd122: begin
                    exp_input[0][31] = ~kernel_2_max[0][31];
                    exp_input[0][30:0] = kernel_2_max[0][30:0];

                    if(Opt_reg) begin // tanh
                        exp_input[1] = kernel_2_max[0];

                        addsub0[0] = exp_res[1];
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;

                        addsub1[0] = exp_res[1];
                        addsub1[1] = exp_res[0];
                        op2 = 1'b1;

                        div_up = addsub_res[1];
                        div_down = addsub_res[0];
                    end
                    else begin // sigmoid
                        exp_input[1] = 0;
                        op2 = 1'b0;
                        addsub1[0] = 0;
                        addsub1[1] = 0;

                        addsub0[0] = ONE;
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;
                        
                        div_up = ONE;
                        div_down = addsub_res[0];
                    end
                end
                'd123: begin
                    exp_input[0][31] = ~kernel_1_max[1][31];
                    exp_input[0][30:0] = kernel_1_max[1][30:0];

                    if(Opt_reg) begin // tanh
                        exp_input[1] = kernel_1_max[1];

                        addsub0[0] = exp_res[1];
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;

                        addsub1[0] = exp_res[1];
                        addsub1[1] = exp_res[0];
                        op2 = 1'b1;

                        div_up = addsub_res[1];
                        div_down = addsub_res[0];
                    end
                    else begin // sigmoid
                        exp_input[1] = 0;
                        op2 = 1'b0;
                        addsub1[0] = 0;
                        addsub1[1] = 0;
                        
                        addsub0[0] = ONE;
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;
                        
                        div_up = ONE;
                        div_down = addsub_res[0];
                    end
                end
                'd124: begin
                    exp_input[0][31] = ~kernel_2_max[1][31];
                    exp_input[0][30:0] = kernel_2_max[1][30:0];

                    if(Opt_reg) begin // tanh
                        exp_input[1] = kernel_2_max[1];

                        addsub0[0] = exp_res[1];
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;

                        addsub1[0] = exp_res[1];
                        addsub1[1] = exp_res[0];
                        op2 = 1'b1;

                        div_up = addsub_res[1];
                        div_down = addsub_res[0];
                    end
                    else begin // sigmoid
                        exp_input[1] = 0;
                        op2 = 1'b0;
                        addsub1[0] = 0;
                        addsub1[1] = 0;
                        
                        addsub0[0] = ONE;
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;
                        
                        div_up = ONE;
                        div_down = addsub_res[0];
                    end
                end
                'd139: begin
                    exp_input[0][31] = ~kernel_1_max[2][31];
                    exp_input[0][30:0] = kernel_1_max[2][30:0];

                    if(Opt_reg) begin // tanh
                        exp_input[1] = kernel_1_max[2];

                        addsub0[0] = exp_res[1];
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;

                        addsub1[0] = exp_res[1];
                        addsub1[1] = exp_res[0];
                        op2 = 1'b1;

                        div_up = addsub_res[1];
                        div_down = addsub_res[0];
                    end
                    else begin // sigmoid
                        exp_input[1] = 0;
                        op2 = 1'b0;
                        addsub1[0] = 0;
                        addsub1[1] = 0;

                        addsub0[0] = ONE;
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;
                        
                        div_up = ONE;
                        div_down = addsub_res[0];
                    end
                end
                'd140: begin
                    exp_input[0][31] = ~kernel_2_max[2][31];
                    exp_input[0][30:0] = kernel_2_max[2][30:0];

                    if(Opt_reg) begin // tanh
                        exp_input[1] = kernel_2_max[2];

                        addsub0[0] = exp_res[1];
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;

                        addsub1[0] = exp_res[1];
                        addsub1[1] = exp_res[0];
                        op2 = 1'b1;

                        div_up = addsub_res[1];
                        div_down = addsub_res[0];
                    end
                    else begin // sigmoid
                        exp_input[1] = 0;
                        op2 = 1'b0;
                        addsub1[0] = 0;
                        addsub1[1] = 0;

                        addsub0[0] = ONE;
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;
                        
                        div_up = ONE;
                        div_down = addsub_res[0];
                    end
                end
                'd141: begin
                    exp_input[0][31] = ~kernel_1_max[3][31];
                    exp_input[0][30:0] = kernel_1_max[3][30:0];

                    if(Opt_reg) begin // tanh
                        exp_input[1] = kernel_1_max[3];

                        addsub0[0] = exp_res[1];
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;

                        addsub1[0] = exp_res[1];
                        addsub1[1] = exp_res[0];
                        op2 = 1'b1;

                        div_up = addsub_res[1];
                        div_down = addsub_res[0];
                    end
                    else begin // sigmoid
                        exp_input[1] = 0;
                        op2 = 1'b0;
                        addsub1[0] = 0;
                        addsub1[1] = 0;

                        addsub0[0] = ONE;
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;
                        
                        div_up = ONE;
                        div_down = addsub_res[0];
                    end
                end
                'd142: begin
                    exp_input[0][31] = ~kernel_2_max[3][31];
                    exp_input[0][30:0] = kernel_2_max[3][30:0];

                    if(Opt_reg) begin // tanh
                        exp_input[1] = kernel_2_max[3];

                        addsub0[0] = exp_res[1];
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;

                        addsub1[0] = exp_res[1];
                        addsub1[1] = exp_res[0];
                        op2 = 1'b1;

                        div_up = addsub_res[1];
                        div_down = addsub_res[0];
                    end
                    else begin // sigmoid
                        exp_input[1] = 0;
                        op2 = 1'b0;
                        addsub1[0] = 0;
                        addsub1[1] = 0;

                        addsub0[0] = ONE;
                        addsub0[1] = exp_res[0];
                        op1 = 1'b0;
                        
                        div_up = ONE;
                        div_down = addsub_res[0];
                    end
                end
                default: begin 
                    exp_input[0] = 0;
                    exp_input[1] = 0;
                    addsub0[0] = 0;
                    addsub0[1] = 0;
                    addsub1[0] = 0;
                    addsub1[1] = 0;
                    op1 = 1'b0;
                    op2 = 1'b0;
                    div_up = 0;
                    div_down = 0;
                end
            endcase
        end
        default: begin 
            exp_input[0] = 0;
            exp_input[1] = 0;
            addsub0[0] = 0;
            addsub0[1] = 0;
            addsub1[0] = 0;
            addsub1[1] = 0;
            op1 = 1'b0;
            op2 = 1'b0;
            div_up = 0;
            div_down = 0;
        end
    endcase
end

always@(posedge clk) begin
    case(c_state)
        POOLIG_ACTIVA : begin
            case(img_pixel_num)
                'd121 : activate[0] <= div_res;
                'd122 : activate[4] <= div_res;
                'd123 : activate[1] <= div_res;
                'd124 : activate[5] <= div_res;
                'd139 : activate[2] <= div_res;
                'd140 : activate[6] <= div_res;
                'd141 : activate[3] <= div_res;
                'd142 : activate[7] <= div_res;
            endcase
        end
    endcase
end

always@(posedge clk) begin
    case(c_state)
        POOLIG_ACTIVA : begin
            if(img_pixel_num == 'd141) fully_connect_flag <= 1;
        end
        FULLY : begin
            fully_connect_flag <= 1;
            fully_cnt <= fully_cnt + 1;
        end
        default: begin
            fully_cnt <= 0;
            fully_connect_flag <= 0;
        end
    endcase
end

always@(posedge clk) begin
    case(c_state)
        FULLY : begin
            case(fully_cnt)
                1: fully_connect[0] <= add_res[0];
                2: fully_connect[1] <= add_res[0];
                3: fully_connect[2] <= add_res[0];
            endcase
        end
    endcase
end


always@(posedge clk) begin
    case(c_state)
        FULLY : begin
            case(fully_cnt)
                3: begin
                    e[0] <= exp_res[0];
                    e[1] <= exp_res[1];
                end
                4: begin
                    e[2] <= exp_res[0];
                end
            endcase
        end
    endcase
end

always@(posedge clk) begin
    case(c_state)
        FULLY : begin
            if(fully_cnt == 'd4) soft_flag <= 1;
        end
        default: soft_flag <= 0;
    endcase
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <= 0;
        out <= 0;
    end
    else begin
        case(c_state)
            FULLY : begin
                case(fully_cnt)
                    5: begin
                        out_valid <= 1;
                        out <= div_res;
                    end
                    6: out <= div_res;
                    7: out <= div_res;
                    default: begin
                        out_valid <= 0;
                        out <= 0;
                    end
                endcase
            end
            default: begin
                out_valid <= 0;
                out <= 0;
            end
        endcase
    end
end

endmodule
