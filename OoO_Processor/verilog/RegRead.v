

//`define LOG_PHYS    $clog2(NUM_PHYS_REGS)

module RegRead#(
    parameter NUM_PHYS_REGS = 64 
)
(
	input 			CLK,
	input 			RESET,
	input [31:0]    	Instr_UID_in,
	input [31:0]    	Instr_in,
	input [31:0]		Instr_PC_in,
	input [31:0]    	Instr_PC_Plus4_in,
	input [22:0]		Instr_Flags_in,
        input [5:0]		rs_in,
	input [5:0]		rt_in,
	input [5:0]		rd_in,
	input			iq_empty,
	//input			select_Instr,
	input[5:0]              WriteRegister_fMM, // write back from mem
	input[31:0]             WriteData_fMM, // write back from mem
	input 			RegWrite_fMM, // write back from mem
	
	output  [31:0]    	Instr_UID_out,
	output  [31:0]	Instr1_out,
	output  [31:0]	Instr1_PC_out,
	output  [31:0]	OperandA1,
	output  [31:0]	OperandB1,
	output  [5:0]	ReadRegisterA1,
	output  [5:0]	ReadRegisterB1,
	output  [5:0]	WriteRegister_tMM, // data to memory
	output  [31:0]	MemWriteData_tMM, // data to memory
	output  		RegWrite_tMM, // signal to memory
	output  [5:0]	ALU_Control,
	output  		MemRead,
	output  		MemWrite,
	output  [4:0]	ShiftAmount,
	output 		br_taken,
	output  [31:0]	Alt_PC_Br,
	output 		read_done_RR

    /* Write Me */

    );



	//Flag wires 
	wire [5:0]		ALU_control1;
	wire			link1;
	wire			RegDst1;
	wire			jump1;
	wire			branch1;
	wire			MemRead1;
	wire			MemWrite1;
// if it has an immediate value ** not used dunno why
	/* verilator lint_off UNUSED */ 
	wire			ALUSrc1; 
	wire			RegWrite1_tMM; // flag to memory
	wire			jumpRegister_Flag1;
	wire			sign_or_zero_Flag1;
	wire [4:0]     		shiftAmount1;
	wire [15:0]    		immediate1;
	wire [5:0]		WriteRegister1_tMM;	//Register to write memory
	wire [31:0]		MemWriteData1_tMM; //Data to write to memory
	wire [31:0]		OpA1;	//Operand A
	wire [31:0]		OpB1;	//Operand B
	wire			br_taken1;	//Do we want to branch/jump?
	wire [31:0]		Alt_PC_Br1;
	wire [31:0]    		signExtended_immediate1;
	wire [31:0]    		zeroExtended_immediate1;	 
	wire [5:0]		rs1;
	wire [5:0]		rt1;
	wire [31:0]		rsval1;
	wire [31:0]		rtval1;
	/* verilator lint_off UNUSED */
	wire [1:0]		MultRegAccess1;
	wire [31:0] 		rsval_jump1;


	wire[5:0]              WriteRegister1_fMM; // write back from mem
	wire[31:0]             WriteData1_fMM; // write back from mem
	wire 		       RegWrite1_fMM;
	/* verilator lint_off UNUSED */
	wire[31:0] 	       unsed_wire;

