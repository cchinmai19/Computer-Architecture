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
    wire        STALL_IDIF;
    wire        Request_Alt_PC_IDIF;
    wire [31:0] Alt_PC_IDIF;
   
    
    
//Connecting wires between IC and IF
    wire [31:0] Instr_address_2IC/*verilator public*/;
    //Instr_address_2IC is verilator public so that sim_main can give accurate 
    //displays.
    //We could use Instr_address_2IM, but this way sim_main doesn't have to 
    //worry about whether or not a cache is present.
    wire [31:0] Instr1_fIC;
    wire        Instr1_ReadyfICache;
//Connecting wires between Memory and Cache
   // wire [31:0] Instr_addr_fIM;
  
    wire [31:0] Instr2_fIC;
    //assign Instr_address_2IM = {Instr_address_2IC[31:5], 5'b0};
    //assign Instr_address_2IC = Instr_address_2IM;
    //assign Instr1_fIC = Instr1_fIM;
    //assign Instr2_fIC = Instr2_fIM;
   // assign iBlkRead = 1'b1;
    /*verilator lint_off UNUSED*/
    wire [255:0] memblk_i;
    wire memblk_valid_i;
    /*verilator lint_on UNUSED*/
    assign memblk_i = block_read_fIM;
    assign Instr_addr_fIM = Instr_address_2IM;

  ICache IC(
	.CLK(CLK),
	.RESET(RESET),
	//.blk_read_valid(block_read_fIM_valid),
	.Instr_addr(Instr_address_2IC),
	.mem_block(memblk_i), //memory block currently read
	.iBlkread1(iBlkRead),
	.Instr_out(Instr1_fIC),
	.Instr_valid(Instr1_ReadyfICache),
	.mem_address(Instr_address_2IM)
	);


`ifdef SUPERSCALAR
`else
    /*verilator lint_off UNUSED*/
    wire [31:0] unused_i3;
    /*verilator lint_on UNUSED*/
    //assign unused_i3 = Instr2_fIC;
   // assign unused_i3 = Instr1_fIC;
`endif

    IF IF(
        .CLK(CLK),
        .RESET(RESET),
        .Instr1_OUT(Instr1_IFID),
        .Instr_PC_OUT(Instr_PC_IFID),
        .Instr_PC_Plus4(Instr_PC_Plus4_IFID),
        .STALL(STALL_IDIF),
        .Request_Alt_PC(Request_Alt_PC_IDIF),
        .Alt_PC(Alt_PC_IDIF),
        .Instr_address_2IM(Instr_address_2IC),
        .Instr1_fIM(Instr1_fIC),
	.ReadyfIF(Instr1_ReadyfICache),
	.Stall_fmem(Stall_mem)
    );
    

	wire [4:0]  WriteRegister1_MEMWB;
	wire [31:0] WriteData1_MEMWB;
	wire        RegWrite1_MEMWB;

	wire [31:0] Instr1_IDEXE;
	wire [31:0] Instr1_PC_IDEXE;
	wire [31:0] OperandA1_IDEXE;
	wire [31:0] OperandB1_IDEXE;
`ifdef HAS_FORWARDING
    wire [4:0]  RegisterA1_IDEXE;
    wire [4:0]  RegisterB1_IDEXE;
`endif
    wire [4:0]  WriteRegister1_IDEXE;
    wire [31:0] MemWriteData1_IDEXE;
    wire        RegWrite1_IDEXE;
    wire [5:0]  ALU_Control1_IDEXE;
    wire        MemRead1_IDEXE;
    wire        MemWrite1_IDEXE;
    wire [4:0]  ShiftAmount1_IDEXE;
    
`ifdef HAS_FORWARDING
    wire [4:0]  BypassReg1_EXEID;
    wire [31:0] BypassData1_EXEID;
    wire        BypassValid1_EXEID;
    
    wire [4:0]  BypassReg1_MEMID;
    wire [31:0] BypassData1_MEMID;
    wire        BypassValid1_MEMID;
