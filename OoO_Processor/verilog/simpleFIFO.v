/**************************************
* Module: FIFO
* Date: 20 December, 2016
* Author: Nate
* Date: Dec 20, 2016	8:30 PM
* Description: Simplified general-purpose FIFO queue.
***************************************/

module simpleFIFO(
	input	CLK,
	input	RESET,
	input	RECOVER,
	input	NQ,
	input	DQ,
	input	FLUSH_IN,
	input	[DATA_WIDTH-1:0] Q_IN,

	output	FULL_OUT,
	output	EMPTY_OUT,
	output	[DATA_WIDTH-1:0] Q_OUT);


	parameter ID = "FIFO (rename me!)";  // change this when instantiating as appropriate to distinguish between queues
	parameter SLOTS = 8;
	parameter DATA_WIDTH = 32;
	localparam SLOTLINES=$clog2(SLOTS);


	reg [SLOTLINES-1:0] head;
	reg [SLOTLINES-1:0] tail;
	reg [SLOTLINES-1:0] size;

	reg [DATA_WIDTH-1:0] slots [0:SLOTS-1];

	wire empty;
	wire full;
	assign empty = head==tail;
	assign full = (tail+1'b1)==head;
	
	assign EMPTY_OUT = empty;
	assign FULL_OUT = full;
	
	assign Q_OUT = slots[head]; // Head is always available at the output

	always @(posedge CLK or negedge RESET) begin
	//always @(*) begin
		//$display("%s\tSize: %0d, Head: %0d (%x), Tail-: %0d (%x), NQ[%s], DQ[%s]",ID,size,head,slots[head],tail-1'b1,slots[tail-1'b1],NQ?"x":" ",DQ?"x":" ");
		if (!RESET || FLUSH_IN) begin
			$display ("%s:reset.", ID);
			head<={SLOTLINES{1'b0}};
			tail<={SLOTLINES{1'b0}};
			size<={SLOTLINES{1'b0}};
			for (int i=0; i<SLOTS; i=i+1) begin
				slots[i]<=0;
			end
		end else begin
			if (RECOVER) begin
				$display ("%s:recover.", ID);
				tail <= size>=1 && !DQ ? 1 : 0; // if queue isn't empty, set tail directly behind head, otherwise make them the same
				size <= size>=1 && !DQ ? 1 : 0;
			end else begin
				if (NQ && !full) begin
					$display("%s enqueueing: %x",ID,Q_IN);
					slots[tail] <= Q_IN;
					tail<=tail+1;
					size <= size + 1;
				end
				
				if (DQ && !empty) begin
					$display("%s dequeueing: %x",ID,Q_OUT);
					head<=head+1;
					size <= size - 1;
				end
			end
		end
$display("****");
	end

endmodule
