//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2014 leishangwen@163.com                       ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
// Module:  id
// File:    id.v
// Author:  Lei Silei
// E-mail:  leishangwen@163.com
// Description: 译码阶段
// Revision: 1.0
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module id(

	input wire										rst,
	input wire[`InstAddrBus]			pc_i,
	input wire[`InstBus]          inst_i,

  //处于执行阶段的指令的一些信息，用于解决load相关
  input wire[`AluOpBus]					ex_aluop_i,

	//处于执行阶段的指令要写入的目的寄存器信息
	input wire										ex_wreg_i,
	input wire[`RegBus]						ex_wdata_i,
	input wire[`RegAddrBus]       ex_wd_i,
	
	//处于访存阶段的指令要写入的目的寄存器信息
	input wire										mem_wreg_i,
	input wire[`RegBus]						mem_wdata_i,
	input wire[`RegAddrBus]       mem_wd_i,
	
	input wire[`RegBus]           reg1_data_i,
	input wire[`RegBus]           reg2_data_i,

	//如果上一条指令是转移指令，那么下一条指令在译码的时候is_in_delayslot为true
	input wire                    is_in_delayslot_i,

	//送到regfile的信息
	output reg                    reg1_read_o,
	output reg                    reg2_read_o,     
	output reg[`RegAddrBus]       reg1_addr_o,
	output reg[`RegAddrBus]       reg2_addr_o, 	      
	
	//送到执行阶段的信息
	output reg[11:0] immer,
	output reg[`AluOpBus]         aluop_o,
	output reg[`AluSelBus]        alusel_o,
	output reg[`RegBus]           reg1_o,
	output reg[`RegBus]           reg2_o,
	output reg[`RegAddrBus]       wd_o,
	output reg                    wreg_o,
	output wire[`RegBus]          inst_o,

	output reg                    next_inst_in_delayslot_o,
	
	output reg                    branch_flag_o,
	output reg[`RegBus]           branch_target_address_o,       
	output reg[`RegBus]           link_addr_o,
	output reg                    is_in_delayslot_o,
	
	output wire                   stallreq	
);

  wire[6:0] op1 = inst_i[6:0];
  wire[4:0] op2 = inst_i[11:7];
  wire[2:0] op3 = inst_i[14:12];
  wire[4:0] op4 = inst_i[19:15];
  wire[4:0] op5 = inst_i[24:20];
  wire[6:0] op6 = inst_i[31:25];
  
  reg[`RegBus]	imm;
  reg instvalid;
  wire[`RegBus] pc_plus_8;
  wire[`RegBus] pc_plus_4;
  wire[`RegBus] pc_plus_0;
  wire[`RegBus] imm_sll2_signedext;  
  wire[`RegBus] imm_sll2_unsignedext;

  reg stallreq_for_reg1_loadrelate;
  reg stallreq_for_reg2_loadrelate;
  wire pre_inst_is_load;
  
  reg[30:0] reg1u;
  reg[30:0] reg2u;
  
  assign pc_plus_8 = pc_i + 8;
  assign pc_plus_4 = pc_i + 4;
  assign pc_plus_0 = pc_i;
  assign imm_sll2_signedext = {{20{inst_i[31]}}, inst_i[7],inst_i[30:25],inst_i[11:8],1'b0 };  
  assign imm_sll2_unsignedext = {20'b0, inst_i[7],inst_i[30:25],inst_i[11:8],1'b0 };  
  assign stallreq = stallreq_for_reg1_loadrelate | stallreq_for_reg2_loadrelate;
  assign pre_inst_is_load = ((ex_aluop_i == `EXE_LB_OP) || 
  													(ex_aluop_i == `EXE_LBU_OP)||
  													(ex_aluop_i == `EXE_LH_OP) ||
  													(ex_aluop_i == `EXE_LHU_OP)||
  													(ex_aluop_i == `EXE_LW_OP) ||
  													(ex_aluop_i == `EXE_LWR_OP)||
  													(ex_aluop_i == `EXE_LWL_OP)||
  													(ex_aluop_i == `EXE_LL_OP) ||
  													(ex_aluop_i == `EXE_SC_OP)) ? 1'b1 : 1'b0;

  assign inst_o = inst_i;
    
	always @ (*) begin	
		if (rst == `RstEnable) begin
			aluop_o <= `EXE_NOP_OP;
			alusel_o <= `EXE_RES_NOP;
			wd_o <= `NOPRegAddr;
			wreg_o <= `WriteDisable;
			instvalid <= `InstValid;
			reg1_read_o <= 1'b0;
			reg2_read_o <= 1'b0;
			reg1_addr_o <= `NOPRegAddr;
			reg2_addr_o <= `NOPRegAddr;
			imm <= 32'h0;	
			link_addr_o <= `ZeroWord;
			branch_target_address_o <= `ZeroWord;
			branch_flag_o <= `NotBranch;
			next_inst_in_delayslot_o <= `InstValid;	
		  end else if ( is_in_delayslot_i == `InstInvalid) begin
                  aluop_o <= `EXE_NOP_OP;
                      alusel_o <= `EXE_RES_NOP;
                      wd_o <= `NOPRegAddr;
                      wreg_o <= `WriteDisable;
                      instvalid <= `InstValid;
                      reg1_read_o <= 1'b0;
                      reg2_read_o <= 1'b0;
                      reg1_addr_o <= `NOPRegAddr;
                      reg2_addr_o <= `NOPRegAddr;
                      imm <= 32'h0;    
                      link_addr_o <= `ZeroWord;
                      branch_target_address_o <= `ZeroWord;
                      branch_flag_o <= `NotBranch;
                      next_inst_in_delayslot_o <= `InstValid;				
	  end else begin
			aluop_o <= `EXE_NOP_OP;
			alusel_o <= `EXE_RES_NOP;
			wd_o <= inst_i[11:7];
			wreg_o <= `WriteDisable;
			instvalid <= `InstInvalid;	   
			reg1_read_o <= 1'b0;
			reg2_read_o <= 1'b0;
			reg1_addr_o <= inst_i[19:15];
			reg2_addr_o <= inst_i[24:20];		
			imm <= `ZeroWord;
			link_addr_o <= `ZeroWord;
			branch_target_address_o <= `ZeroWord;
			branch_flag_o <= `NotBranch;	
			next_inst_in_delayslot_o <= `NotInDelaySlot; 			
		    case (op1)
		          `OP_OP: begin
		                  case (op3)
		    				`FUNCT3_OR:	begin
		    					wreg_o <= `WriteEnable;		aluop_o <= `EXE_OR_OP;
		  						alusel_o <= `EXE_RES_LOGIC; 	reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
		  						instvalid <= `InstValid;	
								end  
		    				`FUNCT3_AND:	begin
		    					wreg_o <= `WriteEnable;		aluop_o <= `EXE_AND_OP;
		  						alusel_o <= `EXE_RES_LOGIC;	  reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;	
		  						instvalid <= `InstValid;	
								end  	
		    				`FUNCT3_XOR:	begin
		    					wreg_o <= `WriteEnable;		aluop_o <= `EXE_XOR_OP;
		  						alusel_o <= `EXE_RES_LOGIC;		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;	
		  						instvalid <= `InstValid;	
								end  				
							`FUNCT3_SLT: begin
                                wreg_o <= `WriteEnable;        aluop_o <= `EXE_SLT_OP;
                                alusel_o <= `EXE_RES_ARITHMETIC;        reg1_read_o <= 1'b1;    reg2_read_o <= 1'b1;
                                instvalid <= `InstValid;    
                                end
                             `FUNCT3_SLTU: begin
                                  wreg_o <= `WriteEnable;        aluop_o <= `EXE_SLTU_OP;
                                  alusel_o <= `EXE_RES_ARITHMETIC;        reg1_read_o <= 1'b1;    reg2_read_o <= 1'b1;
                                  instvalid <= `InstValid;    
                                  end
                              `FUNCT3_SLL: begin
                                  wreg_o <= `WriteEnable;		aluop_o <= `EXE_SLL_OP;
                                  alusel_o <= `EXE_RES_SHIFT;        reg1_read_o <= 1'b1;    reg2_read_o <= 1'b1;
                                  instvalid <= `InstValid;    
                                     end 
                               `FUNCT3_SRL_SRA :
                                    if (op6 == 7'b0000000) begin
                                  wreg_o <= `WriteEnable;		aluop_o <= `EXE_SRL_OP;
                                  alusel_o <= `EXE_RES_SHIFT;        reg1_read_o <= 1'b1;    reg2_read_o <= 1'b1;
                                  instvalid <= `InstValid;  
                                   end  else
                                   begin
                                                    	wreg_o <= `WriteEnable;		aluop_o <= `EXE_SRA_OP;
                                                        alusel_o <= `EXE_RES_SHIFT;        reg1_read_o <= 1'b1;    reg2_read_o <= 1'b1;
                                                        instvalid <= `InstValid;      
                                                  end
                             `FUNCT3_ADD_SUB: 
                                     if (op6 == 7'b0000000) 
                                     begin
                                     wreg_o <= `WriteEnable;        aluop_o <= `EXE_ADD_OP;
                                     alusel_o <= `EXE_RES_ARITHMETIC;        reg1_read_o <= 1'b1;    reg2_read_o <= 1'b1;
                                     instvalid <= `InstValid;    
                                 end else
                                  begin
                                     wreg_o <= `WriteEnable;        aluop_o <= `EXE_SUB_OP;
                                      alusel_o <= `EXE_RES_ARITHMETIC;        reg1_read_o <= 1'b1;    reg2_read_o <= 1'b1;
                                      instvalid <= `InstValid;    
                                       end
							default begin
								end
						endcase
						end
						 `OP_OP_IMM: 
						         case (op3)
								  					    							  
                                `FUNCT3_ORI:            begin                        //ORI指令
                                        wreg_o <= `WriteEnable;        aluop_o <= `EXE_OR_OP;
                                        alusel_o <= `EXE_RES_LOGIC; reg1_read_o <= 1'b1;    reg2_read_o <= 1'b0;          
                                        imm <= {{20{inst_i[31]}} , inst_i[31:20]};        wd_o <= inst_i[11:7]; 
                                        instvalid <= `InstValid;    
                                        end
                                `FUNCT3_ANDI :            begin
                                        wreg_o <= `WriteEnable;        aluop_o <= `EXE_AND_OP;
                                        alusel_o <= `EXE_RES_LOGIC;    reg1_read_o <= 1'b1;    reg2_read_o <= 1'b0;          
                                        imm <= {{20{inst_i[31]}} , inst_i[31:20]};       wd_o <= inst_i[11:7];              
                                        instvalid <= `InstValid;    
                                        end         
                                `FUNCT3_XORI:            begin
                                        wreg_o <= `WriteEnable;        aluop_o <= `EXE_XOR_OP;
                                        alusel_o <= `EXE_RES_LOGIC;    reg1_read_o <= 1'b1;    reg2_read_o <= 1'b0;          
                                        imm <= {{20{inst_i[31]}} , inst_i[31:20]};        wd_o <= inst_i[11:7];             
                                        instvalid <= `InstValid;    
                                        end             
                                      
                                `FUNCT3_SLTI:            begin
                                        wreg_o <= `WriteEnable;        aluop_o <= `EXE_SLT_OP;
                                        alusel_o <= `EXE_RES_ARITHMETIC; reg1_read_o <= 1'b1;    reg2_read_o <= 1'b0;          
                                        imm <= {{20{inst_i[31]}} , inst_i[31:20]};         wd_o <= inst_i[11:7];              
                                        instvalid <= `InstValid;    
                                        end
                                `FUNCT3_SLTIU:            begin
                                        wreg_o <= `WriteEnable;        aluop_o <= `EXE_SLTU_OP;
                                        alusel_o <= `EXE_RES_ARITHMETIC; reg1_read_o <= 1'b1;    reg2_read_o <= 1'b0;          
                                        imm <= {21'b0 , inst_i[30:20]};         wd_o <= inst_i[11:7];              
                                        instvalid <= `InstValid;    
                                        end                      
                                `FUNCT3_ADDI:            begin
                                        wreg_o <= `WriteEnable;        aluop_o <= `EXE_ADDI_OP;
                                        alusel_o <= `EXE_RES_ARITHMETIC; reg1_read_o <= 1'b1;    reg2_read_o <= 1'b0;          
                                        imm <= {{20{inst_i[31]}} , inst_i[31:20]};       wd_o <= inst_i[11:7];              
                                        instvalid <= `InstValid;    
                                        end
                                 `FUNCT3_SLLI : begin
                                        wreg_o <= `WriteEnable;		aluop_o <= `EXE_SLL_OP;
                                        alusel_o <= `EXE_RES_SHIFT; reg1_read_o <= 1'b1;    reg2_read_o <= 1'b0;          
                                        imm[4:0] <= {27'b000000000000000000000000000,inst_i[24:20]};        wd_o <= inst_i[11:7];
                                        instvalid <= `InstValid;      
                                        end 
                                 `FUNCT3_SRLI_SRAI: 
                                        if (op6 == 7'b0000000) begin
                                        wreg_o <= `WriteEnable;		aluop_o <= `EXE_SRL_OP;
                                        alusel_o <= `EXE_RES_SHIFT; reg1_read_o <= 1'b1;    reg2_read_o <= 1'b0;          
                                        imm <= {27'b000000000000000000000000000 , inst_i[24:20]};        wd_o <= inst_i[11:7];
                                        instvalid <= `InstValid;      
                                        end       else               
                                        begin
                                        wreg_o <= `WriteEnable;		aluop_o <= `EXE_SRA_OP;
                                        alusel_o <= `EXE_RES_SHIFT; reg1_read_o <= 1'b1;    reg2_read_o <= 1'b0;          
                                        imm <= {27'b000000000000000000000000000 , inst_i[24:20]};         wd_o <= inst_i[11:7];
                                        instvalid <= `InstValid;           
                                        end
                                    default begin end
                                    endcase
                        `OP_LUI:     begin
                                   wreg_o <= `WriteEnable;        aluop_o <= `EXE_OR_OP;
                                   alusel_o <= `EXE_RES_LOGIC; reg1_read_o <= 1'b1;    reg2_read_o <= 1'b0;  
                                   reg1_addr_o <= 5'b00000;        
                                   imm <= {inst_i[31:12], 12'h0};        wd_o <= inst_i[11:7];              
                                   instvalid <= `InstValid;    
                         end  
                        `OP_AUIPC:     begin
                                   wreg_o <= `WriteEnable;        aluop_o <= `EXE_OR_OP;
                                   alusel_o <= `EXE_RES_LOGIC; reg1_read_o <= 1'b1;    reg2_read_o <= 1'b0;         
                                   reg1_addr_o <= 5'b00000; 
                                   imm <= {inst_i[31:12], 12'h0} + pc_i;        wd_o <= inst_i[11:7];              
                                   instvalid <= `InstValid;    
                                   end  
						`OP_JAL: begin
								wreg_o <= `WriteEnable;		aluop_o <= `EXE_JAL_OP;
                                alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b0;    reg2_read_o <= 1'b0;
                                wd_o <= inst_i[11:7];    
                                link_addr_o <= pc_plus_4 ;
                                branch_target_address_o <= {{12{inst_i[31]}}, inst_i[19:12],inst_i[20:20],inst_i[30:25], inst_i[24:21],1'b0} + pc_plus_0;
                                branch_flag_o <= `Branch;
                               next_inst_in_delayslot_o <= `InDelaySlot;              
                               instvalid <= `InstInvalid;    	
								end
						`OP_JALR: begin
								wreg_o <= `WriteEnable;		aluop_o <= `EXE_JALR_OP;
		  						alusel_o <= `EXE_RES_JUMP_BRANCH;   reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;
		  						wd_o <= inst_i[11:7];
		  						link_addr_o <= pc_plus_4;					
			            	    branch_target_address_o <= reg1_o + pc_plus_0;
			            	    branch_flag_o <= `Branch;  
			                   next_inst_in_delayslot_o <= `InDelaySlot;
			                     instvalid <= `InstInvalid;   
								end		
				`OP_BRANCH		:
				case (op3) 								 											  											
				`FUNCT3_BEQ:			begin
		  		                  wreg_o <= `WriteDisable;		aluop_o <= `EXE_BEQ_OP;
		  		                  alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
		  		              instvalid <= `InstInvalid;     
		  		                  if(reg1_o == reg2_o) begin
			    	                    branch_target_address_o <= pc_plus_0 + imm_sll2_signedext;
			    	                    branch_flag_o <= `Branch;
			    	                    next_inst_in_delayslot_o <= `InDelaySlot;		  	
			    end
				end
				`FUNCT3_BNE:			begin
                                  wreg_o <= `WriteDisable;        aluop_o <= `EXE_BLEZ_OP;
                                  alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;    reg2_read_o <= 1'b1;
                            instvalid <= `InstInvalid;     
                                  if(reg1_o != reg2_o) begin
                                    branch_target_address_o <= pc_plus_0 + imm_sll2_signedext;
                                    branch_flag_o <= `Branch;
                                    next_inst_in_delayslot_o <= `InDelaySlot;              
                                end
                                end
				`FUNCT3_BGE:			begin
		  		wreg_o <= `WriteDisable;		aluop_o <= `EXE_BGTZ_OP;
		  		alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
		 instvalid <= `InstInvalid;  	
		  		reg1u <= reg1_o[30:0];
                reg2u <= reg2_o[30:0];
                if((reg1_o[31] == 1'b0 && reg2_o[31] == 1'b1) || (reg1_o[31] == 1'b0 && reg2_o[31] == 1'b0 && reg1u >= reg2u) || (reg1_o[31] == 1'b1 && reg2_o[31] == 1'b1 && reg1u <= reg2u)) begin
			    	branch_target_address_o <= pc_plus_0 + imm_sll2_signedext;
			    	branch_flag_o <= `Branch;
			    	next_inst_in_delayslot_o <= `InstInvalid;		  	
			    end
				end
				`FUNCT3_BGEU:			begin
                                  wreg_o <= `WriteDisable;        aluop_o <= `EXE_BGTZ_OP;
                                  alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;    reg2_read_o <= 1'b1;
                            instvalid <= `InstInvalid;      
                                  if(reg1_o >= reg2_o) begin
                                    branch_target_address_o <= pc_plus_0 + imm_sll2_signedext;
                                    branch_flag_o <= `Branch;
                                    next_inst_in_delayslot_o <= `InDelaySlot;              
                                end
                                end
				`FUNCT3_BLT:			begin
		  		wreg_o <= `WriteDisable;		aluop_o <= `EXE_BLEZ_OP;
		  		alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1;
		 instvalid <= `InstInvalid;  
		         reg1u <= reg1_o[30:0];
		         reg2u <= reg2_o[30:0];
		  		if((reg1_o[31] == 1'b1 && reg2_o[31] == 1'b0) || (reg1_o[31] == 1'b0 && reg2_o[31] == 1'b0 && reg1u < reg2u) || (reg1_o[31] == 1'b1 && reg2_o[31] == 1'b1 && reg1u > reg2u)) begin
			    	branch_target_address_o <= pc_plus_0 + imm_sll2_signedext;
			    	branch_flag_o <= `Branch;
			    next_inst_in_delayslot_o <= `InDelaySlot;		  	
			    end
				end
				`FUNCT3_BLTU:			begin
                              wreg_o <= `WriteDisable;        aluop_o <= `EXE_BLEZ_OP;
                              alusel_o <= `EXE_RES_JUMP_BRANCH; reg1_read_o <= 1'b1;    reg2_read_o <= 1'b1;
                           instvalid <= `InstInvalid;   
                              	if(reg1_o < reg2_o) begin
                                branch_target_address_o <= pc_plus_0 + imm_sll2_signedext;
                                branch_flag_o <= `Branch;
                               next_inst_in_delayslot_o <= `InDelaySlot;              
                   end
                   end
				default begin end
				endcase
			`OP_LOAD	:  
			begin
			immer <= inst_i[31:20];
			case (op3)
				`FUNCT3_LB:			begin
		  		wreg_o <= `WriteEnable;		aluop_o <= `EXE_LB_OP;
		  		alusel_o <= `EXE_RES_LOAD_STORE; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
					wd_o <= inst_i[11:7]; instvalid <= `InstValid;
				end
				`FUNCT3_LBU:			begin
		  		wreg_o <= `WriteEnable;		aluop_o <= `EXE_LBU_OP;
		  		alusel_o <= `EXE_RES_LOAD_STORE; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
					wd_o <= inst_i[11:7]; instvalid <= `InstValid;	
				end
				`FUNCT3_LH:			begin
		  		wreg_o <= `WriteEnable;		aluop_o <= `EXE_LH_OP;
		  		alusel_o <= `EXE_RES_LOAD_STORE; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
					wd_o <= inst_i[11:7]; instvalid <= `InstValid;	
				end
				`FUNCT3_LHU:			begin
		  		wreg_o <= `WriteEnable;		aluop_o <= `EXE_LHU_OP;
		  		alusel_o <= `EXE_RES_LOAD_STORE; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
					wd_o <= inst_i[11:7]; instvalid <= `InstValid;	
				end
				`FUNCT3_LW:			begin
		  		wreg_o <= `WriteEnable;		aluop_o <= `EXE_LW_OP;
		  		alusel_o <= `EXE_RES_LOAD_STORE; reg1_read_o <= 1'b1;	reg2_read_o <= 1'b0;	  	
					wd_o <= inst_i[11:7]; instvalid <= `InstValid;	
				end
		        default begin end
		        endcase
		        end
		   `OP_STORE:
		   begin
		   immer <= {inst_i[31:25],inst_i[11:7]};
		   case (op3)		
				`FUNCT3_SB:			begin
		  		wreg_o <= `WriteDisable;		aluop_o <= `EXE_SB_OP;
		  		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1; instvalid <= `InstValid;	
		  		alusel_o <= `EXE_RES_LOAD_STORE; 
				end
				`FUNCT3_SH:			begin
		  		wreg_o <= `WriteDisable;		aluop_o <= `EXE_SH_OP;
		  		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1; instvalid <= `InstValid;	
		  		alusel_o <= `EXE_RES_LOAD_STORE; 
				end
				`FUNCT3_SW:			begin
		  		wreg_o <= `WriteDisable;		aluop_o <= `EXE_SW_OP;
		  		reg1_read_o <= 1'b1;	reg2_read_o <= 1'b1; instvalid <= `InstValid;	
		  		alusel_o <= `EXE_RES_LOAD_STORE; 
				end
			    default begin end
			    endcase		
			    end
			    
			default begin end
			endcase
			
						 //case op
		  
		 	  
		  
		end       //if
	end         //always
	

	always @ (*) begin
			stallreq_for_reg1_loadrelate <= `NoStop;	
		if(rst == `RstEnable) begin
			reg1_o <= `ZeroWord;	
		end else if(pre_inst_is_load == 1'b1 && ex_wd_i == reg1_addr_o 
								&& reg1_read_o == 1'b1 ) begin
		  stallreq_for_reg1_loadrelate <= `Stop;							
		end else if((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1) 
								&& (ex_wd_i == reg1_addr_o) && (reg1_addr_o != 5'b00000)) begin
			reg1_o <= ex_wdata_i; 
		end else if((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1) 
								&& (mem_wd_i == reg1_addr_o)&& (reg1_addr_o != 5'b00000)) begin
			reg1_o <= mem_wdata_i; 			
	  end else if(reg1_read_o == 1'b1) begin
	  	reg1_o <= reg1_data_i;
	  end else if(reg1_read_o == 1'b0) begin
	  	reg1_o <= imm;
	  end else begin
	    reg1_o <= `ZeroWord;
	  end
	end
	
	always @ (*) begin
			stallreq_for_reg2_loadrelate <= `NoStop;
		if(rst == `RstEnable) begin
			reg2_o <= `ZeroWord;
		end else if(pre_inst_is_load == 1'b1 && ex_wd_i == reg2_addr_o 
								&& reg2_read_o == 1'b1 ) begin
		  stallreq_for_reg2_loadrelate <= `Stop;			
		end else if((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1) 
								&& (ex_wd_i == reg2_addr_o) && (reg2_addr_o != 5'b00000)) begin
			reg2_o <= ex_wdata_i; 
		end else if((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1) 
								&& (mem_wd_i == reg2_addr_o)&& (reg1_addr_o != 5'b00000)) begin
			reg2_o <= mem_wdata_i;			
	  end else if(reg2_read_o == 1'b1) begin
	  	reg2_o <= reg2_data_i;
	  end else if(reg2_read_o == 1'b0) begin
	  	reg2_o <= imm;
	  end else begin
	    reg2_o <= `ZeroWord;
	  end
	end

	always @ (*) begin
		if(rst == `RstEnable) begin
			is_in_delayslot_o <= `NotInDelaySlot;
		end else begin
		  is_in_delayslot_o <= is_in_delayslot_i;		
	  end
	end

endmodule