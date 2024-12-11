module CLK_1_MODULE (
    clk,
    rst_n,
    in_valid,
	in_row,
    in_kernel,
    out_idle,
    handshake_sready,
    handshake_din,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

	fifo_empty,
    fifo_rdata,
    fifo_rinc,
    out_valid,
    out_data,

    flag_clk1_to_fifo,
    flag_fifo_to_clk1
);
input clk;
input rst_n;
input in_valid;
input [17:0] in_row;
input [11:0] in_kernel;
input out_idle;
output reg handshake_sready;
output reg [29:0] handshake_din;
// You can use the the custom flag ports for your design
input  flag_handshake_to_clk1;
output flag_clk1_to_handshake;

input fifo_empty;
input [7:0] fifo_rdata;
output reg fifo_rinc;
output reg out_valid;
output reg [7:0] out_data;
// You can use the the custom flag ports for your design
output flag_clk1_to_fifo;
input flag_fifo_to_clk1;

//================= Reg & Wire =================//
reg [4:0] input_cnt; // range from 0-5
reg [17:0] matrix [0:5];
reg [11:0] kernel [0:5];
reg [3:0] sending_num;

reg fifo_ff1, fifo_ff2;
//==============================================//

/* FSM */
localparam  IDLE = 2'd0,
            RECIEVE_INPUT = 2'd1,
            HAND_SHAKE = 2'd2;

reg [1:0] c_state_clk1, n_state_clk1;

//==================== FSM =====================//
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        c_state_clk1 <= IDLE;
    else 
        c_state_clk1 <= n_state_clk1;
end

always @(*) begin
    case (c_state_clk1)
        IDLE:   n_state_clk1 = (in_valid) ? RECIEVE_INPUT : IDLE;
        RECIEVE_INPUT:  n_state_clk1 = (input_cnt >= 5) ? HAND_SHAKE : RECIEVE_INPUT;
        HAND_SHAKE: n_state_clk1 = (sending_num >= 6) ? ((out_idle) ? IDLE : HAND_SHAKE) : HAND_SHAKE;
        default:    n_state_clk1 = IDLE;
    endcase
end
//==============================================//

/* Recieve Matrix data & Control input_cnt */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)  input_cnt <= 1'b0;
    else begin
        if(in_valid)    input_cnt <= input_cnt + 1'b1;
        else if(c_state_clk1 == IDLE)    input_cnt <= 1'b0;
    end
end

always @(posedge clk) begin
    if(in_valid) begin 
        matrix[input_cnt][17:0] <= in_row;
        kernel[input_cnt][11:0] <= in_kernel;
    end
end

//================= Send data ==================//

always @(*) begin
    if(input_cnt > 0 && sending_num < 6) handshake_sready = out_idle;
    else handshake_sready = 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)  sending_num <= 0;
    else begin
        case(c_state_clk1)
            RECIEVE_INPUT, HAND_SHAKE: begin 
                if(handshake_sready && (sending_num < 6)) sending_num <= sending_num + 1'b1;
            end
            IDLE: sending_num <= 0;
        endcase
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) handshake_din <= 0;
    else begin
        case(c_state_clk1)
            RECIEVE_INPUT, HAND_SHAKE: begin 
                if(handshake_sready) begin 
                    if(sending_num < 6) begin
                        handshake_din[17:0] <= matrix[sending_num];
                        handshake_din[29:18] <= kernel[sending_num];
                    end
                end
            end
            IDLE: handshake_din <= 0;
        endcase
    end
end
//==============================================//

//================ FIFO data in ================//

always @(*) begin
    if(!fifo_empty) fifo_rinc = 1'b1;
    else fifo_rinc = 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) fifo_ff1 <= 1'b1;
    else fifo_ff1 <= fifo_empty;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) fifo_ff2 <= 1'b1;
    else fifo_ff2 <= fifo_ff1;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        out_valid <= 1'b0;
        out_data <= 1'b0;
    end 
    else begin
        if(!fifo_ff2) begin
            out_valid <= 1'b1;
            out_data <= fifo_rdata;
            // $display("fifo_rdata: %d",fifo_rdata);
        end 
        else begin
            out_valid <= 1'b0;
            out_data <= 1'b0;
        end
    end
