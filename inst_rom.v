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
// Module:  inst_rom
// File:    inst_rom.v
// Author:  Lei Silei
// E-mail:  leishangwen@163.com
// Description: Ö¸Áî´æ´¢Æ÷
// Revision: 1.0
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module inst_rom(

//	input	wire										clk,
	input wire										ce,
	input wire[`InstAddrBus]			addr,
	output reg[`InstBus]					inst
	
);

	reg[`InstBus]  inst_mem[0:`InstMemNum-1];
    reg[31:0] inster;
    reg[31:0] reinst;
	initial $readmemh ( "C:/Users/liu/Desktop/sample.data", inst_mem );

	always @ (*) begin
		if (ce == `ChipDisable) begin
			inst <= `ZeroWord;
	  end else begin
	      inster <= inst_mem[addr[`InstMemNumLog2+1:2]];
	      reinst[31:24] <= inster[7:0];
	      reinst[23:16] <= inster[15:8];
	      reinst[15:8] <= inster[23:16];
	      reinst[7:0] <= inster[31:24];
		  inst <= reinst;
		end
	end

endmodule