`endif
    
	
	ID ID(
		.CLK(CLK),
		.RESET(RESET),
		.Instr1_IN(Instr1_IFID),
		.Instr_PC_IN(Instr_PC_IFID),
		.Instr_PC_Plus4_IN(Instr_PC_Plus4_IFID),
		.WriteRegister1_IN(WriteRegister1_MEMWB),
		.WriteData1_IN(WriteData1_MEMWB),
		.RegWrite1_IN(RegWrite1_MEMWB),
		.Alt_PC(Alt_PC_IDIF),
		.Request_Alt_PC(Request_Alt_PC_IDIF),
		.Instr1_OUT(Instr1_IDEXE),
        .Instr1_PC_OUT(Instr1_PC_IDEXE),
		.OperandA1_OUT(OperandA1_IDEXE),
		.OperandB1_OUT(OperandB1_IDEXE),
`ifdef HAS_FORWARDING
		.ReadRegisterA1_OUT(RegisterA1_IDEXE),
		.ReadRegisterB1_OUT(RegisterB1_IDEXE),
`else
/* verilator lint_off PINCONNECTEMPTY */
        .ReadRegisterA1_OUT(),
        .ReadRegisterB1_OUT(),
/* verilator lint_on PINCONNECTEMPTY */
`endif
		.WriteRegister1_OUT(WriteRegister1_IDEXE),
		.MemWriteData1_OUT(MemWriteData1_IDEXE),
		.RegWrite1_OUT(RegWrite1_IDEXE),
		.ALU_Control1_OUT(ALU_Control1_IDEXE),
		.MemRead1_OUT(MemRead1_IDEXE),
		.MemWrite1_OUT(MemWrite1_IDEXE),
		.ShiftAmount1_OUT(ShiftAmount1_IDEXE),
`ifdef HAS_FORWARDING
		.BypassReg1_EXEID(BypassReg1_EXEID),
		.BypassData1_EXEID(BypassData1_EXEID),
		.BypassValid1_EXEID(BypassValid1_EXEID),
		.BypassReg1_MEMID(BypassReg1_MEMID),
		.BypassData1_MEMID(BypassData1_MEMID),
		.BypassValid1_MEMID(BypassValid1_MEMID),
`endif
		.SYS(SYS),
		.WANT_FREEZE(STALL_IDIF),
		.ReadyfID(Instr1_ReadyfICache),
		.Stall_fmem(Stall_mem)
	);
	
	wire [31:0] Instr1_EXEMEM;
	wire [31:0] Instr1_PC_EXEMEM;
	wire [31:0] ALU_result1_EXEMEM;
    wire [4:0]  WriteRegister1_EXEMEM;
    wire [31:0] MemWriteData1_EXEMEM;
    wire        RegWrite1_EXEMEM;
    wire [5:0]  ALU_Control1_EXEMEM;
    wire        MemRead1_EXEMEM;
    wire        MemWrite1_EXEMEM;
`ifdef HAS_FORWARDING
    wire [31:0] ALU_result_async1;
    wire        ALU_result_async_valid1;
`endif
	
	EXE EXE(
		.CLK(CLK),
		.RESET(RESET),
		.Instr1_IN(Instr1_IDEXE),
		.Instr1_PC_IN(Instr1_PC_IDEXE),
`ifdef HAS_FORWARDING
		.RegisterA1_IN(RegisterA1_IDEXE),
`endif
		.OperandA1_IN(OperandA1_IDEXE),
`ifdef HAS_FORWARDING
		.RegisterB1_IN(RegisterB1_IDEXE),
`endif
		.OperandB1_IN(OperandB1_IDEXE),
		.WriteRegister1_IN(WriteRegister1_IDEXE),
		.MemWriteData1_IN(MemWriteData1_IDEXE),
		.RegWrite1_IN(RegWrite1_IDEXE),
		.ALU_Control1_IN(ALU_Control1_IDEXE),
		.MemRead1_IN(MemRead1_IDEXE),
		.MemWrite1_IN(MemWrite1_IDEXE),
		.ShiftAmount1_IN(ShiftAmount1_IDEXE),
		.Instr1_OUT(Instr1_EXEMEM),
		.Instr1_PC_OUT(Instr1_PC_EXEMEM),
		.ALU_result1_OUT(ALU_result1_EXEMEM),
		.WriteRegister1_OUT(WriteRegister1_EXEMEM),
		.MemWriteData1_OUT(MemWriteData1_EXEMEM),
		.RegWrite1_OUT(RegWrite1_EXEMEM),
		.ALU_Control1_OUT(ALU_Control1_EXEMEM),
		.MemRead1_OUT(MemRead1_EXEMEM),
		.MemWrite1_OUT(MemWrite1_EXEMEM)
`ifdef HAS_FORWARDING
		,
		.BypassReg1_MEMEXE(WriteRegister1_MEMWB),
		.BypassData1_MEMEXE(WriteData1_MEMWB),
		.BypassValid1_MEMEXE(RegWrite1_MEMWB),
		.ALU_result_async1(ALU_result_async1),
		.ALU_result_async_valid1(ALU_result_async_valid1),
`endif
		.ReadyfEXE(Instr1_ReadyfICache),
		.Stall_fmem(Stall_mem)
	);
	
