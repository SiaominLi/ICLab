module sort(
    in_0, in_1, in_2, in_3,
    in_4, in_5, in_6, in_7,
    sorted_0, sorted_1, sorted_2, sorted_3,
    sorted_4, sorted_5, sorted_6, sorted_7
);

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input wire [7:0] in_0, in_1, in_2, in_3, in_4, in_5, in_6, in_7;
output wire [7:0] sorted_0, sorted_1, sorted_2, sorted_3, sorted_4, sorted_5, sorted_6, sorted_7;
// output wire sorted_done;

//================================================================
//    Wire & Registers 
//================================================================
wire [7:0] stage0_0, stage0_1, stage0_2, stage0_3, stage0_4, stage0_5, stage0_6, stage0_7;
wire [7:0] stage1_0, stage1_1, stage1_2, stage1_3, stage1_4, stage1_5, stage1_6, stage1_7;
wire [7:0] stage1_1_1, stage1_1_2, stage1_1_5, stage1_1_6;
wire [7:0] stage2_0, stage2_1, stage2_2, stage2_3, stage2_4, stage2_5, stage2_6, stage2_7;
wire [7:0] stage3_1, stage3_2, stage3_5, stage3_6;
wire [7:0] stage4_2, stage4_3, stage4_4, stage4_5;

//================================================================
//    DESIGN
//================================================================

// Layer 0: [(0,1), (2,3), (4,5), (6,7)]
assign {stage0_0, stage0_1} = (in_0 > in_1) ? {in_0 , in_1} : {in_1 , in_0};
// assign stage0_1 = (in_0 > in_1) ? in_1 : in_0;
assign {stage0_2, stage0_3} = (in_2 > in_3) ? {in_2 , in_3} : {in_3 , in_2};
// assign stage0_3 = (in_2 > in_3) ? in_3 : in_2;
assign {stage0_4, stage0_5} = (in_4 > in_5) ? {in_4 , in_5} : {in_5 , in_4};
// assign stage0_5 = (in_4 > in_5) ? in_5 : in_4;
assign {stage0_6, stage0_7} = (in_6 > in_7) ? {in_6 , in_7} : {in_7 , in_6};
// assign stage0_7 = (in_6 > in_7) ? in_7 : in_6;

// // Layer 1: [(0,2), (1,3), (4,6), (5,7)]
// assign stage1_0 = (stage0_0 > stage0_2) ? stage0_0 : stage0_2;
// assign stage1_1 = (stage0_0 > stage0_2) ? stage0_2 : stage0_0;
// assign stage1_2 = (stage0_1 > stage0_3) ? stage0_1 : stage0_3;
// assign stage1_3 = (stage0_1 > stage0_3) ? stage0_3 : stage0_1;
// assign stage1_4 = (stage0_4 > stage0_6) ? stage0_4 : stage0_6;
// assign stage1_5 = (stage0_4 > stage0_6) ? stage0_6 : stage0_4;
// assign stage1_6 = (stage0_5 > stage0_7) ? stage0_5 : stage0_7;
// assign stage1_7 = (stage0_5 > stage0_7) ? stage0_7 : stage0_5;

// // Layer 1-1: [(1,2), (5,6)]
// assign stage1_1_1 = (stage1_1 > stage1_2) ? stage1_1 : stage1_2;
// assign stage1_1_2 = (stage1_1 > stage1_2) ? stage1_2 : stage1_1;
// assign stage1_1_5 = (stage1_5 > stage1_6) ? stage1_5 : stage1_6;
// assign stage1_1_6 = (stage1_5 > stage1_6) ? stage1_6 : stage1_5;

// // Layer 2: [(0,4), (1,5), (2,6), (3,7)]
// assign stage2_0 = (stage1_0 > stage1_4) ? stage1_0 : stage1_4;
// assign stage2_1 = (stage1_0 > stage1_4) ? stage1_4 : stage1_0;
// assign stage2_2 = (stage1_1_1 > stage1_1_5) ? stage1_1_1 : stage1_1_5;
// assign stage2_3 = (stage1_1_1 > stage1_1_5) ? stage1_1_5 : stage1_1_1;

// assign stage2_4 = (stage1_1_2 > stage1_1_6) ? stage1_1_2 : stage1_1_6;
// assign stage2_5 = (stage1_1_2 > stage1_1_6) ? stage1_1_6 : stage1_1_2;
// assign stage2_6 = (stage1_3 > stage1_7) ? stage1_3 : stage1_7;
// assign stage2_7 = (stage1_3 > stage1_7) ? stage1_7 : stage1_3;

