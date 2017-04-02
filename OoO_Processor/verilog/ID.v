`include "config.v"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:49:08 10/16/2013 
// Design Name: 
// Module Name:    ID2 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module ID(
    input CLK,
    input RESET,
//Instruction from Fetch
    input[31:0]Instr1_IN,
	 //PC of instruction fetched
    input[31:0]Instr_PC_IN,
    //PC+4 of instruction fetched (needed for various things)
    input[31:0]Instr_PC_Plus4_IN,
    // Check if DQ_empty
    input DQ_empty,
    // check if rename queue is full 
    input RNMQ_full,
    //Instruction being passed to EXE [debug]
     output reg [31:0]Instr1_OUT,
    //PC of instruction being passed to EXE [debug]
     output reg [31:0]Instr1_PC_OUT,
      //RegisterA passed to EXE
    output reg [4:0]ReadRegisterA1_OUT,
     //RegisterB passed to EXE
    output reg [4:0]ReadRegisterB1_OUT,
     //Destination Register passed to EXE
    output reg [4:0]WriteRegister1_OUT,
     //we'll be writing to a register... passed to EXE
    output reg RegWrite1_OUT, //flag**
    //ALU control passed to EXE
    output reg [5:0]ALU_Control1_OUT,//flag**
    //This is a memory read (passed to EXE)
    output reg MemRead1_OUT, //flag**
    //This is a memory write (passed to EXE)
    output reg MemWrite1_OUT,//flag**
    //Shift amount [for ALU functions] (passed to EXE)
    output reg [4:0]ShiftAmount1_OUT,
    
    //Tell the simulator to process a system call
    output reg SYS,
    //Tell fetch to stop advancing the PC, and wait.
    output WANT_FREEZE,
    // send the PC+4 for NIC in register read stage
    output reg [31:0] Instr_PC_Plus4_OUT,
    //sending all flags FORMAT : 
    //Link,RegDest,Jump,Branch,ALUSrc(if value is immediate),
    //JumpRegister,SignOrZero,MultRegAccess[1:0]
    output reg [8:0] Instr_Flags,
    output RNMQ_NQ,
    output IDQ_DQ
    );
	 
	 wire [5:0]	ALU_control1;	//async. ALU_Control output
	 wire			link1;			//whether this is a "And Link" instruction
	 wire			RegDst1;			//whether this instruction uses the "rd" register (Instr[15:11])
	 wire			jump1;			//whether we unconditionally jump
	 wire			branch1;			//whether we are branching
	 wire			MemRead1;		//whether this instruction is a load
	 wire			MemWrite1;		//whether this instruction is a store
	 /*verilator lint_off UNUSED */
	 //We don't need this now.
	 wire			ALUSrc1;			//whether this instruction uses an immediate
	 /*verilator lint_on UNUSED */
	 wire			RegWrite1;		//whether we want to write to a register with this instruction (do_writeback)
	 wire			jumpRegister_Flag1;	//this is a Jump Register function (also set for other functions; vestige of previous code)
	 wire			sign_or_zero_Flag1;	//If 1, we use sign-extended immediate; otherwise, 0-extended immediate.
	 wire [1:0] 		MultRegAccess1;
	 wire			syscal1;			//If this instruction is a syscall
	/* verilator lint_off UNUSED */ 
	wire		        comment1;
	 assign		        comment1 = 1;
	 
	 wire [4:0]		RegA1;		//Register A
	 wire [4:0]		RegB1;		//Register B
	 wire [4:0]		WriteRegister1;	//Register to write
	wire [4:0]              rs1;     //also format1
	wire [4:0]            rt1;
	wire [4:0]              rd1;
	wire [4:0]     		shiftAmount1;
	reg  [2:0]		syscall_bubble_counter;
	wire [31:0]		Instr_PC_Plus4_IN1;



	assign rs1 = Instr1_IN[25:21];
	assign rt1 = Instr1_IN[20:16];
	assign rd1 = Instr1_IN[15:11];
	assign shiftAmount1 = Instr1_IN[10:6];
	assign Instr_PC_Plus4_IN1 = Instr_PC_Plus4_IN;
	assign RegA1 = link1?5'b00000:rs1;
	assign RegB1 = RegDst1?rt1:5'd0;
 	assign WriteRegister1 = RegDst1?rd1:(link1?5'd31:rt1);
	 
	 reg FORCE_FREEZE;
	 reg INHIBIT_FREEZE;

assign WANT_FREEZE = ((FORCE_FREEZE | syscal1) && !INHIBIT_FREEZE);
	 

always @(posedge CLK or negedge RESET) begin
	if(!RESET) begin
	
		Instr1_OUT <= 0;
		ReadRegisterA1_OUT <= 0;
		ReadRegisterB1_OUT <= 0;
		WriteRegister1_OUT <= 0;
		RegWrite1_OUT <= 0;
		ALU_Control1_OUT <= 0;
		MemRead1_OUT <= 0;
		MemWrite1_OUT <= 0;
		ShiftAmount1_OUT <= 0;
		Instr1_PC_OUT <= 0;
		SYS <= 0;
		syscall_bubble_counter <= 0;
		FORCE_FREEZE <= 0;
		INHIBIT_FREEZE <= 0;
		Instr_PC_Plus4_OUT <= 0;
		Instr_Flags <= 0;
		RNMQ_NQ <= 0;
		IDQ_DQ <= 0;
	$display("ID:RESET");
	end else begin
			case (syscall_bubble_counter)
				5,4,3: begin
					//$display("ID:Decrement sbc");
					syscall_bubble_counter <= syscall_bubble_counter - 3'b1;
					end
				2: begin
					//$display("ID:Decrement sbc, , send sys");
					syscall_bubble_counter <= syscall_bubble_counter - 3'b1;
					SYS <= (ALU_control1 != 6'b101000) && (ALU_control1 != 6'b110110);  //We do a flush on LL/SC, but don't need to tell sim_main.
					INHIBIT_FREEZE <=1;
					end
				1: begin
					//$display("ID:Decrement sbc, inhibit freeze, clear sys");
					syscall_bubble_counter <= syscall_bubble_counter - 3'b1;
					SYS <= 0;
					INHIBIT_FREEZE <=0;
					end
				0: begin
					//$display("ID:reenable freezes");
					INHIBIT_FREEZE <=0;
					end
			endcase
			if(syscal1 && (syscall_bubble_counter==0)) begin
				//$display("ID:init SBC");
				syscall_bubble_counter <= 4;
			end
			//$display("sc1,sbc=%d",{syscal1,syscall_bubble_counter});
			case ({syscal1,syscall_bubble_counter})
				8,13,12,11,
				9,1: begin	//9 and 1 depend on multiple syscall in a row
					//$display("ID:send nop");
					Instr1_OUT <= (Instr1_IN==32'hc)?Instr1_IN:0; //We need to propagate the syscall to MEM to flush the cache!
					ReadRegisterA1_OUT <= 0;
					ReadRegisterB1_OUT <= 0;
					WriteRegister1_OUT <= 0;
					RegWrite1_OUT <= 0;
					ALU_Control1_OUT <= (Instr1_IN==32'hc)?ALU_control1:0;
					MemRead1_OUT <= 0;
					MemWrite1_OUT <= 0;
					ShiftAmount1_OUT <= 0;
					Instr_PC_Plus4_OUT <= 0;
		    			Instr_Flags <= 0;
					RNMQ_NQ <= 0;
					IDQ_DQ <= 0;
					end
				10,
				0: begin
					if(!DQ_empty && !RNMQ_full)begin  
					$display("ID:CheckQs-RNMQ_full=%d; RNMQ_full=%d",DQ_empty,RNMQ_full);		//$display("ID: send instr");
					    Instr1_OUT <= Instr1_IN;
					    ReadRegisterA1_OUT <= RegA1;
					    ReadRegisterB1_OUT <= RegB1;
					    WriteRegister1_OUT <= WriteRegister1;
					    RegWrite1_OUT <= (WriteRegister1!=5'd0)?RegWrite1:1'd0;
					    ALU_Control1_OUT <= ALU_control1;
					    MemRead1_OUT <= MemRead1;
					    MemWrite1_OUT <= MemWrite1;
					    ShiftAmount1_OUT <= shiftAmount1;
					    Instr1_PC_OUT <= Instr_PC_IN;
					    Instr_PC_Plus4_OUT <= Instr_PC_Plus4_IN1;
					    Instr_Flags <= {link1,RegDst1,jump1,branch1,ALUSrc1,jumpRegister_Flag1,sign_or_zero_Flag1,MultRegAccess1};
					    RNMQ_NQ <= 1;
					    IDQ_DQ <= 1;
					     $display("IDQ_DQ %d",IDQ_DQ);
					     $display("ID:Instr=%x,Instr_PC=%x",Instr1_IN,Instr_PC_IN);
					    $display("ID1:A:Reg[%d]; B:Reg[%d]; Write?%d to %d",RegA1, RegB1, (WriteRegister1!=5'd0)?RegWrite1:1'd0, WriteRegister1);
					$display("ID1:link1 %d,RegDst1 %d,jump1%d,branch1 %d,ALUSrc1 %d,jumpRegister_Flag1 %d,sign_or_zero_Flag1 %d,MultRegAccess1 %d",link1,RegDst1,jump1,branch1,ALUSrc1,jumpRegister_Flag1,sign_or_zero_Flag1,MultRegAccess1);
					    // $display("ID1: Instr_Flags: %x",Instr_Flags);
						end
					end
			endcase
			/*if (RegWrite_IN) begin
				Reg[WriteRegister_IN] <= WriteData_IN;
				$display("IDWB:Reg[%d]=%x",WriteRegister_IN,WriteData_IN);
			end*/
			/*if(comment1) begin
                $display("ID1:Instr=%x,Instr_PC=%x,SYS=%d(%d)",Instr1_IN,Instr_PC_IN,syscal1,syscall_bubble_counter);
                $display("ID1:A:Reg[%d]; B:Reg[%d]; Write?%d to %d",RegA1, RegB1, (WriteRegister1!=5'd0)?RegWrite1:1'd0, WriteRegister1);
                $display("ID1:ALU_Control=%x; MemRead=%d; MemWrite=%d ; ShiftAmount=%d",ALU_control1, MemRead1, MemWrite1,shiftAmount1);
			end*/
	end
$display("*************************************************************");
end
    Decoder #(
    .TAG("1")
    )
    Decoder1 (
    .Instr(Instr1_IN), 
    .Instr_PC(Instr_PC_IN), 
    .Link(link1), 
    .RegDest(RegDst1), //if dst reg present
    .Jump(jump1), //
    .Branch(branch1), //
    .MemRead(MemRead1), // load
    .MemWrite(MemWrite1), //store
    .ALUSrc(ALUSrc1), 
    .RegWrite(RegWrite1), 
    .JumpRegister(jumpRegister_Flag1), 
    .SignOrZero(sign_or_zero_Flag1), //for a value
    .Syscall(syscal1), 
    .ALUControl(ALU_control1),//opcode
/* verilator lint_off PINCONNECTEMPTY */
    .MultRegAccess(MultRegAccess1),   //Needed for out-of-order
/* verilator lint_on PINCONNECTEMPTY */
     .comment1(1'b1)
    );

endmodule