//sending all flags FORMAT : 
//MemRead1,MemWrite1,RegWrite1,
//ALU_Control1,ShiftAmount1,Instr_Flags(Link,RegDest,Jump,Branch,ALUSrc,JumpRegister,SignOrZero,MultRegAccess[1:0])

	assign rs1 = rs_in;
	assign rt1 = rt_in; 
	assign WriteRegister1_tMM = rd_in;

	assign MemRead1 = Instr_Flags_in[22];
	assign MemWrite1 = Instr_Flags_in[21];
	assign RegWrite1_tMM = Instr_Flags_in[20];
	assign ALU_control1 = Instr_Flags_in[19:14];
	assign shiftAmount1 = Instr_Flags_in[13:9];
	assign link1 = Instr_Flags_in[8];
	assign RegDst1 = Instr_Flags_in[7];
	assign jump1 = Instr_Flags_in[6];
	assign branch1 = Instr_Flags_in[5];
	assign ALUSrc1 = Instr_Flags_in[4];
	assign jumpRegister_Flag1 = Instr_Flags_in[3];
	assign sign_or_zero_Flag1 = Instr_Flags_in[2];
	assign MultRegAccess1 = Instr_Flags_in[1:0];

	assign immediate1 = Instr_in[15:0];
	assign signExtended_immediate1 = {{16{immediate1[15]}},immediate1};
	assign zeroExtended_immediate1 = {{16{1'b0}},immediate1};

	assign WriteRegister1_fMM = WriteRegister_fMM;
	assign WriteData1_fMM = WriteData_fMM;
	assign RegWrite1_fMM = RegWrite_fMM;

assign rsval_jump1 = rsval1;

NextInstructionCalculator NIA1 (
    .Instr_PC_Plus4(Instr_PC_Plus4_in),
    .Instruction(Instr_in), 
    .Jump(jump1), 
    .JumpRegister(jumpRegister_Flag1), 
    .RegisterValue(rsval_jump1), 
    .NextInstructionAddress(Alt_PC_Br1),
	 .Register(rs1)
    );

compare branch_compare1 (
    .Jump(jump1), 
    .OpA(OpA1),
    .OpB(OpB1),
    .Instr_input(Instr_in), 
    .taken(br_taken1)
    );

assign OpA1 = link1?0:rsval1;
assign OpB1 = branch1?(link1?(Instr_PC_Plus4_in+4):rtval1):(RegDst1?rtval1:(sign_or_zero_Flag1?signExtended_immediate1:zeroExtended_immediate1));

/* verilator lint_off PINMISSING */
	PhysRegFile  #(
		.NUM_PHYS_REGS(NUM_PHYS_REGS)
	)
	PhysRegFile(
		.CLK(CLK),
		.RESET(RESET),
		.RegSelect1(rs1), // read
		.RegSelect2(rt1), // read 
		.RegSelect3(WriteRegister1_tMM), // read
		.RegSelect4(WriteRegister1_fMM), // write back
		.WriteEnable1_IN(1'b0),
		.WriteEnable2_IN(1'b0),
		.WriteEnable3_IN(~RegWrite1_tMM),
		.WriteEnable4_IN(RegWrite1_fMM), // write back	
		.Data1_IN(32'h0000_0000),
		.Data2_IN(32'h0000_0000),
		.Data3_IN(32'h0000_0000),
		.Data4_IN(WriteData1_fMM),
		.Data1_OUT(rsval1),
		.Data2_OUT(rtval1),
		.Data3_OUT(MemWriteData1_tMM),
		.Data4_OUT(unsed_wire)
    );
/* verilator lint_on PINMISSING */
    
    /* Write Me */
	always @(posedge CLK or negedge RESET) begin
		if(!RESET) begin
			Instr_UID_out <= 0; 
			Instr1_out <= 0;
			Instr1_PC_out <= 0;
			OperandA1 <= 0;
			OperandB1 <= 0;
			ReadRegisterA1 <= 0;
			ReadRegisterB1 <= 0;
			WriteRegister_tMM <= 0;
			MemWriteData_tMM<= 0;
			RegWrite_tMM <= 0;
			ALU_Control <= 0;
			MemRead <= 0;
			MemWrite <= 0;
			ShiftAmount <= 0;
			br_taken <= 0;
			Alt_PC_Br <= 0;
			read_done_RR <= 0;
			$display("RegRead reset");
		end else begin
			if(!iq_empty) begin 
				Instr_UID_out <= Instr_UID_in;
				Instr1_out <= Instr_in;
				Instr1_PC_out <= Instr_PC_in;
				OperandA1 <= OpA1;
				OperandB1 <= OpB1;
				ReadRegisterA1 <= rs1;
				ReadRegisterB1 <= rt1;
				WriteRegister_tMM <= WriteRegister1_tMM;
				MemWriteData_tMM <= MemWriteData1_tMM;
				RegWrite_tMM <= RegWrite1_tMM;
				ALU_Control <= ALU_control1;
				MemRead <= MemRead1;
				MemWrite <= MemWrite1;
				ShiftAmount <= shiftAmount1;
				br_taken <= br_taken1;
				Alt_PC_Br <= Alt_PC_Br1;
				read_done_RR <= 1'b1;
				$display("RR: Instr_UID_out %d,Instr1_out %d, Instr1_PC_out %d, OperandA1 %d, OperandB1 %d, ReadRegisterA1 %d, ReadRegisterB1 %d, WriteRegister_tMM %d, MemWriteData_tMM %d, RegWrite_tMM %d, ALU_Control %d, MemRead %d, MemWrite %d, ShiftAmount %d, br_taken %d, Alt_PC_Br %d, read_done_RR %d",Instr_UID_out,Instr1_out, Instr1_PC_out, OperandA1, OperandB1, ReadRegisterA1, ReadRegisterB1, WriteRegister_tMM, MemWriteData_tMM, RegWrite_tMM, ALU_Control, MemRead, MemWrite, ShiftAmount, br_taken, Alt_PC_Br, read_done_RR);
			end else begin 
				$display("RegRead STALL : iq_empty %d",iq_empty);
			end 
		end
$display("***************************************************************");	
end
    
endmodule
