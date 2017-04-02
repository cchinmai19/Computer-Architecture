/**************************************
* Module: FIFO
* Date: 3 December, 2016
* Author: Nate
*
* Description: General-purpose FIFO queue. Used for ROB, etc.
***************************************/

module FIFO(
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

	always @(posedge CLK or negedge RESET) begin
		$display(" %s NQ %d , DQ %d",ID,NQ,DQ);
		//$display("%s\tSize: %0d, Head: %0d (%x), Tail-: %0d (%x), NQ[%s], DQ[%s]",ID,size,head,slots[head],tail-1'b1,slots[tail-1'b1],NQ?"x":" ",DQ?"x":" ");
		if (!RESET) begin
			$display ("%s:reset.", ID);
			head<={SLOTLINES{1'b0}};
			tail<={SLOTLINES{1'b0}};
			size<={SLOTLINES{1'b0}};
			Q_OUT<=0;
			FULL_OUT<=0;
			EMPTY_OUT<=1;
			for (int i=0; i<SLOTS; i=i+1) begin
				slots[i]<=0;
			end
		end else if (FLUSH_IN) begin
			// Does a reset, but respects simultaneous enqueues and potential dequeues
			$display ("%s:flush.", ID);
			head <= 0;
			tail <= NQ && !DQ ? 1 : 0;
			size <= NQ && !DQ ? 1 : 0;
			Q_OUT <= NQ && DQ ? Q_IN : 0;
			EMPTY_OUT<=(NQ && DQ) || !NQ;
			FULL_OUT<=0;
			slots[0] <= NQ && !DQ ? Q_IN : 0;
			for (int i=1; i<SLOTS; i=i+1) begin
				slots[i]<=0;
			end
		end else begin
			if (RECOVER) begin			// Remove everything except head
				// TODO: Allow simultaneous enqueues?
				$display ("%s:recover.", ID);
				Q_OUT <= DQ && size>=1 ? slots[head] : 0; 
				slots[0] <= slots[head];
				head<=0;
				tail <= size>=1 && !DQ ? 1 : 0;
				size <= size>=1 && !DQ ? 1 : 0;
				FULL_OUT<=0;
				EMPTY_OUT<=DQ || size==0;
			end else begin
				if (NQ && !DQ && !full) begin		// Case 1: enqueueing only
					$display("%s: Enqueueing 0x%x",ID,Q_IN);
					slots[tail] <= Q_IN;
					FULL_OUT<=(tail+1'b1==head-1'b1);				
					tail <= tail+1'b1;
					size <= size+1'b1;
					EMPTY_OUT<=0;
				end else if (DQ && !NQ && !empty) begin	// Case 2: dequeueing only
					$display("%s: Dequeueing 0x%x",ID,slots[head]);
					EMPTY_OUT<=(head+1'b1==tail);
					FULL_OUT<=0;
					Q_OUT <= slots[head];
					slots[head]<=0;
					head <= head+1'b1;
					size <= size-1'b1;
				end else if (NQ && DQ && full) begin	// Case 3: simultaneous enqueueing and dequeueing while full
					$display("%s: Enqueueing 0x%x, Dequeueing 0x%x",ID,Q_IN,slots[head]);
					Q_OUT <= slots[head];
					slots[tail] <= Q_IN;
					head <= head+1'b1;
					tail <= tail+1'b1;
					EMPTY_OUT<=0;
					FULL_OUT<=1;
				end else if (NQ && DQ && empty) begin	// Case 4: simultaneous enqueueing and dequeueing while empty (direct passthrough)
					Q_OUT <= Q_IN;
					//$display("%s: Passing 0x%x",ID,Q_IN);
					EMPTY_OUT<=1;
					FULL_OUT<=0;
				end else if (NQ && DQ) begin		// Case 5: simultaneous enqueueing and dequeueing while neither full nor empty
					$display("%s: Enqueueing 0x%x, Dequeueing 0x%x",ID,Q_IN,slots[head]);
					slots[tail] <= Q_IN;
					Q_OUT <= slots[head];
					tail <= tail+1'b1;
					head <= head+1'b1;
					EMPTY_OUT<=0;
					FULL_OUT<=0;
				end else if (NQ && full) begin
					$display ("!!!FIFO %s error: can't enqueue while full!!!", ID);
					EMPTY_OUT<=0;
					FULL_OUT<=1;
				end else if (DQ && empty) begin
					$display ("!!!FIFO %s error: can't dequeue while empty!!!", ID);
					EMPTY_OUT<=1;
					FULL_OUT<=0;
				end
			end
		end
	end

endmodule
