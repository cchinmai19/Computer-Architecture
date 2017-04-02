`include "config.v"

/**************************************
* Module: OOOMEM
* Author: Nate
* Date: Dec 21, 2016	11:45 AM
* Description: Memory stage for out-of-order processor (final project)
***************************************/

module OOOMEM(
	input CLK,
	input RESET,

	/* Enqueue inputs */
//	input [ID_WIDTH-1:0] NQ_ID_IN,	// Instruction ID input (for enqueueing)


	//input [31:0] Instr1_IN,		// Instruction to be enqueued
	//input [31:0] Instr1_PC_IN,    //PC of executing instruction [debug only]

	/* Connect these to the physical regfile */
	output reg [`LEN_MEM_RegID-1:0] PRegID_OUT, // The ID of the physical register we are writing
	output reg RegWriteEnable_OUT, // Flag to enable register write
	output reg [31:0] RegData_OUT, // Data to write to register
 
	/* Connect these to the data memory/cache */
	output reg [31:0] data_write_2DM,
	output [31:0] data_address_2DM,
	output reg [1:0] data_write_size_2DM,
	input [31:0] data_read_fDM,

	output MemRead_2DM,
	output MemWrite_2DM,
	output MemFlush_2DM,
	input data_valid_fDM,

	
	/* connect these to the rename stage */
	input [`LEN_MEM_ENTRY-1:0] NQ_DATA_IN, // All of the data from the Rename stage
	input NQ_IN,
	output Full_OUT,
	output Empty_OUT,

	/* connect this to the ROB/commit */
	output Ready_OUT, // 0: Waiting for current head to finish; 1: Ready to retire next load/store
	input Retire_IN,	// signals that the ROB is ready to retire the next L/S instruction

	/* connect these to the ALU */
	input [`LEN_UID-1:0] ALU_ID1_IN,	// Instruction ID input (for ALU results, from EXE)
	input [31:0] ALU_result1_IN,    //Output of ALU (contains address to access, or data enroute to writeback)