// // Layer 3: [(1,2), (5,6)]
// assign stage3_1 = (stage2_1 > stage2_2) ? stage2_1 : stage2_2;
// assign stage3_2 = (stage2_1 > stage2_2) ? stage2_2 : stage2_1;
// assign stage3_5 = (stage2_5 > stage2_6) ? stage2_5 : stage2_6;
// assign stage3_6 = (stage2_5 > stage2_6) ? stage2_6 : stage2_5;

// // Layer 4: [(2,4), (3,5)]
// assign stage4_2 = (stage3_2 > stage2_4) ? stage3_2 : stage2_4;
// assign stage4_3 = (stage3_2 > stage2_4) ? stage2_4 : stage3_2;
// assign stage4_4 = (stage2_3 > stage3_5) ? stage2_3 : stage3_5;
// assign stage4_5 = (stage2_3 > stage3_5) ? stage3_5 : stage2_3;

// // Layer 6: result 
// assign sorted_0 = stage2_0;
// assign sorted_1 = stage3_1;
// assign sorted_2 = stage4_2;

// assign sorted_3 = (stage4_3 > stage4_4) ? stage4_3 : stage4_4;
// assign sorted_4 = (stage4_3 > stage4_4) ? stage4_4 : stage4_3;

// assign sorted_5 = stage4_5;
// assign sorted_6 = stage3_6;
// assign sorted_7 = stage2_7;

// Layer 1: [(0,2), (1,3), (4,6), (5,7)]
assign {stage1_0, stage1_1} = (stage0_0 > stage0_2) ? {stage0_0, stage0_2} : {stage0_2, stage0_0};
assign {stage1_2, stage1_3} = (stage0_1 > stage0_3) ? {stage0_1, stage0_3} : {stage0_3, stage0_1};
assign {stage1_4, stage1_5} = (stage0_4 > stage0_6) ? {stage0_4, stage0_6} : {stage0_6, stage0_4};
assign {stage1_6, stage1_7} = (stage0_5 > stage0_7) ? {stage0_5, stage0_7} : {stage0_7, stage0_5};

// Layer 1-1: [(1,2), (5,6)]
assign {stage1_1_1, stage1_1_2} = (stage1_1 > stage1_2) ? {stage1_1, stage1_2} : {stage1_2, stage1_1};
assign {stage1_1_5, stage1_1_6} = (stage1_5 > stage1_6) ? {stage1_5, stage1_6} : {stage1_6, stage1_5};

// Layer 2: [(0,4), (1,5), (2,6), (3,7)]
assign {stage2_0, stage2_1} = (stage1_0 > stage1_4) ? {stage1_0, stage1_4} : {stage1_4, stage1_0};
assign {stage2_2, stage2_3} = (stage1_1_1 > stage1_1_5) ? {stage1_1_1, stage1_1_5} : {stage1_1_5, stage1_1_1};
assign {stage2_4, stage2_5} = (stage1_1_2 > stage1_1_6) ? {stage1_1_2, stage1_1_6} : {stage1_1_6, stage1_1_2};
assign {stage2_6, stage2_7} = (stage1_3 > stage1_7) ? {stage1_3, stage1_7} : {stage1_7, stage1_3};

// Layer 3: [(1,2), (5,6)]
assign {stage3_1, stage3_2} = (stage2_1 > stage2_2) ? {stage2_1, stage2_2} : {stage2_2, stage2_1};
assign {stage3_5, stage3_6} = (stage2_5 > stage2_6) ? {stage2_5, stage2_6} : {stage2_6, stage2_5};

// Layer 4: [(2,4), (3,5)]
assign {stage4_2, stage4_3} = (stage3_2 > stage2_4) ? {stage3_2, stage2_4} : {stage2_4, stage3_2};
assign {stage4_4, stage4_5} = (stage2_3 > stage3_5) ? {stage2_3, stage3_5} : {stage3_5, stage2_3};

// Layer 6: result
assign sorted_0 = stage2_0;
assign sorted_1 = stage3_1;
assign sorted_2 = stage4_2;
assign {sorted_3, sorted_4} = (stage4_3 > stage4_4) ? {stage4_3, stage4_4} : {stage4_4, stage4_3};
assign sorted_5 = stage4_5;
assign sorted_6 = stage3_6;
assign sorted_7 = stage2_7;

endmodule
