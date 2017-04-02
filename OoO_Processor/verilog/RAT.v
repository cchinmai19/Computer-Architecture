`include "config.v"

/**************************************
* Module: RAT
* Author: (completed by Nate)
* Date: Dec 21, 2016	11:45 AM
* Description: Register Alias Table
***************************************/



module RAT #(
	/* 
	 * `NUM_ARCH_REGS is the number of architectural registers present in the 
	 * RAT. 
	 *
	 * sim_main assumes that the value of LO is stored in architectural 
	 * register 33, and that the value of HI is stored in architectural 
	 * register 34.
	 *
	 * It is left as an exercise to the student to explain why.
	 */
	parameter ID = "xRAT" // change this when instantiating as appropriate to distinguish between FRAT,RRAT
    /* Maybe Others? */
)
(
	input CLK,
	input RESET,
	input [`LOG_ARCH-1:0]AREG_IN,
	input [`LOG_PHYS-1:0]PREG_IN,
	input Rename_IN,
	input [`NUM_ARCH_REGS*`LOG_PHYS-1:0]Bulk_IN,
	output [`NUM_ARCH_REGS*`LOG_PHYS-1:0]Bulk_OUT,
	input BulkRead_IN,
	output [`LOG_PHYS-1:0]RegRecycleID_OUT,
	output RegRecycle_OUT
		); 

	// actual RAT memory
	reg [`LOG_PHYS-1:0] regPtrs [`NUM_ARCH_REGS-1:0] /*verilator public_flat*/;
	

	always @(posedge CLK or negedge RESET) begin
		if(!RESET) begin
			$display("%s:reset",ID);

			// for now, just let the RAT point to the architectural registers
			for (int i=0; i<`NUM_ARCH_REGS; i=i+1) begin
				regPtrs[i]<=i[$clog2(`NUM_ARCH_REGS)-1:0];
			end
		end else begin
			RegRecycle_OUT <= Rename_IN && AREG_IN != 0;
			if(Rename_IN && AREG_IN != 0) begin
				$display("%s:Arch[%0d]=>Phys[%0d]",ID,AREG_IN,PREG_IN);
				RegRecycleID_OUT<=regPtrs[AREG_IN]; // Let the free list know that another physical register is free
				regPtrs[AREG_IN]<=PREG_IN;
			end
			

		end
	end

	always @(*) begin
			if (BulkRead_IN) begin
				/* read register contents from bulk xfer bus */
				for (int i=0; i<`NUM_ARCH_REGS; i=i+1) begin
					regPtrs[i[$clog2(`NUM_ARCH_REGS)-1:0]]<=Bulk_IN[i[$clog2(`NUM_ARCH_REGS)-1:0]*`LOG_PHYS +: `LOG_PHYS];
				end
			end else begin
				/* dump register contents to bulk xfer bus */
				for (int i=0; i<`NUM_ARCH_REGS; i=i+1'b1) begin
					Bulk_OUT[i[$clog2(`NUM_ARCH_REGS)-1:0]*`LOG_PHYS +: `LOG_PHYS]=regPtrs[i[$clog2(`NUM_ARCH_REGS)-1:0]];
				end
			end
	end
endmodule

