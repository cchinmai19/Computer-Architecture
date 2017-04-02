// Currently has 4 ports

module PhysRegFile #(
    parameter NUM_PHYS_REGS = 64 
)
(
	input CLK,
	input RESET,

	input [REGLINES-1:0] RegSelect1,
	input [REGLINES-1:0] RegSelect2,
	input [REGLINES-1:0] RegSelect3,
	input [REGLINES-1:0] RegSelect4,

	input WriteEnable1_IN,
	input WriteEnable2_IN,
	input WriteEnable3_IN,
	input WriteEnable4_IN,

	input [31:0] Data1_IN,
	input [31:0] Data2_IN,
	input [31:0] Data3_IN,
	input [31:0] Data4_IN,

	output [31:0] Data1_OUT,
	output [31:0] Data2_OUT,
	output [31:0] Data3_OUT,
	output [31:0] Data4_OUT

    );
	localparam REGLINES = $clog2(NUM_PHYS_REGS);

	reg [31:0] PReg [NUM_PHYS_REGS-1:0] /*verilator public*/;

	always @(posedge CLK or negedge RESET) begin
		if(!RESET) begin
			$display("PhysReg reset");
			for (int i=0; i<NUM_PHYS_REGS; i=i+1) begin
				PReg[i]<=0;
			end
		end else begin
			$display("PhysReg Select,Write: [{%0d,%0d}, {%0d,%0d}, {%0d,%0d}, {%0d,%0d}]", RegSelect1, WriteEnable1_IN,RegSelect2, WriteEnable2_IN,RegSelect3, WriteEnable3_IN,RegSelect4,WriteEnable4_IN);
			for (int i=0; i<NUM_PHYS_REGS; i=i+1) begin
				if (WriteEnable1_IN) begin
					PReg[RegSelect1]<=Data1_IN;
				end
				if (WriteEnable2_IN) begin
					PReg[RegSelect2]<=Data2_IN;
				end
				if (WriteEnable3_IN) begin
					PReg[RegSelect3]<=Data3_IN;
				end
				if (WriteEnable4_IN) begin
					PReg[RegSelect4]<=Data4_IN;
				end
				Data1_OUT<=PReg[RegSelect1];
				Data2_OUT<=PReg[RegSelect2];
				Data3_OUT<=PReg[RegSelect3];
				Data4_OUT<=PReg[RegSelect4];
			end
		end
	end
    
endmodule