end

endmodule




module CLK_2_MODULE (
    clk,
    rst_n,
    in_valid,
    fifo_full,
    in_data,
    out_valid,
    out_data,
    busy,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo
);

input clk;
input rst_n;
input in_valid;
input fifo_full;
input [29:0] in_data;
output reg out_valid;
output reg [7:0] out_data;
output reg busy;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk2;
output flag_clk2_to_handshake;

input  flag_fifo_to_clk2;
output flag_clk2_to_fifo;

//================= Reg & Wire =================//
integer i;

/* FSM */
localparam  CLK2_IDLE = 0,
            CLK2_RECIEVE_INPUT = 1,
            MEM_WRITE = 2;

reg [1:0] c_state_clk2, n_state_clk2;

reg [5:0] input_cnt_clk2;
reg [17:0] matrix2 [0:5];
reg [11:0] kernel2 [0:5];

reg [3:0] mrow, mcol, kernel_pic_cnt;
reg [8:0] cnt_write;
reg output_flag, in_valid_ff1, in_valid_ff2;

//==================== FSM =====================//
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        c_state_clk2 <= CLK2_IDLE;
    else 
        c_state_clk2 <= n_state_clk2;
end

always@(*) begin 
    case (c_state_clk2)
        CLK2_IDLE : begin
            if(in_valid_ff2) n_state_clk2 = CLK2_RECIEVE_INPUT;
            else  n_state_clk2 = CLK2_IDLE;
        end
        CLK2_RECIEVE_INPUT : begin
            if(input_cnt_clk2 == 5) n_state_clk2 = MEM_WRITE;
            else  n_state_clk2 = CLK2_RECIEVE_INPUT;
        end
        MEM_WRITE : begin
            if(cnt_write == 149 && !fifo_full) n_state_clk2 = CLK2_IDLE;
            else  n_state_clk2 = MEM_WRITE;
        end
        default: n_state_clk2 = CLK2_IDLE;
    endcase
end
//==============================================//

