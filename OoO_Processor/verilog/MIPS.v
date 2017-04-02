`include "config.v"
//-----------------------------------------
//            Pipelined MIPS
//-----------------------------------------
module MIPS (

    input RESET,
    input CLK,
    
    //The physical memory address we want to interact with
    output [31:0] data_address_2DM,
    //We want to perform a read?
    output MemRead_2DM,
    //We want to perform a write?
    output MemWrite_2DM,
    
    //Data being read
    input [31:0] data_read_fDM,
    //Data being written
    output [31:0] data_write_2DM,
    //How many bytes to write:
        // 1 byte: 1
        // 2 bytes: 2
        // 3 bytes: 3
        // 4 bytes: 0
    output [1:0] data_write_size_2DM,
    
    //Data being read
    input [255:0] block_read_fDM,
    //Data being written
    output [255:0] block_write_2DM,
    //Request a block read
    output dBlkRead,
    //Request a block write
    output dBlkWrite,
    //Block read is successful (meets timing requirements)
    input block_read_fDM_valid,
    //Block write is successful
    input block_write_fDM_valid,
    
    //Instruction to fetch
    output [31:0] Instr_address_2IM,
    //Instruction fetched at Instr_address_2IM    
    input [31:0] Instr1_fIM,
    //Instruction fetched at Instr_address_2IM+4 (if you want superscalar)
    input [31:0] Instr2_fIM,

    //Cache block of instructions fetched
    input [255:0] block_read_fIM,
    //Block read is successfull
    input block_read_fIM_valid,
    //Request a block read
    output iBlkRead,
    
    //Tell the simulator that everything's ready to go to process a syscall.
    //Make sure that all register data is flushed to the register file, and that 
    //all data cache lines are flushed and invalidated.
    output SYS
    );
    

//Connecting wires between IF and ID
    wire [31:0] Instr1_IFID;
    wire [31:0] Instr_PC_IFID;
    wire [31:0] Instr_PC_Plus4_IFID;
`ifdef USE_ICACHE
    wire        Instr1_Available_IFID;
`endif
/* verilator lint_off UNUSED */
    wire        STALL_IDIF;
/* verilator lint_off UNDRIVEN */
    wire        Request_Alt_PC_IDRC;
/* verilator lint_off UNDRIVEN */
    wire [31:0] Alt_PC_IDRC;
    wire 	STALL_fMEM;    
    
//Connecting wires between IC and IF
    wire [31:0] Instr_address_2IC/*verilator public*/;
    //Instr_address_2IC is verilator public so that sim_main can give accurate 
    //displays.
    //We could use Instr_address_2IM, but this way sim_main doesn't have to 
    //worry about whether or not a cache is present.
    wire [31:0] Instr1_fIC;
`ifdef USE_ICACHE
    wire        Instr1_fIC_IsValid;
