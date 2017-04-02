module IQ(
	input			CLK,
	input			RESET,
	input [156:0]       	IQ_DATA_IN,
        input [5:0]		PHY_RS_IN,
	input			rs_ready_in,
	input [5:0]		PHY_RT_IN,
	input			rt_ready_in,
	input			insert_IQ, // from rename_stage
	input			read_done, // from readReg
	input [5:0]		common_bus,
	output  [31:0]       Instr_UID_OUT,
	output  [31:0]    	Instr_OUT,
	output  [31:0]	Instr_PC_OUT,
	output  [31:0]    	Instr_PC_Plus4_OUT,
	output  [22:0]	Instr_Flags_OUT,
        output  [5:0]	PHY_RS_OUT,
	output  [5:0]	PHY_RT_OUT,
	output  [5:0]	PHY_RD_OUT,
	output 		IQ_full,
	output 		IQ_empty
	//output 		select_Instr
	);

	reg [15:0] 		free_slot;
	reg [15:0]		Instr_ready;
	reg [156:0]		IQ[15:0];
	reg [5:0]		IQ_RS [15:0];
	reg [5:0]		IQ_RT [15:0];
	reg [15:0]		IQ_rs_ready;
	reg [15:0]		IQ_rt_ready;
	/* verilator lint_off WIDTH */
        wire [3:0]		clog1;
	/* verilator lint_off WIDTH */
	wire [3:0]		clog2;
	reg [3:0]		IQ_slot_free;
	reg [3:0]		IQ_Instr_sel;

//select a free IQ_slot
assign clog1 = $clog2(free_slot & ((~free_slot)+1'b1));

//select an IQ_slot to dispatch
assign clog2 = $clog2(Instr_ready & ((~Instr_ready)+1'b1));

assign IQ_Instr_sel = clog2[3:0];

always @(posedge CLK  or negedge CLK or negedge RESET) begin
		if(!RESET) begin
		Instr_UID_OUT <= 0;
		Instr_OUT <= 0;
		Instr_PC_OUT <= 0;
		Instr_PC_Plus4_OUT <= 0;
		Instr_Flags_OUT <= 0;
		PHY_RS_OUT <=0;
		PHY_RT_OUT <= 0;
		PHY_RD_OUT <= 0;
		IQ_full <= 0;
		IQ_rt_ready <= 16'h0000;
		IQ_rs_ready <= 16'h0000;
		IQ_empty <= 0;
		//select_Instr <= 0;
		Instr_ready <= 16'h0000;
		IQ_slot_free <= 0;
		//IQ_Instr_sel <= 0;
		free_slot <= 16'hffff;
		$display("Issue Q:RESET"); 
		end else if(CLK)begin
			//$display("IQ: insert_IQ %d free_slot %b,IQ_slot_free %d",insert_IQ,free_slot,IQ_slot_free);
			//$display("IQ: read_done %d Instr_ready %b,IQ_Instr_sel %d",read_done,Instr_ready,IQ_Instr_sel);
			//$display("IQ_rt_ready %b IQ_rs_ready %b",IQ_rt_ready,IQ_rt_ready);
			if(insert_IQ)begin // when rename wants to insert
				$display("IQ: free_slot %b,IQ_slot_free %d",free_slot,IQ_slot_free);
				IQ_slot_free <= clog1[3:0];
				IQ[IQ_slot_free] <= IQ_DATA_IN;
				free_slot[IQ_slot_free] <= 1'b0;
				IQ_RS[IQ_slot_free][5:0] <= PHY_RS_IN;
				IQ_RT[IQ_slot_free][5:0] <= PHY_RT_IN;
				IQ_rs_ready[IQ_slot_free] <= rs_ready_in;
				IQ_rt_ready[IQ_slot_free] <= rt_ready_in;
				$display("IQ: Inserting into the Q");	
				$display("IQ[%d]= %x,IQ_RS=%d,IQ_RT= %d",IQ_slot_free,IQ[IQ_slot_free],IQ_RS[IQ_slot_free][5:0],IQ_RT[IQ_slot_free][5:0]);
				$display("IQ: IQ_rs_ready[%d]=%d,IQ_rt_ready[%d]=%d",IQ_slot_free,IQ_rs_ready[IQ_slot_free],IQ_slot_free,IQ_rt_ready[IQ_slot_free]);
				$display("Instr_ready[%d] = %b",IQ_slot_free,Instr_ready);	
			end 
			if(!read_done || ((!IQ_Instr_sel) && !(Instr_ready[0]))) begin
				$display("Cannot Select read_done %d IQ_Instr_sel %d Instr_ready[0]%d",read_done,IQ_Instr_sel,Instr_ready);
			end else begin 
				$display("IQ: read_done %d IQ_Instr_sel %d Instr_ready[0]%d Instr_ready%d ",read_done,IQ_Instr_sel,Instr_ready,Instr_ready);
				free_slot[IQ_Instr_sel] <= 1'b1; 
				Instr_UID_OUT <= IQ[IQ_Instr_sel][156:125];
			   	Instr_OUT <= IQ[IQ_Instr_sel][124:93];
				Instr_PC_OUT <= IQ[IQ_Instr_sel][92:61];
			   	Instr_PC_Plus4_OUT <= IQ[IQ_Instr_sel][60:29];
				Instr_Flags_OUT <= IQ[IQ_Instr_sel][28:6];
				PHY_RD_OUT <= IQ[IQ_Instr_sel][5:0];
        			PHY_RS_OUT <= IQ_RS[IQ_Instr_sel];
				PHY_RT_OUT <= IQ_RT[IQ_Instr_sel];
				IQ_full <= &free_slot; // none slots free
				IQ_empty <= ~|free_slot; // nonr slots full
				//select_Instr <= 1'b1;
				$display("IQ:sending Output");	
				$display("IQ: Instr_UID_OUT %x Instr_OUT %x Instr_PC_OUT %x Instr_PC_Plus4_OUT %x",Instr_UID_OUT,Instr_OUT,Instr_PC_OUT,Instr_PC_Plus4_OUT );	
				$display("Instr_Flags_OUT %x PHY_RD_OUT %d PHY_RS_OUT %d PHY_RT_OUT %d IQ_full %x",Instr_Flags_OUT,PHY_RD_OUT,PHY_RS_OUT,PHY_RT_OUT,IQ_full);		
			end
		end else if(!CLK) begin
			if(common_bus != 6'b000000) begin 
				for (int i=0; i < 16; i=i+1) begin
					IQ_rs_ready[i] <= IQ_rs_ready[i] | (IQ_RS[i] == common_bus);
					IQ_rt_ready[i] <= IQ_rt_ready[i] | (IQ_RT[i] == common_bus);
					Instr_ready[i] <= IQ_rs_ready[i] & IQ_rt_ready[i];
					$display("IQ_RS[%d]= %d IQ_RT[%d]= %d common_bus %d",i,IQ_RS[i],i,IQ_RT[i],common_bus);
				end
			end
			
		end	
$display("*************************************************************");
end
endmodule

	