input [5:0] ALU_Control1_IN,    //Output of ALU (contains address to access, or data enroute to writeback)

	
	/* connect these to the common data bus */
	input data_broadcast_IN,
	input [`LEN_MEM_RegID-1:0] reg_ID_broadcast_IN,
	input [31:0] reg_data_broadcast_IN
);

	parameter LSQ_LENGTH = 16; // Number of entries in load/store queue

	localparam ENTRYLINES=$clog2(LSQ_LENGTH); // Number of select lines needed to address LDQ entries

	/* the actual load/store queue */
	reg [`LEN_MEM_ENTRY-1:0] LSQ [0:LSQ_LENGTH-1];

	/* pointers for queue head/tail */
	reg [ENTRYLINES-1:0] head;
	reg [ENTRYLINES-1:0] tail;
	wire empty;
	wire full;
		assign empty = head==tail;
		assign full = (tail+1'b1)==head;
		assign Full_OUT = full;
		assign Empty_OUT = empty;

	/* verilator lint_off UNUSED */
	wire [`LEN_MEM_ENTRY-1:0] head_data;
	/* verilator lint_on UNUSED */
	
	assign head_data = LSQ[head];
	
	/* properties of the LSQ head are always accessible via these wires */

	wire [`LEN_UID-1:0] head_id=head_data[`OFF_MEM_ID -: `LEN_MEM_ID];
	wire [5:0] head_dest_register=head_data[`OFF_MEM_DST_ID -: `LEN_MEM_RegID];
	wire [31:0] head_src_data=head_data[`OFF_MEM_SRC_DATA -: 32]; // TODO: make sure this is the register for stores (rt1?)
	wire [31:0] head_ALU_result=head_data[`OFF_MEM_ALU_result -: `LEN_MEM_ALU_result];
	wire [5:0] head_ALU_control=head_data[`OFF_MEM_ALU_control -: `LEN_MEM_ALU_control];
	/* verilator lint_off UNUSED */
	wire [31:0] head_PC=head_data[`OFF_MEM_PC -: 32]; 
	wire [5:0] head_src_register=head_data[`OFF_MEM_SRC_ID -: `LEN_MEM_RegID];
	/* verilator lint_on UNUSED */
	wire head_ls=head_data[`OFF_MEM_LS];

	/* intermediate wires to link original logic from MEM.v to head of LSQ */
	wire [31:0] MemWriteAddress;
		assign data_address_2DM = head_ls? MemWriteAddress : MemReadAddress;
	wire [31:0] MemReadAddress;
		assign MemReadAddress={head_ALU_result[31:2], 2'b00};
	








	always @(posedge CLK or negedge RESET) begin // TODO: make sure the data_valid_fDM sensitivity does what we think it does
		if(!RESET) begin 
			head<=0;
			tail<=0;

			MemWrite_2DM<=0;
			MemRead_2DM<=0;
			MemFlush_2DM<=0;
			Ready_OUT<=1;
		end else begin

			/* BEGIN receiving data for load instruction */
			if (data_valid_fDM && !Ready_OUT && head_ls==0) begin // If we've gotten data from the cache, and the head is a load, and we've already indicated that we're waiting...
				$display("MEM Received:data_read_fDM=%x",data_read_fDM);

				Ready_OUT<=1; // Let retire/commit know that we're ready to retire the next LS instruction
				head<=head+1'b1; //dequeue head of LSQ

				/* Handle possible load instructions */
				case(head_ALU_control)
					6'b101101: begin	//LWL   (Load Word Left)
							case (head_ALU_result[1:0])
							0: RegData_OUT <= data_read_fDM;		//Aligned access; read everything
							1:  RegData_OUT[31:8] <= data_read_fDM[23:0];	//Mem:[3,2,1,0] => [2,1,0,8'h00]
							2:  RegData_OUT[31:16] <= data_read_fDM[15:0]; //Mem: [3,2,1,0] => [1,0,16'h0000]
							3:  RegData_OUT[31:24] <= data_read_fDM[7:0];	//Mem: [3,2,1,0] => [0,24'h000000]
						endcase
						data_write_size_2DM <= 0;
					end
					6'b101110: begin	//LWR (Load Word Right)
						case (head_ALU_result[1:0])
							0:  RegData_OUT[7:0] <= data_read_fDM[31:24];	//Mem:[3,2,1,0] => [2,1,0,8'h00]
							1:  RegData_OUT[15:0] <= data_read_fDM[31:16]; //Mem: [3,2,1,0] => [1,0,16'h0000]
							2:  RegData_OUT[23:0] <= data_read_fDM[31:8];	//Mem: [3,2,1,0] => [0,24'h000000]
							3:	RegData_OUT <= data_read_fDM;		//Aligned access; read everything
						endcase
						data_write_size_2DM <= 0;
					end
					6'b100001: begin			//LB (Load byte and sign-extend it)
						case (head_ALU_result[1:0])
							0: RegData_OUT<={{24{data_read_fDM[31]}},data_read_fDM[31:24]};
							1: RegData_OUT<={{24{data_read_fDM[23]}},data_read_fDM[23:16]};
							2: RegData_OUT<={{24{data_read_fDM[15]}},data_read_fDM[15:8]};
							3: RegData_OUT<={{24{data_read_fDM[7]}},data_read_fDM[7:0]};
						endcase
						data_write_size_2DM <= 0;
					end
					6'b101011: begin			//LH (Load halfword)
						case( head_ALU_result[1:0] )
							0:RegData_OUT<={{16{data_read_fDM[31]}},data_read_fDM[31:16]};
							2:RegData_OUT<={{16{data_read_fDM[15]}},data_read_fDM[15:0]};
						endcase
						data_write_size_2DM<=0;
					end
					6'b101010: begin
						case (head_ALU_result[1:0])			//LBU (Load byte unsigned)
							0: RegData_OUT<={{24{1'b0}},data_read_fDM[31:24]};
							1: RegData_OUT<={{24{1'b0}},data_read_fDM[23:16]};
							2: RegData_OUT<={{24{1'b0}},data_read_fDM[15:8]};
							3: RegData_OUT<={{24{1'b0}},data_read_fDM[7:0]};
						endcase
						data_write_size_2DM <= 0;
					end
					6'b101100: begin			//LHU (Load halfword unsigned)
						case( head_ALU_result[1:0] )
							0:RegData_OUT<={{16{1'b0}},data_read_fDM[31:16]};
							2:RegData_OUT<={{16{1'b0}},data_read_fDM[15:0]};
						endcase
						data_write_size_2DM<=0;
					end
					6'b111101, 6'b101000, 6'd0, 6'b110101: begin	//LW, LL, NOP, LWC1
						RegData_OUT <= data_read_fDM;
						data_write_size_2DM<=0;
					end
					default: begin

					end
				endcase

				RegWriteEnable_OUT <= 1;
				MemRead_2DM<=0;
				PRegID_OUT <= head_dest_register;
			end else begin
				RegWriteEnable_OUT <= 0; // Don't request a register write if conditions aren't met
			end
			/* END receiving data for load instruction */


			/* BEGIN retiring head of LSQ */
			if (Retire_IN && Ready_OUT && !empty) begin
				$display("MEM: ROB is ready to retire head of LSQ");
						if (head_ls==0) begin // Instruction is a LOAD
							//data_address_2DM<=MemReadAddress; // Send address to data memory/cache
							Ready_OUT<=0;
							MemRead_2DM<=1;
							MemWrite_2DM<=0;
						end else begin // Instruction is a STORE
							head<=head+1;
							Ready_OUT<=1;
							/* Handle possible store instructions */
							case(head_ALU_control)
								6'b101111: begin	//SB
									data_write_size_2DM<=1;
									data_write_2DM[7:0] <= head_src_data[7:0];
								end
								6'b110000: begin	//SH
									data_write_size_2DM<=2;
									data_write_2DM[15:0] <= head_src_data[15:0];
								end
								6'b110001, 6'b110110: begin	//SW/SC
									data_write_size_2DM<=0;
									data_write_2DM <= head_src_data;
								end
								6'b110010: begin	//SWL
									MemWriteAddress <= head_ALU_result;
									case( head_ALU_result[1:0] )
										0: begin data_write_2DM <= head_src_data; data_write_size_2DM<=0; end
										1: begin data_write_2DM[23:0] <= head_src_data[31:8]; data_write_size_2DM<=3; end
										2: begin data_write_2DM[15:0] <= head_src_data[31:16]; data_write_size_2DM<=2; end
										3: begin data_write_2DM[7:0] <= head_src_data[31:24]; data_write_size_2DM<=1; end
									endcase
								end
								6'b110011: begin	//SWR
									MemWriteAddress <= MemReadAddress;
									case( head_ALU_result[1:0] )
										0: begin data_write_2DM[7:0] <= head_src_data[7:0]; data_write_size_2DM<=1; end
										1: begin data_write_2DM[15:0] <= head_src_data[15:0]; data_write_size_2DM<=2; end
										2: begin data_write_2DM[23:0] <= head_src_data[23:0]; data_write_size_2DM<=3; end
										3: begin data_write_2DM <= head_src_data; data_write_size_2DM<=0; end
									endcase
								end
								default: begin

								end
							endcase
				
							MemRead_2DM<=0;
							MemWrite_2DM<=1;
							MemWriteAddress <= head_ALU_result;				
						end
			end else begin
				MemWrite_2DM <= 0; // Don't request a write unless we need one
			end
			/* END retiring head of LSQ */
		

			/* get data from ALU */
			for (int i = 0; i<LSQ_LENGTH; i=i+1) begin
					if (head_id==ALU_ID1_IN) begin
						LSQ[head][`OFF_MEM_ALU_result -: `LEN_MEM_ALU_result]<=ALU_result1_IN;
						LSQ[head][`OFF_MEM_ALU_control -: `LEN_MEM_ALU_control]<=ALU_Control1_IN;
					end
			end

			/* if there is a register value being broadcast, check to see if any entries in the LSQ are listening for it */
			if(data_broadcast_IN) begin
						$display("MEM: broadcast received on CDB");
						for (int i = 0; i<LSQ_LENGTH; i=i+1) begin
							if (LSQ[i][ `OFF_MEM_SRC_ID -: `LEN_MEM_RegID ]==reg_ID_broadcast_IN) begin
								LSQ[i][ `OFF_MEM_SRC_DATA -: 32 ]<=reg_data_broadcast_IN;
							end
						end
			end

			
			if (NQ_IN && !full) begin
				LSQ[tail] <= NQ_DATA_IN;
				tail<=tail+1;
			end
		end
	end
	
endmodule