`ifdef HAS_FORWARDING
    assign BypassReg1_EXEID = WriteRegister1_IDEXE;
    assign BypassData1_EXEID = ALU_result_async1;
    assign BypassValid1_EXEID = ALU_result_async_valid1;
`endif
     
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
    wire      Stall_mem;

    DCache DC(
	.CLK(CLK),
	.RESET(RESET),
	.read(read_2DC), //load
	.write(write_2DC), //store
	.data_address(data_address_2DC), //address of dat
	.writeSize(data_write_size_2DC),
	.WriteData(data_write_2DC), //store word
	.dataRead_blk(block_read_fDM),
	.blkRead(dBlkRead),
	.blkWrite(dBlkWrite),
	.data_memaddr(data_address_2DM),
	.ReadData(data_read_fDC),
	.dataWrite_blk(block_write_2DM),
	.Stall(Stall_mem)
	);	

    //assign data_write_2DM = data_write_2DC;
    //assign data_address_2DM = data_address_2DC;
    //assign data_write_size_2DM = data_write_size_2DC;
    //assign data_read_fDC = data_read_fDM;
   // assign MemRead_2DM = read_2DC;
   // assign MemWrite_2DM = write_2DC;


//TO GET RID OF WARNINGS
   assign data_valid_fDC = 1'b1;
    assign MemRead_2DM = 1'b0;
    assign MemWrite_2DM = 1'b0;
    assign data_write_2DM = 32'd0;
    assign data_write_size_2DM = 2'b0;

    //assign dBlkRead = 1'b0;
    ///assign dBlkWrite = 1'b0;
    //assign block_write_2DM = block_read_fDM;
    /*verilator lint_off UNUSED*/
    wire unused_d1;
    wire unused_d2;
    /*verilator lint_on UNUSED*/
    assign unused_d1 = block_read_fDM_valid;
    assign unused_d2 = block_write_fDM_valid;
     
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
        .MemWrite_2DM(write_2DC),
	`ifdef HAS_FORWARDING
        
        .WriteData1_async(BypassData1_MEMID),
	
`endif
	.ReadyfMEM(Instr1_ReadyfICache),
	.Stall_mem(Stall_mem)

    );
     
`ifdef HAS_FORWARDING
    assign BypassReg1_MEMID = WriteRegister1_EXEMEM;
    assign BypassValid1_MEMID = RegWrite1_EXEMEM && !Stall_mem;
`endif

/*always@(posedge CLK)begin 
	$display("******SENT FROM EXE*******");
	$display("Instr1_EXEMEM %x Instr1_PC_EXEMEM %x",Instr1_EXEMEM,Instr1_PC_EXEMEM);
	$display("ALU_result1_EXEMEM %x",ALU_result1_EXEMEM);
	$display("WriteRegister1_EXEMEM %x MemWriteData1_EXEMEM %x",WriteRegister1_EXEMEM, MemWriteData1_EXEMEM);
	$display("RegWrite1_EXEMEM %x ALU_Control1_EXEMEM %x",RegWrite1_EXEMEM, ALU_Control1_EXEMEM);
	$display("MemRead1_EXEMEM %x MemWrite1_EXEMEM %x",MemRead1_EXEMEM,MemWrite1_EXEMEM);
	$display("*******EXE DISPLAY END********");
	$display("***WHAT MEMORY WANTS***");
	$display("Memory wants to read or write: read_2DC %x write_2DC %x",read_2DC,write_2DC);
	$display("Memory wants data from address: data_address_2DC %x",data_address_2DC);
	$display("Memory wants to write data data_write_2DC:%x of size data_write_size_2DC:%x",data_write_2DC,data_write_size_2DC);
	$display("BUS block_read_fDM: %x",block_read_fDM);
	$display("BUS block_write_2DM: %x",block_write_2DM);
	$display("******************************");
	
end*/

endmodule
