/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2023 Autumn IC Design Laboratory 
Lab10: SystemVerilog Coverage & Assertion
File Name   : CHECKER.sv
Module Name : CHECKER
Release version : v1.0 (Release Date: Nov-2023)
Author : Jui-Huang Tsai (erictsai.10@nycu.edu.tw)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

`include "Usertype.sv"
module Checker(input clk, INF.CHECKER inf);
import usertype::*;

// integer fp_w;

// initial begin
// fp_w = $fopen("out_valid.txt", "w");
// end

/**
 * This section contains the definition of the class and the instantiation of the object.
 *  * 
 * The always_ff blocks update the object based on the values of valid signals.
 * When valid signal is true, the corresponding property is updated with the value of inf.D
 */

class Formula_and_mode;
    Formula_Type f_type;
    Mode f_mode;
endclass

Formula_and_mode fm_info = new();

//  =========================================================
//    Coverage
//  =========================================================

always_ff @(posedge clk) begin
    if (inf.formula_valid) begin
        fm_info.f_type = inf.D.d_formula[0] ;
    end
end

always_ff @(posedge clk) begin
    if (inf.mode_valid) begin
        fm_info.f_mode = inf.D.d_mode[0];
    end
end

covergroup Spec1 @(posedge clk iff(inf.formula_valid));
    option.per_instance = 1;
    option.at_least = 150;
    btype:coverpoint inf.D.d_formula[0] {
        bins b_f_type [] = {Formula_A, Formula_B,Formula_C, Formula_D, Formula_E, Formula_F, Formula_G, Formula_H};
    }
endgroup

Spec1 spec1_inst = new() ;

covergroup Spec2 @(posedge clk iff(inf.mode_valid));
    option.per_instance = 1;
    option.at_least = 150;
    bsize : coverpoint inf.D.d_mode[0] {
        bins b_f_mode [] = {Insensitive, Normal, Sensitive} ;
    }
endgroup

Spec2 spec2_inst = new() ;


covergroup Spec3 @(negedge clk iff(inf.mode_valid));
    option.per_instance = 1;
    option.at_least = 150;
	cross fm_info.f_mode, fm_info.f_type ;
endgroup

Spec3 spec3_inst = new();

covergroup Spec4 @(negedge clk iff(inf.out_valid));
    option.per_instance = 1;
    option.at_least = 50;
	out : coverpoint inf.warn_msg {
		bins e_err [] = {[No_Warn:Data_Warn]} ;
	}
endgroup

Spec4 spec4_inst = new() ;


covergroup Spec5 @(posedge clk iff(inf.sel_action_valid));
    option.per_instance = 1 ;
    option.at_least = 300 ;
	act : coverpoint inf.D.d_act[0] {
		bins a_act [] = ([Index_Check:Check_Valid_Date] => [Index_Check:Check_Valid_Date]) ;
	}
endgroup

Spec5 spec5_inst = new() ;


covergroup Spec6 @(posedge clk iff(inf.index_valid));
    option.per_instance = 1 ;
    option.at_least = 1 ;
	input_ing : coverpoint inf.D.d_index[0] {
		option.auto_bin_max = 32 ;
	}
endgroup

Spec6 spec6_inst = new() ;

//  =========================================================
//    Asseration
//  =========================================================

Action store_action ;
logic last_invalid ;
logic [2:0] index_count ;

always_ff @ (posedge clk or negedge inf.rst_n) begin 
	if (!inf.rst_n) begin 
		index_count = 0 ;
	end
	else begin 
		if (inf.index_valid) index_count = index_count + 1 ;
		else if (index_count == 4) index_count = 0 ;
	end
end

always_ff @ (posedge clk or negedge inf.rst_n) begin  
	if (!inf.rst_n) store_action = Index_Check ;
	else begin 
		if (inf.sel_action_valid)
			store_action = inf.D.d_act[0] ;
	end
end

always_ff @ (posedge clk or negedge inf.rst_n) begin 
	if (!inf.rst_n) last_invalid = 0 ;
	else begin 
		case (store_action)
			Index_Check, Update : begin 
				if (index_count == 4) last_invalid = 1 ;
				else last_invalid = 0 ;
			end
			Check_Valid_Date : begin 
				if (inf.data_no_valid) last_invalid = 1 ;
				else last_invalid = 0 ;
			end
		endcase
	end
end

// ==========================================================================

always @ (negedge inf.rst_n) begin 
	#1 ;
	Assertion1 : assert (inf.out_valid === 0 && inf.warn_msg === 0 && inf.complete === 0 && 
                         inf.AR_VALID === 0 && inf.AR_ADDR === 0 && inf.R_READY === 0 && inf.AW_VALID === 0 &&
                         inf.AW_ADDR === 0 && inf.W_VALID === 0 && inf.W_DATA === 0 && inf.B_READY === 0) 
				else begin 
					$display("==========================================================================") ;
					$display("                       Assertion 1 is violated                            ") ;			
					$display("==========================================================================") ;
					$fatal ;
				end
end
						
// ==========================================================================

property p_last_invalid ;
	@ (posedge clk) last_invalid |-> (##[1:1000] inf.out_valid) ;
endproperty : p_last_invalid 

always @ (posedge clk) begin
	Assertion2 : assert property (p_last_invalid)
				 else begin 
					$display("==========================================================================") ;
					$display("                       Assertion 2 is violated                            ") ;
					$display("==========================================================================") ;
					$fatal ;
				 end
end

// ==========================================================================

property p_complete ;
	@ (negedge clk) inf.complete |-> (inf.warn_msg == No_Warn) ;
endproperty : p_complete

always @ (negedge clk)
	Assertion3 : assert property (p_complete)
				 else begin 
					$display("==========================================================================") ;
					$display("                      Assertion 3 is violated                             ") ;
					$display("==========================================================================") ;
					$fatal ;
				 end

// ==========================================================================

property p_begin ;
	@ (posedge clk) inf.sel_action_valid |-> (##[1:4] (inf.formula_valid | inf.date_valid)) ;
endproperty : p_begin

property p_index_check ;
	@ (posedge clk) inf.formula_valid |-> (##[1:4] inf.mode_valid ##[1:4] inf.date_valid ##[1:4] inf.data_no_valid  ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid) ;
endproperty : p_index_check 

property p_update ;
	@ (posedge clk) inf.date_valid |-> (##[1:4] inf.data_no_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid) ;
endproperty : p_update 

property p_check_date ;
	@ (posedge clk) inf.date_valid |-> (##[1:4] inf.data_no_valid) ;
endproperty : p_check_date 

always @ (posedge clk) begin
	
	if (inf.sel_action_valid) begin 
		Asseration4 : assert property (p_begin)
				  else begin 
					$display("==========================================================================") ;
					$display("                       Assertion 4 is violated                            ") ;
					$display("==========================================================================") ;
					$fatal ;
				  end
	end
	else if (store_action == Index_Check) begin 
		Assertion4_MD : assert property (p_index_check)
					 else begin 
						$display("==========================================================================") ;
						$display("                       Assertion 4 is violated                            ") ;
						$display("==========================================================================") ;
						$fatal ;
					 end
	end
	else if (store_action == Update) begin 
		Assertion4_S : assert property (p_update)
					 else begin 
						$display("==========================================================================") ;
						$display("                       Assertion 4 is violated                            ") ;
						$display("==========================================================================") ;
						$fatal ;
					 end
	end
	else if (store_action == Check_Valid_Date) begin 
		Assertion4_CVD : assert property (p_check_date)
					 else begin 
						$display("==========================================================================") ;
						$display("                       Assertion 4 is violated                            ") ;
						$display("==========================================================================") ;
						$fatal ;
					 end
	end
end

// ==========================================================================

property p_action_overlap ;
	@ (posedge clk) inf.sel_action_valid |-> ((inf.formula_valid | inf.mode_valid | inf.date_valid | inf.data_no_valid | inf.index_valid) == 0) ;
endproperty : p_action_overlap 

property p_formula_overlap ;
	@ (posedge clk) inf.formula_valid |-> ((inf.sel_action_valid | inf.mode_valid | inf.date_valid | inf.data_no_valid | inf.index_valid) == 0) ;
endproperty : p_formula_overlap 

property p_mode_overlap ;
	@ (posedge clk) inf.mode_valid |-> ((inf.sel_action_valid | inf.formula_valid | inf.date_valid | inf.data_no_valid | inf.index_valid) == 0) ;
endproperty : p_mode_overlap 

property p_date_overlap ;
	@ (posedge clk) inf.date_valid |-> ((inf.sel_action_valid | inf.formula_valid | inf.mode_valid | inf.data_no_valid | inf.index_valid) == 0) ;
endproperty : p_date_overlap 

property p_datano_overlap ;
	@ (posedge clk) inf.data_no_valid |-> ((inf.sel_action_valid | inf.formula_valid | inf.mode_valid | inf.date_valid | inf.index_valid) == 0) ;
endproperty : p_datano_overlap 

property p_index_overlap ;
	@ (posedge clk) inf.index_valid |-> ((inf.sel_action_valid | inf.formula_valid | inf.mode_valid | inf.date_valid | inf.data_no_valid) == 0) ;
endproperty : p_index_overlap 

always @ (posedge clk) begin 
	Asseration_action_overlap : assert property (p_action_overlap)
							else begin 
								$display("==========================================================================") ;
								$display("                        Assertion 5 is violated                           ") ;
								$display("==========================================================================") ;
							    $fatal ;
							end
	Asseration_type_overlap   : assert property (p_formula_overlap)
							else begin 
								$display("==========================================================================") ;
								$display("                        Assertion 5 is violated                           ") ;
								$display("==========================================================================") ;
							    $fatal ;
							end
	Asseration_size_overlap   : assert property (p_mode_overlap)
							else begin 
								$display("==========================================================================") ;
								$display("                        Assertion 5 is violated                           ") ;
								$display("==========================================================================") ;
							    $fatal ;
							end
	Asseration_date_overlap   : assert property (p_date_overlap)
							else begin 
								$display("==========================================================================") ;
								$display("                        Assertion 5 is violated                           ") ;
								$display("==========================================================================") ;
							    $fatal ;
							end
	Asseration_boxno_overlap  : assert property (p_datano_overlap)
							else begin 
								$display("==========================================================================") ;
								$display("                        Assertion 5 is violated                           ") ;
								$display("==========================================================================") ;
							    $fatal ;
							end
	Asseration_boxsup_overlap : assert property (p_index_overlap)
							else begin 
								$display("==========================================================================") ;
								$display("                        Assertion 5 is violated                           ") ;
								$display("==========================================================================") ;
							    $fatal ;
							end
end
	
// ==========================================================================

property p_outvalid ;
	@ (posedge clk) inf.out_valid |-> (##1 (inf.out_valid == 0)) ;
endproperty : p_outvalid

always @ (posedge clk)
	Asseration_outvalid : assert property (p_outvalid)
						else begin 
							$display("==========================================================================") ;
							$display("                        Assertion 6 is violated                           ") ;
							$display("==========================================================================") ;
						    $fatal ;
						end

// ==========================================================================

property p_next_pat ;
	@ (posedge clk) inf.out_valid |-> (##[1:4] inf.sel_action_valid) ;
endproperty : p_next_pat

always @ (posedge clk)
	Asseration_gap : assert property (p_next_pat)
						else begin 
							$display("==========================================================================") ;
							$display("                        Assertion 7 is violated                           ") ;
							$display("==========================================================================") ;
						    $fatal ;
						end


// ==========================================================================

property p_check_month ;
	@ (posedge clk) inf.date_valid |-> (inf.D.d_date[0].M <= 12 && inf.D.d_date[0].M >= 1) ;
endproperty : p_check_month

property p_31_month ;
	@ (posedge clk) (inf.date_valid && (inf.D.d_date[0].M == 1 | inf.D.d_date[0].M == 3 |inf.D.d_date[0].M == 5 |inf.D.d_date[0].M == 7 |inf.D.d_date[0].M == 8 |inf.D.d_date[0].M == 10 | inf.D.d_date[0].M == 12)) |-> (inf.D.d_date[0].D <= 31 && inf.D.d_date[0].D >= 1) ;
endproperty : p_31_month

property p_30_month ;
	@ (posedge clk) (inf.date_valid && (inf.D.d_date[0].M == 4 | inf.D.d_date[0].M == 6 |inf.D.d_date[0].M == 9 |inf.D.d_date[0].M == 11)) |-> (inf.D.d_date[0].D <= 30 && inf.D.d_date[0].D >= 1) ;
endproperty : p_30_month

property p_February ;
	@ (posedge clk) (inf.date_valid && (inf.D.d_date[0].M == 2)) |-> (inf.D.d_date[0].D <= 28 && inf.D.d_date[0].D >= 1) ;
endproperty : p_February

always @ (posedge clk) begin
	Asseration_check_month : assert property (p_check_month)
						else begin 
							$display("==========================================================================") ;
							$display("                        Assertion 8 is violated                           ") ;
							$display("==========================================================================") ;
						    $fatal ;
						end
	
	Asseration_big_month : assert property (p_31_month)
						else begin 
							$display("==========================================================================") ;
							$display("                        Assertion 8 is violated                           ") ;
							$display("==========================================================================") ;
						    $fatal ;
						end
	Asseration_small_month : assert property (p_30_month)
						else begin 
							$display("==========================================================================") ;
							$display("                        Assertion 8 is violated                           ") ;
							$display("==========================================================================") ;
						    $fatal ;
						end					
	Asseration_february : assert property (p_February)
						else begin 
							$display("==========================================================================") ;
							$display("                        Assertion 8 is violated                           ") ;
							$display("==========================================================================") ;
						    $fatal ;
						end
end

// ==========================================================================

property p_dram_overlap ;
	@ (posedge clk) inf.AR_VALID |-> (inf.AW_VALID == 0) ;
endproperty : p_dram_overlap 

always @ (posedge clk) begin 
	Asseration_dram_overlap : assert property (p_dram_overlap)
							else begin 
								$display("==========================================================================") ;
								$display("                        Assertion 9 is violated                           ") ;
								$display("==========================================================================") ;
							    $fatal ;
							end
end


endmodule