//========= Recieve Data From Handshake ========//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) busy <= 0;
    else if(input_cnt_clk2 > 5 && cnt_write != 'd256) busy <= 1;
    else if(cnt_write == 'd256 && !fifo_full) busy <= 0;
    else busy <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) in_valid_ff1 <= 1'b0;
    else in_valid_ff1 <= in_valid;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) in_valid_ff2 <= 1'b0;
    else if(!in_valid) in_valid_ff2 <= (in_valid ^ in_valid_ff1);
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) input_cnt_clk2 <= 'd0;
    else begin
        if(input_cnt_clk2 < 6 && in_valid_ff2) input_cnt_clk2 <= input_cnt_clk2 + 1;
        else if(cnt_write == 'd256 || c_state_clk2 == CLK2_IDLE) input_cnt_clk2 <= 'd0;
    end
end

always@(posedge clk) begin
    if(in_valid_ff2) begin
        matrix2[input_cnt_clk2] <= in_data[17:0];
        kernel2[input_cnt_clk2] <= in_data[29:18];
    end
end
//==============================================//

//=================== CONV =====================//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) mrow <= 0 ;
    else if(c_state_clk2 == CLK2_IDLE) mrow <= 0 ;
    else if(input_cnt_clk2 > 'd5 && !fifo_full)
        if(mrow == 'd4 && mcol == 'd4) mrow <= 0;
        else if(mcol == 'd4) mrow <= mrow + 'd1;
        // else mrow <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) mcol <= 0 ;
    else if(c_state_clk2 == CLK2_IDLE) mcol <= 0 ;
    else if(input_cnt_clk2 > 'd5 && !fifo_full) mcol <= (mcol == 'd4) ? 'd0 : mcol + 'd1;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) kernel_pic_cnt <= 0 ;
    else if(c_state_clk2 == CLK2_IDLE) kernel_pic_cnt <= 0 ;
    else if(input_cnt_clk2 >'d5 && kernel_pic_cnt < 5 && !fifo_full)
        if(mrow == 'd4 && mcol == 'd4) kernel_pic_cnt <= kernel_pic_cnt + 'd1;
end


reg [2:0] matrix_mul [0:3], kernel_mul [0:3];

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        matrix_mul[0] <= 0;
        matrix_mul[1] <= 0;
        matrix_mul[2] <= 0;
        matrix_mul[3] <= 0;
        kernel_mul[0] <= 0;
        kernel_mul[1] <= 0;
        kernel_mul[2] <= 0;
        kernel_mul[3] <= 0;
    end
    else if(c_state_clk2 == CLK2_IDLE) begin
        matrix_mul[0] <= 0;
        matrix_mul[1] <= 0;
        matrix_mul[2] <= 0;
        matrix_mul[3] <= 0;
        kernel_mul[0] <= 0;
        kernel_mul[1] <= 0;
        kernel_mul[2] <= 0;
        kernel_mul[3] <= 0;
    end
    else if(input_cnt_clk2 >'d5 && ~fifo_full) begin
        if(mcol == 'd0) begin
            {matrix_mul[1], matrix_mul[0]} <= matrix2[mrow][5:0];
            {matrix_mul[3], matrix_mul[2]} <= matrix2[mrow+1][5:0];
        end
        else if(mcol == 'd1) begin
            {matrix_mul[1], matrix_mul[0]} <= matrix2[mrow][8:3];
            {matrix_mul[3], matrix_mul[2]} <= matrix2[mrow+1][8:3];
        end
        else if(mcol == 'd2) begin
            {matrix_mul[1], matrix_mul[0]} <= matrix2[mrow][11:6];
            {matrix_mul[3], matrix_mul[2]} <= matrix2[mrow+1][11:6];
        end
        else if(mcol == 'd3) begin
            {matrix_mul[1], matrix_mul[0]} <= matrix2[mrow][14:9];
            {matrix_mul[3], matrix_mul[2]} <= matrix2[mrow+1][14:9];
        end
        else if(mcol == 'd4) begin
            {matrix_mul[1], matrix_mul[0]} <= matrix2[mrow][17:12];
            {matrix_mul[3], matrix_mul[2]} <= matrix2[mrow+1][17:12];
        end
        else begin
            matrix_mul[0] <= 0;
            matrix_mul[1] <= 0;
            matrix_mul[2] <= 0;
            matrix_mul[3] <= 0;
        end

        {kernel_mul[3], kernel_mul[2], kernel_mul[1], kernel_mul[0]} <= kernel2[kernel_pic_cnt]; // [11:0]
    end
end
//==============================================//

//=============== Send data FIFO ===============//

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) cnt_write <= 0;
    else if(c_state_clk2 == CLK2_IDLE) cnt_write <= 0;
    else if(output_flag && cnt_write < 'd256 && !fifo_full) cnt_write <= cnt_write + 1;
    else cnt_write <= cnt_write;
end

always @(*) begin
    if(c_state_clk2 == CLK2_IDLE) output_flag = 0;
    else if(kernel_pic_cnt > 0 && kernel_pic_cnt < 6) output_flag = 1;
    else if(mcol >= 1 || mrow >= 1) output_flag = 1;
    else output_flag = 0;
end

always @(*) begin
    if (cnt_write < 'd256 && !fifo_full && output_flag) begin
        out_valid = 1;
        out_data = (matrix_mul[0] * kernel_mul[0]) + (matrix_mul[1] * kernel_mul[1]) 
                    + (matrix_mul[2] * kernel_mul[2]) + (matrix_mul[3] * kernel_mul[3]);
    end
    else begin
        out_valid = 'd0;
        out_data = 'd0;
    end
end

endmodule
