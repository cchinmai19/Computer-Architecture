	/* Various constants, offsets, etc. used by several modules */
	`define NUM_ARCH_REGS 35
	`define NUM_PHYS_REGS 64

	`define LOG_ARCH    $clog2(`NUM_ARCH_REGS)
	`define LOG_PHYS    $clog2(`NUM_PHYS_REGS)
	
	`define LEN_UID 32 // Unique instruction ID length
	
	`define RAT_BUSWIDTH `NUM_ARCH_REGS*`LOG_PHYS

	// TODO: check that Instr_Flags[6] is sufficient to ensure a store, check that reg ids are correct for L/S
	// data_out_LSQ <= {{(LEN_MEM_DST_DATA + LEN_MEM_SRC_DATA + LEN_MEM_ALU_result + LEN_MEM_ALU_control){1'b0}},Instr_Flags[6],PhyReg_rs,PhyReg_rd,Instr_PC,Instr_UID};
	
	/* entry field offsets for OoOMEM entries */
	`define OFF_MEM_DST_DATA	(`OFF_MEM_SRC_DATA + `LEN_MEM_DST_DATA)
	`define OFF_MEM_SRC_DATA	(`OFF_MEM_ALU_result + 32)
	`define OFF_MEM_ALU_result	(`OFF_MEM_ALU_control + `LEN_MEM_ALU_result)
	`define OFF_MEM_ALU_control	(`OFF_MEM_LS + `LEN_MEM_ALU_control)
	`define OFF_MEM_LS	(`OFF_MEM_SRC_ID + 1)
	`define OFF_MEM_SRC_ID	(`OFF_MEM_DST_ID + `LEN_MEM_RegID)
	`define OFF_MEM_DST_ID	(`OFF_MEM_PC + `LEN_MEM_RegID)
	`define OFF_MEM_PC	(`OFF_MEM_ID + `LEN_MEM_PC)
	`define OFF_MEM_ID	(`LEN_MEM_ID  - 1)

	`define LEN_MEM_ENTRY (`OFF_MEM_DST_DATA+1) // Length of the entire entry is just the first field offset plus 1
	`define LEN_MEM_SRC_DATA 32
	`define LEN_MEM_DST_DATA 32
	`define LEN_MEM_ALU_result	32
	`define LEN_MEM_ALU_control	6
	`define LEN_MEM_RegID	6
	`define LEN_MEM_PC 	 32
	`define LEN_MEM_ID 	 `LEN_UID

	
	// TODO: if we implement actual branch prediction, put PC and prediction in here
	// data_out_ROB <= {0,0,0,32'b0,Instr_Flags[4],is_LDST,RD,PhyReg_rd,Instr_PC,Instr_UID};

	/* entry field offsets for RetireCommit entries */
	`define OFF_RC_mispred	(`OFF_RC_complete + 1)
	`define OFF_RC_complete		(`OFF_RC_branchtaken + 1)
	`define OFF_RC_branchtaken	(`OFF_RC_branchPC + 1)
	`define OFF_RC_branchPC	(`OFF_RC_branch + `LEN_RC_branchPC)
	`define OFF_RC_branch	(`OFF_RC_ls + 1)
	`define OFF_RC_ls	(`OFF_RC_adest + 1)
	`define OFF_RC_adest	(`OFF_RC_pdest + `LEN_RC_adest)
	`define OFF_RC_pdest	(`OFF_RC_PC + `LEN_RC_pdest)
	`define OFF_RC_PC	(`OFF_RC_uid + 32)
	`define OFF_RC_uid	(`LEN_RC_uid - 1)

	`define LEN_RC_ENTRY (`OFF_RC_mispred+1)
	`define LEN_RC_adest	`LOG_ARCH
	`define LEN_RC_pdest	`LOG_PHYS
	`define LEN_RC_branchPC	32
	`define LEN_RC_uid	`LEN_UID
