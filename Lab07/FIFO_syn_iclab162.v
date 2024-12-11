module FIFO_syn #(parameter WIDTH=8, parameter WORDS=64) (
    wclk,
    rclk,
    rst_n,
    winc,
    wdata,
    wfull,
    rinc,
    rdata,
    rempty,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo,

    flag_fifo_to_clk1,
	flag_clk1_to_fifo
);

input wclk, rclk;
input rst_n;
input winc;
input [WIDTH-1:0] wdata;
output reg wfull;
input rinc;
output reg [WIDTH-1:0] rdata;
output reg rempty;

// You can change the input / output of the custom flag ports
output  flag_fifo_to_clk2;
input flag_clk2_to_fifo;

output flag_fifo_to_clk1;
input flag_clk1_to_fifo;

wire [WIDTH-1:0] rdata_q;

// Remember: 
//   wptr and rptr should be gray coded
//   Don't modify the signal name
reg [$clog2(WORDS):0] wptr;
reg [$clog2(WORDS):0] rptr;


wire [WIDTH-1:0] rdata_d;
reg rinc_q;
wire [$clog2(WORDS):0] wptr_q;
wire [$clog2(WORDS):0] rptr_q;
reg [5:0] raddr;
reg [6:0] rptr_ns;
reg [6:0] r_binary_current;
reg [6:0] r_binary_next;

reg [5:0] waddr;
reg [6:0] wptr_ns;
reg [6:0] w_binary_current; 
reg [6:0] w_binary_next;
wire [6:0] wptr_m;  
wire w_en_n = ~winc;

//================================================================
//    DESIGN
//================================================================

DUAL_64X8X1BM1 u_dual_sram(
.CKA(wclk),     .CKB(rclk), .WEAN(w_en_n),  .WEBN(1'b1),
.CSA(1'b1),     .CSB(1'b1), .OEA(1'b1),     .OEB(1'b1),
.A0(waddr[0]),  .A1(waddr[1]),  .A2(waddr[2]),  .A3(waddr[3]),  .A4(waddr[4]),  .A5(waddr[5]),
.B0(raddr[0]),  .B1(raddr[1]),  .B2(raddr[2]),  .B3(raddr[3]),  .B4(raddr[4]),  .B5(raddr[5]),
.DIA0(wdata[0]),    .DIA1(wdata[1]),    .DIA2(wdata[2]),    .DIA3(wdata[3]),    
.DIA4(wdata[4]),    .DIA5(wdata[5]),    .DIA6(wdata[6]),    .DIA7(wdata[7]),
.DOB0(rdata_d[0]),  .DOB1(rdata_d[1]),  .DOB2(rdata_d[2]),  .DOB3(rdata_d[3]),
.DOB4(rdata_d[4]),  .DOB5(rdata_d[5]),  .DOB6(rdata_d[6]),  .DOB7(rdata_d[7]));


NDFF_BUS_syn #(.WIDTH(WIDTH-1)) rtow_ptr(.D(rptr), .Q(rptr_q), .clk(wclk), .rst_n(rst_n));
NDFF_BUS_syn #(.WIDTH(WIDTH-1)) wtor_ptr(.D(wptr), .Q(wptr_q), .clk(rclk), .rst_n(rst_n));

always @(posedge rclk or negedge rst_n) begin
    if(!rst_n) rdata <= 0;
    else if(rinc || rinc_q) rdata <= rdata_d;
end

always @(posedge rclk or negedge rst_n) begin
    if(!rst_n) begin
        rinc_q <= 1'b0;
        r_binary_current <= 1'b0;
        rptr <= 1'b0;
    end
    else begin
        rinc_q <= rinc;
        r_binary_current <= r_binary_next;
        rptr <= rptr_ns;
    end
end

always@(*)  begin
    r_binary_next = r_binary_current + (rinc & !rempty);
    rptr_ns = (r_binary_next >> 1) ^ r_binary_next; // Convert to Gray Code
    raddr = r_binary_current[5:0];
end

always @(posedge rclk or negedge rst_n)begin
    if(!rst_n) rempty <= 1'b1;
    else rempty <= (rptr_ns == wptr_q) ? 1'b1 : 1'b0;
end

always@(*)  begin
    w_binary_next = w_binary_current + (winc & ~wfull);
    wptr_ns = (w_binary_next >> 1) ^ w_binary_next; // Convert to Gray Code
    waddr = w_binary_current[5:0];
end

always @(posedge wclk or negedge rst_n) begin
    if(!rst_n) begin
        w_binary_current <= 1'b0;
        wptr <= 1'b0;
    end
    else begin
        w_binary_current <= w_binary_next;
        wptr <= wptr_ns;
    end
end

assign wptr_m = {~wptr_ns[6:5], wptr_ns[4:0]};

always @(posedge wclk or negedge rst_n) begin
    if  (!rst_n) wfull <= 1'b0;
    else begin
        if (wptr_m == rptr_q) wfull <= 1'b1;
        else wfull <= 1'b0;
    end
end


endmodule