`endif
    wire [31:0] Instr2_fIC;
`ifdef USE_ICACHE
    wire        Instr2_fIC_IsValid;
    Cache #(
    .CACHENAME("I$1")
    ) ICache(
        .CLK(CLK),
        .RESET(RESET),
        .Read1(1'b1),
        .Write1(1'b0),
        .Flush1(1'b0),
        .Address1(Instr_address_2IC),
        .WriteData1(32'd0),
        .WriteSize1(2'd0),
        .ReadData1(Instr1_fIC),
        .OperationAccepted1(Instr1_fIC_IsValid),
`ifdef SUPERSCALAR
        .ReadData2(Instr2_fIC),
        .DataValid2(Instr2_fIC_IsValid),
`endif
        .read_2DM(iBlkRead),
/* verilator lint_off PINCONNECTEMPTY */
        .write_2DM(),
/* verilator lint_on PINCONNECTEMPTY */
        .address_2DM(Instr_address_2IM),
/* verilator lint_off PINCONNECTEMPTY */
        .data_2DM(),
/* verilator lint_on PINCONNECTEMPTY */
        .data_fDM(block_read_fIM),
        .dm_operation_accepted(block_read_fIM_valid)
    );
    /*verilator lint_off UNUSED*/
    wire [31:0] unused_i1;
    wire [31:0] unused_i2;
    /*verilator lint_on UNUSED*/
    assign unused_i1 = Instr1_fIM;
    assign unused_i2 = Instr2_fIM;
`ifdef SUPERSCALAR
`else
    assign Instr2_fIC = 32'd0;
    assign Instr2_fIC_IsValid = 1'b0;
`endif
`else
    assign Instr_address_2IM = Instr_address_2IC;
    assign Instr1_fIC = Instr1_fIM;
    assign Instr2_fIC = Instr2_fIM;
    assign iBlkRead = 1'b0;
    /*verilator lint_off UNUSED*/
    wire [255:0] unused_i1;
    wire unused_i2;
    /*verilator lint_on UNUSED*/
    assign unused_i1 = block_read_fIM;
    assign unused_i2 = block_read_fIM_valid;
`endif
`ifdef SUPERSCALAR
`else
    /*verilator lint_off UNUSED*/
    wire [31:0] unused_i3;
`ifdef USE_ICACHE
    wire unused_i4;
`endif
    /*verilator lint_on UNUSED*/
    assign unused_i3 = Instr2_fIC;
`ifdef USE_ICACHE
    assign unused_i4 = Instr2_fIC_IsValid;
`endif
`endif

    IF IF(
        .CLK(CLK),
        .RESET(RESET),
        .Instr1_OUT(Instr1_IFID),
        .Instr_PC_OUT(Instr_PC_IFID),
        .Instr_PC_Plus4(Instr_PC_Plus4_IFID),
`ifdef USE_ICACHE
        .Instr1_Available(Instr1_Available_IFID),
`endif
`ifdef IDQ
        .STALL(IDQ_FULL),
`else
        .STALL(STALL_IDIF),
`endif
        .Request_Alt_PC(Request_Alt_PC_IDRC), // ** from retire and commit
        .Alt_PC(Alt_PC_IDRC), // ** from retire and commit
        .Instr_address_2IM(Instr_address_2IC),

`ifdef USE_ICACHE
        .Instr1_fIM(Instr1_fIC),
        .Instr1_fIM_IsValid(Instr1_fIC_IsValid)
`endif
    );

    
`ifdef IDQ
	wire IDQ_RESET;
		//assign IDQ_RESET = RESET || Request_Alt_PC_IDIF;// CH 
		assign IDQ_RESET = RESET;
	wire IDQ_NQ;
		assign IDQ_NQ = Instr1_Available_IFID;

	wire IDQ_DQ;
	//	assign IDQ_DQ = !(IDQ_EMPTY || STALL_IDIF); // Feed ID an instruction when it doesn't want to stall

	wire IDQ_FLUSH;
		assign IDQ_FLUSH = Request_Alt_PC_IDRC;
	wire IDQ_RECOVER;
		assign IDQ_RECOVER = 0;

		wire [95:0] IDQ_DATA_IN;
		wire [31:0] IDQ_DATA_IN_INSTR;
		wire [31:0] IDQ_DATA_IN_PC;
		wire [31:0] IDQ_DATA_IN_PCPLUS4;
		assign IDQ_DATA_IN = {IDQ_DATA_IN_INSTR, IDQ_DATA_IN_PC, IDQ_DATA_IN_PCPLUS4};
		assign IDQ_DATA_IN_INSTR = Instr1_IFID;
		assign IDQ_DATA_IN_PC = Instr_PC_IFID;
		assign IDQ_DATA_IN_PCPLUS4 = Instr_PC_Plus4_IFID;

	wire [95:0] IDQ_DATA_OUT;
		wire [31:0] IDQ_DATA_OUT_INSTR;
		wire [31:0] IDQ_DATA_OUT_PC;
		wire [31:0] IDQ_DATA_OUT_PCPLUS4;
		assign IDQ_DATA_OUT_INSTR = IDQ_DATA_OUT[3*32-1 -: 32];
		assign IDQ_DATA_OUT_PC = IDQ_DATA_OUT[2*32-1 -: 32];
		assign IDQ_DATA_OUT_PCPLUS4 = IDQ_DATA_OUT[1*32-1 -: 32];

	wire IDQ_EMPTY;
	wire IDQ_FULL;


	simpleFIFO #(
		.ID("IDQUEUE"),
		.SLOTS(8),
		.DATA_WIDTH(96)
	)IDQ(
	.CLK(CLK),
	.RESET(IDQ_RESET),
	.NQ(IDQ_NQ),
	.DQ(IDQ_DQ),
	.EMPTY_OUT(IDQ_EMPTY),
	.FULL_OUT(IDQ_FULL),
	.Q_IN(IDQ_DATA_IN),
	.Q_OUT(IDQ_DATA_OUT),
	.FLUSH_IN(IDQ_FLUSH),
	.RECOVER(IDQ_RECOVER)

	);

`endif

// wires to connect ID and Rename Queue

    wire [31:0] Instr1_IDRNM;
    wire [31:0] Instr1_PC_IDRNM;
    wire [4:0]  WriteRegister1_IDRNM;
    wire        RegWrite1_IDRNM;
    wire [5:0]  ALU_Control1_IDRNM;
    wire        MemRead1_IDRNM;
    wire        MemWrite1_IDRNM;
    wire [4:0]  ShiftAmount1_IDRNM;
    wire [4:0]  RegisterA1_IDRNM;
    wire [4:0]  RegisterB1_IDRNM;
    wire [31:0]	Instr_PC_Plus4_OUT_IDRNM;
    wire [8:0]	Instr_Flags_IDRNM;

	ID ID(
		.CLK(CLK),
		.RESET(RESET),
`ifdef IDQ
		.Instr1_IN(IDQ_DATA_OUT_INSTR),
		.Instr_PC_IN(IDQ_DATA_OUT_PC),
		.Instr_PC_Plus4_IN(IDQ_DATA_OUT_PCPLUS4),
		.DQ_empty(IDQ_EMPTY),
		.RNMQ_full(RNM_FULL),
`else
		.Instr1_IN(Instr1_IFID),
		.Instr_PC_IN(Instr_PC_IFID),
		.Instr_PC_Plus4_IN(Instr_PC_Plus4_IFID),
`endif
		.Instr1_OUT(Instr1_IDRNM),
        	.Instr1_PC_OUT(Instr1_PC_IDRNM),
		.ReadRegisterA1_OUT(RegisterA1_IDRNM),
		.ReadRegisterB1_OUT(RegisterB1_IDRNM),
		.WriteRegister1_OUT(WriteRegister1_IDRNM),
		.RegWrite1_OUT(RegWrite1_IDRNM),
		.ALU_Control1_OUT(ALU_Control1_IDRNM),
		.MemRead1_OUT(MemRead1_IDRNM),
		.MemWrite1_OUT(MemWrite1_IDRNM),
		.ShiftAmount1_OUT(ShiftAmount1_IDRNM),
		.SYS(SYS),
		.WANT_FREEZE(STALL_IDIF),
		.Instr_PC_Plus4_OUT(Instr_PC_Plus4_OUT_IDRNM),
		.Instr_Flags(Instr_Flags_IDRNM),
		.RNMQ_NQ(RNM_NQ),
		.IDQ_DQ(IDQ_DQ)
	);
/*sending all flags FORMAT : 
  Link,RegDest,Jump,Branch,ALUSrc(if value is immediate),
  JumpRegister,SignOrZero,MultRegAccess[1:0]	*/


// Fill the Rename Queue with 
	wire RNM_NQ;
	wire RNM_DQ;
	wire RNM_EMPTY;
	wire RNM_FULL;
	wire [133:0] RNM_DATA_IN;
	wire [133:0] RNM_DATA_OUT;
	wire RNM_FLUSH ;
	wire RNM_RECOVER;
 
assign RNM_FLUSH = 0;
assign RNM_RECOVER = 0;
assign RNM_DATA_IN ={Instr1_IDRNM,Instr1_PC_IDRNM,Instr_PC_Plus4_OUT_IDRNM,
		RegisterA1_IDRNM,RegisterB1_IDRNM,WriteRegister1_IDRNM,
		MemRead1_IDRNM,MemWrite1_IDRNM,RegWrite1_IDRNM,
		ALU_Control1_IDRNM,ShiftAmount1_IDRNM,Instr_Flags_IDRNM};

`ifdef RNMQ
	simpleFIFO #(
		.ID("RENAME_QUEUE"),
		.SLOTS(8),
		.DATA_WIDTH(134)
	)RNMQ(
	.CLK(CLK),
	.RESET(RESET),
	.NQ(RNM_NQ),
	.DQ(RNM_DQ),
	.EMPTY_OUT(RNM_EMPTY),
	.FULL_OUT(RNM_FULL),
	.Q_IN(RNM_DATA_IN),
	.Q_OUT(RNM_DATA_OUT),
	.FLUSH_IN(RNM_FLUSH),
	.RECOVER(RNM_RECOVER)

	);

	
`endif 

// wires connecting between RNMQ and Rename_Stage
`ifdef RNMQ
	wire [31:0] Instr1_fRNMQ;
	wire [31:0] Instr1_PC_fRNMQ;
	wire [31:0] Instr1_PC_Plus4_fRNMQ;
    	wire [4:0]  RS_fRNMQ;
        wire [4:0]  RT_fRNMQ;
	wire [4:0]  RD_fRNMQ;
	wire [22:0] Instr_Flags_RNM;
	wire is_ld_st;

	assign Instr1_fRNMQ = RNM_DATA_OUT[133:102];
	assign Instr1_PC_fRNMQ = RNM_DATA_OUT[101:70];
	assign Instr1_PC_Plus4_fRNMQ = RNM_DATA_OUT[69:38];
	assign RS_fRNMQ = RNM_DATA_OUT[37:33];
	assign RT_fRNMQ = RNM_DATA_OUT[32:28];
	assign RD_fRNMQ = RNM_DATA_OUT[27:23];
	assign Instr_Flags_RNM = RNM_DATA_OUT[22:0];
	assign is_ld_st	= RNM_DATA_OUT[24] | RNM_DATA_OUT[25];

`endif
//sending all flags FORMAT : 
//MemRead1,MemWrite1,RegWrite1,
//ALU_Control1,ShiftAmount1,Instr_Flags(Link,RegDest,Jump,Branch,ALUSrc,JumpRegister,SignOrZero,MultRegAccess[1:0])

`ifdef RNMQ
//wires to connect with LD/STQ, ROB, IQ

	wire LDST_NQ;
//	wire LDST_DQ;
	/* verilator lint_off UNUSED */
	wire LDST_EMPTY;
	wire LDST_FULL;
	wire [`LEN_MEM_ENTRY-1:0] LDST_DATA_IN;
	/* verilator lint_off UNUSED */
	wire [133:0] LDST_DATA_OUT;
	wire LDST_FLUSH ;
	wire LDST_RECOVER;

assign LDST_FLUSH = 0;
assign LDST_RECOVER = 0;
//assign LDST_DQ = 1; 

	wire ROB_NQ;
//	wire ROB_DQ;
	/* veilator lint_off UNUSED */
	wire ROB_EMPTY;
	wire ROB_FULL;
	wire [`LEN_RC_ENTRY-1:0] ROB_DATA_IN;
	/* verilator lint_off UNUSED */
//	wire [113:0] ROB_DATA_OUT;
//	wire ROB_FLUSH ;
//	wire ROB_RECOVER;

//assign ROB_FLUSH = 0;
//assign ROB_RECOVER = 0;
//assign ROB_DQ = 1;

// wires to IQ from Rename stage 
wire [156:0]    IQ_DATA_fRNM;
wire [5:0]	PHY_RS_fRNM;
wire		rs_ready_fRNM;
wire [5:0]	PHY_RT_fRNM;
wire		rt_ready_fRNM;
wire		insert_IQ_fRNM; // from rename_stage
wire		IQ_full_IQtRNM;

//wires from EXE to Rename
//wire 		reset_Busybit_fEXE; 
//wire [5:0]	Phy_RegDst_fEXE;

//assign reset_Busybit_fEXE = 1'b0;
//assign Phy_RegDst_fEXE = 6'b000000;

Rename Rename(
		.CLK(CLK),
		.RESET(RESET),
		.RNMQ_empty(RNM_EMPTY),
		.Instr_IN(Instr1_fRNMQ),
		.Instr_PC(Instr1_PC_fRNMQ),
		.Instr_PC_Plus4_IN(Instr1_PC_Plus4_fRNMQ),
        	.RS(RS_fRNMQ),
		.RT(RT_fRNMQ),
		.RD(RD_fRNMQ),
		.is_LDST(is_ld_st),
		.Instr_Flags(Instr_Flags_RNM),
		.IQ_full(IQ_full_IQtRNM),
		.LDST_Q_full(LDST_FULL),
		.ROB_full(ROB_FULL),
		.reset_Busybit(RegWrite1_EXEMEM), // receive it after EXE
		.RegRecycle_IN(RRFL_RegRecycle),
		.RegRecycleID_IN( RRFL_RegRecycleID),
		.Phy_RegDst_EXE(WriteRegister1_EXEMEM), // receive it after EXE
		.LSQ_NQ(LDST_NQ),
		.ROB_NQ(ROB_NQ),
		.insert_IQ(insert_IQ_fRNM),
		.data_out_IQ(IQ_DATA_fRNM), 
		.data_out_LSQ(LDST_DATA_IN),
		.data_out_ROB(ROB_DATA_IN),
		.RNM_DQ(RNM_DQ),
		.Phy_RS_OUT(PHY_RS_fRNM),
		.rs_ready_out(rs_ready_fRNM),
		.Phy_RT_OUT(PHY_RT_fRNM),
		.rt_ready_out(rt_ready_fRNM));





//wires from RegRead
wire 	read_done_fRR;

//wires to RegRead
wire [31:0]     Instr_UID_IQtRR;
wire [31:0]    	Instr_IQtRR;
wire [31:0]	Instr_PC_IQtRR;
wire [31:0]    	Instr_PC_Plus4_IQtRR;
wire [22:0]	Instr_Flags_IQtRR;
wire [5:0]	PHY_RS_IQtRR;
wire [5:0]	PHY_RT_IQtRR;
wire [5:0]	PHY_RD_IQtRR;
wire		IQ_empty_IQtRR;
//wire		select_Instr_IQtRR;	

IQ
	Issue_Queue(
		.CLK(CLK),
		.RESET(RESET),
		.IQ_DATA_IN(IQ_DATA_fRNM),
        	.PHY_RS_IN(PHY_RS_fRNM),
		.rs_ready_in(rs_ready_fRNM),
		.PHY_RT_IN(PHY_RT_fRNM),
		.rt_ready_in(rt_ready_fRNM),
		.insert_IQ(insert_IQ_fRNM), // from rename_stage
		.read_done(read_done_fRR), // from readReg
		.common_bus(WriteRegister1_EXEMEM),// from EXE
		.Instr_UID_OUT(Instr_UID_IQtRR),
		.Instr_OUT(Instr_IQtRR),
		.Instr_PC_OUT(Instr_PC_IQtRR),
		.Instr_PC_Plus4_OUT(Instr_PC_Plus4_IQtRR),
		.Instr_Flags_OUT(Instr_Flags_IQtRR),
        	.PHY_RS_OUT(PHY_RS_IQtRR),
		.PHY_RT_OUT(PHY_RT_IQtRR),
		.PHY_RD_OUT(PHY_RD_IQtRR),
		.IQ_full(IQ_full_IQtRNM),
		.IQ_empty(IQ_empty_IQtRR)
		//.select_Instr(select_Instr_IQtRR)
);
`endif 

/* verilator lint_off UNUSED */
wire [31:0] Instr_UID_EXEMEM;
wire [31:0] Instr1_UID_RREXE;
wire [31:0] Instr1_RREXE;
wire [31:0] Instr1_PC_RREXE;
wire [31:0] OperandA1_RREXE;
wire [31:0] OperandB1_RREXE;
wire [5:0]  RegisterA1_RREXE;
wire [5:0]  RegisterB1_RREXE;
wire [5:0]  WriteRegister1_RREXE;
wire [31:0] MemWriteData1_RREXE;
wire        RegWrite1_RREXE;
wire [5:0]  ALU_Control1_RREXE;
wire        MemRead1_RREXE;
wire        MemWrite1_RREXE;
wire [4:0]  ShiftAmount1_RREXE;
wire [5:0]  WriteRegister1_MEMWB;
wire [31:0] WriteData1_MEMWB;
wire        RegWrite1_MEMWB;  
/* verilator lint_off UNUSED */ 
wire        br_taken_fRR; // should be sent to Commit along wit UID of Instr
/* verilator lint_off UNUSED */
wire [31:0] Alt_PC_Br_fRR; // should be send to Commit along with UID of Instr

`ifdef OUT_OF_ORDER
    RegRead RegRead(
	.CLK(CLK),
	.RESET(RESET),
	.Instr_UID_in(Instr_UID_IQtRR),
	.Instr_in(Instr_IQtRR),
	.Instr_PC_in(Instr_PC_IQtRR),
	.Instr_PC_Plus4_in(Instr_PC_Plus4_IQtRR),
	.Instr_Flags_in(Instr_Flags_IQtRR),
        .rs_in(PHY_RS_IQtRR),
	.rt_in(PHY_RT_IQtRR),
	.rd_in(PHY_RD_IQtRR),
	.iq_empty(IQ_empty_IQtRR),
	//.select_Instr(select_Instr_IQtRR),
	.WriteRegister_fMM(WriteRegister1_MEMWB), // write back from mem
	.WriteData_fMM(WriteData1_MEMWB), // write back from mem
	.RegWrite_fMM(RegWrite1_MEMWB), // write back from mem
	
	.Instr_UID_out(Instr1_UID_RREXE), // *** let lose 
	.Instr1_out(Instr1_RREXE),
	.Instr1_PC_out(Instr1_PC_RREXE),
	.OperandA1(OperandA1_RREXE),
	.OperandB1(OperandB1_RREXE),
	.ReadRegisterA1(RegisterA1_RREXE),
	.ReadRegisterB1(RegisterB1_RREXE),
	.WriteRegister_tMM(WriteRegister1_RREXE), // data to memory
	.MemWriteData_tMM(MemWriteData1_RREXE), // data to memory
	.RegWrite_tMM(RegWrite1_RREXE), // signal to memory
	.ALU_Control(ALU_Control1_RREXE),
	.MemRead(MemRead1_RREXE),
	.MemWrite(MemWrite1_RREXE),
	.ShiftAmount(ShiftAmount1_RREXE),
	.br_taken(br_taken_fRR), // *** let lose 
	.Alt_PC_Br(Alt_PC_Br_fRR), // *** let lose 
	.read_done_RR(read_done_fRR) 
    );
`endif

	
	wire [31:0] Instr1_EXEMEM;
	wire [31:0] Instr1_PC_EXEMEM;
	wire [31:0] ALU_result1_EXEMEM;
	wire [5:0]  WriteRegister1_EXEMEM;
	wire [31:0] MemWriteData1_EXEMEM;
	wire        RegWrite1_EXEMEM;
	wire [5:0]  ALU_Control1_EXEMEM;
	wire        MemRead1_EXEMEM;
	wire        MemWrite1_EXEMEM;

	EXE EXE(
		.CLK(CLK),
		.RESET(RESET),
`ifdef USE_DCACHE
		.STALL_fMEM(STALL_fMEM),
`endif
		.Instr_UIDfRR(Instr1_UID_RREXE),
		.read_complete(read_done_fRR),
		.Instr1_IN(Instr1_RREXE),
		.Instr1_PC_IN(Instr1_PC_RREXE),
`ifdef HAS_FORWARDING
		.RegisterA1_IN(RegisterA1_RREXE),
`endif
		.OperandA1_IN(OperandA1_RREXE),
`ifdef HAS_FORWARDING
		.RegisterB1_IN(RegisterB1_RREXE),
`endif
		.OperandB1_IN(OperandB1_RREXE),
		.WriteRegister1_IN(WriteRegister1_RREXE),
		.MemWriteData1_IN(MemWriteData1_RREXE),
		.RegWrite1_IN(RegWrite1_RREXE),
		.ALU_Control1_IN(ALU_Control1_RREXE),
		.MemRead1_IN(MemRead1_RREXE),
		.MemWrite1_IN(MemWrite1_RREXE),
		.ShiftAmount1_IN(ShiftAmount1_RREXE),
		.Instr1_OUT(Instr1_EXEMEM),
		.Instr1_PC_OUT(Instr1_PC_EXEMEM),
		.ALU_result1_OUT(ALU_result1_EXEMEM),
		.WriteRegister1_OUT(WriteRegister1_EXEMEM),
		.MemWriteData1_OUT(MemWriteData1_EXEMEM),
		.RegWrite1_OUT(RegWrite1_EXEMEM),
		.ALU_Control1_OUT(ALU_Control1_EXEMEM),
		.MemRead1_OUT(MemRead1_EXEMEM),
		.MemWrite1_OUT(MemWrite1_EXEMEM),
		.Instr_UIDfEXE(Instr_UID_EXEMEM) //** let lose
	);
	
     
    wire [31:0] data_write_2DC/*verilator public*/;
    wire [31:0] data_address_2DC/*verilator public*/;
    wire [1:0]  data_write_size_2DC/*verilator public*/;
    wire [31:0] data_read_fDC/*verilator public*/;
    wire        read_2DC/*verilator public*/;
    wire        write_2DC/*verilator public*/;
    //No caches, so:
    /* verilator lint_off UNUSED */
    wire        flush_2DC/*verilator public*/;
    /* verilator lint_on UNUSED */
    wire        data_valid_fDC /*verilator public*/;
`ifdef USE_DCACHE
    Cache #(
    .CACHENAME("D$1")
    ) DCache(
        .CLK(CLK),
        .RESET(RESET),
        .Read1(read_2DC),
        .Write1(write_2DC),
        .Flush1(flush_2DC),
        .Address1(data_address_2DC),
        .WriteData1(data_write_2DC),
        .WriteSize1(data_write_size_2DC),
        .ReadData1(data_read_fDC),
        .OperationAccepted1(data_valid_fDC),
`ifdef SUPERSCALAR
/* verilator lint_off PINCONNECTEMPTY */
        .ReadData2(),
        .DataValid2(),
/* verilator lint_on PINCONNECTEMPTY */
`endif
        .read_2DM(dBlkRead),
        .write_2DM(dBlkWrite),
        .address_2DM(data_address_2DM),
        .data_2DM(block_write_2DM),
        .data_fDM(block_read_fDM),
        .dm_operation_accepted((dBlkRead & block_read_fDM_valid) | (dBlkWrite & block_write_fDM_valid))
    );
    assign MemRead_2DM = 1'b0;
    assign MemWrite_2DM = 1'b0;
    assign data_write_2DM = 32'd0;
    assign data_write_size_2DM = 2'b0;
    /*verilator lint_off UNUSED*/
    wire [31:0] unused_d1;
    /*verilator lint_on UNUSED*/
    assign unused_d1 = data_read_fDM;
`else
    assign data_write_2DM = data_write_2DC;
    assign data_address_2DM = data_address_2DC;
    assign data_write_size_2DM = data_write_size_2DC;
    assign data_read_fDC = data_read_fDM;
    assign MemRead_2DM = read_2DC;
    assign MemWrite_2DM = write_2DC;
    assign data_valid_fDC = 1'b1;
     
    assign dBlkRead = 1'b0;
    assign dBlkWrite = 1'b0;
    assign block_write_2DM = block_read_fDM;
    /*verilator lint_off UNUSED*/
    wire unused_d1;
    wire unused_d2;
    /*verilator lint_on UNUSED*/
    assign unused_d1 = block_read_fDM_valid;
    assign unused_d2 = block_write_fDM_valid;
`endif
   /*  
    MEM MEM(
        .CLK(CLK),
        .RESET(RESET),
        .Instr1_IN(Instr1_EXEMEM),
        .Instr1_PC_IN(Instr1_PC_EXEMEM),
        .ALU_result1_IN(ALU_result1_EXEMEM),
        .WriteRegister1_IN(WriteRegister1_EXEMEM),
        .MemWriteData1_IN(MemWriteData1_EXEMEM),
        .RegWrite1_IN(RegWrite1_EXEMEM),
        .ALU_Control1_IN(ALU_Control1_EXEMEM),
        .MemRead1_IN(MemRead1_EXEMEM),
        .MemWrite1_IN(MemWrite1_EXEMEM),
        .WriteRegister1_OUT(WriteRegister1_MEMWB),
        .RegWrite1_OUT(RegWrite1_MEMWB),
        .WriteData1_OUT(WriteData1_MEMWB),
        .data_write_2DM(data_write_2DC),
        .data_address_2DM(data_address_2DC),
        .data_write_size_2DM(data_write_size_2DC),
        .data_read_fDM(data_read_fDC),
        .MemRead_2DM(read_2DC),
        .MemWrite_2DM(write_2DC)
`ifdef USE_DCACHE
        ,
        .MemFlush_2DM(flush_2DC),
        .data_valid_fDM(data_valid_fDC),
        .Mem_Needs_Stall(STALL_fMEM)
`endif
    );
     */

`ifdef OUT_OF_ORDER
    RetireCommit RetireCommit(

	.CLK(CLK),
	.RESET(RESET),
	
	//Connect these to branch calc/compare 
	.BranchTaken_IN(BranchTaken), // Set to 1 when a branch is taken
	.IsBranch_IN(IsBranch),	// Set to 1 when the instruction is a branch
	.BranchUID_IN(BranchUID), // Set to an instruction's UID when a branch is taken; 0 otherwise
	.BranchDest_IN(BranchPC), // Set to the branch destination when it is known
	
	// This should be a general flush/reset signal
	.Recover_OUT(RC_Recover),
	
	// connect this to the LSQ / OOOMEM stage 
	.LS_Retire_OUT(RCMEM_Retire),
	.LS_Retire_Ready_IN(MEMRC_Ready),

	// connect this to IF
	.IF_BranchPC_OUT(RCIF_AltPC),
	
	// Connect these to the free list / FRAT / rename stage 
	.ROB_full_OUT(ROB_FULL),
	.ROB_empty_OUT(ROB_EMPTY),
	.ROB_NQ(ROB_NQ),
	.Instruction_IN(ROB_DATA_IN),
	.RRAT_Dump_OUT(RRAT2FRAT),
	.RegRecycleID_OUT(RRFL_RegRecycleID), // ID of physical register to add back to free list
	.RegRecycle_OUT(RRFL_RegRecycle) // Request a register recycle
	
    );
	
	wire RCMEM_Retire;
	wire MEMRC_Ready;
	wire [31:0] RCIF_AltPC;
	wire RC_Recover;
	assign Request_Alt_PC_IDRC=RC_Recover;
	/* verilator lint_off UNUSED */
	wire [`RAT_BUSWIDTH-1:0] RRAT2FRAT; // TODO: Connect this to FRAT, free list
	/* verilator lint_on UNUSED */
	wire [`LOG_PHYS-1:0]RRFL_RegRecycleID; // TODO: Connect this to free list
	wire RRFL_RegRecycle; // TODO: Connect this to free list

	/* connect these between RC and branch resolver */
	wire BranchTaken;
	wire IsBranch;
	wire [`LEN_UID-1:0]BranchUID;
	wire [31:0]BranchPC;
	    assign Alt_PC_IDRC=RCIF_AltPC;
	
	
	
		OOOMEM OOOMEM(
			.CLK(CLK),
			.RESET(RESET),
			
			.PRegID_OUT(WriteRegister1_MEMWB), // The ID of the physical register we are writing
			.RegWriteEnable_OUT(RegWrite1_MEMWB), // Flag to enable register write
			.RegData_OUT(WriteData1_MEMWB), // Data to write to register
		 
			/* Connect these to the data memory/cache */
			.data_write_2DM(data_write_2DC),
			.data_address_2DM(data_address_2DC),
			.data_write_size_2DM(data_write_size_2DC),
			.data_read_fDM(data_read_fDC),

			.MemRead_2DM(read_2DC),
			.MemWrite_2DM(write_2DC),
			.MemFlush_2DM(flush_2DC),
			.data_valid_fDM(data_valid_fDC),

			
			/* connect these to the rename stage */
			.NQ_DATA_IN(LDST_DATA_IN), // All of the data from the Rename stage
			.NQ_IN(LDST_NQ),
			.Full_OUT(LDST_FULL),
			.Empty_OUT(LDST_EMPTY),

			/* connect this to the ROB/commit */
			.Ready_OUT(MEMRC_Ready), // 0: Waiting for current head to finish; 1: Ready to retire next load/store
			.Retire_IN(RCMEM_Retire),	// signals that the ROB is ready to retire the next L/S instruction

			/* connect these to the ALU */
			.ALU_ID1_IN(Instr_UID_EXEMEM),	// Instruction ID input (for ALU results, from EXE)
			.ALU_result1_IN(ALU_result1_EXEMEM),    //Output of ALU (contains address to access, or data enroute to writeback)
			.ALU_Control1_IN(ALU_Control1_EXEMEM),    //Output of ALU (contains address to access, or data enroute to writeback)
			
			/* connect these to the common data bus */
			.data_broadcast_IN(RegWrite1_EXEMEM),
			.reg_ID_broadcast_IN(WriteRegister1_EXEMEM),
			.reg_data_broadcast_IN(MemWriteData1_EXEMEM)
	);
	
`endif 
endmodule
