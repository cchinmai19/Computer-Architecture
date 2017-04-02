`include "config.v"
`include "const.v"

/**************************************
* Module: RetireCommit
* Author: (completed by Nate)
* Date: Dec 21, 2016	11:45 AM
* Description: ROB, Retire/Commit stage for out-of-order processor (final project)
***************************************/

`define LOG_ROBENTRY $clog2(ROB_entries)

module  RetireCommit #(
	parameter ROB_entries = 64
)
(
	input CLK,
	input RESET,
	
	/* Connect these to branch calc/compare */
	input BranchTaken_IN, // Set to 1 when a branch is taken
	input IsBranch_IN,	// Set to 1 when the instruction is a branch
	input [`LEN_UID-1:0]BranchUID_IN, // Set to an instruction's UID when a branch is taken; 0 otherwise
	input [31:0]BranchDest_IN, // Set to the branch destination when it is known
	
	/* This should be a general flush/reset signal, but  */
	output Recover_OUT,
	
	/* connect this to the LSQ / OOOMEM stage */
	output LS_Retire_OUT,
	input LS_Retire_Ready_IN,

	/* connect this to IF */
	output [31:0]IF_BranchPC_OUT,
	
	/* Connect these to the free list / FRAT / rename stage */
	output ROB_full_OUT,
	output ROB_empty_OUT,
	input ROB_NQ,
	input [`LEN_RC_ENTRY-1:0] Instruction_IN,
	output [`RAT_BUSWIDTH-1:0]RRAT_Dump_OUT,
	output [`LOG_PHYS-1:0]RegRecycleID_OUT, // ID of physical register to add back to free list
	output RegRecycle_OUT // Request a register recycle
	
	
);/*verilator public_module*/



/* begin ROB */
reg [`LEN_RC_ENTRY-1:0] ROB[0:ROB_entries-1];
reg [`LOG_ROBENTRY-1:0]ROB_head_ptr;
reg [`LOG_ROBENTRY-1:0]ROB_tail_ptr;
wire ROB_full=(ROB_tail_ptr+1'b1)==ROB_head_ptr;
wire ROB_empty=ROB_head_ptr==ROB_tail_ptr;

/* verilator lint_off UNUSED */
wire [`LEN_RC_ENTRY-1:0] ROB_head = ROB[ROB_head_ptr];
/* verilator lint_on UNUSED */

assign ROB_full_OUT = ROB_full;
assign ROB_empty_OUT = ROB_empty;
/* end ROB */

RAT #(
    /* Maybe Others? */
	.ID("RRAT")
)RRAT(
	.CLK(CLK),
	.RESET(RESET),
	.AREG_IN(head_adest),
	.PREG_IN(head_pdest),
	.Rename_IN(RRAT_Rename),
	.Bulk_OUT(RRAT_Dump_OUT),
	.Bulk_IN(0),
	.BulkRead_IN(0),

	/* These go straight through to the rename stage */
	.RegRecycleID_OUT(RegRecycleID),
	.RegRecycle_OUT(RegRecycle)
);

wire [`LOG_PHYS-1:0]RegRecycleID;
wire RegRecycle;
assign RegRecycle_OUT=RegRecycle;
assign RegRecycleID_OUT=RegRecycleID;


/* These are just fields in the ROB entry */
wire head_complete = ROB_head[`OFF_RC_complete]; // instruction complete flag
wire head_ls = ROB_head[`OFF_RC_ls];	// instruction LS flag (1 if it's a load OR a store; 0 otherwise)
wire head_branch = ROB_head[`OFF_RC_branch]; // instruction branch flag (1 if it's a branch)
wire head_mispred = ROB_head[`OFF_RC_mispred]; // mispredicted branch flag (1 if it was mispredicted)
wire [31:0]head_branchPC = ROB_head[`OFF_RC_branchPC -: 32]; // PC to be taken by the branch
wire [`LOG_PHYS-1:0]head_pdest = ROB_head[`OFF_RC_pdest -: `LOG_PHYS]; // ROB head's destination register ID (physical)
wire [`LOG_ARCH-1:0]head_adest = ROB_head[`OFF_RC_adest -: `LOG_ARCH]; // ROB head's destination register ID (architectural)

wire RRAT_Rename;

	always @(posedge CLK or negedge RESET) begin
		if(!RESET) begin
			$display("RETIRECOMMIT:reset");
			Recover_OUT<=0;
			RRAT_Rename<=0;
		end else begin
			Recover_OUT<=head_branch && head_mispred; // Trigger recovery when the ROB head is a mispredicted branch
			
			/* Trigger RRAT update when an instruction is complete and it isn't a branch */
			RRAT_Rename<= !ROB_empty && head_complete && !head_branch;
			// TODO: Ensure that we aren't doing anything weird with instructions that don't actually have a dest reg (e.g. NOP, BRA, SW)
			
			
			if(ROB_NQ) begin// && Instruction_IN != {`LEN_RC_ENTRY{1'b0}} && Instruction_IN !=ROB[ROB_tail_ptr]) begin
				// Enqueue an instruction if it's nonzero and doesn't match the last instruction to be enqueued (bit of a hack)
				ROB[ROB_tail_ptr]<=Instruction_IN;
				ROB_tail_ptr<=ROB_tail_ptr+1;
			end
			
			// Set misprediction flag when branch decision/destination is determined to be incorrect
			// Assumes no actual instruction's ID is 0. Might want to change that to a dedicated trigger signal...
			if(BranchUID_IN!=0)begin
				for (int i=0; i<ROB_entries; i=i+1'b1) begin
					if (ROB[i][`OFF_RC_uid-:`LEN_UID] == BranchUID_IN) begin
						// If this instruction (in the ROB) has matching ID, then determine whether it was a misprediction
						
						// It's a misprediction if:
						// It's a branch and...
						// 		...we branched to the wrong PC, OR...
						//		...we didn't branch when we should have, OR...
						//		...we branched when we shouldn't have.
						// OR it's NOT a branch and...
						//		...we thought it was AND we branched.
						ROB[i][`OFF_RC_mispred] <= (!ROB[i][`OFF_RC_branchtaken] && BranchTaken_IN) || (ROB[i][`OFF_RC_branchtaken] && !BranchTaken_IN) || (ROB[i][`OFF_RC_branchtaken] && ROB[i][`OFF_RC_branchPC -: 32]!=BranchDest_IN) || (!IsBranch_IN && ROB[i][`OFF_RC_branchtaken]);
						
						if ((!ROB[i][`OFF_RC_branchtaken] && BranchTaken_IN) || (ROB[i][`OFF_RC_branchtaken] && !BranchTaken_IN) || (ROB[i][`OFF_RC_branchtaken] && ROB[i][`OFF_RC_branchPC -: 32]!=BranchDest_IN) || (!IsBranch_IN && ROB[i][`OFF_RC_branchtaken])) begin
							$display("ROB:learned of a branch misprediction. This has all been in vain!");
						end
						
						ROB[i][`OFF_RC_branchPC -: 32]<=BranchDest_IN;
						ROB[i][`OFF_RC_branchtaken] <=BranchTaken_IN;
					end
				end
			end
			
			if (!ROB_empty) begin
				if(head_complete && (!head_branch || (head_branch && !head_mispred))) begin
					// If instruction is done with no mispredictions, dequeue it and update the RRAT with its destination reg mapping

					// Dequeue head
					ROB_head_ptr <= ROB_head_ptr+1;
				end else if (head_ls && LS_Retire_Ready_IN) begin
					// If instruction is not done but is just a load/store, trigger the MEM stage and dequeue it
					// UNLESS the LSQ isn't ready (i.e., waiting for a load to finish)

					// Dequeue head
					ROB_head_ptr <= ROB_head_ptr+1;
					
					LS_Retire_OUT<=1;
				end else if (head_branch && head_mispred) begin
					$display("ROB:Mispredicted branch is ROB head. The time of reckoning is at hand!");
					// On misprediction, send correct PC to IF
					// If taken, send branch destination
					// If not taken, send PC+4
					ROB_tail_ptr <= ROB_head_ptr+1; // Empty ROB except for head
					IF_BranchPC_OUT<=ROB_head[`OFF_RC_branchtaken] ? head_branchPC : ROB_head[`OFF_RC_PC-:32]+32'd4; // If branch wasn't taken, dest PC=PC+4, otherwise branch dest
				end
			end
		end
	end

endmodule
