/**************************************************************************/
// Copyright (c) 2024, OASIS Lab
// MODULE: PATTERN
// FILE NAME: PATTERN.v
// VERSRION: 1.0
// DATE: August 15, 2024
// AUTHOR: Yu-Hsuan Hsu, NYCU IEE
// DESCRIPTION: ICLAB2024FALL / LAB3 / PATTERN
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/

`ifdef RTL
    `define CYCLE_TIME 40.0
`endif
`ifdef GATE
    `define CYCLE_TIME 40.0
`endif

module PATTERN(
	//OUTPUT
	rst_n,
	clk,
	in_valid,
	tetrominoes,
	position,
	//INPUT
	tetris_valid,
	score_valid,
	fail,
	score,
	tetris
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
output reg			rst_n, clk, in_valid;
output reg	[2:0]	tetrominoes;
output reg  [2:0]	position;
input 				tetris_valid, score_valid, fail;
input 		[3:0]	score;
input		[71:0]	tetris;

//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer total_latency;
real CYCLE = `CYCLE_TIME;

integer i_pat, i, t, j;
integer f_in;
integer pattern_count, pattern_num;
integer latency, lat_circle;
			
//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------
reg [95:0] golden_map; // 12x6 unpacked array
reg [3:0] golden_score;
reg golden_fail;
reg [2:0] c_tetrominoes, c_position;
reg [2:0] output_tetrominoes [0:15], output_position [0:15];
reg score_v, tetris_v;

//---------------------------------------------------------------------
//  CLOCK
//---------------------------------------------------------------------
initial clk = 0;
always #(CYCLE/2) clk = ~clk;

//---------------------------------------------------------------------
//  SIMULATION
//---------------------------------------------------------------------

//   *INITIALIZATION AND RESET
initial begin
   
    f_in = $fopen("../00_TESTBED/input.txt", "r");
    if (f_in == 0) begin
        $display("Error: Input file not found.");
        $finish;
    end
    // Read the number of patterns
    $fscanf(f_in, "%d\n", pattern_count);

	reset_task;

    for (i_pat = 0; i_pat < pattern_count; i_pat = i_pat + 1) begin
        golden_map = 'b0;
        golden_score = 4'b0;
        golden_fail = 1'b0;

        // $fscanf(f_in, "%d\n", pattern_num);
        // for (j = 0; j < 16; j = j + 1) begin
        //     $fscanf(f_in, "%d   %d", c_tetrominoes[j], c_position[j]);
        // end
        read_input_task;

        for (i = 0; i < 16; i = i + 1) begin
            // input_task;
            t = $urandom_range(1, 4);
            repeat(t) @(negedge clk);

            // $fscanf(f_in, "%d   %d", c_tetrominoes[i], c_position[i]);
            if( !golden_fail )begin
                c_tetrominoes = output_tetrominoes[i];
                c_position = output_position[i];

                in_valid = 1'b1;
                tetrominoes = output_tetrominoes[i];
                position = output_position[i];

                calculate_output_map;
                calculate_score;
                
                @(negedge clk);

                in_valid = 1'b0;
                tetrominoes = 3'bxxx;
                position = 3'bxxx;

                wait_for_output;
                check_result;
            end
            else break;
        end
    end

    pass_msg_task;
end

//   *RESET TASK
task reset_task; 
begin
    rst_n = 1'b1;
    in_valid = 1'b0;
    tetrominoes = 3'bxxx;
    position = 3'bxxx;
    total_latency = 0;

    force clk = 0;

    #CYCLE; rst_n = 1'b0;  
    #CYCLE; rst_n = 1'b1; 
    
    #100;

    // Check initial conditions after 100ns
    if (tetris_valid !== 1'b0 || score_valid !== 1'b0 || fail !== 1'b0 || score !== 4'b0000 || tetris !== 72'b0) begin
        // Output signals should be 0 after initial RESET
        $display("                    SPEC-4 FAIL                   ");
        // repeat (2) #CYCLE;
        $finish;
    end
    #CYCLE; release clk;
end 
endtask



//   *INPUT TASK: Read input from file and send tetrominoes and positions
task read_input_task; begin
    $fscanf(f_in, "%d\n", pattern_num);
    for (j = 0; j < 16; j = j + 1) begin
        $fscanf(f_in, "%d   %d", output_tetrominoes[j], output_position[j]);
    end
end endtask


//   *WAIT FOR OUTPUT VALID
task wait_for_output; begin
    latency = 1;
    
    while (score_valid !== 1) begin
        if (score_valid !== 1) begin
            if (score !== 4'b0000 || fail !== 1'b0 || tetris_valid !== 1'b0) begin
                $display("                    SPEC-5 FAIL                   ");
                $finish;
            end
        end
        if (tetris_valid !== 1 && tetris !== 72'b0) begin
            $display("                    SPEC-5 FAIL                   ");
            $finish;
        end 
        if (latency >= 1000) begin
            // The execution latency exceeded 1000 cycles
            $display("                    SPEC-6 FAIL                   ");
            $finish;
        end
        // repeat (3) @(negedge clk);
        @(negedge clk);
        latency = latency + 1;
        // $display("--------------latency:  %d ---------------- ",     latency);
    end
    
    if (tetris_valid !== 1 && tetris !== 72'b0) begin
        $display("                    SPEC-5 FAIL                   ");
        $finish;
    end 
    if (score_valid !== 1) begin
        if (score !== 4'b0000 || fail !== 1'b0 || tetris_valid !== 1'b0) begin
            $display("                    SPEC-5 FAIL                   ");
            $finish;
        end
    end

    total_latency = total_latency + latency;
    
end endtask


//   *CHECK RESULT
task check_result; begin
    lat_circle = 0;
    while (score_valid  === 1'b1 || tetris_valid === 1'b1) begin

        if (score_valid === 1'b1 && lat_circle === 0) begin
            // score_v = 1;
            if (score !== golden_score || fail !== golden_fail) begin
                $display("                    SPEC-7 FAIL                   ");
                $display("7-1 %d",(fail !== golden_fail));
                $finish;
            end
        end

        if (tetris_valid === 1'b1  && lat_circle === 0) begin
            // tetris_v = 1;
            if (tetris !== golden_map[71:0]) begin
                $display("                    SPEC-7 FAIL                   ");
                $display("7-2");
                $finish;
            end
        end

        if (lat_circle >= 1) begin
            $display("                    SPEC-8 FAIL                   ");
            $finish;
        end

        @(negedge clk);
        lat_circle = lat_circle + 1;
    end

end endtask



//   *YOU PASS TASK: Indicate successful completion of all patterns
task pass_msg_task; begin
        $display("                  Congratulations!               ");
        $display("              execution cycles = %7d", total_latency);
        $display("              clock period = %4fns", CYCLE);
        $finish;
end endtask



// for spec check
// $display("                    SPEC-4 FAIL                   ");
// $display("                    SPEC-5 FAIL                   ");
// $display("                    SPEC-6 FAIL                   ");
// $display("                    SPEC-7 FAIL                   ");
// $display("                    SPEC-8 FAIL                   ");
// for successful design
// $display("                  Congratulations!               ");
// $display("              execution cycles = %7d", total_latency);
// $display("              clock period = %4fns", CYCLE);

task calculate_output_map; begin
    integer row;
    reg [89:0] temp_position [0:3];

    case(c_tetrominoes)
        3'b000: begin   // O-shape (2x2 square)
                        // oo
                        // oo
            for(row = 14; row >= 1; row = row - 1) begin
                temp_position[0] = row * 6 + c_position;          // 左上
                temp_position[1] = row * 6 + c_position + 1;      // 右上
                temp_position[2] = (row-1) * 6 + c_position;      // 左下
                temp_position[3] = (row-1) * 6 + c_position + 1;  // 右下

                // 檢查是否被阻擋 (有任何位置不為0)
                if(golden_map[temp_position[0]] !== 0 || golden_map[temp_position[1]] !== 0 || 
                    golden_map[temp_position[2]] !== 0 || golden_map[temp_position[3]] !== 0) begin
                    // 向上一層放置方塊
                    golden_map[temp_position[0] + 6] = 1;
                    golden_map[temp_position[1] + 6] = 1;
                    golden_map[temp_position[2] + 6] = 1;
                    golden_map[temp_position[3] + 6] = 1;
                    // 如果 row > 9（表示這個方塊放置得很高），設置 fail = 1
                    // if(row >= 10) fail = 1'b1;
                    break;  // 結束方塊放置
                end
                else begin
                    if(row === 1) begin
                        // 若方塊在最底層，直接放置
                        golden_map[temp_position[0]] = 1;
                        golden_map[temp_position[1]] = 1;
                        golden_map[temp_position[2]] = 1;
                        golden_map[temp_position[3]] = 1;
                    end
                end
            end
        end
        3'b001: begin   // I-shape (4x1 line)
                        // o
                        // o
                        // o
                        // o
            for(row = 14; row >= 3; row = row - 1) begin
                temp_position[0] = row * 6 + c_position;      // 最上
                temp_position[1] = (row-1) * 6 + c_position;  // 次上
                temp_position[2] = (row-2) * 6 + c_position;  // 次下
                temp_position[3] = (row-3) * 6 + c_position;  // 最下

                if(golden_map[temp_position[0]] !== 0 || golden_map[temp_position[1]] !== 0 || 
                    golden_map[temp_position[2]] !== 0 || golden_map[temp_position[3]] !== 0) begin
                    // 向上一層放置方塊
                    golden_map[temp_position[0] + 6] = 1;
                    golden_map[temp_position[1] + 6] = 1;
                    golden_map[temp_position[2] + 6] = 1;
                    golden_map[temp_position[3] + 6] = 1;
                    // 如果 row > 9（表示這個方塊放置得很高），設置 fail = 1
                    // if(row >= 8) fail = 1'b1;
                    break;  // 結束方塊放置
                end
                else begin
                    if(row === 3) begin
                        // 若方塊在最底層，直接放置
                        golden_map[temp_position[0]] = 1;
                        golden_map[temp_position[1]] = 1;
                        golden_map[temp_position[2]] = 1;
                        golden_map[temp_position[3]] = 1;
                    end
                end
            end
        end
        3'b010: begin   // I-shape (1x4 line)
                        // oooo
            for(row = 14; row >= 0; row = row - 1) begin
                temp_position[0] = row * 6 + c_position;      
                temp_position[1] = row * 6 + c_position + 1;  
                temp_position[2] = row * 6 + c_position + 2;  
                temp_position[3] = row * 6 + c_position + 3;  

                if(golden_map[temp_position[0]] !== 0 || golden_map[temp_position[1]] !== 0 || 
                    golden_map[temp_position[2]] !== 0 || golden_map[temp_position[3]] !== 0) begin
                    // 向上一層放置方塊
                    golden_map[temp_position[0] + 6] = 1;
                    golden_map[temp_position[1] + 6] = 1;
                    golden_map[temp_position[2] + 6] = 1;
                    golden_map[temp_position[3] + 6] = 1;
                    // 如果 row > 9（表示這個方塊放置得很高），設置 fail = 1
                    // if(row >= 10) fail = 1'b1;
                    break;  // 結束方塊放置
                end
                else begin
                    if(row === 0) begin
                        // 若方塊在最底層，直接放置
                        golden_map[temp_position[0]] = 1;
                        golden_map[temp_position[1]] = 1;
                        golden_map[temp_position[2]] = 1;
                        golden_map[temp_position[3]] = 1;
                    end
                end
            end
        end
        3'b011: begin   // L-shape 
                        // oo
                        //  o
                        //  o
            for(row = 14; row >= 2; row = row - 1) begin
                // 定義該方塊的四個位置
                temp_position[0] = row * 6 + c_position;          // 最上橫向左側
                temp_position[1] = row * 6 + c_position + 1;      // 最上橫向右側
                temp_position[2] = (row-1) * 6 + c_position + 1;  // 中間垂直部分
                temp_position[3] = (row-2) * 6 + c_position + 1;  // 最下垂直部分

                // 檢查是否有阻擋
                if(golden_map[temp_position[0]] !== 0 || golden_map[temp_position[1]] !== 0 || 
                    golden_map[temp_position[2]] !== 0 || golden_map[temp_position[3]] !== 0) begin
                    // 向上一層放置方塊
                    golden_map[temp_position[0] + 6] = 1;
                    golden_map[temp_position[1] + 6] = 1;
                    golden_map[temp_position[2] + 6] = 1;
                    golden_map[temp_position[3] + 6] = 1;
                    // 如果 row > 9（表示這個方塊放置得很高），設置 fail = 1
                    // if(row >= 9) fail = 1'b1;
                    break;  // 結束方塊放置
                end
                else begin
                    if(row === 2) begin
                        // 若方塊在最底層，直接放置
                        golden_map[temp_position[0]] = 1;
                        golden_map[temp_position[1]] = 1;
                        golden_map[temp_position[2]] = 1;
                        golden_map[temp_position[3]] = 1;
                    end
                end
            end
        end
        3'b100: begin   // L-shape
                        // ooo
                        // o
            for(row = 14; row >= 1; row = row - 1) begin
                temp_position[0] = row * 6 + c_position;      // 上橫的左
                temp_position[1] = row * 6 + c_position + 1;  // 上橫的中
                temp_position[2] = row * 6 + c_position + 2;  // 上橫的右
                temp_position[3] = (row-1) * 6 + c_position;  // 下橫的左

                if(golden_map[temp_position[0]] !== 0 || golden_map[temp_position[1]] !== 0 || 
                    golden_map[temp_position[2]] !== 0 || golden_map[temp_position[3]] !== 0) begin
                    // 向上一層放置方塊
                    golden_map[temp_position[0] + 6] = 1;
                    golden_map[temp_position[1] + 6] = 1;
                    golden_map[temp_position[2] + 6] = 1;
                    golden_map[temp_position[3] + 6] = 1;
                    // 如果 row > 9（表示這個方塊放置得很高），設置 fail = 1
                    // if(row >= 10) fail = 1'b1;
                    break;  // 結束方塊放置
                end
                else begin
                    if(row === 1) begin
                        // 若方塊在最底層，直接放置
                        golden_map[temp_position[0]] = 1;
                        golden_map[temp_position[1]] = 1;
                        golden_map[temp_position[2]] = 1;
                        golden_map[temp_position[3]] = 1;
                    end
                end
            end
        end
        3'b101: begin   // L-shape
                        // o
                        // o
                        // oo
            for(row = 14; row >= 2; row = row - 1) begin
                // 定義該方塊的四個位置
                temp_position[0] = row * 6 + c_position;          // 最上垂直部分
                temp_position[1] = (row-1) * 6 + c_position;      // 中間垂直部分
                temp_position[2] = (row-2) * 6 + c_position;      // 左下橫向部分
                temp_position[3] = (row-2) * 6 + c_position + 1;  // 右下橫向部分

                // 檢查是否有阻擋
                if(golden_map[temp_position[0]] !== 0 || golden_map[temp_position[1]] !== 0 || 
                    golden_map[temp_position[2]] !== 0 || golden_map[temp_position[3]] !== 0) begin
                    // 向上一層放置方塊
                    golden_map[temp_position[0] + 6] = 1;
                    golden_map[temp_position[1] + 6] = 1;
                    golden_map[temp_position[2] + 6] = 1;
                    golden_map[temp_position[3] + 6] = 1;
                    // 如果 row > 9（表示這個方塊放置得很高），設置 fail = 1
                    // if(row >= 9) fail = 1'b1;
                    break;  // 結束方塊放置
                end
                else begin
                    if(row === 2) begin
                        // 若方塊在最底層，直接放置
                        golden_map[temp_position[0]] = 1;
                        golden_map[temp_position[1]] = 1;
                        golden_map[temp_position[2]] = 1;
                        golden_map[temp_position[3]] = 1;
                    end
                end
            end
        end

        3'b110: begin   // Z-shape
                        // o
                        // oo
                        //  o
            for(row = 14; row >= 2; row = row - 1) begin
                // 定義該方塊的四個位置
                temp_position[0] = row * 6 + c_position;          // 最上垂直部分
                temp_position[1] = (row-1) * 6 + c_position;      // 中間左側
                temp_position[2] = (row-1) * 6 + c_position + 1;  // 中間右側
                temp_position[3] = (row-2) * 6 + c_position + 1;  // 最下右側

                // 檢查是否有阻擋
                if(golden_map[temp_position[0]] !== 0 || golden_map[temp_position[1]] !== 0 || 
                    golden_map[temp_position[2]] !== 0 || golden_map[temp_position[3]] !== 0) begin
                    // 向上一層放置方塊
                    golden_map[temp_position[0] + 6] = 1;
                    golden_map[temp_position[1] + 6] = 1;
                    golden_map[temp_position[2] + 6] = 1;
                    golden_map[temp_position[3] + 6] = 1;
                    // 如果 row > 9，設置 fail = 1
                    // if(row >= 9) fail = 1'b1;
                    break;  // 結束方塊放置
                end
                else begin
                    if(row === 2) begin
                        // 若方塊在最底層，直接放置
                        golden_map[temp_position[0]] = 1;
                        golden_map[temp_position[1]] = 1;
                        golden_map[temp_position[2]] = 1;
                        golden_map[temp_position[3]] = 1;
                    end
                end
            end
        end

        3'b111: begin   // S-shape
                        //  oo
                        // oo
            for(row = 14; row >= 1; row = row - 1) begin
                // 定義該方塊的四個位置
                temp_position[0] = row * 6 + c_position + 1;      // 最上右側
                temp_position[1] = row * 6 + c_position + 2;      // 最上最右側
                temp_position[2] = (row-1) * 6 + c_position;      // 中間左側
                temp_position[3] = (row-1) * 6 + c_position + 1;  // 中間右側

                // 檢查是否有阻擋
                if(golden_map[temp_position[0]] !== 0 || golden_map[temp_position[1]] !== 0 || 
                    golden_map[temp_position[2]] !== 0 || golden_map[temp_position[3]] !== 0) begin
                    // 向上一層放置方塊
                    golden_map[temp_position[0] + 6] = 1;
                    golden_map[temp_position[1] + 6] = 1;
                    golden_map[temp_position[2] + 6] = 1;
                    golden_map[temp_position[3] + 6] = 1;
                    // 如果 row > 9，設置 fail = 1
                    // if(row >= 10) fail = 1'b1;
                    break;  // 結束方塊放置
                end
                else begin
                    if(row === 1) begin
                        // 若方塊在最底層，直接放置
                        golden_map[temp_position[0]] = 1;
                        golden_map[temp_position[1]] = 1;
                        golden_map[temp_position[2]] = 1;
                        golden_map[temp_position[3]] = 1;
                    end 
                end
            end
        end
    endcase
end endtask

task calculate_score;begin
        integer height, h2;              // 高度指標，列
        reg [2:0] cur_score_counter;  // 計分器
        cur_score_counter = 3'b0;

        // 檢查每一行是否為滿列
        for (height = 0; height < 12; height = height + 1) begin
            // 檢查當前行是否滿列
            if (&golden_map[height * 6 +: 6]) begin
                cur_score_counter = cur_score_counter + 1; // 增加分數
                // $display("height: %d",height);
                for (h2 = height; h2 < 15; h2 = h2 + 1) begin 
                    golden_map[h2*6 +: 6] = golden_map[(h2+1)*6 +: 6];
                end
                height = height - 1;
            end
        end
        // for (height = 0; height < 12; height = height + 1) begin
        //     // 檢查當前行是否滿列
        //     if (&golden_map[height * 6 +: 6]) begin
        //         cur_score_counter = cur_score_counter + 1; // 增加分數
        //         for (h2 = height; h2 < 15; h2 = h2 + 1) begin 
        //             golden_map[h2*6 +: 6] = golden_map[(h2+1)*6 +: 6];
        //         end
        //         // height = height - 1;
        //     end
        // end
        // $display("current_score: %d",cur_score_counter);
        // 更新總分數
        golden_score = golden_score + cur_score_counter;

        // 檢查是否有任何方塊在第 15 行（超過範圍）
        if ((|golden_map[72 +: 6]) || (|golden_map[78 +: 6])  || (|golden_map[84 +: 6]) ) begin
            golden_fail = 1'b1; // 設置失敗狀態
        end
end endtask

// task calculate_score; 
//     begin
//         reg [4:0] line_ptr = 5'b0;  // 行指標
//         integer height;              // 高度指標，列
//         reg get_score;               // 行是否滿的標誌

//         // 檢查每一行
//         for(height = 0; height < 15; height = height + 1) begin
//             // 不斷檢查當前行是否滿
//             while(1'b1) begin
//                 get_score = &(golden_map[line_ptr * 6 +: 6]); // 檢查行是否滿
//                 if(get_score) begin
//                     line_ptr = line_ptr + 1;               // 移動到下一行
//                     golden_score = golden_score + 1;      // 增加分數
//                 end
//                 else break; // 如果行不滿，退出循環
//             end

//             // 如果 line_ptr 等於當前高度，表示沒有行需要移動
//             if(line_ptr == height) begin
//                 line_ptr = line_ptr < 14 ? line_ptr + 1 : 14; // 移動指標
//                 continue; // 繼續檢查下一行
//             end
//             else begin
//                 // 將 line_ptr 位置的行向上移動到 height 行
//                 golden_map[height*6 +: 6] = golden_map[line_ptr*6 +: 6];

//                 line_ptr = line_ptr < 14 ? line_ptr + 1 : 14; // 移動指標
//             end
//         end
        
//         // 檢查是否有任何方塊在第 15 行（超過範圍）
//         if(golden_map[84] !== 0 || golden_map[85] !== 0 || 
//            golden_map[86] !== 0 || golden_map[87] !== 0 || 
//            golden_map[88] !== 0 || golden_map[89] !== 0) begin
//             golden_fail = 1'b1; // 設置失敗狀態
//         end
//     end 
// endtask

endmodule