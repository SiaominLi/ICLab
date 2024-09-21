module BB(
    //Input Ports
    input clk,
    input rst_n,
    input in_valid,
    input [1:0] inning,   // Current inning number
    input half,           // 0: top of the inning, 1: bottom of the inning
    input [2:0] action,   // Action code

    //Output Ports
    output reg out_valid,  // Result output valid
    output reg [7:0] score_A,  // Score of team A (guest team)
    output reg [7:0] score_B,  // Score of team B (home team)
    output reg [1:0] result    // 0: Team A wins, 1: Team B wins, 2: Darw
);

//==============================================//
//             Parameter and Integer            //
//==============================================//
// Action code interpretation:
parameter WALK       = 3'd0;  // Walk (BB)
parameter SINGLE_HIT = 3'd1;  // 1H (single hit)
parameter DOUBLE_HIT = 3'd2;  // 2H (double hit)
parameter TRIPLE_HIT = 3'd3;  // 3H (triple hit)
parameter HOME_RUN   = 3'd4;  // HR (home run)
parameter BUNT       = 3'd5;  // Bunt (short hit)
parameter GROUND_BALL = 3'd6; // Ground ball
parameter FLY_BALL   = 3'd7;  // Fly ball

// FSM states
// parameter IDLE = 3'd0;
// parameter PLAY = 3'd1;
parameter PLAYING = 1'd0;
// parameter END_EARLY = 3'd2;
parameter END_GAME = 1'd1;


//==============================================//
//                 reg declaration              //
//==============================================//
reg [2:0] current_state, next_state;
reg [1:0] outs;
reg flag;
reg [7:0] score_t2, score_t3, score_t;
reg [2:0] bases; // bit 0: 1st base, bit 1: 2nd base, bit 2: 3rd base
reg [4:0] current_score;
reg [1:0] current_inning;
reg current_half; // Top or Bottom of the inning
reg played, early_end;


//==============================================//
//             Current State Block              //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        current_state <= PLAYING;
    else 
        current_state <= next_state;
end

//==============================================//
//              Next State Block                //
//==============================================//
always @(*) begin
    if(!rst_n) next_state = PLAYING;
    else begin
        if (!current_state)
            next_state = (played && !in_valid);
        else
            next_state = PLAYING;
    end
end


//==============================================//
//             Base and Score Logic             //
//==============================================//
// Handle base runner movements and score calculation.
// Update bases and score depending on the action:
// Example: Walk, Hits (1H, 2H, 3H), Home Runs, etc.


always @(*) begin
    score_t3 = ( (half) ? score_B : score_A ) + ( (early_end && half) ? 'd0 : current_score );
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_score <= 0;
        out_valid <= 1'd0;
        result <= 'd0;
    end 
    else begin
        if (!current_state) begin
            out_valid <= 1'd0;
            if (in_valid) begin
                current_score <= 3'd0;
                case (action)
                    WALK: begin //0
                        if (bases == 3'b111) current_score <= 4'd1;
                    end
                    SINGLE_HIT: begin //1
                        if(outs == 2'b10)begin
                            case(bases)
                                3'b100, 3'b101, 3'b010, 3'b011:  begin
                                    current_score <= 4'd1;
                                end
                                3'b111, 3'b110: begin
                                    current_score <= 2;
                                end
                                default: ;
                            endcase
                        end
                        else begin
                            if (bases[2]) begin
                                current_score <= 4'd1;
                            end
                        end
                    end
                    DOUBLE_HIT: begin //2
                        if(outs == 2'b10)begin
                            current_score <= bases[0] + bases[1] + bases[2];
                        end
                        else begin
                            if (bases[2] || bases[1]) begin
                                current_score <= bases[2] + bases[1];
                            end
                        end;
                    end
                    TRIPLE_HIT: begin //3
                        current_score <= bases[0] + bases[1] + bases[2];
                    end
                    HOME_RUN: begin //4
                        current_score <= bases[0] + bases[1] + bases[2] + 1;
                    end
                    BUNT: begin //5
                        current_score <= bases[2];
                    end
                    GROUND_BALL: begin //6
                        if (!outs || (outs == 2'b01 && !bases[0])) begin
                            current_score <= bases[2];
                        end 
                    end
                    FLY_BALL: begin //7
                        if (!outs[1])  current_score <= bases[2];
                    end
                endcase
            end  
        end
        else begin
            out_valid <= 1'd1;
            if (score_A > score_B) result <= 2'b00;
            else if (score_B > score_A) result <= 2'b01;
            else result <= 2'b10;
        end
    end
end


// Process how many prople on bases
always@(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bases <= 3'b000;
        outs <= 0;
        played <= 1'd0;
        early_end <= 1'd0;
        score_A <= 'd0;
        score_B <= 'd0;
    end 
    else begin
        if (!current_state) begin
            // out_valid <= 1'd0;

            if (!played) begin
                score_A <= 8'd0;
                score_B <= 8'd0;
            end
            if (in_valid) begin
                played <= 1'd1;
                if ({inning, half} == 3'b110) begin
                    early_end <= score_B > score_A;
                end
                if (half) score_B <= score_t3;
                else score_A <= score_t3;
                
                case (action)
                    WALK: begin //0
                        case(bases)
                            3'b000, 3'b010, 3'b100, 3'b110: bases[0] <= 1'b1;
                            3'b001, 3'b101: begin
                                bases[1:0] <= 2'b11;
                            end
                            default: bases <= 3'b111;
                        endcase
                    end
                    SINGLE_HIT: begin //1
                        if(outs == 2'b10)begin
                            // bases <= bases << 2;
                            bases[2] <= bases[0];
                            bases[1:0] <= 2'b01;
                            // bases[0] <= 1'b1;
                        end
                        else begin
                            bases[2:1] <= bases[1:0];
                            bases[0] <= 1'b1;
                        end
                    end 
                    DOUBLE_HIT: begin //2
                        if(outs == 2'b10)begin
                            // bases <= bases << 3;
                            bases[2:0] <= 3'b010;
                        end
                        else begin
                            // bases <= bases << 2;
                            bases[2] <= bases[0];
                            bases[1:0] <= 2'b10;
                            // bases[1] <= 1'b1;
                        end
                    end 
                    TRIPLE_HIT: begin //3
                        bases <= 3'b100;
                    end 
                    HOME_RUN: begin //4
                        bases <= 3'b000; 
                    end 
                    BUNT: begin //5
                        if(outs == 2'b10) begin
                            outs <= 2'b00;
                            bases <= 'd0;
                        end
                        else outs <= outs + 1;
                        bases <= {bases[1], bases[0], 1'b0};
                    end 
                    GROUND_BALL: begin //6
                        if (!outs && !bases[0]) begin // 0 outs & base1 
                            outs <= 2'b01;
                            bases <= {bases[1], 1'b0, 1'b0};
                        end 
                        else if ((!outs && bases[0]) || (outs == 2'b01 && !bases[0])) begin
                            outs <= 2'b10;
                            bases <= {bases[1], 1'b0, 1'b0};
                        end
                        else begin
                            outs <= 2'b00;
                            bases <= 'd0;
                        end
                    end 
                    FLY_BALL: begin //7
                        if (outs < 2) begin
                            outs <= outs + 1;
                            bases[2] <= 1'b0;
                        end
                        else begin
                            outs <= 2'b00;
                            bases <= 'd0;
                        end
                    end 
                endcase
            end
        end
        else begin
            played <= 1'd0;
            early_end <= 1'd0;
        end
    end
end

//==============================================//
//                Output Block                  //
//==============================================//
// Decide when to set out_valid high, and output score_A, score_B, and result.


endmodule
