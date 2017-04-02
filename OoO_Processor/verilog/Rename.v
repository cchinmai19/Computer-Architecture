/**************************************
* Module: Rename
* Date: 3 December, 2016
* Author: Chinmai
*
* Description: Cosists of FRAT, Free LIst, Busy Bits
***************************************/

// should sent stall signals from Rename when ??
// Remember to add a feedback from RRAT

`include "config.v"

module Rename (
	input			CLK,
	input			RESET,
	input   		RNMQ_empty,
	input [31:0]    	Instr_IN,
	input [31:0]		Instr_PC,
	input [31:0]    	Instr_PC_Plus4_IN,
        input [4:0]		RS,
	input [4:0]		RT,
	input [4:0]		RD,
	input 			is_LDST,
	input [22:0]		Instr_Flags,
	input   		IQ_full,
	input   		LDST_Q_full,
	input 			ROB_full,
	input 			reset_Busybit,
	input			RegRecycle_IN,
	input [`LOG_PHYS-1:0]	RegRecycleID_IN,
	input [5:0]		Phy_RegDst_EXE,
	output	reg		LSQ_NQ,
	output	reg		ROB_NQ,
	output	reg		insert_IQ,
	output	reg [156:0]	data_out_IQ,
	output	reg [`LEN_MEM_ENTRY-1:0]	data_out_LSQ,
	output  reg [`LEN_RC_ENTRY-1:0]	data_out_ROB,
	output  reg        	RNM_DQ,
	output  reg [5:0]	Phy_RS_OUT,
	output	reg		rs_ready_out,
	output  reg [5:0]	Phy_RT_OUT,
	output	reg		rt_ready_out);


	reg [63:0]	freeList; // 1 - free
	reg [5:0]	FRAT [31:0];/*FRAT RAM verilator public_flat*/
	reg [63:0]	BusyBit;// 1 - busy
	reg [31:0]	Instr_UID; //unique ID for each instruction 

	/* verilator lint_off WIDTH */
	wire [5:0]	pos;

	wire [5:0]	PhyReg_rt;
	wire [5:0]	PhyReg_rs;
	wire [5:0]	PhyReg_rd;

	assign 	PhyReg_rt = FRAT[RT];
	assign  PhyReg_rs = FRAT[RS];
	assign  PhyReg_rd = FRAT[RD];	
	assign  pos =  $clog2(freeList&((~freeList)+1'b1)); 

	always @(posedge CLK or negedge RESET) begin
		if(!RESET) begin
		RNM_DQ <=0;
		Instr_UID <= 0;
		freeList <= 64'hffff_ffff_ffff_ffff;
		BusyBit <= 0;
		data_out_IQ <= 0;
		data_out_LSQ <= 0;
		data_out_ROB <= 0;
		RNM_DQ <= 0;
		Phy_RS_OUT <= 0;
		rs_ready_out <= 0;
		Phy_RT_OUT <= 0;
		rt_ready_out <= 0;
		$display("Rename:RESET"); 
		end else begin
		if (RegRecycle_IN) begin
			freeList[RegRecycleID_IN]<=1;
			BusyBit[RegRecycleID_IN]<=0;
		end
		
			if(reset_Busybit) begin 
				BusyBit[Phy_RegDst_EXE] <= 0;
			end
			RNM_DQ <= 1;
			//map a new PhyReg for Dst
// rename for destination registers other than 0  

			if(RD != 5'b00000) begin 				
				freeList[pos] <= 0;
				BusyBit[pos] <= 1;
				FRAT[RD] <= pos;
			end			
		
			$display("ID TO RNM: RT %d RS %d RD %d",RT,RS,RD);
			$display("RNM: Instr_UID %x,Instr_IN %x,Instr_PC %x,Instr_PC_Plus4_IN %x,Instr_Flags %d,PhyReg_rs %d,PhyReg_rt %d,PhyReg_rd %d",
Instr_UID,Instr_IN,Instr_PC,Instr_PC_Plus4_IN,Instr_Flags,PhyReg_rs,PhyReg_rt,PhyReg_rd);
		        $display("RNM: RD rename FRAT[%d]= %d",RD, pos);
			$display("RNM: free spot %x index%d",freeList,pos);
			for (int i=0; i < 35; i=i+4) begin
			$display("FRAT[%d] = %d FRAT[%d] = %d FRAT[%d] = %d FRAT[%d] = %d",i,FRAT[i],i+1,FRAT[i+1],i+2,FRAT[i+2],i+3,FRAT[i+3]);
			end
			Instr_UID <= Instr_UID +1;
			
			insert_IQ<= is_LDST &&(!IQ_full && !ROB_full && !RNMQ_empty) || !is_LDST && (!IQ_full && !ROB_full && !RNMQ_empty);
			
			if(is_LDST)begin 
				if(!LDST_Q_full)begin
					if(!IQ_full && !ROB_full && !RNMQ_empty) begin
						LSQ_NQ <= 1'b1;
						//data_out_LSQ <= {Instr_UID,Instr_IN,Instr_PC,PhyReg_rd,{32{1'b0}}};
						data_out_LSQ <= {{(`LEN_MEM_DST_DATA + `LEN_MEM_SRC_DATA + `LEN_MEM_ALU_result + `LEN_MEM_ALU_control){1'b0}},Instr_Flags[6],PhyReg_rs,PhyReg_rd,Instr_PC,Instr_UID};
						//insert_IQ <= 1'b1;
						Phy_RS_OUT <= PhyReg_rs;
						rs_ready_out <= ~BusyBit[PhyReg_rs] ;
						Phy_RT_OUT <= PhyReg_rt;
						rt_ready_out <= ~BusyBit[PhyReg_rt] ;
						data_out_IQ <= {Instr_UID,Instr_IN,Instr_PC,Instr_PC_Plus4_IN,Instr_Flags,PhyReg_rd};
						ROB_NQ <=  1'b1;
					//	data_out_ROB <= {Instr_UID,Instr_IN,Instr_PC,PhyReg_rs,PhyReg_rt,PhyReg_rd};
						data_out_ROB <= {1'b0,1'b0,1'b0,32'b0,Instr_Flags[4],is_LDST,RD,PhyReg_rd,Instr_PC,Instr_UID};
						$display("RNM: Sent Value to ROB_Q & I_Q & LDST_Q");
						$display("data_out_LSQ %x data_out_IQ %x data_out_ROB %x",data_out_LSQ, data_out_IQ ,data_out_ROB);
						//$display("RNM: Instr_UID %x,Instr_IN %x,Instr_PC %x,Instr_PC_Plus4_IN %x,Instr_Flags %d,PhyReg_rs %d,PhyReg_rt %d,PhyReg_rd %d",
						//Instr_UID,Instr_IN,Instr_PC,Instr_PC_Plus4_IN,Instr_Flags,PhyReg_rs,PhyReg_rt,PhyReg_rd);
					end else begin 
						//$display("Rename STALL: IQ_full %d,ROB_full %d,RNMQ_empty %d",IQ_full,ROB_full,RNMQ_empty);
					end
				end else begin
					//$display("Rename STALL:IQ_full %d,ROB_full %d,RNMQ_empty %d LDST_Q_full %d",IQ_full,ROB_full,RNMQ_empty,LDST_Q_full);
				end
			end else begin 
				if(!IQ_full && !ROB_full && !RNMQ_empty) begin
					//insert_IQ <= 1'b1;
					Phy_RS_OUT <= PhyReg_rs;
					rs_ready_out <= ~BusyBit[PhyReg_rs] ;
					Phy_RT_OUT <= PhyReg_rt;
					rt_ready_out <= ~BusyBit[PhyReg_rt] ;
					data_out_IQ <= {Instr_UID,Instr_IN,Instr_PC,Instr_PC_Plus4_IN,Instr_Flags,PhyReg_rd};
					ROB_NQ <=  1'b1;
					//data_out_ROB <= {Instr_UID,Instr_IN,Instr_PC,PhyReg_rs,PhyReg_rt,PhyReg_rd};
					data_out_ROB <= {1'b0,1'b0,1'b0,32'b0,Instr_Flags[4],is_LDST,RD,PhyReg_rd,Instr_PC,Instr_UID};
					$display("RNM: Sent Value to ROB_Q & I_Q");
					$display(" data_out_IQ %x data_out_ROB %x",data_out_IQ ,data_out_ROB);
					//$display("RNM: Instr_UID %x,Instr_IN %x,Instr_PC %x,Instr_PC_Plus4_IN %x,Instr_Flags %d,PhyReg_rs %d,PhyReg_rt %d,PhyReg_rd %d",
					//Instr_UID,Instr_IN,Instr_PC,Instr_PC_Plus4_IN,Instr_Flags,PhyReg_rs,PhyReg_rt,PhyReg_rd);	
				end else begin 
					$display("Rename STALL: IQ_full %d,ROB_full %d,RNMQ_empty %d",IQ_full,ROB_full,RNMQ_empty);
				end
			end  
		end
$display("**************************************************************");
	end 
endmodule 
