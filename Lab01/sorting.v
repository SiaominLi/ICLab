module sorting(
    in_0, in_1, in_2, in_3,
    in_4, in_5, in_6, in_7,
    sorted_0, sorted_1, sorted_2, sorted_3,
    sorted_4, sorted_5, sorted_6, sorted_7
);

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input wire [7:0] in_0, in_1, in_2, in_3, in_4, in_5, in_6, in_7;
output reg [7:0] sorted_0, sorted_1, sorted_2, sorted_3, sorted_4, sorted_5, sorted_6, sorted_7;

//================================================================
//    Wire & Registers 
//================================================================
reg [7:0] array [0:7];

//================================================================
//    DESIGN
//================================================================
always @(*) begin
    integer i, j;
    reg [7:0] temp;

    array[0] = in_0;
    array[1] = in_1;
    array[2] = in_2;
    array[3] = in_3;
    array[4] = in_4;
    array[5] = in_5;
    array[6] = in_6;
    array[7] = in_7;

    for (i = 0; i < 8; i = i + 1) begin
        for (j = i + 1; j < 8; j = j + 1) begin
            if (array[i] < array[j]) begin
                temp = array[i];
                array[i] = array[j];
                array[j] = temp;
            end
        end
    end
    sorted_0 = array[0];
    sorted_1 = array[1];
    sorted_2 = array[2];
    sorted_3 = array[3];
    sorted_4 = array[4];
    sorted_5 = array[5];
    sorted_6 = array[6];
    sorted_7 = array[7];
end

endmodule